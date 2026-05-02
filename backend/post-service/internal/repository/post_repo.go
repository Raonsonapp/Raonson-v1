package repository

import (
	"context"
	"encoding/json"
	"fmt"
	"time"

	"post-service/internal/model"

	"github.com/jackc/pgx/v5/pgxpool"
)

type PostRepository struct {
	db *pgxpool.Pool
}

func NewPostRepository(db *pgxpool.Pool) *PostRepository {
	return &PostRepository{db: db}
}

// ── CREATE POST ───────────────────────────────────────────────────
func (r *PostRepository) CreatePost(ctx context.Context, userID string, req *model.CreatePostRequest) (*model.Post, error) {
	tx, err := r.db.Begin(ctx)
	if err != nil {
		return nil, err
	}
	defer tx.Rollback(ctx)

	var postID string
	err = tx.QueryRow(ctx,
		`INSERT INTO posts(user_id,caption) VALUES($1,$2) RETURNING id`,
		userID, req.Caption,
	).Scan(&postID)
	if err != nil {
		return nil, err
	}

	for i, m := range req.Media {
		url, _ := m["url"].(string)
		mtype, _ := m["type"].(string)
		if mtype == "" { mtype = "image" }
		tx.Exec(ctx,
			`INSERT INTO post_media(post_id,url,type,position) VALUES($1,$2,$3,$4)`,
			postID, url, mtype, i)
	}
	tx.Exec(ctx, `UPDATE users SET posts_count=posts_count+1 WHERE id=$1`, userID)
	if err = tx.Commit(ctx); err != nil {
		return nil, err
	}

	// Fetch user info
	var uname, uavatar string
	var verified bool
	r.db.QueryRow(ctx,
		`SELECT username, COALESCE(avatar,''), COALESCE(verified,false) FROM users WHERE id=$1`, userID,
	).Scan(&uname, &uavatar, &verified)

	media := make([]model.MediaItem, 0, len(req.Media))
	for i, m := range req.Media {
		url, _ := m["url"].(string)
		mtype, _ := m["type"].(string)
		if mtype == "" { mtype = "image" }
		media = append(media, model.MediaItem{URL: url, Type: mtype, Position: i})
	}

	return &model.Post{
		ID: postID, Caption: req.Caption,
		LikesCount: 0, CommentsCount: 0,
		Media:     media,
		CreatedAt: time.Now(),
		User: &model.PostUser{
			ID: userID, Username: uname, Avatar: uavatar, Verified: verified,
		},
	}, nil
}

// ── GET POST ──────────────────────────────────────────────────────
func (r *PostRepository) GetPostByID(ctx context.Context, postID, myID string) (*model.Post, error) {
	var p model.Post
	var u model.PostUser
	var mediaJSON interface{}
	err := r.db.QueryRow(ctx, `
		SELECT p.id, p.caption, COALESCE(p.likes_count,0), COALESCE(p.comments_count,0), p.created_at,
		  u.id, u.username, COALESCE(u.avatar,''), COALESCE(u.verified,false),
		  (SELECT COALESCE(json_agg(
		     json_build_object('url',m.url,'type',m.type)
		     ORDER BY m.position),'[]'::json)
		   FROM post_media m WHERE m.post_id=p.id) AS media,
		  EXISTS(SELECT 1 FROM post_likes WHERE post_id=p.id AND user_id=$2) AS liked,
		  EXISTS(SELECT 1 FROM post_saves  WHERE post_id=p.id AND user_id=$2) AS saved
		FROM posts p JOIN users u ON u.id=p.user_id
		WHERE p.id=$1 AND p.hidden=FALSE`, postID, myID,
	).Scan(&p.ID, &p.Caption, &p.LikesCount, &p.CommentsCount, &p.CreatedAt,
		&u.ID, &u.Username, &u.Avatar, &u.Verified,
		&mediaJSON, &p.Liked, &p.Saved)
	if err != nil {
		return nil, err
	}
	p.User = &u
	if mediaJSON != nil {
		b, _ := json.Marshal(mediaJSON)
		json.Unmarshal(b, &p.Media)
	}
	return &p, nil
}

