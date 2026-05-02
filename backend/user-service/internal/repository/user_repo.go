package repository

import (
	"context"
	"fmt"
	"strings"
	"time"

	"user-service/internal/model"

	"github.com/jackc/pgx/v5/pgxpool"
)

type UserRepository struct {
	db *pgxpool.Pool
}

func NewUserRepository(db *pgxpool.Pool) *UserRepository {
	return &UserRepository{db: db}
}

const userSelectSQL = `
	SELECT
		id, username,
		COALESCE(avatar,''), COALESCE(bio,''),
		COALESCE(website,''), COALESCE(location,''),
		COALESCE(verified,false), COALESCE(is_private,false),
		COALESCE(banned,false), COALESCE(role,'user'),
		COALESCE(posts_count,0), COALESCE(followers_count,0),
		COALESCE(following_count,0),
		last_seen,
		COALESCE(note,''), note_expires_at,
		COALESCE(note_song_title,''), COALESCE(note_song_artist,''),
		COALESCE(note_song_art_url,''), COALESCE(note_song_preview_url,''),
		COALESCE(note_song_track_ms,0), COALESCE(note_song_start_ms,0),
		COALESCE(note_song_end_ms,30000),
		created_at
	FROM users`

func (r *UserRepository) scanUser(row interface{ Scan(...any) error }) (*model.User, error) {
	u := &model.User{}
	song := &model.NoteSong{}
	err := row.Scan(
		&u.ID, &u.Username, &u.Avatar, &u.Bio,
		&u.Website, &u.Location,
		&u.Verified, &u.IsPrivate, &u.Banned, &u.Role,
		&u.PostsCount, &u.FollowersCount, &u.FollowingCount,
		&u.LastSeen,
		&u.Note, &u.NoteExpiresAt,
		&song.Title, &song.Artist, &song.ArtURL, &song.PreviewURL,
		&song.TrackMs, &song.StartMs, &song.EndMs,
		&u.CreatedAt,
	)
	if err != nil {
		return nil, err
	}
	u.NoteSong = song
	// Clear expired note
	if u.NoteExpiresAt != nil && u.NoteExpiresAt.Before(time.Now()) {
		u.Note = ""
		u.NoteExpiresAt = nil
		go r.db.Exec(context.Background(),
			`UPDATE users SET note='', note_expires_at=NULL WHERE id=$1`, u.ID)
	}
	return u, nil
}

func (r *UserRepository) GetByID(ctx context.Context, id string) (*model.User, error) {
	row := r.db.QueryRow(ctx, userSelectSQL+" WHERE id=$1 AND banned=FALSE", id)
	return r.scanUser(row)
}

func (r *UserRepository) GetByUsername(ctx context.Context, username string) (*model.User, error) {
	row := r.db.QueryRow(ctx, userSelectSQL+" WHERE username=$1 AND banned=FALSE",
		strings.ToLower(username))
	return r.scanUser(row)
}

func (r *UserRepository) UpdateProfile(ctx context.Context, userID string, req *model.UpdateProfileRequest) (*model.User, error) {
	_, err := r.db.Exec(ctx, `
		UPDATE users SET
		  bio       = COALESCE($1, bio),
		  avatar    = COALESCE($2, avatar),
		  is_private= COALESCE($3, is_private),
		  username  = COALESCE($4, username),
		  website   = COALESCE($5, website),
		  location  = COALESCE($6, location),
		  updated_at= NOW()
		WHERE id=$7`,
		req.Bio, req.Avatar, req.IsPrivate, req.Username,
		req.Website, req.Location, userID,
	)
	if err != nil {
		if strings.Contains(err.Error(), "unique") {
			return nil, fmt.Errorf("username already taken")
		}
		return nil, err
	}
	return r.GetByID(ctx, userID)
}

func (r *UserRepository) SetNote(ctx context.Context, userID string, req *model.SetNoteRequest) error {
	text := req.Note
	if len([]rune(text)) > 60 {
		text = string([]rune(text)[:60])
	}
	var title, artist, artURL, previewURL string
	var trackMs, startMs, endMs int
	endMs = 30000

	if req.Song != nil {
		title, _ = req.Song["title"].(string)
		artist, _ = req.Song["artist"].(string)
		artURL, _ = req.Song["artUrl"].(string)
		previewURL, _ = req.Song["previewUrl"].(string)
		if v, ok := req.Song["trackMs"].(float64); ok { trackMs = int(v) }
		if v, ok := req.Song["startMs"].(float64); ok { startMs = int(v) }
		if v, ok := req.Song["endMs"].(float64); ok   { endMs = int(v) }
	}

	var expires interface{}
	if text != "" || title != "" {
		expires = time.Now().Add(24 * time.Hour)
	}

	_, err := r.db.Exec(ctx, `
		UPDATE users SET
		  note=$1, note_expires_at=$2,
		  note_song_title=$3, note_song_artist=$4, note_song_art_url=$5,
		  note_song_preview_url=$6, note_song_track_ms=$7,
		  note_song_start_ms=$8, note_song_end_ms=$9
		WHERE id=$10`,
		text, expires, title, artist, artURL, previewURL,
		trackMs, startMs, endMs, userID,
	)
	return err
}

