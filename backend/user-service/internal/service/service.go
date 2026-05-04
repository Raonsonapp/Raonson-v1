package service

import (
	"context"
	"encoding/json"
	"time"

	"user-service/internal/model"
	"user-service/internal/repository"
	rdb "user-service/pkg/redis"
)

type UserService struct {
	repo *repository.UserRepository
}

func NewUserService(repo *repository.UserRepository) *UserService {
	return &UserService{repo: repo}
}

func (s *UserService) GetMyProfile(ctx context.Context, myID string) (*model.User, []map[string]interface{}, error) {
	cacheKey := "profile:" + myID
	if cached, err := rdb.Get(cacheKey); err == nil {
		var u model.User
		if json.Unmarshal([]byte(cached), &u) == nil {
			posts, _ := s.repo.GetPostsForUser(ctx, myID, 30)
			return &u, posts, nil
		}
	}
	u, err := s.repo.GetByID(ctx, myID)
	if err != nil {
		return nil, nil, err
	}
	u.IsFollowing = false
	go s.cacheProfile(u)
	posts, _ := s.repo.GetPostsForUser(ctx, myID, 30)
	return u, posts, nil
}

func (s *UserService) GetProfileByUsername(ctx context.Context, username, myID string) (*model.User, []map[string]interface{}, error) {
	u, err := s.repo.GetByUsername(ctx, username)
	if err != nil {
		return nil, nil, err
	}
	u.IsFollowing = s.repo.IsFollowing(ctx, myID, u.ID)
	posts, _ := s.repo.GetPostsForUser(ctx, u.ID, 30)
	return u, posts, nil
}

func (s *UserService) GetUserByID(ctx context.Context, targetID, myID string) (*model.User, error) {
	cacheKey := "profile:" + targetID
	if cached, err := rdb.Get(cacheKey); err == nil {
		var u model.User
		if json.Unmarshal([]byte(cached), &u) == nil {
			u.IsFollowing = s.repo.IsFollowing(ctx, myID, targetID)
			return &u, nil
		}
	}
	u, err := s.repo.GetByID(ctx, targetID)
	if err != nil {
		return nil, err
	}
	u.IsFollowing = s.repo.IsFollowing(ctx, myID, targetID)
	go s.cacheProfile(u)
	return u, nil
}

func (s *UserService) UpdateProfile(ctx context.Context, myID string, req *model.UpdateProfileRequest) (*model.User, error) {
	u, err := s.repo.UpdateProfile(ctx, myID, req)
	if err != nil {
		return nil, err
	}
	// Invalidate cache
	go rdb.Del("profile:"+myID)
	return u, nil
}

func (s *UserService) SetNote(ctx context.Context, myID string, req *model.SetNoteRequest) error {
	err := s.repo.SetNote(ctx, myID, req)
	if err == nil {
		go rdb.Del("profile:"+myID)
	}
	return err
}

func (s *UserService) Follow(ctx context.Context, myID, targetID string) (string, error) {
	err := s.repo.Follow(ctx, myID, targetID)
	if err != nil {
		if err.Error() == "request_sent" {
			return "requested", nil
		}
		return "", err
	}
	// Invalidate both profiles
	go rdb.Del("profile:"+myID, "profile:"+targetID)
	return "following", nil
}

func (s *UserService) Unfollow(ctx context.Context, myID, targetID string) error {
	err := s.repo.Unfollow(ctx, myID, targetID)
	if err == nil {
		go rdb.Del("profile:"+myID, "profile:"+targetID)
	}
	return err
}

func (s *UserService) GetFollowers(ctx context.Context, userID, cursor string) ([]*model.MiniUser, string, error) {
	return s.repo.GetFollowers(ctx, userID, cursor, 20)
}

func (s *UserService) GetFollowing(ctx context.Context, userID, cursor string) ([]*model.MiniUser, string, error) {
	return s.repo.GetFollowing(ctx, userID, cursor, 20)
}

func (s *UserService) AcceptRequest(ctx context.Context, myID, requesterID string) error {
	err := s.repo.AcceptRequest(ctx, myID, requesterID)
	if err == nil {
		go rdb.Del("profile:"+myID, "profile:"+requesterID)
	}
	return err
}

func (s *UserService) RejectRequest(ctx context.Context, myID, requesterID string) error {
	return s.repo.RejectRequest(ctx, myID, requesterID)
}

func (s *UserService) SearchUsers(ctx context.Context, q string) ([]*model.MiniUser, error) {
	if len(q) < 2 {
		return []*model.MiniUser{}, nil
	}
	cacheKey := "search:users:" + q
	if cached, err := rdb.Get(cacheKey); err == nil {
		var users []*model.MiniUser
		if json.Unmarshal([]byte(cached), &users) == nil {
			return users, nil
		}
	}
	users, err := s.repo.SearchUsers(ctx, q)
	if err != nil {
		return nil, err
	}
	if b, err := json.Marshal(users); err == nil {
		go rdb.Set(cacheKey, string(b), 30*time.Second)
	}
	return users, nil
}

func (s *UserService) GetFriendsNotes(ctx context.Context, myID string) ([]map[string]interface{}, error) {
	return s.repo.GetFriendsNotes(ctx, myID)
}

func (s *UserService) DeleteUser(ctx context.Context, myID string) error {
	err := s.repo.DeleteUser(ctx, myID)
	if err == nil {
		go rdb.Del("profile:"+myID)
	}
	return err
}

func (s *UserService) cacheProfile(u *model.User) {
	b, err := json.Marshal(u)
	if err != nil {
		return
	}
	rdb.Set("profile:"+u.ID, string(b), 5*time.Minute)
}
