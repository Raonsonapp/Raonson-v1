package service

import (
	"context"
	"encoding/json"
	"fmt"
	"time"

	"post-service/internal/model"
	"post-service/internal/repository"
	"post-service/pkg/httpclient"
	"post-service/pkg/logger"
	rdb "post-service/pkg/redis"

	"go.uber.org/zap"
)

type Service struct {
	repo     *repository.PostRepository
	feedCli  *httpclient.Client
	notifCli *httpclient.Client
}

func New(repo *repository.PostRepository, feedURL, notifURL string) *Service {
	return &Service{
		repo:     repo,
		feedCli:  httpclient.New(feedURL, 3*time.Second, 3),
		notifCli: httpclient.New(notifURL, 3*time.Second, 3),
	}
}

// ── CREATE POST ───────────────────────────────────────────────────
func (s *Service) CreatePost(ctx context.Context, userID string, req *model.CreatePostRequest) (*model.Post, error) {
	post, err := s.repo.CreatePost(ctx, userID, req)
	if err != nil {
		return nil, err
	}
	reqID, _ := ctx.Value("requestID").(string)
	go s.cachePost(post)
	go s.fanOut(post, reqID)
	return post, nil
}

// ── GET POST ──────────────────────────────────────────────────────
func (s *Service) GetPost(ctx context.Context, postID, myID string) (*model.Post, bool, error) {
	if data, err := rdb.Get("post:" + postID); err == nil {
		var p model.Post
		if json.Unmarshal([]byte(data), &p) == nil {
			return &p, true, nil // true = from cache
		}
	}
	p, err := s.repo.GetPostByID(ctx, postID, myID)
	if err != nil {
		return nil, false, err
	}
	go s.cachePost(p)
	return p, false, nil
}

// ── DELETE POST ───────────────────────────────────────────────────
func (s *Service) DeletePost(ctx context.Context, postID, userID string) error {
	err := s.repo.DeletePost(ctx, postID, userID)
	if err == nil {
		go rdb.Del("post:"+postID, "post:likes:"+postID)
	}
	return err
}

// ── UPDATE CAPTION ────────────────────────────────────────────────
func (s *Service) UpdateCaption(ctx context.Context, postID, userID, caption string) error {
	err := s.repo.UpdateCaption(ctx, postID, userID, caption)
	if err == nil {
		go rdb.Del("post:" + postID)
	}
	return err
}

// ── TOGGLE LIKE ───────────────────────────────────────────────────
func (s *Service) ToggleLike(ctx context.Context, postID, userID string) (bool, int64, error) {
	likeKey := "post:likes:" + postID

	if rdb.SIsMember(likeKey, userID) {
		rdb.SRem(likeKey, userID)
		count := rdb.Decr("post:likes_count:" + postID)
		go s.repo.ToggleLike(context.Background(), postID, userID)
		return false, count, nil
	}

	rdb.SAdd(likeKey, userID, 24*time.Hour)
	count := rdb.Incr("post:likes_count:"+postID, 24*time.Hour)
	go s.repo.ToggleLike(context.Background(), postID, userID)

	// Send like notification
	reqID, _ := ctx.Value("requestID").(string)
	go s.sendNotif(postID, userID, "like", reqID)
	return true, count, nil
}

// ── TOGGLE SAVE ───────────────────────────────────────────────────
func (s *Service) ToggleSave(ctx context.Context, postID, userID string) (bool, error) {
	return s.repo.ToggleSave(ctx, postID, userID)
}

// ── REPORT POST ───────────────────────────────────────────────────
func (s *Service) ReportPost(ctx context.Context, postID, userID, reason string) error {
	return s.repo.ReportPost(ctx, postID, userID, reason)
}

// ── TRACK VIEW ────────────────────────────────────────────────────
func (s *Service) TrackView(ctx context.Context, postID, userID string) {
	viewKey := "viewed:" + userID
	if rdb.SIsMember(viewKey, postID) {
		return
	}
	rdb.SAdd(viewKey, postID, 24*time.Hour)
	go s.repo.TrackView(context.Background(), postID, userID)
}

// ── COMMENTS ─────────────────────────────────────────────────────
func (s *Service) GetComments(ctx context.Context, postID, myID, cursor string) ([]*model.Comment, string, error) {
	cacheKey := fmt.Sprintf("comments:%s:%s", postID, cursor)
	if cursor == "" {
		if data, err := rdb.Get(cacheKey); err == nil {
			var res struct {
				Comments []*model.Comment `json:"comments"`
				Cursor   string           `json:"cursor"`
			}
			if json.Unmarshal([]byte(data), &res) == nil {
				return res.Comments, res.Cursor, nil
			}
		}
	}
	comments, next, err := s.repo.GetComments(ctx, postID, myID, cursor, 20)
	if err != nil {
		return nil, "", err
	}
	if cursor == "" {
		if b, e := json.Marshal(map[string]interface{}{"comments": comments, "cursor": next}); e == nil {
			go rdb.Set(cacheKey, string(b), 30*time.Second)
		}
	}
	return comments, next, nil
}

func (s *Service) AddComment(ctx context.Context, postID, userID, text string) (*model.Comment, error) {
	c, err := s.repo.AddComment(ctx, postID, userID, text)
	if err != nil {
		return nil, err
	}
	go rdb.Del("comments:" + postID + ":")
	reqID, _ := ctx.Value("requestID").(string)
	go s.sendNotif(postID, userID, "comment", reqID)
	return c, nil
}

func (s *Service) DeleteComment(ctx context.Context, commentID, userID string) error {
	return s.repo.DeleteComment(ctx, commentID, userID)
}

func (s *Service) ToggleCommentLike(ctx context.Context, commentID, userID string) (bool, error) {
	return s.repo.ToggleCommentLike(ctx, commentID, userID)
}

func (s *Service) GetUserPosts(ctx context.Context, userID, cursor string) ([]*model.Post, string, error) {
	return s.repo.GetUserPosts(ctx, userID, cursor, 24)
}

// ── private: fan-out to feed-service with retry ───────────────────
func (s *Service) fanOut(post *model.Post, reqID string) {
	if s.feedCli == nil {
		return
	}
	payload := map[string]interface{}{
		"postID": post.ID,
		"userID": post.User.ID,
		"post":   post,
		"score":  float64(post.CreatedAt.Unix()),
	}
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	if err := s.feedCli.Post(ctx, "/internal/fanout", payload, reqID); err != nil {
		logger.Error("fan-out failed", zap.Error(err), zap.String("postID", post.ID))
	}
}

// ── private: send notification with retry ────────────────────────
func (s *Service) sendNotif(targetID, fromUserID, nType, reqID string) {
	if s.notifCli == nil {
		return
	}
	payload := map[string]interface{}{
		"fromUserID": fromUserID,
		"targetID":   targetID,
		"type":       nType,
	}
	ctx, cancel := context.WithTimeout(context.Background(), 3*time.Second)
	defer cancel()
	if err := s.notifCli.Post(ctx, "/internal/notify", payload, reqID); err != nil {
		logger.Error("notification failed", zap.Error(err), zap.String("type", nType))
	}
}

func (s *Service) cachePost(post *model.Post) {
	if b, err := json.Marshal(post); err == nil {
		rdb.Set("post:"+post.ID, string(b), 7*24*time.Hour)
	}
}
