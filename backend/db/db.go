package db

import (
	"context"
	"log"
	"os"
	"strconv"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

var Pool *pgxpool.Pool

// envInt — танзими адад аз env (барои миқёскунӣ бе тағйири код).
func envInt(key string, def int) int {
	if v := os.Getenv(key); v != "" {
		if n, err := strconv.Atoi(v); err == nil && n > 0 {
			return n
		}
	}
	return def
}

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
	// Барои horizontal scaling: DB_MAX_CONNS/DB_MIN_CONNS-ро дар ҳар нусха
	// танзим кунед (default 25/5). Маҷмӯъ аз ҳади DB-и шумо камтар бошад.
	cfg.MaxConns          = int32(envInt("DB_MAX_CONNS", 25))
	cfg.MinConns          = int32(envInt("DB_MIN_CONNS", 5))
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

	// Галочкаҳои мӯҳлаташон гузаштаро ҳар соат хомӯш мекунад (@raonson истисно).
	go func() {
		expire := func() {
			Pool.Exec(context.Background(), `
				UPDATE users SET verified=FALSE
				WHERE verified=TRUE AND verified_until IS NOT NULL
				  AND verified_until < NOW()
				  AND LOWER(username) <> 'raonson'`)
		}
		expire()
		t := time.NewTicker(1 * time.Hour)
		defer t.Stop()
		for range t.C {
			expire()
		}
	}()
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
	-- Сифати паст (480p) барои интернети суст — пахши адаптивӣ.
	ALTER TABLE reels ADD COLUMN IF NOT EXISTS video_url_low TEXT DEFAULT '';

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

	-- ── Таърихи воридшавӣ / дастгоҳҳо (Login history) ──
	CREATE TABLE IF NOT EXISTS login_sessions (
		id TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
		user_id    TEXT NOT NULL,
		device     TEXT DEFAULT '',
		ip         TEXT DEFAULT '',
		created_at TIMESTAMPTZ DEFAULT NOW()
	);
	CREATE INDEX IF NOT EXISTS idx_login_sessions_user
		ON login_sessions(user_id, created_at DESC);

	-- ── App settings persistence (theme / language) ──
	ALTER TABLE users ADD COLUMN IF NOT EXISTS theme    VARCHAR(10) DEFAULT 'dark';
	ALTER TABLE users ADD COLUMN IF NOT EXISTS language VARCHAR(5)  DEFAULT 'tj';

	-- ── Registration profile fields ──
	ALTER TABLE users ADD COLUMN IF NOT EXISTS full_name VARCHAR(100) DEFAULT '';
	ALTER TABLE users ADD COLUMN IF NOT EXISTS phone     VARCHAR(20)  DEFAULT '';

	-- ── Verification expiry (NULL = беохир) ──
	ALTER TABLE users ADD COLUMN IF NOT EXISTS verified_until TIMESTAMPTZ;

	-- ── VIP (720p/1080p-и аниме) — admin медиҳад ──
	ALTER TABLE users ADD COLUMN IF NOT EXISTS is_vip BOOLEAN DEFAULT FALSE;

	-- ── Username change rate-limit (once every 14 days) ──
	ALTER TABLE users ADD COLUMN IF NOT EXISTS username_changed_at TIMESTAMPTZ;

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
	-- items: [{"url":"...","type":"image|video"}] — медиа дар худи highlight нигоҳ
	-- дошта мешавад, то баъди тамом шудани story ҳам намонад (мисли Instagram).
	ALTER TABLE highlights ADD COLUMN IF NOT EXISTS items JSONB DEFAULT '[]'::jsonb;

	-- ════════════════════════════════════════════════════════════════
	-- Columns/tables referenced by handlers but missing from migrate()
	-- (schema.sql is NOT executed at boot — only this migrate() runs).
	-- ════════════════════════════════════════════════════════════════
	ALTER TABLE posts    ADD COLUMN IF NOT EXISTS hidden         BOOLEAN DEFAULT FALSE;
	ALTER TABLE posts    ADD COLUMN IF NOT EXISTS interest_score INTEGER DEFAULT 0;
	ALTER TABLE posts    ADD COLUMN IF NOT EXISTS music_title    TEXT DEFAULT '';
	ALTER TABLE posts    ADD COLUMN IF NOT EXISTS music_artist   TEXT DEFAULT '';
	ALTER TABLE posts    ADD COLUMN IF NOT EXISTS music_url      TEXT DEFAULT '';
	ALTER TABLE posts    ADD COLUMN IF NOT EXISTS location       TEXT DEFAULT '';
	ALTER TABLE posts    ADD COLUMN IF NOT EXISTS tagged_users   TEXT[] DEFAULT '{}';
	ALTER TABLE posts    ADD COLUMN IF NOT EXISTS collaborators  TEXT[] DEFAULT '{}';
	ALTER TABLE comments ADD COLUMN IF NOT EXISTS updated_at     TIMESTAMPTZ DEFAULT NOW();
	ALTER TABLE comments ADD COLUMN IF NOT EXISTS parent_id      TEXT;
	ALTER TABLE messages ADD COLUMN IF NOT EXISTS type           VARCHAR(16) DEFAULT 'text';
	ALTER TABLE messages ADD COLUMN IF NOT EXISTS reply_to_id    TEXT;
	ALTER TABLE messages ADD COLUMN IF NOT EXISTS is_deleted     BOOLEAN DEFAULT FALSE;
	ALTER TABLE messages ADD COLUMN IF NOT EXISTS updated_at     TIMESTAMPTZ DEFAULT NOW();
	ALTER TABLE messages ADD COLUMN IF NOT EXISTS group_id       TEXT;

	-- ── Group chats (гурӯҳҳои чат) ──────────────────────────────────
	CREATE TABLE IF NOT EXISTS group_chats (
		id TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
		name TEXT NOT NULL,
		avatar TEXT DEFAULT '',
		owner_id TEXT NOT NULL,
		invite_token TEXT UNIQUE DEFAULT substr(md5(random()::text), 1, 12),
		created_at TIMESTAMPTZ DEFAULT NOW()
	);
	CREATE TABLE IF NOT EXISTS group_members (
		group_id TEXT NOT NULL,
		user_id TEXT NOT NULL,
		role TEXT DEFAULT 'member',
		joined_at TIMESTAMPTZ DEFAULT NOW(),
		PRIMARY KEY (group_id, user_id)
	);
	CREATE INDEX IF NOT EXISTS idx_group_members_user ON group_members(user_id);
	CREATE INDEX IF NOT EXISTS idx_messages_group ON messages(group_id, created_at DESC);

	-- ── Shopping (маҳсулот дар пост + фармоишҳо + комиссия) ─────────
	ALTER TABLE posts ADD COLUMN IF NOT EXISTS is_product   BOOLEAN DEFAULT FALSE;
	ALTER TABLE posts ADD COLUMN IF NOT EXISTS price        NUMERIC DEFAULT 0;
	ALTER TABLE posts ADD COLUMN IF NOT EXISTS currency     TEXT DEFAULT 'TJS';
	ALTER TABLE posts ADD COLUMN IF NOT EXISTS product_name TEXT DEFAULT '';
	ALTER TABLE posts ADD COLUMN IF NOT EXISTS shop_lat     DOUBLE PRECISION DEFAULT 0;
	ALTER TABLE posts ADD COLUMN IF NOT EXISTS shop_lng     DOUBLE PRECISION DEFAULT 0;
	ALTER TABLE posts ADD COLUMN IF NOT EXISTS shop_address TEXT DEFAULT '';
	ALTER TABLE posts ADD COLUMN IF NOT EXISTS in_stock     BOOLEAN DEFAULT TRUE;
	-- Роҳҳои алоқа бо фурӯшанда (харидор кадомашро мехоҳад интихоб мекунад).
	ALTER TABLE posts ADD COLUMN IF NOT EXISTS contact_raonson  BOOLEAN DEFAULT TRUE;
	ALTER TABLE posts ADD COLUMN IF NOT EXISTS shop_whatsapp    TEXT DEFAULT '';
	ALTER TABLE posts ADD COLUMN IF NOT EXISTS shop_phone       TEXT DEFAULT '';
	CREATE INDEX IF NOT EXISTS idx_posts_product ON posts(is_product, created_at DESC);

	CREATE TABLE IF NOT EXISTS orders (
		id TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
		post_id    TEXT NOT NULL,
		buyer_id   TEXT NOT NULL,
		seller_id  TEXT NOT NULL,
		price      NUMERIC DEFAULT 0,
		commission NUMERIC DEFAULT 0,
		currency   TEXT DEFAULT 'TJS',
		status     TEXT DEFAULT 'pending',
		note       TEXT DEFAULT '',
		created_at TIMESTAMPTZ DEFAULT NOW()
	);
	CREATE INDEX IF NOT EXISTS idx_orders_buyer  ON orders(buyer_id, created_at DESC);
	CREATE INDEX IF NOT EXISTS idx_orders_seller ON orders(seller_id, created_at DESC);
	-- ── Order status management (seller CRM) ──
	ALTER TABLE orders ADD COLUMN IF NOT EXISTS status TEXT DEFAULT 'pending';

	-- ── Промокодҳо / купонҳо (Business) ──
	CREATE TABLE IF NOT EXISTS promo_codes (
		id TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
		seller_id    TEXT NOT NULL,
		code         TEXT NOT NULL,
		discount_pct INT  DEFAULT 0,
		max_uses     INT  DEFAULT 0,
		used_count   INT  DEFAULT 0,
		expires_at   TIMESTAMPTZ,
		created_at   TIMESTAMPTZ DEFAULT NOW(),
		UNIQUE(seller_id, code)
	);
	CREATE INDEX IF NOT EXISTS idx_promo_seller ON promo_codes(seller_id);

	-- ── Effects marketplace (эффектҳои корбарон) ────────────────────
	CREATE TABLE IF NOT EXISTS effects (
		id TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
		creator_id TEXT NOT NULL,
		name       TEXT NOT NULL,
		matrix     TEXT NOT NULL,          -- JSON: [20 double]
		price      NUMERIC DEFAULT 0,      -- 0 = ройгон
		downloads  INTEGER DEFAULT 0,
		created_at TIMESTAMPTZ DEFAULT NOW()
	);
	CREATE INDEX IF NOT EXISTS idx_effects_created ON effects(created_at DESC);
	CREATE TABLE IF NOT EXISTS effect_purchases (
		effect_id  TEXT NOT NULL,
		buyer_id   TEXT NOT NULL,
		creator_id TEXT NOT NULL,
		price      NUMERIC DEFAULT 0,
		commission NUMERIC DEFAULT 0,
		created_at TIMESTAMPTZ DEFAULT NOW(),
		PRIMARY KEY (effect_id, buyer_id)
	);

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

	-- ── Tables/columns for newly-connected features ──
	ALTER TABLE reel_comments ADD COLUMN IF NOT EXISTS parent_id   TEXT;
	ALTER TABLE users         ADD COLUMN IF NOT EXISTS notif_prefs JSONB DEFAULT '{}';

	CREATE TABLE IF NOT EXISTS reel_reports (
		reel_id    TEXT NOT NULL,
		user_id    TEXT NOT NULL,
		reason     TEXT DEFAULT '',
		created_at TIMESTAMPTZ DEFAULT NOW(),
		PRIMARY KEY (reel_id, user_id)
	);
	CREATE TABLE IF NOT EXISTS reel_not_interested (
		reel_id    TEXT NOT NULL,
		user_id    TEXT NOT NULL,
		created_at TIMESTAMPTZ DEFAULT NOW(),
		PRIMARY KEY (reel_id, user_id)
	);
	CREATE TABLE IF NOT EXISTS reel_comment_likes (
		comment_id TEXT NOT NULL,
		user_id    TEXT NOT NULL,
		PRIMARY KEY (comment_id, user_id)
	);
	CREATE TABLE IF NOT EXISTS story_replies (
		id           TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
		story_id     TEXT NOT NULL,
		from_user_id TEXT NOT NULL,
		text         TEXT NOT NULL,
		created_at   TIMESTAMPTZ DEFAULT NOW()
	);
	CREATE INDEX IF NOT EXISTS idx_story_replies_story ON story_replies(story_id);

	-- Барои тартиби бинандагони story (Instagram "seen by")
	ALTER TABLE story_views ADD COLUMN IF NOT EXISTS viewed_at TIMESTAMPTZ DEFAULT NOW();

	-- ── Performance indexes on hot reverse-lookup columns ──
	CREATE INDEX IF NOT EXISTS idx_users_phone       ON users(phone);
	CREATE INDEX IF NOT EXISTS idx_post_saves_post   ON post_saves(post_id);
	CREATE INDEX IF NOT EXISTS idx_post_views_post   ON post_views(post_id);
	CREATE INDEX IF NOT EXISTS idx_reel_likes_reel   ON reel_likes(reel_id);
	CREATE INDEX IF NOT EXISTS idx_reel_saves_reel   ON reel_saves(reel_id);
	CREATE INDEX IF NOT EXISTS idx_comment_likes_cmt ON comment_likes(comment_id);
	CREATE INDEX IF NOT EXISTS idx_story_views_story ON story_views(story_id);

	-- ── Composite indexes барои EXISTS-и isLiked/isSaved/isFollowing ──
	-- Дар feed/reels ин санҷишҳо барои ҲАР пост/reel иҷро мешаванд; индекси
	-- мураккаб онро ба як ҷустуҷӯи индекс табдил медиҳад (барои 20k+ муҳим).
	CREATE INDEX IF NOT EXISTS idx_post_likes_post_user   ON post_likes(post_id, user_id);
	CREATE INDEX IF NOT EXISTS idx_post_saves_post_user   ON post_saves(post_id, user_id);
	CREATE INDEX IF NOT EXISTS idx_reel_likes_reel_user   ON reel_likes(reel_id, user_id);
	CREATE INDEX IF NOT EXISTS idx_reel_saves_reel_user   ON reel_saves(reel_id, user_id);
	CREATE INDEX IF NOT EXISTS idx_story_likes_story_user ON story_likes(story_id, user_id);
	CREATE INDEX IF NOT EXISTS idx_story_views_story_user ON story_views(story_id, user_id);
	CREATE INDEX IF NOT EXISTS idx_follows_pair           ON follows(follower_id, following_id);
	CREATE INDEX IF NOT EXISTS idx_comment_likes_cmt_user ON comment_likes(comment_id, user_id);

	-- ── Реклама / Тарғиб (promotions) — фармоиши реклама барои пост ──
	CREATE TABLE IF NOT EXISTS promotions (
		id          TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
		user_id     TEXT NOT NULL,
		post_id     TEXT NOT NULL,
		goal        TEXT DEFAULT 'profile',   -- profile | website | messages
		action_url  TEXT DEFAULT '',
		audience    TEXT DEFAULT 'auto',      -- auto | manual
		budget_cents INTEGER DEFAULT 100,     -- буҷет (сент/рӯз)
		duration_days INTEGER DEFAULT 1,
		status      TEXT DEFAULT 'in_review', -- in_review | active | finished | rejected
		impressions INTEGER DEFAULT 0,
		clicks      INTEGER DEFAULT 0,
		created_at  TIMESTAMPTZ DEFAULT NOW(),
		ends_at     TIMESTAMPTZ
	);
	CREATE INDEX IF NOT EXISTS idx_promotions_user ON promotions(user_id, created_at DESC);
	CREATE INDEX IF NOT EXISTS idx_promotions_post ON promotions(post_id);

	-- ── Тӯҳфаҳо (gifts / звёзды) — дастгирии муаллифон ──
	CREATE TABLE IF NOT EXISTS gifts (
		id           TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
		from_user_id TEXT NOT NULL,
		to_user_id   TEXT NOT NULL,
		target_type  TEXT DEFAULT 'reel',   -- reel | post | comment
		target_id    TEXT DEFAULT '',
		stars        INTEGER DEFAULT 1,
		message      TEXT DEFAULT '',
		created_at   TIMESTAMPTZ DEFAULT NOW()
	);
	CREATE INDEX IF NOT EXISTS idx_gifts_to   ON gifts(to_user_id, created_at DESC);
	CREATE INDEX IF NOT EXISTS idx_gifts_from ON gifts(from_user_id, created_at DESC);
	ALTER TABLE users ADD COLUMN IF NOT EXISTS stars_balance INTEGER DEFAULT 0;
	ALTER TABLE users ADD COLUMN IF NOT EXISTS bio_song      JSONB   DEFAULT '{}'::jsonb;
	ALTER TABLE users ADD COLUMN IF NOT EXISTS cover_url     TEXT    DEFAULT '';
	ALTER TABLE users ADD COLUMN IF NOT EXISTS bio_links     TEXT    DEFAULT '';
	ALTER TABLE posts ADD COLUMN IF NOT EXISTS hide_likes    BOOLEAN DEFAULT FALSE;
	ALTER TABLE posts ADD COLUMN IF NOT EXISTS comments_off  BOOLEAN DEFAULT FALSE;
	ALTER TABLE posts ADD COLUMN IF NOT EXISTS archived      BOOLEAN DEFAULT FALSE;
	ALTER TABLE posts ADD COLUMN IF NOT EXISTS scheduled_at  TIMESTAMPTZ;
	ALTER TABLE posts ADD COLUMN IF NOT EXISTS featured      BOOLEAN DEFAULT FALSE;
	ALTER TABLE reels ADD COLUMN IF NOT EXISTS hide_likes    BOOLEAN DEFAULT FALSE;
	ALTER TABLE reels ADD COLUMN IF NOT EXISTS comments_off  BOOLEAN DEFAULT FALSE;
	ALTER TABLE stories ADD COLUMN IF NOT EXISTS archived    BOOLEAN DEFAULT FALSE;
	ALTER TABLE stories ADD COLUMN IF NOT EXISTS replies_off BOOLEAN DEFAULT FALSE;

	-- ── Live-стримҳо (Agora broadcast) ──
	CREATE TABLE IF NOT EXISTS live_streams (
		id TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
		host_id    TEXT NOT NULL,
		channel    TEXT NOT NULL,
		title      TEXT DEFAULT '',
		viewers    INTEGER DEFAULT 0,
		likes      INTEGER DEFAULT 0,
		active     BOOLEAN DEFAULT TRUE,
		started_at TIMESTAMPTZ DEFAULT NOW(),
		ended_at   TIMESTAMPTZ
	);
	CREATE INDEX IF NOT EXISTS idx_live_active ON live_streams(active, started_at DESC);
	ALTER TABLE live_streams ADD COLUMN IF NOT EXISTS likes INTEGER DEFAULT 0;

	CREATE TABLE IF NOT EXISTS live_comments (
		id TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
		stream_id  TEXT NOT NULL,
		user_id    TEXT NOT NULL,
		text       TEXT NOT NULL,
		created_at TIMESTAMPTZ DEFAULT NOW()
	);
	CREATE INDEX IF NOT EXISTS idx_live_comments ON live_comments(stream_id, created_at);

	-- ── Шикоят аз корбар ва маҳдудкунӣ (report / restrict) ──
	CREATE TABLE IF NOT EXISTS user_reports (
		reported_id TEXT NOT NULL,
		user_id     TEXT NOT NULL,
		reason      TEXT DEFAULT '',
		created_at  TIMESTAMPTZ DEFAULT NOW(),
		PRIMARY KEY (reported_id, user_id)
	);
	CREATE TABLE IF NOT EXISTS user_restricts (
		user_id      TEXT NOT NULL,
		restricted_id TEXT NOT NULL,
		created_at   TIMESTAMPTZ DEFAULT NOW(),
		PRIMARY KEY (user_id, restricted_id)
	);

	-- ── Дархостҳои паём: қабул/пинҳон (мисли Instagram message requests) ──
	CREATE TABLE IF NOT EXISTS chat_accepts (
		user_id TEXT NOT NULL,
		peer_id TEXT NOT NULL,
		created_at TIMESTAMPTZ DEFAULT NOW(),
		PRIMARY KEY (user_id, peer_id)
	);
	CREATE TABLE IF NOT EXISTS chat_hidden (
		user_id TEXT NOT NULL,
		peer_id TEXT NOT NULL,
		created_at TIMESTAMPTZ DEFAULT NOW(),
		PRIMARY KEY (user_id, peer_id)
	);

	-- ── Analytics events (batch-inserted from client) ──
	CREATE TABLE IF NOT EXISTS events (
		id         TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
		user_id    TEXT,
		event      TEXT NOT NULL,
		params     JSONB DEFAULT '{}'::jsonb,
		created_at TIMESTAMPTZ DEFAULT NOW()
	);
	CREATE INDEX IF NOT EXISTS idx_events_user  ON events(user_id, created_at DESC);
	CREATE INDEX IF NOT EXISTS idx_events_event ON events(event, created_at DESC);

	-- ── Reel watch-time tracking (avg watch / completion rate) ──
	CREATE TABLE IF NOT EXISTS reel_watch (
		user_id    TEXT NOT NULL,
		reel_id    TEXT NOT NULL,
		watch_ms   INTEGER DEFAULT 0,
		completed  BOOLEAN DEFAULT FALSE,
		created_at TIMESTAMPTZ DEFAULT NOW(),
		PRIMARY KEY (user_id, reel_id)
	);
	CREATE INDEX IF NOT EXISTS idx_reel_watch_reel ON reel_watch(reel_id);

	-- ── Perf indexes (block/view dedup lookups) ──
	CREATE INDEX IF NOT EXISTS idx_blocks_blocked ON blocks(blocked_id);
	CREATE INDEX IF NOT EXISTS idx_post_views_user_post ON post_views(user_id, post_id);
	CREATE INDEX IF NOT EXISTS idx_reel_views_dedup ON reel_views(user_id, reel_id);

	-- ── Muted users ──
	CREATE TABLE IF NOT EXISTS muted_users (
		user_id  TEXT NOT NULL,
		muted_id TEXT NOT NULL,
		muted_at TIMESTAMPTZ DEFAULT NOW(),
		PRIMARY KEY (user_id, muted_id)
	);
	CREATE INDEX IF NOT EXISTS idx_muted_users ON muted_users(user_id);

	-- ── Post "not interested" ──
	CREATE TABLE IF NOT EXISTS post_not_interested (
		post_id TEXT NOT NULL,
		user_id TEXT NOT NULL,
		PRIMARY KEY (post_id, user_id)
	);

	-- ── Дӯстони наздик (close friends, мисли Instagram «Близкие друзья») ──
	ALTER TABLE users ADD COLUMN IF NOT EXISTS phone VARCHAR(20) DEFAULT '';
	CREATE TABLE IF NOT EXISTS close_friends (
		user_id    TEXT NOT NULL,
		friend_id  TEXT NOT NULL,
		created_at TIMESTAMPTZ DEFAULT now(),
		PRIMARY KEY (user_id, friend_id)
	);
	CREATE INDEX IF NOT EXISTS idx_close_friends_user ON close_friends(user_id);

	-- ── App owner: @raonson ҳамеша admin + verified + VIP (ройгон, бе харид) ──
	UPDATE users SET role='admin', verified=TRUE, is_vip=TRUE
	WHERE LOWER(username)='raonson';
	`
	if _, err := Pool.Exec(ctx, sql); err != nil {
		log.Fatalf("❌ Migration failed: %v", err)
	}
	log.Println("✅ DB schema ready")
}
