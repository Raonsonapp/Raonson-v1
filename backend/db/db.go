package db

import (
	"context"
	"log"
	"os"

	"github.com/jackc/pgx/v5/pgxpool"
)

var Pool *pgxpool.Pool

func Init() {
	dsn := os.Getenv("DATABASE_URL")
	if dsn == "" {
		log.Fatal("❌ DATABASE_URL not set")
	}

	cfg, err := pgxpool.ParseConfig(dsn)
	if err != nil {
		log.Fatalf("❌ DB config error: %v", err)
	}
	cfg.MaxConns = 20

	Pool, err = pgxpool.NewWithConfig(context.Background(), cfg)
	if err != nil {
		log.Fatalf("❌ DB connect error: %v", err)
	}

	if err = Pool.Ping(context.Background()); err != nil {
		log.Fatalf("❌ DB ping failed: %v", err)
	}

	migrate()
	log.Println("✅ PostgreSQL connected (Supabase)")
}

func migrate() {
	sql := `
	CREATE EXTENSION IF NOT EXISTS "pgcrypto";

	-- USERS
	CREATE TABLE IF NOT EXISTS users (
		id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
		username VARCHAR(50) UNIQUE NOT NULL,
		email VARCHAR(255) UNIQUE,
		password TEXT NOT NULL DEFAULT '',
		avatar TEXT DEFAULT '',
		bio TEXT DEFAULT '',
		verified BOOLEAN DEFAULT FALSE,
		is_private BOOLEAN DEFAULT FALSE,
		banned BOOLEAN DEFAULT FALSE,
		role VARCHAR(20) DEFAULT 'user' CHECK (role IN ('user','admin')),
		last_seen TIMESTAMPTZ,
		website VARCHAR(100) DEFAULT '',
		location VARCHAR(100) DEFAULT '',
		birthday DATE,
		-- Notes (Instagram Notes feature)
		note VARCHAR(60) DEFAULT '',
		note_expires_at TIMESTAMPTZ,
		note_song_title TEXT DEFAULT '',
		note_song_artist TEXT DEFAULT '',
		note_song_art_url TEXT DEFAULT '',
		note_song_preview_url TEXT DEFAULT '',
		note_song_track_ms INTEGER DEFAULT 0,
		note_song_start_ms INTEGER DEFAULT 0,
		note_song_end_ms INTEGER DEFAULT 30000,
		-- Counters (denormalized for speed)
		posts_count INTEGER DEFAULT 0,
		followers_count INTEGER DEFAULT 0,
		following_count INTEGER DEFAULT 0,
		created_at TIMESTAMPTZ DEFAULT NOW(),
		updated_at TIMESTAMPTZ DEFAULT NOW()
	);
	CREATE INDEX IF NOT EXISTS idx_users_username ON users(username);
	CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);

	-- FOLLOWS
	CREATE TABLE IF NOT EXISTS follows (
		follower_id UUID REFERENCES users(id) ON DELETE CASCADE,
		following_id UUID REFERENCES users(id) ON DELETE CASCADE,
		created_at TIMESTAMPTZ DEFAULT NOW(),
		PRIMARY KEY (follower_id, following_id)
	);
	CREATE INDEX IF NOT EXISTS idx_follows_following ON follows(following_id);

	-- FOLLOW REQUESTS (private accounts)
	CREATE TABLE IF NOT EXISTS follow_requests (
		requester_id UUID REFERENCES users(id) ON DELETE CASCADE,
		target_id UUID REFERENCES users(id) ON DELETE CASCADE,
		created_at TIMESTAMPTZ DEFAULT NOW(),
		PRIMARY KEY (requester_id, target_id)
	);

	-- POSTS
	CREATE TABLE IF NOT EXISTS posts (
		id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
		user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
		caption TEXT DEFAULT '',
		comments_count INTEGER DEFAULT 0,
		likes_count INTEGER DEFAULT 0,
		created_at TIMESTAMPTZ DEFAULT NOW(),
		updated_at TIMESTAMPTZ DEFAULT NOW()
	);
	CREATE INDEX IF NOT EXISTS idx_posts_user ON posts(user_id);
	CREATE INDEX IF NOT EXISTS idx_posts_created ON posts(created_at DESC);

	-- POST MEDIA
	CREATE TABLE IF NOT EXISTS post_media (
		id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
		post_id UUID NOT NULL REFERENCES posts(id) ON DELETE CASCADE,
		url TEXT NOT NULL,
		type VARCHAR(10) DEFAULT 'image',
		position INTEGER DEFAULT 0
	);
	CREATE INDEX IF NOT EXISTS idx_post_media_post ON post_media(post_id);

	-- POST LIKES
	CREATE TABLE IF NOT EXISTS post_likes (
		user_id UUID REFERENCES users(id) ON DELETE CASCADE,
		post_id UUID REFERENCES posts(id) ON DELETE CASCADE,
		created_at TIMESTAMPTZ DEFAULT NOW(),
		PRIMARY KEY (user_id, post_id)
	);

	-- POST SAVES
	CREATE TABLE IF NOT EXISTS post_saves (
		user_id UUID REFERENCES users(id) ON DELETE CASCADE,
		post_id UUID REFERENCES posts(id) ON DELETE CASCADE,
		PRIMARY KEY (user_id, post_id)
	);

	-- COMMENTS
	CREATE TABLE IF NOT EXISTS comments (
		id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
		post_id UUID NOT NULL REFERENCES posts(id) ON DELETE CASCADE,
		user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
		text TEXT NOT NULL,
		likes_count INTEGER DEFAULT 0,
		created_at TIMESTAMPTZ DEFAULT NOW()
	);
	CREATE INDEX IF NOT EXISTS idx_comments_post ON comments(post_id);

	-- COMMENT LIKES
	CREATE TABLE IF NOT EXISTS comment_likes (
		user_id UUID REFERENCES users(id) ON DELETE CASCADE,
		comment_id UUID REFERENCES comments(id) ON DELETE CASCADE,
		PRIMARY KEY (user_id, comment_id)
	);

	-- STORIES
	CREATE TABLE IF NOT EXISTS stories (
		id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
		user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
		media_url TEXT NOT NULL,
		media_type VARCHAR(10) NOT NULL,
		caption TEXT DEFAULT '',
		expires_at TIMESTAMPTZ NOT NULL,
		created_at TIMESTAMPTZ DEFAULT NOW()
	);
	CREATE INDEX IF NOT EXISTS idx_stories_expires ON stories(expires_at);
	CREATE INDEX IF NOT EXISTS idx_stories_user ON stories(user_id);

	-- STORY VIEWS
	CREATE TABLE IF NOT EXISTS story_views (
		user_id UUID REFERENCES users(id) ON DELETE CASCADE,
		story_id UUID REFERENCES stories(id) ON DELETE CASCADE,
		viewed_at TIMESTAMPTZ DEFAULT NOW(),
		PRIMARY KEY (user_id, story_id)
	);

	-- STORY LIKES
	CREATE TABLE IF NOT EXISTS story_likes (
		user_id UUID REFERENCES users(id) ON DELETE CASCADE,
		story_id UUID REFERENCES stories(id) ON DELETE CASCADE,
		PRIMARY KEY (user_id, story_id)
	);

	-- REELS
	CREATE TABLE IF NOT EXISTS reels (
		id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
		user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
		video_url TEXT NOT NULL,
		caption TEXT DEFAULT '',
		views_count INTEGER DEFAULT 0,
		likes_count INTEGER DEFAULT 0,
		created_at TIMESTAMPTZ DEFAULT NOW()
	);
	CREATE INDEX IF NOT EXISTS idx_reels_user ON reels(user_id);
	CREATE INDEX IF NOT EXISTS idx_reels_created ON reels(created_at DESC);

	-- REEL LIKES
	CREATE TABLE IF NOT EXISTS reel_likes (
		user_id UUID REFERENCES users(id) ON DELETE CASCADE,
		reel_id UUID REFERENCES reels(id) ON DELETE CASCADE,
		PRIMARY KEY (user_id, reel_id)
	);

	-- REEL SAVES
	CREATE TABLE IF NOT EXISTS reel_saves (
		user_id UUID REFERENCES users(id) ON DELETE CASCADE,
		reel_id UUID REFERENCES reels(id) ON DELETE CASCADE,
		PRIMARY KEY (user_id, reel_id)
	);

	-- REEL COMMENTS
	CREATE TABLE IF NOT EXISTS reel_comments (
		id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
		reel_id UUID NOT NULL REFERENCES reels(id) ON DELETE CASCADE,
		user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
		text TEXT NOT NULL,
		created_at TIMESTAMPTZ DEFAULT NOW()
	);

	-- MESSAGES
	CREATE TABLE IF NOT EXISTS messages (
		id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
		chat_id VARCHAR(120) NOT NULL,
		sender_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
		receiver_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
		text TEXT DEFAULT '',
		media_url TEXT DEFAULT '',
		read BOOLEAN DEFAULT FALSE,
		created_at TIMESTAMPTZ DEFAULT NOW()
	);
	CREATE INDEX IF NOT EXISTS idx_messages_chat ON messages(chat_id, created_at);
	CREATE INDEX IF NOT EXISTS idx_messages_sender ON messages(sender_id);
	CREATE INDEX IF NOT EXISTS idx_messages_receiver ON messages(receiver_id);

	-- NOTIFICATIONS
	CREATE TABLE IF NOT EXISTS notifications (
		id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
		user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
		from_user_id UUID REFERENCES users(id) ON DELETE SET NULL,
		type VARCHAR(50) NOT NULL,
		target_id UUID,
		read BOOLEAN DEFAULT FALSE,
		created_at TIMESTAMPTZ DEFAULT NOW()
	);
	CREATE INDEX IF NOT EXISTS idx_notif_user ON notifications(user_id, created_at DESC);

	-- GENERIC LIKES (post/comment/story/reel)
	CREATE TABLE IF NOT EXISTS likes (
		id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
		user_id UUID REFERENCES users(id) ON DELETE CASCADE,
		target_id UUID NOT NULL,
		target_type VARCHAR(20) NOT NULL,
		created_at TIMESTAMPTZ DEFAULT NOW(),
		UNIQUE(user_id, target_id, target_type)
	);
	CREATE INDEX IF NOT EXISTS idx_likes_target ON likes(target_id);

	-- POST VIEWS (for smart feed dedup)
	CREATE TABLE IF NOT EXISTS post_views (
		user_id UUID REFERENCES users(id) ON DELETE CASCADE,
		post_id UUID REFERENCES posts(id) ON DELETE CASCADE,
		viewed_at TIMESTAMPTZ DEFAULT NOW(),
		PRIMARY KEY (user_id, post_id)
	);

	-- FCM PUSH TOKENS
	CREATE TABLE IF NOT EXISTS push_tokens (
		user_id  UUID REFERENCES users(id) ON DELETE CASCADE,
		token    TEXT NOT NULL,
		platform VARCHAR(10) DEFAULT 'android',
		updated_at TIMESTAMPTZ DEFAULT NOW(),
		UNIQUE(user_id, platform)
	);

	-- BLOCKS
	CREATE TABLE IF NOT EXISTS blocks (
		blocker_id UUID REFERENCES users(id) ON DELETE CASCADE,
		blocked_id UUID REFERENCES users(id) ON DELETE CASCADE,
		created_at TIMESTAMPTZ DEFAULT NOW(),
		PRIMARY KEY (blocker_id, blocked_id)
	);
	`

	if _, err := Pool.Exec(context.Background(), sql); err != nil {
		log.Fatalf("❌ Migration failed: %v", err)
	}
	log.Println("✅ DB schema ready")
}

// Exec helper — ignores result
func Exec(sql string, args ...interface{}) {
	Pool.Exec(context.Background(), sql, args...)
}

// QueryRow helper
func QueryRow(sql string, args ...interface{}) interface{ Scan(...any) error } {
	return Pool.QueryRow(context.Background(), sql, args...)
}