func (r *UserRepository) IsFollowing(ctx context.Context, followerID, followingID string) bool {
	var exists bool
	r.db.QueryRow(ctx,
		`SELECT EXISTS(SELECT 1 FROM follows WHERE follower_id=$1 AND following_id=$2)`,
		followerID, followingID,
	).Scan(&exists)
	return exists
}

func (r *UserRepository) Follow(ctx context.Context, followerID, followingID string) error {
	if followerID == followingID {
		return fmt.Errorf("cannot follow yourself")
	}
	// Check if target is private
	var isPrivate bool
	r.db.QueryRow(ctx, `SELECT is_private FROM users WHERE id=$1`, followingID).Scan(&isPrivate)

	if isPrivate {
		_, err := r.db.Exec(ctx,
			`INSERT INTO follow_requests(requester_id,target_id) VALUES($1,$2) ON CONFLICT DO NOTHING`,
			followerID, followingID)
		if err != nil {
			return err
		}
		return fmt.Errorf("request_sent") // Signal to handler
	}

	_, err := r.db.Exec(ctx,
		`INSERT INTO follows(follower_id,following_id) VALUES($1,$2) ON CONFLICT DO NOTHING`,
		followerID, followingID)
	if err != nil {
		return err
	}
	// Update counters
	r.db.Exec(ctx, `UPDATE users SET followers_count=followers_count+1 WHERE id=$1`, followingID)
	r.db.Exec(ctx, `UPDATE users SET following_count=following_count+1 WHERE id=$1`, followerID)
	return nil
}

func (r *UserRepository) Unfollow(ctx context.Context, followerID, followingID string) error {
	res, err := r.db.Exec(ctx,
		`DELETE FROM follows WHERE follower_id=$1 AND following_id=$2`, followerID, followingID)
	if err != nil {
		return err
	}
	if res.RowsAffected() > 0 {
		r.db.Exec(ctx, `UPDATE users SET followers_count=followers_count-1 WHERE id=$1 AND followers_count>0`, followingID)
		r.db.Exec(ctx, `UPDATE users SET following_count=following_count-1 WHERE id=$1 AND following_count>0`, followerID)
	}
	return nil
}

func (r *UserRepository) AcceptRequest(ctx context.Context, myID, requesterID string) error {
	res, err := r.db.Exec(ctx,
		`DELETE FROM follow_requests WHERE requester_id=$1 AND target_id=$2`,
		requesterID, myID)
	if err != nil || res.RowsAffected() == 0 {
		return fmt.Errorf("request not found")
	}
	r.db.Exec(ctx,
		`INSERT INTO follows(follower_id,following_id) VALUES($1,$2) ON CONFLICT DO NOTHING`,
		requesterID, myID)
	r.db.Exec(ctx, `UPDATE users SET followers_count=followers_count+1 WHERE id=$1`, myID)
	r.db.Exec(ctx, `UPDATE users SET following_count=following_count+1 WHERE id=$1`, requesterID)
	return nil
}

func (r *UserRepository) RejectRequest(ctx context.Context, myID, requesterID string) error {
	_, err := r.db.Exec(ctx,
		`DELETE FROM follow_requests WHERE requester_id=$1 AND target_id=$2`,
		requesterID, myID)
	return err
}

func (r *UserRepository) GetFollowers(ctx context.Context, userID, cursor string, limit int) ([]*model.MiniUser, string, error) {
	var rows interface{ Next() bool }
	var err error
	if cursor == "" {
		rows, err = r.db.Query(ctx, `
			SELECT u.id, u.username, COALESCE(u.avatar,''), COALESCE(u.verified,false), COALESCE(u.bio,'')
			FROM follows f JOIN users u ON u.id=f.follower_id
			WHERE f.following_id=$1
			ORDER BY f.created_at DESC LIMIT $2`, userID, limit+1)
	} else {
		rows, err = r.db.Query(ctx, `
			SELECT u.id, u.username, COALESCE(u.avatar,''), COALESCE(u.verified,false), COALESCE(u.bio,'')
			FROM follows f JOIN users u ON u.id=f.follower_id
			WHERE f.following_id=$1
			  AND f.created_at < (SELECT created_at FROM follows WHERE follower_id=$2 AND following_id=$1)
			ORDER BY f.created_at DESC LIMIT $3`, userID, cursor, limit+1)
	}
	if err != nil {
		return nil, "", err
	}
	return r.scanMiniUsers(rows, limit)
}

