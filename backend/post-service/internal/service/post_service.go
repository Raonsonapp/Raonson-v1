package service

import (
	"bytes"
	"context"
	"encoding/json"
	"log"
	"net/http"
	"os"
	"strconv"
	"time"

	"post-service/internal/model"
	"post-service/internal/repository"
	rdb "post-service/pkg/redis"
)

type PostService struct {
	repo            *repository.PostRepository
	feedServiceURL  string
	notifServiceURL string
}

func NewPostService(repo *repository.PostRepository) *PostService {
	return &PostService{
		repo:            repo,
		feedServiceURL:  os.Getenv("FEED_SERVICE_URL"),
		notifServiceURL: os.Getenv("NOTIFICATION_SERVICE_URL"),
	}
}

// ── CREATE POST ───────────────────────────────────────────────────
func (s *PostService) CreatePost(ctx context.Context, userID string, req *model.CreatePostRequest) (*model.Post, error) {
	post, err := s.repo.CreatePost(ctx, userID, req)
	if err != nil {
		return nil, err
	}
	// Async: cache post + fan-out to feed-service
	go s.cachePost(post)
	go s.fanOut(post)
	return post, nil
}

// ── GET POST ──────────────────────────────────────────────────────
func (s *PostService) GetPost(ctx context.Context, postID, myID string) (*model.Post, error) {
	cacheKey := "post:" + postID
	if cached, err := rdb.Get(cacheKey); err == nil {
		var p model.Post
		if json.Unmarshal([]byte(cached), &p) == nil {
			c.Header = // can't set header here; caller sets X-Cache
			return &p, nil
		}
	}
	return s.repo.GetPostByID(ctx, postID, myID)
}

// ── DELETE POST ───────────────────────────────────────────────────
func (s *PostService) DeletePost(ctx context.Context, postID, userID string) error {
	err := s.repo.DeletePost(ctx, postID, userID)
	if err == nil {
		go rdb.Del("post:"+postID, "post:likes:"+postID)
	}
	return err
}

// ── UPDATE CAPTION ────────────────────────────────────────────────
func (s *PostService) UpdateCaption(ctx context.Context, postID, userID, caption string) error {
	err := s.repo.UpdateCaption(ctx, postID, userID, caption)
	if err == nil {
		go rdb.Del("post:" + postID)
	}
	return err
}

// ── TOGGLE LIKE ───────────────────────────────────────────────────
func (s *PostService) ToggleLike(ctx context.Context, postID, userID string) (bool, int64, error) {
	// Use Redis for fast like count
	likeKey := "post:likes:" + postID
	isLiked := rdb.SIsMember(likeKey, userID)

	if isLiked {
		rdb.SRem(likeKey, userID)
		count, _ := strconv.ParseInt(rdb.DecrBy("post:likes_count:"+postID, 1), 10, 64)
		go s.repo.ToggleLike(ctx, postID, userID)
		return false, count, nil
	}

	rdb.SAdd(likeKey, userID, 24*time.Hour)
	count, _ := strconv.ParseInt(rdb.IncrBy("post:likes_count:"+postID, 1, 24*time.Hour), 10, 64)
	go s.repo.ToggleLike(ctx, postID, userID)
	// Send notification async
	go s.sendNotification(postID, userID, "like")
	return true, count, nil
}

// ── TOGGLE SAVE ───────────────────────────────────────────────────
func (s *PostService) ToggleSave(ctx context.Context, postID, userID string) (bool, error) {
	return s.repo.ToggleSave(ctx, postID, userID)
}

// ── REPORT POST ───────────────────────────────────────────────────
func (s *PostService) ReportPost(ctx context.Context, postID, userID, reason string) error {
	return s.repo.ReportPost(ctx, postID, userID, reason)
}

// ── TRACK VIEW ────────────────────────────────────────────────────
func (s *PostService) TrackView(ctx context.Context, postID, userID string) {
	viewKey := "viewed:" + userID
	if rdb.SIsMember(viewKey, postID) {
		return
	}
	rdb.SAdd(viewKey, postID, 24*time.Hour)
	go s.repo.TrackView(ctx, postID, userID)
}

// ── COMMENTS ──────────────────────────────────────────────────────
func (s *PostService) GetComments(ctx context.Context, postID, myID, cursor string) ([]*model.Comment, string, error) {
	cacheKey := "comments:" + postID + ":" + cursor
	if cursor == "" {
		if cached, err := rdb.Get(cacheKey); err == nil {
			var result struct {
				Comments []*model.Comment `json:"comments"`
				Cursor   string           `json:"cursor"`
			}
			if json.Unmarshal([]byte(cached), &result) == nil {
				return result.Comments, result.Cursor, nil
			}
		}
	}
	comments, nextCursor, err := s.repo.GetComments(ctx, postID, myID, cursor, 20)
	if err != nil {
		return nil, "", err
	}
	if cursor == "" {
		if b, err := json.Marshal(map[string]interface{}{"comments": comments, "cursor": nextCursor}); err == nil {
			go rdb.Set(cacheKey, string(b), 30*time.Second)
		}
	}
	return comments, nextCursor, nil
}

func (s *PostService) AddComment(ctx context.Context, postID, userID, text string) (*model.Comment, error) {
	comment, err := s.repo.AddComment(ctx, postID, userID, text)
	if err != nil {
		return nil, err
	}
	go rdb.Del("comments:" + postID + ":")
	go s.sendNotification(postID, userID, "comment")
	return comment, nil
}

func (s *PostService) DeleteComment(ctx context.Context, commentID, userID string) error {
	return s.repo.DeleteComment(ctx, commentID, userID)
}

func (s *PostService) ToggleCommentLike(ctx context.Context, commentID, userID string) (bool, error) {
	return s.repo.ToggleCommentLike(ctx, commentID, userID)
}

func (s *PostService) GetUserPosts(ctx context.Context, userID, cursor string) ([]*model.Post, string, error) {
	return s.repo.GetUserPosts(ctx, userID, cursor, 24)
}

// ── HTTP fan-out to feed-service ─────────────────────────────────
func (s *PostService) fanOut(post *model.Post) {
	if s.feedServiceURL == "" {
		return
	}
	payload := map[string]interface{}{
		"postID": post.ID,
		"userID": post.User.ID,
		"post":   post,
		"score":  float64(post.CreatedAt.Unix()),
	}
	b, _ := json.Marshal(payload)
	resp, err := http.Post(
		s.feedServiceURL+"/internal/fanout",
		"application/json",
		bytes.NewReader(b),
	)
	if err != nil {
		log.Printf("[post-service] fan-out error: %v", err)
		return
	}
	resp.Body.Close()
}

// ── HTTP notification to notification-service ─────────────────────
func (s *PostService) sendNotification(targetID, fromUserID, nType string) {
	if s.notifServiceURL == "" {
		return
	}
	// Get post owner ID
	// (in production: fetch from DB or cache)
	payload := map[string]interface{}{
		"fromUserID": fromUserID,
		"targetID":   targetID,
		"type":       nType,
	}
	b, _ := json.Marshal(payload)
	resp, err := http.Post(
		s.notifServiceURL+"/internal/notify",
		"application/json",
		bytes.NewReader(b),
	)
	if err != nil {
		log.Printf("[post-service] notify error: %v", err)
		return
	}
	resp.Body.Close()
}

func (s *PostService) cachePost(post *model.Post) {
	b, err := json.Marshal(post)
	if err != nil {
		return
	}
	rdb.Set("post:"+post.ID, string(b), 7*24*time.Hour)
}
