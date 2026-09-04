package db

// Схемаи кашфиёт: Trend Radar, эҷодкорони боло, ҷамъбасти ҳафтаина.
//
// Тренд дар вақти дархост ҳисоб НАМЕШАВАД. Ҳисоби «7 рӯзи ҷорӣ бар
// зидди 7 рӯзи гузашта» дар тамоми ҷадвали ҳодисаҳо гарон аст ва
// ҳар кушодани экран онро такрор мекард. Job онро як бор ҳисоб
// мекунад ва ин ҷо мегузорад.
const discoverSchema = `
-- ── Тренди мавзӯъ ────────────────────────────────────────────────
-- Ҳар сатр як мавзӯъ дар як лаҳзаи ҳисоб.
CREATE TABLE IF NOT EXISTS trend_snapshots (
    id            BIGSERIAL PRIMARY KEY,
    kind          TEXT NOT NULL DEFAULT 'topic',   -- 'topic' | 'hashtag'
    slug          TEXT NOT NULL,
    -- Шумориши давраи ҷорӣ ва давраи қаблӣ (ҳамон дарозӣ).
    current_count  INTEGER NOT NULL DEFAULT 0,
    previous_count INTEGER NOT NULL DEFAULT 0,
    -- Фоизи тағйир. NULL вақте намунаи маълумот кам аст — дар ин
    -- ҳолат фоиз бемаъно мешавад ва НИШОН ДОДА НАМЕШАВАД.
    change_pct    REAL,
    -- Оё ин сатр барои намоиш кофӣ маълумот дорад?
    significant   BOOLEAN NOT NULL DEFAULT FALSE,
    computed_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT trend_kind CHECK (kind IN ('topic','hashtag'))
);
CREATE INDEX IF NOT EXISTS idx_trend_latest
    ON trend_snapshots(kind, computed_at DESC);
-- Дар як лаҳза як мавзӯъ як бор.
CREATE UNIQUE INDEX IF NOT EXISTS uq_trend_slot
    ON trend_snapshots(kind, slug, computed_at);

-- ── Холи «боло рафтани» эҷодкор ──────────────────────────────────
-- Аз рӯи ҳодисаҳои ВОҚЕӢ ҳисоб мешавад, на аз шумораи обуначиён.
CREATE TABLE IF NOT EXISTS creator_rising (
    creator_id     TEXT PRIMARY KEY,
    -- Сигналҳои хом — то маълум бошад, ки хол аз чӣ омад.
    followers_gained INTEGER NOT NULL DEFAULT 0,
    impressions      INTEGER NOT NULL DEFAULT 0,
    completions      INTEGER NOT NULL DEFAULT 0,
    saves            INTEGER NOT NULL DEFAULT 0,
    shares           INTEGER NOT NULL DEFAULT 0,
    content_count    INTEGER NOT NULL DEFAULT 0,
    score            REAL NOT NULL DEFAULT 0,
    computed_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_creator_rising_score
    ON creator_rising(score DESC);

-- ── Ҷамъбасти ҳафтаина ───────────────────────────────────────────
-- Барои корбар ва барои эҷодкор. Як сатр ба ҳар ҳафта.
CREATE TABLE IF NOT EXISTS weekly_recaps (
    user_id     TEXT NOT NULL,
    week_start  DATE NOT NULL,
    kind        TEXT NOT NULL,          -- 'viewer' | 'creator'
    payload     JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (user_id, week_start, kind),
    CONSTRAINT weekly_recap_kind CHECK (kind IN ('viewer','creator'))
);
CREATE INDEX IF NOT EXISTS idx_weekly_recaps_user
    ON weekly_recaps(user_id, week_start DESC);

-- ── Дастовардҳои эҷодкор ─────────────────────────────────────────
-- Танҳо сервер онҳоро медиҳад; client ҳеҷ гоҳ.
CREATE TABLE IF NOT EXISTS creator_achievements (
    user_id    TEXT NOT NULL,
    code       TEXT NOT NULL,
    -- Арзише, ки дастовардро ба вуҷуд овард (масалан 1000 биниш).
    value      BIGINT NOT NULL DEFAULT 0,
    earned_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (user_id, code)
);
CREATE INDEX IF NOT EXISTS idx_creator_achievements_user
    ON creator_achievements(user_id, earned_at DESC);
`
