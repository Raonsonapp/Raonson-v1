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
	// Use TEXT for IDs — avoids UUID type issues on all PostgreSQL versions
	sql := `
	CREATE TABLE IF NOT EXISTS users (
		id TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
		username VARCHAR(50) UNIQUE NOT NULL,
		email VARCHAR(255) UNIQUE,
		password TEXT NOT NULL DEFAULT '',
		avatar TEXT DEFAULT '',
		bio TEXT DEFAULT '',
		verified BOOLEAN DEFAULT FALSE,
		is_private BOOLEAN DEFAULT FALSE,
		banned BOOLEAN DEFAULT FALSE,
		role VARCHAR(20) DEFAULT 'user',
		last_seen TIMESTAMPTZ,
		website VARCHAR(100) DEFAULT '',
		location VARCHAR(100) DEFAULT '',
		birthday DATE,
		note VARCHAR(60) DEFAULT '',
		note_expires_at TIMESTAMPTZ,
		note_song_title TEXT DEFAULT '',
		note_song_artist TEXT DEFAULT '',
		note_song_art_url TEXT DEFAULT '',
		note_song_preview_url TEXT DEFAULT '',
		note_song_track_ms INTEGER DEFAULT 0,
		note_song_start_ms INTEGER DEFAULT 0,
		note_song_end_ms INTEGER DEFAULT 30000,
		posts_count INTEGER DEFAULT 0,
		followers_count INTEGER DEFAULT 0,
		following_count INTEGER DEFAULT 0,
		created_at TIMESTAMPTZ DEFAULT NOW(),
		updated_at TIMESTAMPTZ DEFAULT NOW()
	);
	CREATE INDEX IF NOT EXISTS idx_users_username ON users(username);
	CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);

	CREATE TABLE IF NOT EXISTS follows (
		follower_id TEXT REFERENCES users(id) ON DELETE CASCADE,
		following_id TEXT REFERENCES users(id) ON DELETE CASCADE,
		created_at TIMESTAMPTZ DEFAULT NOW(),
		PRIMARY KEY (follower_id, following_id)
	);

	CREATE TABLE IF NOT EXISTS follow_requests (
		requester_id TEXT REFERENCES users(id) ON DELETE CASCADE,
		target_id TEXT REFERENCES users(id) ON DELETE CASCADE,
		created_at TIMESTAMPTZ DEFAULT NOW(),
		PRIMARY KEY (requester_id, target_id)
	);

	CREATE TABLE IF NOT EXISTS posts (
		id TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
		user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
		caption TEXT DEFAULT '',
		comments_count INTEGER DEFAULT 0,
		likes_count INTEGER DEFAULT 0,
		created_at TIMESTAMPTZ DEFAULT NOW(),
		updated_at TIMESTAMPTZ DEFAULT NOW()
	);
	CREATE INDEX IF NOT EXISTS idx_posts_user ON posts(user_id);
	CREATE INDEX IF NOT EXISTS idx_posts_created ON posts(created_at DESC);

	CREATE TABLE IF NOT EXISTS post_media (
		id TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
		post_id TEXT NOT NULL REFERENCES posts(id) ON DELETE CASCADE,
		url TEXT NOT NULL,
		type VARCHAR(10) DEFAULT 'image',
		position INTEGER DEFAULT 0
	);
	CREATE INDEX IF NOT EXISTS idx_post_media_post ON post_media(post_id);

	CREATE TABLE IF NOT EXISTS post_likes (
		user_id TEXT REFERENCES users(id) ON DELETE CASCADE,
		post_id TEXT REFERENCES posts(id) ON DELETE CASCADE,
		created_at TIMESTAMPTZ DEFAULT NOW(),
		PRIMARY KEY (user_id, post_id)
	);

	CREATE TABLE IF NOT EXISTS post_saves (
		user_id TEXT REFERENCES users(id) ON DELETE CASCADE,
		post_id TEXT REFERENCES posts(id) ON DELETE CASCADE,
		PRIMARY KEY (user_id, post_id)
	);

	CREATE TABLE IF NOT EXISTS post_views (
		user_id TEXT REFERENCES users(id) ON DELETE CASCADE,
		post_id TEXT REFERENCES posts(id) ON DELETE CASCADE,
		viewed_at TIMESTAMPTZ DEFAULT NOW(),
		PRIMARY KEY (user_id, post_id)
	);

	CREATE TABLE IF NOT EXISTS comments (
		id TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
		post_id TEXT NOT NULL REFERENCES posts(id) ON DELETE CASCADE,
		user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
		text TEXT NOT NULL,
		likes_count INTEGER DEFAULT 0,
		created_at TIMESTAMPTZ DEFAULT NOW()
	);
	CREATE INDEX IF NOT EXISTS idx_comments_post ON comments(post_id);

	CREATE TABLE IF NOT EXISTS comment_likes (
		user_id TEXT REFERENCES users(id) ON DELETE CASCADE,
		comment_id TEXT REFERENCES comments(id) ON DELETE CASCADE,
		PRIMARY KEY (user_id, comment_id)
	);

	CREATE TABLE IF NOT EXISTS stories (
		id TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
		user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
		media_url TEXT NOT NULL,
		media_type VARCHAR(10) NOT NULL,
		caption TEXT DEFAULT '',
		expires_at TIMESTAMPTZ NOT NULL,
		created_at TIMESTAMPTZ DEFAULT NOW()
	);
	CREATE INDEX IF NOT EXISTS idx_stories_expires ON stories(expires_at);
	CREATE INDEX IF NOT EXISTS idx_stories_user ON stories(user_id);

	CREATE TABLE IF NOT EXISTS story_views (
		user_id TEXT REFERENCES users(id) ON DELETE CASCADE,
		story_id TEXT REFERENCES stories(id) ON DELETE CASCADE,
		PRIMARY KEY (user_id, story_id)
	);

	CREATE TABLE IF NOT EXISTS story_likes (
		user_id TEXT REFERENCES users(id) ON DELETE CASCADE,
		story_id TEXT REFERENCES stories(id) ON DELETE CASCADE,
		PRIMARY KEY (user_id, story_id)
	);

	CREATE TABLE IF NOT EXISTS reels (
		id TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
		user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
		video_url TEXT NOT NULL,
		caption TEXT DEFAULT '',
		views_count INTEGER DEFAULT 0,
		likes_count INTEGER DEFAULT 0,
		created_at TIMESTAMPTZ DEFAULT NOW()
	);
	CREATE INDEX IF NOT EXISTS idx_reels_user ON reels(user_id);
	CREATE INDEX IF NOT EXISTS idx_reels_created ON reels(created_at DESC);

	CREATE TABLE IF NOT EXISTS reel_likes (
		user_id TEXT REFERENCES users(id) ON DELETE CASCADE,
		reel_id TEXT REFERENCES reels(id) ON DELETE CASCADE,
		PRIMARY KEY (user_id, reel_id)
	);

	CREATE TABLE IF NOT EXISTS reel_saves (
		user_id TEXT REFERENCES users(id) ON DELETE CASCADE,
		reel_id TEXT REFERENCES reels(id) ON DELETE CASCADE,
		PRIMARY KEY (user_id, reel_id)
	);

	CREATE TABLE IF NOT EXISTS reel_comments (
		id TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
		reel_id TEXT NOT NULL REFERENCES reels(id) ON DELETE CASCADE,
		user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
		text TEXT NOT NULL,
		created_at TIMESTAMPTZ DEFAULT NOW()
	);

	CREATE TABLE IF NOT EXISTS messages (
		id TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
		chat_id VARCHAR(120) NOT NULL,
		sender_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
		receiver_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
		text TEXT DEFAULT '',
		media_url TEXT DEFAULT '',
		read BOOLEAN DEFAULT FALSE,
		created_at TIMESTAMPTZ DEFAULT NOW()
	);
	CREATE INDEX IF NOT EXISTS idx_messages_chat ON messages(chat_id, created_at);

	CREATE TABLE IF NOT EXISTS notifications (
		id TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
		user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
		from_user_id TEXT REFERENCES users(id) ON DELETE SET NULL,
		type VARCHAR(50) NOT NULL,
		target_id TEXT,
		read BOOLEAN DEFAULT FALSE,
		created_at TIMESTAMPTZ DEFAULT NOW()
	);
	CREATE INDEX IF NOT EXISTS idx_notif_user ON notifications(user_id, created_at DESC);

	CREATE TABLE IF NOT EXISTS likes (
		id TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
		user_id TEXT REFERENCES users(id) ON DELETE CASCADE,
		target_id TEXT NOT NULL,
		target_type VARCHAR(20) NOT NULL,
		created_at TIMESTAMPTZ DEFAULT NOW(),
		UNIQUE(user_id, target_id, target_type)
	);

	CREATE TABLE IF NOT EXISTS blocks (
		blocker_id TEXT REFERENCES users(id) ON DELETE CASCADE,
		blocked_id TEXT REFERENCES users(id) ON DELETE CASCADE,
		created_at TIMESTAMPTZ DEFAULT NOW(),
		PRIMARY KEY (blocker_id, blocked_id)
	);

	CREATE TABLE IF NOT EXISTS push_tokens (
		user_id TEXT REFERENCES users(id) ON DELETE CASCADE,
		token TEXT NOT NULL,
		platform VARCHAR(10) DEFAULT 'android',
		updated_at TIMESTAMPTZ DEFAULT NOW(),
		UNIQUE(user_id, platform)
	);
	`

	if _, err := Pool.Exec(context.Background(), sql); err != nil {
		log.Fatalf("❌ Migration failed: %v", err)
	}
	log.Println("✅ DB schema ready")
}