// ── DELETE POST ───────────────────────────────────────────────────
func (r *PostRepository) DeletePost(ctx context.Context, postID, userID string) error {
	res, err := r.db.Exec(ctx,
		`DELETE FROM posts WHERE id=$1 AND user_id=$2`, postID, userID)
	if err != nil {
		return err
	}
	if res.RowsAffected() == 0 {
		return fmt.Errorf("not found or not owner")
	}
	r.db.Exec(ctx, `UPDATE users SET posts_count=posts_count-1 WHERE id=$1 AND posts_count>0`, userID)
	return nil
}

// ── UPDATE CAPTION ────────────────────────────────────────────────
func (r *PostRepository) UpdateCaption(ctx context.Context, postID, userID, caption string) error {
	res, err := r.db.Exec(ctx,
		`UPDATE posts SET caption=$1, updated_at=NOW() WHERE id=$2 AND user_id=$3`,
		caption, postID, userID)
	if err != nil {
		return err
	}
	if res.RowsAffected() == 0 {
		return fmt.Errorf("not found or not owner")
	}
	return nil
}

// ── TOGGLE LIKE ───────────────────────────────────────────────────
func (r *PostRepository) ToggleLike(ctx context.Context, postID, userID string) (bool, int64, error) {
	var liked bool
	r.db.QueryRow(ctx,
		`SELECT EXISTS(SELECT 1 FROM post_likes WHERE user_id=$1 AND post_id=$2)`,
		userID, postID).Scan(&liked)

	if liked {
		r.db.Exec(ctx, `DELETE FROM post_likes WHERE user_id=$1 AND post_id=$2`, userID, postID)
		r.db.Exec(ctx, `UPDATE posts SET likes_count=likes_count-1 WHERE id=$1 AND likes_count>0`, postID)
		return false, 0, nil
	}
	r.db.Exec(ctx, `INSERT INTO post_likes(user_id,post_id) VALUES($1,$2) ON CONFLICT DO NOTHING`, userID, postID)
	var count int64
	r.db.Exec(ctx, `UPDATE posts SET likes_count=likes_count+1 WHERE id=$1 RETURNING likes_count`, postID)
	r.db.QueryRow(ctx, `SELECT likes_count FROM posts WHERE id=$1`, postID).Scan(&count)
	return true, count, nil
}

// ── TOGGLE SAVE ───────────────────────────────────────────────────
func (r *PostRepository) ToggleSave(ctx context.Context, postID, userID string) (bool, error) {
	var saved bool
	r.db.QueryRow(ctx,
		`SELECT EXISTS(SELECT 1 FROM post_saves WHERE user_id=$1 AND post_id=$2)`,
		userID, postID).Scan(&saved)

	if saved {
		r.db.Exec(ctx, `DELETE FROM post_saves WHERE user_id=$1 AND post_id=$2`, userID, postID)
		return false, nil
	}
	r.db.Exec(ctx, `INSERT INTO post_saves(user_id,post_id) VALUES($1,$2) ON CONFLICT DO NOTHING`, userID, postID)
	return true, nil
}

// ── REPORT POST ───────────────────────────────────────────────────
func (r *PostRepository) ReportPost(ctx context.Context, postID, userID, reason string) error {
	r.db.Exec(ctx,
		`INSERT INTO post_reports(post_id,user_id,reason,created_at)
		 VALUES($1,$2,$3,NOW()) ON CONFLICT DO NOTHING`,
		postID, userID, reason)
	var count int
	r.db.QueryRow(ctx, `SELECT COUNT(*) FROM post_reports WHERE post_id=$1`, postID).Scan(&count)
	if count >= 10 {
		r.db.Exec(ctx, `UPDATE posts SET hidden=TRUE WHERE id=$1`, postID)
	}
	return nil
}

