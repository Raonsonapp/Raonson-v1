package db

import (
	"context"
	"log"
	"os"
	"time"

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

	// ── Оптимизатсияи пул барои HuggingFace (2 CPU, 16GB RAM) ──
	cfg.MaxConns          = 25            // ↑ аз 10 то 25
	cfg.MinConns          = 5             // ↑ аз 2 то 5 (пешакӣ омода)
	cfg.MaxConnLifetime   = 30 * time.Minute
	cfg.MaxConnIdleTime   = 5 * time.Minute
	cfg.HealthCheckPeriod = 30 * time.Second

	// Supabase pgBouncer: SimpleProtocol барои prepared statement bug
	cfg.ConnConfig.DefaultQueryExecMode = pgx.QueryExecModeSimpleProtocol

	// Timeout барои пешгирии freeze
	cfg.ConnConfig.ConnectTimeout = 10 * time.Second

	Pool, err = pgxpool.NewWithConfig(context.Background(), cfg)
	if err != nil {
		log.Fatalf("❌ DB connect error: %v", err)
	}
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()
	if err = Pool.Ping(ctx); err != nil {
		log.Fatalf("❌ DB ping failed: %v", err)
	}
	migrate()
	log.Println("✅ PostgreSQL connected (Supabase) — pool: 5-25 conns")
}

