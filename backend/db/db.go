package db

import (
	"context"
	"log"
	"os"

	"github.com/jackc/pgx/v5"
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
	cfg.MaxConns = 10
	cfg.MinConns = 2

	// ✅ FIX: Supabase pgBouncer "prepared statement already exists" bug
	// Use SimpleProtocol — no server-side prepared statements
	cfg.ConnConfig.DefaultQueryExecMode = pgx.QueryExecModeSimpleProtocol

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
	ctx := context.Background()

	// ⚠️ DROP хориҷ шуд — маълумот нест намешавад!
	// Танҳо CREATE IF NOT EXISTS — mavjud bo'lsa skip qiladi

	sql := `
	CREATE EXTENSION IF NOT EXISTS "pgcrypto";

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
		website TEXT DEFAULT '',
		location TEXT DEFAULT '',
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
		follower_id TEXT NOT NULL,
		following_id TEXT NOT NULL,
		created_at TIMESTAMPTZ DEFAULT NOW(),
		PRIMARY KEY (follower_id, following_id)
	);

	CREATE TABLE IF NOT EXISTS follow_requests (
		requester_id TEXT NOT NULL,
		target_id TEXT NOT NULL,
		created_at TIMESTAMPTZ DEFAULT NOW(),
		PRIMARY KEY (requester_id, target_id)
	);

	CREATE TABLE IF NOT EXISTS posts (
		id TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
		user_id TEXT NOT NULL,
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
		post_id TEXT NOT NULL,
		url TEXT NOT NULL,
		type VARCHAR(10) DEFAULT 'image',
		position INTEGER DEFAULT 0
	);

	CREATE TABLE IF NOT EXISTS post_likes (
		user_id TEXT NOT NULL,
		post_id TEXT NOT NULL,
		created_at TIMESTAMPTZ DEFAULT NOW(),
		PRIMARY KEY (user_id, post_id)
	);

	CREATE TABLE IF NOT EXISTS post_saves (
		user_id TEXT NOT NULL,
		post_id TEXT NOT NULL,
		PRIMARY KEY (user_id, post_id)
	);

	CREATE TABLE IF NOT EXISTS post_views (
		user_id TEXT NOT NULL,
		post_id TEXT NOT NULL,
		viewed_at TIMESTAMPTZ DEFAULT NOW(),
		PRIMARY KEY (user_id, post_id)
	);

	CREATE TABLE IF NOT EXISTS comments (
		id TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
		post_id TEXT NOT NULL,
		user_id TEXT NOT NULL,
		text TEXT NOT NULL,
		likes_count INTEGER DEFAULT 0,
		created_at TIMESTAMPTZ DEFAULT NOW()
	);
	CREATE INDEX IF NOT EXISTS idx_comments_post ON comments(post_id);

	CREATE TABLE IF NOT EXISTS comment_likes (
		user_id TEXT NOT NULL,
		comment_id TEXT NOT NULL,
		PRIMARY KEY (user_id, comment_id)
	);

	CREATE TABLE IF NOT EXISTS stories (
		id TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
		user_id TEXT NOT NULL,
		media_url TEXT NOT NULL,
		media_type VARCHAR(10) NOT NULL,
		caption TEXT DEFAULT '',
		expires_at TIMESTAMPTZ NOT NULL,
		created_at TIMESTAMPTZ DEFAULT NOW()
	);
	CREATE INDEX IF NOT EXISTS idx_stories_user ON stories(user_id);

	CREATE TABLE IF NOT EXISTS story_views (
		user_id TEXT NOT NULL,
		story_id TEXT NOT NULL,
		PRIMARY KEY (user_id, story_id)
	);

	CREATE TABLE IF NOT EXISTS story_likes (
		user_id TEXT NOT NULL,
		story_id TEXT NOT NULL,
		PRIMARY KEY (user_id, story_id)
	);

	CREATE TABLE IF NOT EXISTS reels (
		id TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
		user_id TEXT NOT NULL,
		video_url TEXT NOT NULL,
		caption TEXT DEFAULT '',
		views_count INTEGER DEFAULT 0,
		likes_count INTEGER DEFAULT 0,
		comments_count INTEGER DEFAULT 0,
		created_at TIMESTAMPTZ DEFAULT NOW()
	);
	CREATE INDEX IF NOT EXISTS idx_reels_user ON reels(user_id);

	CREATE TABLE IF NOT EXISTS reel_likes (
		user_id TEXT NOT NULL,
		reel_id TEXT NOT NULL,
		PRIMARY KEY (user_id, reel_id)
	);

	CREATE TABLE IF NOT EXISTS reel_saves (
		user_id TEXT NOT NULL,
		reel_id TEXT NOT NULL,
		PRIMARY KEY (user_id, reel_id)
	);

	CREATE TABLE IF NOT EXISTS reel_comments (
		id TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
		reel_id TEXT NOT NULL,
		user_id TEXT NOT NULL,
		text TEXT NOT NULL,
		created_at TIMESTAMPTZ DEFAULT NOW()
	);

	CREATE TABLE IF NOT EXISTS messages (
		id TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
		chat_id VARCHAR(120) NOT NULL,
		sender_id TEXT NOT NULL,
		receiver_id TEXT NOT NULL,
		text TEXT DEFAULT '',
		media_url TEXT DEFAULT '',
		read BOOLEAN DEFAULT FALSE,
		created_at TIMESTAMPTZ DEFAULT NOW()
	);
	CREATE INDEX IF NOT EXISTS idx_messages_chat ON messages(chat_id, created_at);

	CREATE TABLE IF NOT EXISTS notifications (
		id TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
		user_id TEXT NOT NULL,
		from_user_id TEXT,
		type VARCHAR(50) NOT NULL,
		target_id TEXT,
		read BOOLEAN DEFAULT FALSE,
		created_at TIMESTAMPTZ DEFAULT NOW()
	);
	CREATE INDEX IF NOT EXISTS idx_notif_user ON notifications(user_id, created_at DESC);

	CREATE TABLE IF NOT EXISTS likes (
		id TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
		user_id TEXT NOT NULL,
		target_id TEXT NOT NULL,
		target_type VARCHAR(20) NOT NULL,
		created_at TIMESTAMPTZ DEFAULT NOW(),
		UNIQUE(user_id, target_id, target_type)
	);

	CREATE TABLE IF NOT EXISTS blocks (
		blocker_id TEXT NOT NULL,
		blocked_id TEXT NOT NULL,
		PRIMARY KEY (blocker_id, blocked_id)
	);

	CREATE TABLE IF NOT EXISTS push_tokens (
		user_id TEXT NOT NULL,
		token TEXT NOT NULL,
		platform VARCHAR(10) DEFAULT 'android',
		updated_at TIMESTAMPTZ DEFAULT NOW(),
		UNIQUE(user_id, platform)
	);
	`

	if _, err := Pool.Exec(ctx, sql); err != nil {
		log.Fatalf("❌ Migration failed: %v", err)
	}
	log.Println("✅ DB schema ready")
}