func (r *UserRepository) GetFollowing(ctx context.Context, userID, cursor string, limit int) ([]*model.MiniUser, string, error) {
	rows, err := r.db.Query(ctx, `
		SELECT u.id, u.username, COALESCE(u.avatar,''), COALESCE(u.verified,false), COALESCE(u.bio,'')
		FROM follows f JOIN users u ON u.id=f.following_id
		WHERE f.follower_id=$1
		ORDER BY f.created_at DESC LIMIT $2`, userID, limit+1)
	if err != nil {
		return nil, "", err
	}
	return r.scanMiniUsers(rows, limit)
}

func (r *UserRepository) SearchUsers(ctx context.Context, query string) ([]*model.MiniUser, error) {
	rows, err := r.db.Query(ctx, `
		SELECT id, username, COALESCE(avatar,''), COALESCE(verified,false), COALESCE(bio,'')
		FROM users
		WHERE username ILIKE $1 AND banned=FALSE
		ORDER BY followers_count DESC
		LIMIT 20`, query+"%")
	if err != nil {
		return nil, err
	}
	users, _, err := r.scanMiniUsers(rows, 20)
	return users, err
}

func (r *UserRepository) GetFriendsNotes(ctx context.Context, myID string) ([]map[string]interface{}, error) {
	rows, err := r.db.Query(ctx, `
		SELECT u.id, u.username, u.avatar, u.verified,
		       u.note, u.note_expires_at,
		       u.note_song_title, u.note_song_artist, u.note_song_art_url,
		       u.note_song_preview_url, u.note_song_track_ms,
		       u.note_song_start_ms, u.note_song_end_ms
		FROM follows f JOIN users u ON u.id=f.following_id
		WHERE f.follower_id=$1
		  AND u.note_expires_at > NOW()
		  AND (u.note != '' OR u.note_song_title != '')`, myID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	result := []map[string]interface{}{}
	for rows.Next() {
		var id, uname, avatar, note, stTitle, stArtist, stArtURL, stPreviewURL string
		var verified bool
		var noteExp interface{}
		var stTrackMs, stStartMs, stEndMs int
		rows.Scan(&id, &uname, &avatar, &verified, &note, &noteExp,
			&stTitle, &stArtist, &stArtURL, &stPreviewURL,
			&stTrackMs, &stStartMs, &stEndMs)
		result = append(result, map[string]interface{}{
			"_id": id, "username": uname, "avatar": avatar, "verified": verified,
			"note": note, "noteExpiresAt": noteExp,
			"noteSong": map[string]interface{}{
				"title": stTitle, "artist": stArtist, "artUrl": stArtURL,
				"previewUrl": stPreviewURL, "trackMs": stTrackMs,
				"startMs": stStartMs, "endMs": stEndMs,
			},
		})
	}
	return result, nil
}

func (r *UserRepository) DeleteUser(ctx context.Context, userID string) error {
	_, err := r.db.Exec(ctx, `DELETE FROM users WHERE id=$1`, userID)
	return err
}

func (r *UserRepository) GetPostsForUser(ctx context.Context, userID string, limit int) ([]map[string]interface{}, error) {
	rows, err := r.db.Query(ctx, `
		SELECT p.id, p.caption,
		       COALESCE(p.likes_count,0), COALESCE(p.comments_count,0),
		       p.created_at,
		       (SELECT COALESCE(json_agg(
		                json_build_object('url',m.url,'type',m.type)
		                ORDER BY m.position), '[]'::json)
		        FROM post_media m WHERE m.post_id=p.id)
		FROM posts p WHERE p.user_id=$1 AND p.hidden=FALSE
		ORDER BY p.created_at DESC LIMIT $2`, userID, limit)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	posts := []map[string]interface{}{}
	for rows.Next() {
		var pid, cap string
		var likes, comms int
		var createdAt, media interface{}
		rows.Scan(&pid, &cap, &likes, &comms, &createdAt, &media)
		posts = append(posts, map[string]interface{}{
			"_id": pid, "caption": cap,
			"likesCount": likes, "commentsCount": comms,
			"createdAt": createdAt, "media": media,
		})
	}
	return posts, nil
}

// ── helpers ───────────────────────────────────────────────────────
func (r *UserRepository) scanMiniUsers(rows interface{ Next() bool }, limit int) ([]*model.MiniUser, string, error) {
	type pgxRows interface {
		Next() bool
		Scan(...any) error
		Close()
	}
	pgRows := rows.(pgxRows)
	defer pgRows.Close()

	users := []*model.MiniUser{}
	var lastID string
	for pgRows.Next() {
		u := &model.MiniUser{}
		pgRows.Scan(&u.ID, &u.Username, &u.Avatar, &u.Verified, &u.Bio)
		users = append(users, u)
		lastID = u.ID
		if len(users) >= limit {
			break
		}
	}
	cursor := ""
	if len(users) == limit {
		cursor = lastID
	}
	return users, cursor, nil
}
