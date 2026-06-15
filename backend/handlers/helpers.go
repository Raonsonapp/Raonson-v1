package handlers

import (
	"context"
	"log"
	"strings"
	"strconv"

	"raonson/db"
	"github.com/gin-gonic/gin"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgconn"
)

const userSelectSQL = `
	SELECT id, username,
	       COALESCE(avatar,''), COALESCE(bio,''),
	       COALESCE(verified,false), COALESCE(is_private,false),
	       COALESCE(role,'user'),
	       COALESCE(posts_count,0), COALESCE(followers_count,0),
	       COALESCE(following_count,0), last_seen,
	       COALESCE(banned,false),
	       COALESCE(note,''), note_expires_at,
	       COALESCE(note_song_title,''), COALESCE(note_song_artist,''),
	       COALESCE(note_song_art_url,''), COALESCE(note_song_preview_url,''),
	       COALESCE(note_song_track_ms,0), COALESCE(note_song_start_ms,0),
	       COALESCE(note_song_end_ms,30000),
	       COALESCE(website,''), COALESCE(location,''),
	       COALESCE(full_name,''), COALESCE(phone,'')
	FROM users`

func scanFullUser(row pgx.Row) (gin.H, error) {
	var (
		id, username, avatar, bio, role string
		verified, isPrivate, banned     bool
		postsCount, followersCount, followingCount int
		lastSeen                        interface{}
		note                            string
		noteExpiresAt                   interface{}
		stTitle, stArtist, stArtUrl, stPreviewUrl string
		stTrackMs, stStartMs, stEndMs   int
		website, location               string
		fullName, phone                 string
	)
	err := row.Scan(
		&id, &username, &avatar, &bio, &verified, &isPrivate, &role,
		&postsCount, &followersCount, &followingCount, &lastSeen,
		&banned, &note, &noteExpiresAt,
		&stTitle, &stArtist, &stArtUrl, &stPreviewUrl,
		&stTrackMs, &stStartMs, &stEndMs,
		&website, &location, &fullName, &phone,
	)
	if err != nil {
		log.Printf("[scanFullUser] error: %v", err)
		return nil, err
	}
	return gin.H{
		"_id": id, "id": id,
		"username": username, "avatar": avatar, "bio": bio,
		"verified": verified, "isPrivate": isPrivate,
		"role": role, "banned": banned,
		"postsCount": postsCount,
		"followersCount": followersCount,
		"followingCount": followingCount,
		"lastSeen": lastSeen,
		"isFollowing": false,
		"website": website, "location": location,
		"fullName": fullName, "phone": phone,
		"note": note, "noteExpiresAt": noteExpiresAt,
		"noteSong": gin.H{
			"title": stTitle, "artist": stArtist,
			"artUrl": stArtUrl, "previewUrl": stPreviewUrl,
			"trackMs": stTrackMs, "startMs": stStartMs, "endMs": stEndMs,
		},
	}, nil
}

func getUserByID(id string) (gin.H, error) {
	row := db.Pool.QueryRow(context.Background(),
		userSelectSQL+" WHERE id=$1", id)
	return scanFullUser(row)
}

func miniUser(rows pgx.Rows) []gin.H {
	out := []gin.H{}
	for rows.Next() {
		var id, uname, avatar, bio string
		var verified bool
		rows.Scan(&id, &uname, &avatar, &verified, &bio)
		out = append(out, gin.H{
			"_id": id, "id": id,
			"username": uname, "avatar": avatar,
			"verified": verified, "bio": bio,
		})
	}
	return out
}

func setIsFollowing(u gin.H, myID, targetID string) {
	var isFollowing bool
	db.Pool.QueryRow(context.Background(),
		`SELECT EXISTS(SELECT 1 FROM follows WHERE follower_id=$1::text AND following_id=$2::text)`,
		myID, targetID).Scan(&isFollowing)
	u["isFollowing"] = isFollowing
}

func postsForUser(userID string, limit int) []gin.H {
	rows, err := db.Pool.Query(context.Background(), `
		SELECT p.id, p.caption,
		       COALESCE(p.likes_count,0), COALESCE(p.comments_count,0),
		       p.created_at,
		       (SELECT COALESCE(json_agg(
		                json_build_object('url',m.url,'type',m.type)
		                ORDER BY m.position), '[]'::json)
		        FROM post_media m WHERE m.post_id=p.id)
		FROM posts p WHERE p.user_id=$1 AND COALESCE(p.archived,false)=FALSE
		ORDER BY p.created_at DESC LIMIT $2`, userID, limit)
	if err != nil {
		log.Printf("[postsForUser] error: %v", err)
		return []gin.H{}
	}
	defer rows.Close()
	return scanPostRows(rows, "")
}

func scanPostRows(rows pgx.Rows, myID string) []gin.H {
	out := []gin.H{}
	for rows.Next() {
		var pid, cap string
		var likes, comms int
		var createdAt, media interface{}
		if err := rows.Scan(&pid, &cap, &likes, &comms, &createdAt, &media); err != nil {
			log.Printf("[scanPostRows] error: %v", err)
			continue
		}
		out = append(out, gin.H{
			"_id": pid, "caption": cap,
			"likesCount": likes, "commentsCount": comms,
			"createdAt": createdAt, "media": nilToEmpty(media),
		})
	}
	return out
}

func nilToEmpty(v interface{}) interface{} {
	if v == nil { return []interface{}{} }
	return v
}

func toInt(s string, def int) int {
	if n, err := strconv.Atoi(s); err == nil && n > 0 { return n }
	return def
}

func isUnique(err error) bool {
	if pgErr, ok := err.(*pgconn.PgError); ok {
		return pgErr.Code == "23505"
	}
	return strings.Contains(err.Error(), "unique")
}

func sortedChatID(a, b string) string {
	if a < b { return a + "_" + b }
	return b + "_" + a
}
