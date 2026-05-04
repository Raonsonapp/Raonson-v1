package service

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"time"

	"notification-service/internal/model"
	"notification-service/internal/repository"
	"notification-service/pkg/httpclient"
	"notification-service/pkg/logger"
	rdb "notification-service/pkg/redis"

	"go.uber.org/zap"
)

type Service struct {
	repo       *repository.Repo
	realtimeCli *httpclient.Client
	fcmKey     string
}

func New(repo *repository.Repo, realtimeURL, fcmKey string) *Service {
	return &Service{
		repo:        repo,
		realtimeCli: httpclient.New(realtimeURL, 3*time.Second, 3),
		fcmKey:      fcmKey,
	}
}

// ── GetNotifications ─────────────────────────────────────────────
func (s *Service) GetNotifications(ctx context.Context, userID, cursor string) ([]*model.Notification, string, int64, error) {
	notifs, next, err := s.repo.List(ctx, userID, cursor, 20)
	if err != nil {
		return nil, "", 0, err
	}
	unread, _ := rdb.C.Get(ctx, "notif:unread:"+userID).Int64()
	return notifs, next, unread, nil
}

// ── MarkAllRead ───────────────────────────────────────────────────
func (s *Service) MarkAllRead(ctx context.Context, userID string) error {
	if err := s.repo.MarkAllRead(ctx, userID); err != nil {
		return err
	}
	rdb.C.Set(ctx, "notif:unread:"+userID, 0, 30*24*time.Hour)
	rdb.Del("notifs:" + userID + ":")
	return nil
}

// ── MarkOneRead ───────────────────────────────────────────────────
func (s *Service) MarkOneRead(ctx context.Context, notifID, userID string) error {
	if err := s.repo.MarkOneRead(ctx, notifID, userID); err != nil {
		return err
	}
	rdb.C.Decr(ctx, "notif:unread:"+userID)
	return nil
}

// ── Delete ────────────────────────────────────────────────────────
func (s *Service) Delete(ctx context.Context, notifID, userID string) error {
	return s.repo.Delete(ctx, notifID, userID)
}

// ── SavePushToken ─────────────────────────────────────────────────
func (s *Service) SavePushToken(ctx context.Context, userID string, req *model.PushTokenReq) error {
	if req.Platform == "" {
		req.Platform = "android"
	}
	return s.repo.SavePushToken(ctx, userID, req.Token, req.Platform)
}

// ── CreateNotification — called by internal endpoint ─────────────
func (s *Service) Create(ctx context.Context, req *model.CreateNotifReq) error {
	// Don't notify yourself
	if req.UserID == req.FromUserID {
		return nil
	}
	// Dedup check
	if s.repo.IsDuplicate(req.UserID, req.FromUserID, req.Type, req.TargetID) {
		return fmt.Errorf("duplicate")
	}

	// Save to DB
	nid, err := s.repo.Create(ctx, req)
	if err != nil {
		return err
	}

	// Increment unread counter
	rdb.C.Incr(ctx, "notif:unread:"+req.UserID)
	rdb.C.Expire(ctx, "notif:unread:"+req.UserID, 30*24*time.Hour)
	rdb.Del("notifs:" + req.UserID + ":")

	// Async: send to WebSocket + FCM
	go s.sendWS(req.UserID, req.Type, req.TargetID, req.FromUserID)
	go s.sendFCM(req.UserID, req.Type, req.FromUserID)

	logger.Info("notification created",
		zap.String("id", nid),
		zap.String("type", req.Type),
		zap.String("to", req.UserID))
	return nil
}

// ── Send to WebSocket via realtime-service ────────────────────────
func (s *Service) sendWS(userID, nType, targetID, fromUserID string) {
	if s.realtimeCli == nil {
		return
	}
	payload, _ := json.Marshal(map[string]interface{}{
		"type":       nType,
		"targetID":   targetID,
		"fromUserID": fromUserID,
	})
	body := map[string]interface{}{
		"userID":  userID,
		"type":    "notification",
		"payload": json.RawMessage(payload),
	}
	ctx, cancel := context.WithTimeout(context.Background(), 3*time.Second)
	defer cancel()
	if err := s.realtimeCli.Post(ctx, "/internal/send", body, ""); err != nil {
		logger.Warn("ws notify failed", zap.Error(err), zap.String("userID", userID))
	}
}

// ── FCM Push Notification ─────────────────────────────────────────
func (s *Service) sendFCM(userID, nType, fromUsername string) {
	if s.fcmKey == "" {
		return
	}
	token := s.repo.GetPushToken(context.Background(), userID)
	if token == "" {
		return
	}
	title, body := notifText(nType, fromUsername)
	payload := map[string]interface{}{
		"to": token,
		"notification": map[string]string{
			"title": title,
			"body":  body,
			"sound": "default",
		},
		"data": map[string]string{
			"type":         nType,
			"fromUser":     fromUsername,
			"click_action": "FLUTTER_NOTIFICATION_CLICK",
		},
		"priority": "high",
	}
	b, _ := json.Marshal(payload)
	req, err := http.NewRequest("POST", "https://fcm.googleapis.com/fcm/send", bytes.NewReader(b))
	if err != nil {
		return
	}
	req.Header.Set("Authorization", "key="+s.fcmKey)
	req.Header.Set("Content-Type", "application/json")
	client := &http.Client{Timeout: 5 * time.Second}
	resp, err := client.Do(req)
	if err != nil {
		logger.Warn("FCM send failed", zap.Error(err))
		return
	}
	resp.Body.Close()
}

func notifText(nType, from string) (title, body string) {
	switch nType {
	case "like":
		return "New Like 💙", from + " liked your post"
	case "comment":
		return "New Comment 💬", from + " commented on your post"
	case "follow":
		return "New Follower 👤", from + " started following you"
	case "mention":
		return "Mention 📣", from + " mentioned you"
	default:
		return "Raonson", "You have a new notification"
	}
}