// ── TRACK VIEW ────────────────────────────────────────────────────
func (r *PostRepository) TrackView(ctx context.Context, postID, userID string) {
	r.db.Exec(ctx,
		`INSERT INTO post_views(user_id,post_id) VALUES($1,$2) ON CONFLICT DO NOTHING`,
		userID, postID)
}

// ── GET COMMENTS ──────────────────────────────────────────────────
func (r *PostRepository) GetComments(ctx context.Context, postID, myID, cursor string, limit int) ([]*model.Comment, string, error) {
	var rows interface{ Next() bool }
	var err error
	if cursor == "" {
		rows, err = r.db.Query(ctx, `
			SELECT c.id, c.text, COALESCE(c.likes_count,0), c.created_at,
			  u.id, u.username, COALESCE(u.avatar,''), COALESCE(u.verified,false),
			  EXISTS(SELECT 1 FROM comment_likes WHERE comment_id=c.id AND user_id=$2) AS liked
			FROM comments c JOIN users u ON u.id=c.user_id
			WHERE c.post_id=$1
			ORDER BY c.created_at DESC LIMIT $3`, postID, myID, limit+1)
	} else {
		rows, err = r.db.Query(ctx, `
			SELECT c.id, c.text, COALESCE(c.likes_count,0), c.created_at,
			  u.id, u.username, COALESCE(u.avatar,''), COALESCE(u.verified,false),
			  EXISTS(SELECT 1 FROM comment_likes WHERE comment_id=c.id AND user_id=$2) AS liked
			FROM comments c JOIN users u ON u.id=c.user_id
			WHERE c.post_id=$1
			  AND c.created_at < (SELECT created_at FROM comments WHERE id=$3)
			ORDER BY c.created_at DESC LIMIT $4`, postID, myID, cursor, limit+1)
	}
	if err != nil {
		return nil, "", err
	}
	type pgxRows interface {
		Next() bool; Scan(...any) error; Close()
	}
	pgRows := rows.(pgxRows)
	defer pgRows.Close()

	comments := []*model.Comment{}
	var lastID string
	for pgRows.Next() {
		cm := &model.Comment{User: &model.PostUser{}}
		pgRows.Scan(&cm.ID, &cm.Text, &cm.LikesCount, &cm.CreatedAt,
			&cm.User.ID, &cm.User.Username, &cm.User.Avatar, &cm.User.Verified,
			&cm.Liked)
		comments = append(comments, cm)
		lastID = cm.ID
		if len(comments) >= limit { break }
	}
	nextCursor := ""
	if len(comments) == limit { nextCursor = lastID }
	return comments, nextCursor, nil
}

// ── ADD COMMENT ───────────────────────────────────────────────────
func (r *PostRepository) AddComment(ctx context.Context, postID, userID, text string) (*model.Comment, error) {
	var commentID string
	err := r.db.QueryRow(ctx,
		`INSERT INTO comments(post_id,user_id,text) VALUES($1,$2,$3) RETURNING id`,
		postID, userID, text).Scan(&commentID)
	if err != nil {
		return nil, err
	}
	r.db.Exec(ctx, `UPDATE posts SET comments_count=comments_count+1 WHERE id=$1`, postID)

	var uname, uavatar string
	var verified bool
	r.db.QueryRow(ctx,
		`SELECT username, COALESCE(avatar,''), COALESCE(verified,false) FROM users WHERE id=$1`, userID,
	).Scan(&uname, &uavatar, &verified)

	return &model.Comment{
		ID: commentID, Text: text, CreatedAt: time.Now(),
		User: &model.PostUser{ID: userID, Username: uname, Avatar: uavatar, Verified: verified},
	}, nil
}

