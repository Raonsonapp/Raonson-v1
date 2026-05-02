-- ============================================================
-- RAONSON — PostgreSQL Schema
-- Run: psql $DATABASE_URL -f schema.sql
-- ============================================================

CREATE EXTENSION IF NOT EXISTS "pgcrypto";
CREATE EXTENSION IF NOT EXISTS "pg_trgm";

-- ── USERS ─────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS users (
    id                    TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
    username              VARCHAR(50) UNIQUE NOT NULL,
    email                 VARCHAR(255) UNIQUE NOT NULL,
    password              TEXT NOT NULL,
    avatar                TEXT DEFAULT '',
    bio                   TEXT DEFAULT '',
    website               TEXT DEFAULT '',
    location              TEXT DEFAULT '',
    verified              BOOLEAN DEFAULT FALSE,
    is_private            BOOLEAN DEFAULT FALSE,
    banned                BOOLEAN DEFAULT FALSE,
    role                  VARCHAR(20) DEFAULT 'user',
    posts_count           INTEGER DEFAULT 0,
    followers_count       INTEGER DEFAULT 0,
    following_count       INTEGER DEFAULT 0,
    note                  VARCHAR(60) DEFAULT '',
    note_expires_at       TIMESTAMPTZ,
    note_song_title       TEXT DEFAULT '',
    note_song_artist      TEXT DEFAULT '',
    note_song_art_url     TEXT DEFAULT '',
    note_song_preview_url TEXT DEFAULT '',
    note_song_track_ms    INTEGER DEFAULT 0,
    note_song_start_ms    INTEGER DEFAULT 0,
    note_song_end_ms      INTEGER DEFAULT 30000,
    last_seen             TIMESTAMPTZ,
    created_at            TIMESTAMPTZ DEFAULT NOW(),
    updated_at            TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_users_username     ON users(username);
CREATE INDEX IF NOT EXISTS idx_users_email        ON users(email);
CREATE INDEX IF NOT EXISTS idx_users_username_trgm ON users USING gin(username gin_trgm_ops);

-- ── FOLLOWS ───────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS follows (
    follower_id  TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    following_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    created_at   TIMESTAMPTZ DEFAULT NOW(),
    PRIMARY KEY (follower_id, following_id)
);

CREATE INDEX IF NOT EXISTS idx_follows_follower  ON follows(follower_id, following_id);
CREATE INDEX IF NOT EXISTS idx_follows_following ON follows(following_id, created_at DESC);

-- ── FOLLOW REQUESTS ───────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS follow_requests (
    requester_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    target_id    TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    created_at   TIMESTAMPTZ DEFAULT NOW(),
    PRIMARY KEY (requester_id, target_id)
);

CREATE INDEX IF NOT EXISTS idx_follow_req_target ON follow_requests(target_id, created_at DESC);

-- ── POSTS ─────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS posts (
    id              TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
    user_id         TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    caption         TEXT DEFAULT '',
    likes_count     INTEGER DEFAULT 0,
    comments_count  INTEGER DEFAULT 0,
    interest_score  INTEGER DEFAULT 0,
    hidden          BOOLEAN DEFAULT FALSE,
    created_at      TIMESTAMPTZ DEFAULT NOW(),
    updated_at      TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_posts_user_created ON posts(user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_posts_created      ON posts(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_posts_likes        ON posts(likes_count DESC, created_at DESC);

-- ── POST MEDIA ────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS post_media (
    id       TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
    post_id  TEXT NOT NULL REFERENCES posts(id) ON DELETE CASCADE,
    url      TEXT NOT NULL,
    type     VARCHAR(10) DEFAULT 'image',
    position INTEGER DEFAULT 0
);

CREATE INDEX IF NOT EXISTS idx_post_media_post ON post_media(post_id, position);

-- ── POST LIKES ────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS post_likes (
    user_id    TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    post_id    TEXT NOT NULL REFERENCES posts(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    PRIMARY KEY (user_id, post_id)
);

CREATE INDEX IF NOT EXISTS idx_post_likes_post ON post_likes(post_id, user_id);
CREATE INDEX IF NOT EXISTS idx_post_likes_user ON post_likes(user_id, created_at DESC);

-- ── POST SAVES ────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS post_saves (
    user_id    TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    post_id    TEXT NOT NULL REFERENCES posts(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    PRIMARY KEY (user_id, post_id)
);

-- ── POST VIEWS ────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS post_views (
    user_id    TEXT NOT NULL,
    post_id    TEXT NOT NULL,
    viewed_at  TIMESTAMPTZ DEFAULT NOW(),
    PRIMARY KEY (user_id, post_id)
);

CREATE INDEX IF NOT EXISTS idx_post_views_user ON post_views(user_id, post_id);

-- ── POST REPORTS ──────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS post_reports (
    post_id    TEXT NOT NULL,
    user_id    TEXT NOT NULL,
    reason     TEXT DEFAULT 'spam',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    PRIMARY KEY (post_id, user_id)
);

-- ── COMMENTS ──────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS comments (
    id          TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
    post_id     TEXT NOT NULL REFERENCES posts(id) ON DELETE CASCADE,
    user_id     TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    text        TEXT NOT NULL,
    likes_count INTEGER DEFAULT 0,
    created_at  TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_comments_post ON comments(post_id, created_at DESC);

-- ── COMMENT LIKES ─────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS comment_likes (
    user_id    TEXT NOT NULL,
    comment_id TEXT NOT NULL,
    PRIMARY KEY (user_id, comment_id)
);

-- ── STORIES ───────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS stories (
    id         TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
    user_id    TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    media_url  TEXT NOT NULL,
    media_type VARCHAR(10) NOT NULL,
    caption    TEXT DEFAULT '',
    expires_at TIMESTAMPTZ NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_stories_user    ON stories(user_id);
CREATE INDEX IF NOT EXISTS idx_stories_expires ON stories(expires_at);

-- ── STORY VIEWS / LIKES ───────────────────────────────────────────
CREATE TABLE IF NOT EXISTS story_views (
    story_id TEXT NOT NULL,
    user_id  TEXT NOT NULL,
    PRIMARY KEY (story_id, user_id)
);

CREATE TABLE IF NOT EXISTS story_likes (
    story_id TEXT NOT NULL,
    user_id  TEXT NOT NULL,
    PRIMARY KEY (story_id, user_id)
);

-- ── REELS ─────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS reels (
    id             TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
    user_id        TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    video_url      TEXT NOT NULL,
    caption        TEXT DEFAULT '',
    views_count    INTEGER DEFAULT 0,
    likes_count    INTEGER DEFAULT 0,
    comments_count INTEGER DEFAULT 0,
    created_at     TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_reels_user    ON reels(user_id);
CREATE INDEX IF NOT EXISTS idx_reels_created ON reels(created_at DESC, likes_count DESC);

-- ── REEL LIKES / SAVES / COMMENTS ────────────────────────────────
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
    id         TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
    reel_id    TEXT NOT NULL,
    user_id    TEXT NOT NULL,
    text       TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_reel_comments_reel ON reel_comments(reel_id, created_at DESC);

-- ── MESSAGES ──────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS messages (
    id          TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
    chat_id     VARCHAR(120) NOT NULL,
    sender_id   TEXT NOT NULL,
    receiver_id TEXT NOT NULL,
    text        TEXT DEFAULT '',
    media_url   TEXT DEFAULT '',
    read        BOOLEAN DEFAULT FALSE,
    created_at  TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_messages_chat   ON messages(chat_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_messages_unread ON messages(receiver_id, read, created_at DESC);

-- ── NOTIFICATIONS ─────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS notifications (
    id           TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
    user_id      TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    from_user_id TEXT REFERENCES users(id) ON DELETE SET NULL,
    type         VARCHAR(50) NOT NULL,
    target_id    TEXT,
    read         BOOLEAN DEFAULT FALSE,
    created_at   TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_notif_user    ON notifications(user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_notif_unread  ON notifications(user_id, read, created_at DESC);

-- ── PUSH TOKENS ───────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS push_tokens (
    user_id    TEXT NOT NULL,
    token      TEXT NOT NULL,
    platform   VARCHAR(10) DEFAULT 'android',
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(user_id, platform)
);

-- ── BLOCKS ────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS blocks (
    blocker_id TEXT NOT NULL,
    blocked_id TEXT NOT NULL,
    PRIMARY KEY (blocker_id, blocked_id)
);

-- ── LIKES (generic) ───────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS likes (
    id          TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
    user_id     TEXT NOT NULL,
    target_id   TEXT NOT NULL,
    target_type VARCHAR(20) NOT NULL,
    created_at  TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(user_id, target_id, target_type)
);