func migrate() {
	ctx := context.Background()
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
	CREATE INDEX IF NOT EXISTS idx_follows_follower ON follows(follower_id);
	CREATE INDEX IF NOT EXISTS idx_follows_following ON follows(following_id);

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
	CREATE INDEX IF NOT EXISTS idx_posts_likes ON posts(likes_count DESC);

	CREATE TABLE IF NOT EXISTS post_media (
		id TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
		post_id TEXT NOT NULL,
		url TEXT NOT NULL,
		type VARCHAR(10) DEFAULT 'image',
		position INTEGER DEFAULT 0
	);
	CREATE INDEX IF NOT EXISTS idx_post_media_post ON post_media(post_id, position);

	CREATE TABLE IF NOT EXISTS post_likes (
		user_id TEXT NOT NULL,
		post_id TEXT NOT NULL,
		created_at TIMESTAMPTZ DEFAULT NOW(),
		PRIMARY KEY (user_id, post_id)
	);
	CREATE INDEX IF NOT EXISTS idx_post_likes_post ON post_likes(post_id);

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
	CREATE INDEX IF NOT EXISTS idx_comments_post ON comments(post_id, created_at);

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
	CREATE INDEX IF NOT EXISTS idx_stories_expires ON stories(expires_at);

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
	CREATE INDEX IF NOT EXISTS idx_reels_created ON reels(created_at DESC);

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
	CREATE INDEX IF NOT EXISTS idx_reel_comments ON reel_comments(reel_id, created_at);

	CREATE TABLE IF NOT EXISTS reel_views (
		user_id TEXT NOT NULL,
		reel_id TEXT NOT NULL,
		viewed_at TIMESTAMPTZ DEFAULT NOW(),
		PRIMARY KEY (user_id, reel_id)
	);
	CREATE INDEX IF NOT EXISTS idx_reel_views_user ON reel_views(user_id, viewed_at);

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
	CREATE INDEX IF NOT EXISTS idx_messages_receiver ON messages(receiver_id, read);

	CREATE TABLE IF NOT EXISTS notifications (
		id TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
		user_id TEXT NOT NULL,
		from_user_id TEXT,
		type VARCHAR(50) NOT NULL,
		target_id TEXT,
		read BOOLEAN DEFAULT FALSE,
		is_read BOOLEAN DEFAULT FALSE,
		created_at TIMESTAMPTZ DEFAULT NOW()
	);
	CREATE INDEX IF NOT EXISTS idx_notif_user ON notifications(user_id, created_at DESC);
	CREATE INDEX IF NOT EXISTS idx_notif_unread ON notifications(user_id, read);

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

	-- ── App settings persistence (theme / language) ──
	ALTER TABLE users ADD COLUMN IF NOT EXISTS theme    VARCHAR(10) DEFAULT 'dark';
	ALTER TABLE users ADD COLUMN IF NOT EXISTS language VARCHAR(5)  DEFAULT 'tj';

	-- ── Registration profile fields ──
	ALTER TABLE users ADD COLUMN IF NOT EXISTS full_name VARCHAR(100) DEFAULT '';
	ALTER TABLE users ADD COLUMN IF NOT EXISTS phone     VARCHAR(20)  DEFAULT '';

	-- ── Pinned posts ──
	ALTER TABLE posts ADD COLUMN IF NOT EXISTS is_pinned BOOLEAN DEFAULT FALSE;

	-- ── Highlights (Актуальный) ──
	CREATE TABLE IF NOT EXISTS highlights (
		id         TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
		user_id    TEXT NOT NULL,
		title      TEXT DEFAULT '',
		cover_url  TEXT DEFAULT '',
		story_ids  TEXT[] DEFAULT '{}',
		created_at TIMESTAMPTZ DEFAULT NOW()
	);
	CREATE INDEX IF NOT EXISTS idx_highlights_user ON highlights(user_id, created_at);

	-- ════════════════════════════════════════════════════════════════
	-- Columns/tables referenced by handlers but missing from migrate()
	-- (schema.sql is NOT executed at boot — only this migrate() runs).
	-- ════════════════════════════════════════════════════════════════
	ALTER TABLE posts    ADD COLUMN IF NOT EXISTS hidden         BOOLEAN DEFAULT FALSE;
	ALTER TABLE posts    ADD COLUMN IF NOT EXISTS interest_score INTEGER DEFAULT 0;
	ALTER TABLE posts    ADD COLUMN IF NOT EXISTS music_title    TEXT DEFAULT '';
	ALTER TABLE posts    ADD COLUMN IF NOT EXISTS music_artist   TEXT DEFAULT '';
	ALTER TABLE posts    ADD COLUMN IF NOT EXISTS music_url      TEXT DEFAULT '';
	ALTER TABLE comments ADD COLUMN IF NOT EXISTS updated_at     TIMESTAMPTZ DEFAULT NOW();
	ALTER TABLE messages ADD COLUMN IF NOT EXISTS type           VARCHAR(16) DEFAULT 'text';
	ALTER TABLE messages ADD COLUMN IF NOT EXISTS reply_to_id    TEXT;
	ALTER TABLE messages ADD COLUMN IF NOT EXISTS is_deleted     BOOLEAN DEFAULT FALSE;
	ALTER TABLE messages ADD COLUMN IF NOT EXISTS updated_at     TIMESTAMPTZ DEFAULT NOW();

	CREATE TABLE IF NOT EXISTS post_reports (
		post_id    TEXT NOT NULL,
		user_id    TEXT NOT NULL,
		reason     TEXT DEFAULT '',
		created_at TIMESTAMPTZ DEFAULT NOW(),
		PRIMARY KEY (post_id, user_id)
	);
	CREATE INDEX IF NOT EXISTS idx_post_reports_post ON post_reports(post_id);

	CREATE TABLE IF NOT EXISTS post_interests (
		post_id    TEXT NOT NULL,
		user_id    TEXT NOT NULL,
		interested BOOLEAN DEFAULT TRUE,
		created_at TIMESTAMPTZ DEFAULT NOW(),
		PRIMARY KEY (post_id, user_id)
	);

	CREATE TABLE IF NOT EXISTS message_reactions (
		message_id TEXT NOT NULL,
		user_id    TEXT NOT NULL,
		emoji      TEXT NOT NULL,
		created_at TIMESTAMPTZ DEFAULT NOW(),
		PRIMARY KEY (message_id, user_id)
	);
	CREATE INDEX IF NOT EXISTS idx_msg_reactions_msg ON message_reactions(message_id);

	-- ── Performance indexes on hot reverse-lookup columns ──
	CREATE INDEX IF NOT EXISTS idx_users_phone       ON users(phone);
	CREATE INDEX IF NOT EXISTS idx_post_saves_post   ON post_saves(post_id);
	CREATE INDEX IF NOT EXISTS idx_post_views_post   ON post_views(post_id);
	CREATE INDEX IF NOT EXISTS idx_reel_likes_reel   ON reel_likes(reel_id);
	CREATE INDEX IF NOT EXISTS idx_reel_saves_reel   ON reel_saves(reel_id);
	CREATE INDEX IF NOT EXISTS idx_comment_likes_cmt ON comment_likes(comment_id);
	CREATE INDEX IF NOT EXISTS idx_story_views_story ON story_views(story_id);

	-- ── App owner: @raonson ҳамеша admin + verified (ройгон, бе харид) ──
	UPDATE users SET role='admin', verified=TRUE
	WHERE LOWER(username)='raonson';
	`
	if _, err := Pool.Exec(ctx, sql); err != nil {
		log.Fatalf("❌ Migration failed: %v", err)
	}
	log.Println("✅ DB schema ready")
}
