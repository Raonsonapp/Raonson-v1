package db

// Як ҳисоб барои Raonson ва TajikShop (SSO).
//
//   - external_accounts — пайванди ҳисоби Raonson бо ҳисоби барномаи
//     шарик. Як ҳисоби TajikShop — як ҳисоби Raonson ва баръакс (ду
//     индекси ягона). `ts_refresh_token` РАМЗГУЗОРӢ шуда нигоҳ дошта
//     мешавад (AES-GCM, ниг. handlers/sso_crypto.go) — дуздидани база
//     сессияи TajikShop намедиҳад.
//   - sso_pending_links — «Ин почта аллакай дар Raonson ҳаст»: пайванд
//     то он даме ки корбар бо рамзи Raonson ворид нашавад, сохта
//     намешавад. Token-и якдафъаина (10 дақ), дар база танҳо ҳэши он.
//
// external_accounts бо ON DELETE CASCADE ба users баста аст ва ғайр аз
// он дар deleteAccount ошкоро пок мешавад. sso_pending_links ҳанӯз
// корбар надорад — он танҳо ба шиносаи TajikShop баста аст.
const SSOSchema = `
CREATE TABLE IF NOT EXISTS external_accounts (
    id               TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
    provider         TEXT NOT NULL,
    external_id      TEXT NOT NULL,
    user_id          TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    ext_name         TEXT NOT NULL DEFAULT '',
    ext_email        TEXT NOT NULL DEFAULT '',
    ts_refresh_token TEXT NOT NULL DEFAULT '',
    linked_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at       TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE UNIQUE INDEX IF NOT EXISTS idx_ext_accounts_ext
    ON external_accounts(provider, external_id);
CREATE UNIQUE INDEX IF NOT EXISTS idx_ext_accounts_user
    ON external_accounts(provider, user_id);

CREATE TABLE IF NOT EXISTS sso_pending_links (
    token_hash       TEXT PRIMARY KEY,
    provider         TEXT NOT NULL,
    external_id      TEXT NOT NULL,
    ext_name         TEXT NOT NULL DEFAULT '',
    ext_email        TEXT NOT NULL DEFAULT '',
    ts_refresh_token TEXT NOT NULL DEFAULT '',
    expires_at       TIMESTAMPTZ NOT NULL,
    used_at          TIMESTAMPTZ,
    created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_sso_pending_exp ON sso_pending_links(expires_at);
`