// ── DELETE COMMENT ────────────────────────────────────────────────
func (r *PostRepository) DeleteComment(ctx context.Context, commentID, userID string) error {
	var postID string
	err := r.db.QueryRow(ctx,
		`DELETE FROM comments WHERE id=$1 AND user_id=$2 RETURNING post_id`,
		commentID, userID).Scan(&postID)
	if err != nil {
		return fmt.Errorf("not found or not owner")
	}
	r.db.Exec(ctx, `UPDATE posts SET comments_count=comments_count-1 WHERE id=$1 AND comments_count>0`, postID)
	return nil
}

// ── TOGGLE COMMENT LIKE ───────────────────────────────────────────
func (r *PostRepository) ToggleCommentLike(ctx context.Context, commentID, userID string) (bool, error) {
	var liked bool
	r.db.QueryRow(ctx,
		`SELECT EXISTS(SELECT 1 FROM comment_likes WHERE user_id=$1 AND comment_id=$2)`,
		userID, commentID).Scan(&liked)
	if liked {
		r.db.Exec(ctx, `DELETE FROM comment_likes WHERE user_id=$1 AND comment_id=$2`, userID, commentID)
		r.db.Exec(ctx, `UPDATE comments SET likes_count=likes_count-1 WHERE id=$1 AND likes_count>0`, commentID)
		return false, nil
	}
	r.db.Exec(ctx, `INSERT INTO comment_likes(user_id,comment_id) VALUES($1,$2) ON CONFLICT DO NOTHING`, userID, commentID)
	r.db.Exec(ctx, `UPDATE comments SET likes_count=likes_count+1 WHERE id=$1`, commentID)
	return true, nil
}

// ── GET USER POSTS ────────────────────────────────────────────────
func (r *PostRepository) GetUserPosts(ctx context.Context, userID, cursor string, limit int) ([]*model.Post, string, error) {
	var rows interface{ Next() bool }
	var err error
	if cursor == "" {
		rows, err = r.db.Query(ctx, `
			SELECT p.id, p.caption, COALESCE(p.likes_count,0), COALESCE(p.comments_count,0), p.created_at,
			  (SELECT COALESCE(json_agg(json_build_object('url',m.url,'type',m.type) ORDER BY m.position),'[]'::json)
			   FROM post_media m WHERE m.post_id=p.id)
			FROM posts p WHERE p.user_id=$1 AND p.hidden=FALSE
			ORDER BY p.created_at DESC LIMIT $2`, userID, limit+1)
	} else {
		rows, err = r.db.Query(ctx, `
			SELECT p.id, p.caption, COALESCE(p.likes_count,0), COALESCE(p.comments_count,0), p.created_at,
			  (SELECT COALESCE(json_agg(json_build_object('url',m.url,'type',m.type) ORDER BY m.position),'[]'::json)
			   FROM post_media m WHERE m.post_id=p.id)
			FROM posts p WHERE p.user_id=$1 AND p.hidden=FALSE
			  AND p.created_at < (SELECT created_at FROM posts WHERE id=$2)
			ORDER BY p.created_at DESC LIMIT $3`, userID, cursor, limit+1)
	}
	if err != nil {
		return nil, "", err
	}
	type pgxRows interface { Next() bool; Scan(...any) error; Close() }
	pgRows := rows.(pgxRows)
	defer pgRows.Close()

	posts := []*model.Post{}
	var lastID string
	for pgRows.Next() {
		p := &model.Post{}
		var mediaJSON interface{}
		pgRows.Scan(&p.ID, &p.Caption, &p.LikesCount, &p.CommentsCount, &p.CreatedAt, &mediaJSON)
		if mediaJSON != nil {
			b, _ := json.Marshal(mediaJSON)
			json.Unmarshal(b, &p.Media)
		}
		posts = append(posts, p)
		lastID = p.ID
		if len(posts) >= limit { break }
	}
	nextCursor := ""
	if len(posts) == limit { nextCursor = lastID }
	return posts, nextCursor, nil
}
