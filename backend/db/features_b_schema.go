package db

// Чор функсияи нав (ниг. handlers/help_board.go, voice_post.go,
// translate.go, business.go). Ҳама IF NOT EXISTS — такрори муҳоҷират
// бехатар аст.
const featuresBSchema = `
-- Тасдиқи телефон (пеш танҳо рақам сабт мешуд, на ин ки тасдиқ шуд ё не).
-- «Кӯмаки фаврӣ» онро ҳамчун нишони эътимод истифода мебарад.
ALTER TABLE users ADD COLUMN IF NOT EXISTS phone_verified_at TIMESTAMPTZ;

-- ── «Кӯмаки фаврӣ» ────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS help_requests (
    id              TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
    user_id         TEXT NOT NULL,
    kind            VARCHAR(16) NOT NULL,
    title           VARCHAR(140) NOT NULL,
    body            TEXT NOT NULL DEFAULT '',
    blood_group     VARCHAR(4) NOT NULL DEFAULT '',
    units           INT NOT NULL DEFAULT 0,
    hospital        VARCHAR(160) NOT NULL DEFAULT '',
    city_id         TEXT NOT NULL,
    place_id        TEXT NOT NULL DEFAULT '',
    photo_url       TEXT NOT NULL DEFAULT '',
    status          VARCHAR(12) NOT NULL DEFAULT 'open',
    hidden          BOOLEAN NOT NULL DEFAULT FALSE,
    expires_at      TIMESTAMPTZ NOT NULL,
    resolved_at     TIMESTAMPTZ,
    notified_count  INT NOT NULL DEFAULT 0,
    responses_count INT NOT NULL DEFAULT 0,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_help_city_open
    ON help_requests(city_id, created_at DESC) WHERE status='open' AND hidden=FALSE;
CREATE INDEX IF NOT EXISTS idx_help_user ON help_requests(user_id, created_at DESC);

-- Донорҳо: гурӯҳи хун ва шаҳр МАХФӢ аст — танҳо барои мувофиқа.
CREATE TABLE IF NOT EXISTS help_donors (
    user_id          TEXT PRIMARY KEY,
    blood_group      VARCHAR(4) NOT NULL,
    city_id          TEXT NOT NULL,
    active           BOOLEAN NOT NULL DEFAULT TRUE,
    last_notified_at TIMESTAMPTZ,
    created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at       TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_help_donors_city ON help_donors(city_id, blood_group) WHERE active;

CREATE TABLE IF NOT EXISTS help_notified (
    request_id TEXT NOT NULL,
    user_id    TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (request_id, user_id)
);
CREATE TABLE IF NOT EXISTS help_responses (
    request_id TEXT NOT NULL,
    user_id    TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (request_id, user_id)
);
CREATE TABLE IF NOT EXISTS help_reports (
    request_id TEXT NOT NULL,
    user_id    TEXT NOT NULL,
    reason     VARCHAR(40) NOT NULL DEFAULT 'spam',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (request_id, user_id)
);

-- ── Пости овозӣ ───────────────────────────────────────────────────
ALTER TABLE post_media ADD COLUMN IF NOT EXISTS duration_ms INT;
ALTER TABLE post_media ADD COLUMN IF NOT EXISTS waveform    TEXT;
ALTER TABLE post_media ADD COLUMN IF NOT EXISTS cover       TEXT;

-- ── Тарҷума: кэш аз рӯи (хэши матн, забон) ────────────────────────
CREATE TABLE IF NOT EXISTS translations_cache (
    text_hash  CHAR(64) NOT NULL,
    target     VARCHAR(5) NOT NULL,
    translated TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (text_hash, target)
);

-- ── Профили тиҷоратӣ ──────────────────────────────────────────────
ALTER TABLE users ADD COLUMN IF NOT EXISTS is_business BOOLEAN DEFAULT FALSE;
ALTER TABLE users ADD COLUMN IF NOT EXISTS business_category VARCHAR(32) DEFAULT '';
CREATE INDEX IF NOT EXISTS idx_users_business
    ON users(business_category) WHERE is_business = TRUE;

CREATE TABLE IF NOT EXISTS business_profiles (
    user_id     TEXT PRIMARY KEY,
    category    VARCHAR(32) NOT NULL DEFAULT '',
    hours       TEXT NOT NULL DEFAULT '{}',
    address     VARCHAR(200) NOT NULL DEFAULT '',
    place_id    TEXT NOT NULL DEFAULT '',
    city_id     TEXT NOT NULL DEFAULT '',
    lat         DOUBLE PRECISION,
    lon         DOUBLE PRECISION,
    phone       VARCHAR(20) NOT NULL DEFAULT '',
    whatsapp    VARCHAR(20) NOT NULL DEFAULT '',
    price_range SMALLINT NOT NULL DEFAULT 0,
    show_chat   BOOLEAN NOT NULL DEFAULT TRUE,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Як сатр барои (тиҷорат, амал, тамошобин, рӯз): такрори ҳамон
-- одам дар ҳамон рӯз рақамро бад намекунад.
CREATE TABLE IF NOT EXISTS business_events (
    business_id TEXT NOT NULL,
    action      VARCHAR(12) NOT NULL,
    viewer_id   TEXT NOT NULL,
    day         DATE NOT NULL,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (business_id, action, viewer_id, day)
);
CREATE INDEX IF NOT EXISTS idx_business_events_day ON business_events(business_id, day);
`
