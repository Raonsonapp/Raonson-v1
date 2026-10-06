package db

// Модератсияи пеш аз нашр (ниг. package moderation ва handlers/moderation.go).
//
//   - moderation_queue   — ҳар қарори BLOCK (барои аудит), ҳар REVIEW
//     (мӯҳтавои пинҳон ё «санҷиданашуда») ва ҳар маҳдудкунии худкор.
//     Admin аз ин ҷо тасдиқ / нест / бан мекунад.
//   - moderation_strikes — огоҳиҳо. 3 дар 30 рӯз → маҳдудкунии муваққатӣ.
//     content_hash: такрори ҳамон мӯҳтаво (масалан навбати офлайни
//     телефон) огоҳии дуюм намедиҳад.
//   - media_uploads      — қарори санҷиш барои ҳар файли боргузошта:
//     ҳангоми сохтани пост файл дубора гирифта намешавад.
//   - users.suspended_until — маҳдудкунии муваққатӣ: корбар ворид
//     мешавад ва мехонад, вале нашр карда наметавонад. Бани доимӣ
//     (users.banned) ТАНҲО аз ҷониби admin.
//   - reels.mod_hold / stories.mod_hold_until — мӯҳтавои «шубҳанок»,
//     ки то тасдиқи admin пинҳон аст.
const moderationSchema = `
CREATE TABLE IF NOT EXISTS moderation_queue (
    id          BIGSERIAL PRIMARY KEY,
    user_id     TEXT NOT NULL,
    surface     TEXT NOT NULL,
    target_id   TEXT NOT NULL DEFAULT '',
    text        TEXT NOT NULL DEFAULT '',
    media_url   TEXT NOT NULL DEFAULT '',
    media_kind  TEXT NOT NULL DEFAULT '',
    categories  TEXT[] NOT NULL DEFAULT '{}',
    score       REAL NOT NULL DEFAULT 0,
    provider    TEXT NOT NULL DEFAULT '',
    reason      TEXT NOT NULL DEFAULT '',
    -- block | review | unscanned | suspension
    action      TEXT NOT NULL,
    held        BOOLEAN NOT NULL DEFAULT FALSE,
    -- pending | approved | removed | banned | restored | blocked
    status      TEXT NOT NULL DEFAULT 'pending',
    reviewed_by TEXT NOT NULL DEFAULT '',
    reviewed_at TIMESTAMPTZ,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_modq_status  ON moderation_queue(status, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_modq_user    ON moderation_queue(user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_modq_target  ON moderation_queue(surface, target_id);

CREATE TABLE IF NOT EXISTS moderation_strikes (
    id           BIGSERIAL PRIMARY KEY,
    user_id      TEXT NOT NULL,
    queue_id     BIGINT,
    surface      TEXT NOT NULL DEFAULT '',
    categories   TEXT[] NOT NULL DEFAULT '{}',
    severe       BOOLEAN NOT NULL DEFAULT FALSE,
    content_hash TEXT NOT NULL DEFAULT '',
    created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_modstrikes_user ON moderation_strikes(user_id, created_at DESC);

CREATE TABLE IF NOT EXISTS media_uploads (
    url        TEXT PRIMARY KEY,
    user_id    TEXT NOT NULL DEFAULT '',
    kind       TEXT NOT NULL DEFAULT '',
    verdict    TEXT NOT NULL DEFAULT '',
    held       BOOLEAN NOT NULL DEFAULT FALSE,
    categories TEXT[] NOT NULL DEFAULT '{}',
    score      REAL NOT NULL DEFAULT 0,
    provider   TEXT NOT NULL DEFAULT '',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE users   ADD COLUMN IF NOT EXISTS suspended_until   TIMESTAMPTZ;
ALTER TABLE users   ADD COLUMN IF NOT EXISTS suspension_reason TEXT NOT NULL DEFAULT '';
ALTER TABLE reels   ADD COLUMN IF NOT EXISTS mod_hold BOOLEAN NOT NULL DEFAULT FALSE;
ALTER TABLE stories ADD COLUMN IF NOT EXISTS mod_hold_until TIMESTAMPTZ;
`
