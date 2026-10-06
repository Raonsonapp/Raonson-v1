package db

// Схемаи иҷтимоии иловагӣ. Идемпотент — ҳар оғози сервер бехатар.
//
//   - follow_sources: «Обуначиён аз ин пост/Reel» (Insights).
//   - contact_hashes: мухотибони телефон ТАНҲО ҳамчун хеш (SHA-256 бо
//     «намак»-и сервер). Рақами хом ҳеҷ гоҳ нигоҳ дошта намешавад.
//   - users.contacts_join_notify: NULL — корбар ҳанӯз розигӣ надодааст;
//     true/false — хоҳиши ӯ «хабар деҳ, вақте мухотибонам ҳамроҳ мешаванд».
//   - users.contacts_announced: ҳамроҳшавии ҳар ҳисоб ТАНҲО ЯК БОР эълон
//     мешавад (ивази чандкаратаи рақам спам намесозад).
//   - thanks: «Раҳмат» — ташаккурномаи кӯтоҳи оммавӣ дар профил.
const socialSchema = `
CREATE TABLE IF NOT EXISTS follow_sources (
    follower_id TEXT NOT NULL,
    followee_id TEXT NOT NULL,
    source_kind TEXT NOT NULL CHECK (source_kind IN ('post','reel')),
    source_id   TEXT NOT NULL,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (follower_id, followee_id)
);
CREATE INDEX IF NOT EXISTS idx_follow_sources_src
    ON follow_sources(source_kind, source_id);

CREATE TABLE IF NOT EXISTS contact_hashes (
    owner_id   TEXT NOT NULL,
    phone_hash TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (owner_id, phone_hash)
);
CREATE INDEX IF NOT EXISTS idx_contact_hashes_hash
    ON contact_hashes(phone_hash);

ALTER TABLE users ADD COLUMN IF NOT EXISTS contacts_join_notify BOOLEAN;
ALTER TABLE users ADD COLUMN IF NOT EXISTS contacts_announced BOOLEAN NOT NULL DEFAULT FALSE;

CREATE TABLE IF NOT EXISTS thanks (
    id         TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
    from_id    TEXT NOT NULL,
    to_id      TEXT NOT NULL,
    text       TEXT NOT NULL,
    hidden     BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (from_id, to_id)
);
CREATE INDEX IF NOT EXISTS idx_thanks_to ON thanks(to_id, updated_at DESC);
`
