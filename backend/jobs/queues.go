package jobs

import (
	"context"
	"fmt"
	"log"
	"time"

	"raonson/db"
	mw "raonson/middleware"
)

// ── Queue system (Go goroutines замени BullMQ) ───────────────────
// BullMQ Redis queue → Go channel-based queue
// Барои 50K+ user: goroutine pool + Redis-backed

// ── Feed Fanout Queue ─────────────────────────────────────────────
// Вақте пост сохта мешавад → ба ҳамаи followers мефиристад
type FeedJob struct {
	PostID   string
	AuthorID string
}

var feedCh = make(chan FeedJob, 10000)

func EnqueueFeedUpdate(postID, authorID string) {
	select {
	case feedCh <- FeedJob{PostID: postID, AuthorID: authorID}:
	default:
		log.Printf("[Queue] feed channel full, dropping job for post %s", postID)
	}
}

func processFeedQueue() {
	workers := 5
	for i := 0; i < workers; i++ {
		go func() {
			for job := range feedCh {
				fanoutFeed(job)
			}
		}()
	}
}

func fanoutFeed(job FeedJob) {
	// Get all followers of author
	rows, err := db.Pool.Query(context.Background(),
		`SELECT follower_id FROM follows WHERE following_id=$1`, job.AuthorID)
	if err != nil {
		return
	}
	defer rows.Close()

	for rows.Next() {
		var followerID string
		rows.Scan(&followerID)
		// Invalidate follower's feed cache
		mw.CacheDel("feed:"+followerID+":1", "smartfeed:"+followerID+":1")
	}
}

// ── Notification Queue ────────────────────────────────────────────
type NotifJob struct {
	To       string
	From     string
	Type     string
	EntityID string
}

var notifCh = make(chan NotifJob, 50000)

func EnqueueNotification(to, from, notifType, entityID string) {
	if to == from {
		return // Notify yourself нест
	}
	select {
	case notifCh <- NotifJob{To: to, From: from, Type: notifType, EntityID: entityID}:
	default:
		log.Printf("[Queue] notif channel full")
	}
}

func processNotifQueue() {
	workers := 3
	for i := 0; i < workers; i++ {
		go func() {
			for job := range notifCh {
				saveNotification(job)
			}
		}()
	}
}

func saveNotification(job NotifJob) {
	var entityID interface{}
	if job.EntityID != "" {
		entityID = job.EntityID
	}

	_, err := db.Pool.Exec(context.Background(), `
		INSERT INTO notifications(user_id, from_user_id, type, target_id)
		VALUES($1, $2, $3, $4)`,
		job.To, job.From, job.Type, entityID)
	if err != nil {
		log.Printf("[Queue] notif save error: %v", err)
	}
}

// ── Email Queue (баъд SendGrid/SES-ро пайваст кунед) ─────────────
type EmailJob struct {
	To      string
	Subject string
	Body    string
}

var emailCh = make(chan EmailJob, 1000)

func EnqueueEmail(to, subject, body string) {
	select {
	case emailCh <- EmailJob{To: to, Subject: subject, Body: body}:
	default:
	}
}

func processEmailQueue() {
	go func() {
		for job := range emailCh {
			log.Printf("[Email] to:%s subject:%s", job.To, job.Subject)
		}
	}()
}

// ── Media Queue (видео thumbnail генерация) ───────────────────────
type MediaJob struct {
	MediaURL  string
	MediaType string
	OwnerID   string
}

var mediaCh = make(chan MediaJob, 500)

func EnqueueMediaJob(mediaURL, mediaType, ownerID string) {
	select {
	case mediaCh <- MediaJob{MediaURL: mediaURL, MediaType: mediaType, OwnerID: ownerID}:
	default:
	}
}

func processMediaQueue() {
	go func() {
		for job := range mediaCh {
			log.Printf("[Media] processing %s for %s", job.MediaType, job.OwnerID)
		}
	}()
}

// ── Stats Job ─────────────────────────────────────────────────────
func runStatsJob() {
	var users, posts, reels int
	db.Pool.QueryRow(context.Background(), `SELECT COUNT(*) FROM users`).Scan(&users)
	db.Pool.QueryRow(context.Background(), `SELECT COUNT(*) FROM posts`).Scan(&posts)
	db.Pool.QueryRow(context.Background(), `SELECT COUNT(*) FROM reels`).Scan(&reels)

	var totalLikes int
	db.Pool.QueryRow(context.Background(), `SELECT COUNT(*) FROM post_likes`).Scan(&totalLikes)

	log.Printf("[Stats] users:%d posts:%d reels:%d likes:%d at:%s",
		users, posts, reels, totalLikes,
		time.Now().Format("2006-01-02 15:04"))

	// Cache stats for admin dashboard
	statsJSON := fmt.Sprintf(
		`{"users":%d,"posts":%d,"reels":%d,"totalLikes":%d,"generatedAt":"%s"}`,
		users, posts, reels, totalLikes, time.Now().Format(time.RFC3339))
	mw.CacheSet("stats:dashboard", []byte(statsJSON), 10*time.Minute)
}
