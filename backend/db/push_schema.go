package db

// Токенҳои дастгоҳ.
//
// Ҷадвали қаблӣ push_tokens калиди UNIQUE(user_id, platform) дошт —
// яъне ҳар корбар барои ҳар платформа ТАНҲО ЯК дастгоҳ дошта
// метавонист. Касе, ки телефон ва планшет дорад, огоҳиномаро танҳо
// ба дастгоҳи охирин мегирифт; барнома дар дастгоҳи аввал хомӯш
// мешуд ва сабабаш маълум набуд.
//
// Ин ҷо калид худи ТОКЕН аст: як дастгоҳ — як сатр.
const pushSchema = `
CREATE TABLE IF NOT EXISTS device_tokens (
    token       TEXT PRIMARY KEY,
    user_id     TEXT NOT NULL,
    platform    TEXT NOT NULL DEFAULT 'android',
    -- Шиносаи дастгоҳ, агар барнома онро диҳад. Ҳангоми иваз шудани
    -- токен дар ҳамон дастгоҳ сатри кӯҳна пок карда мешавад.
    device_id   TEXT NOT NULL DEFAULT '',
    enabled     BOOLEAN NOT NULL DEFAULT TRUE,
    -- Сабаби хомӯш шудан: барои ташхис, бе он «чаро огоҳинома
    -- намеояд» ҷавоб надорад.
    disabled_reason TEXT NOT NULL DEFAULT '',
    fail_count  INTEGER NOT NULL DEFAULT 0,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    last_seen_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_device_tokens_user
    ON device_tokens(user_id) WHERE enabled;
CREATE INDEX IF NOT EXISTS idx_device_tokens_device
    ON device_tokens(user_id, device_id) WHERE device_id <> '';

-- Кӯчонидани токенҳои мавҷуда: касе набояд огоҳиномаро аз даст диҳад.
INSERT INTO device_tokens(token, user_id, platform, created_at, updated_at)
SELECT p.token, p.user_id,
       CASE WHEN p.platform IN ('android','ios') THEN p.platform
            ELSE 'android' END,
       COALESCE(p.updated_at, NOW()), COALESCE(p.updated_at, NOW())
FROM push_tokens p
WHERE p.token <> ''
ON CONFLICT (token) DO NOTHING;

-- ── Ҳисоби фиристодан ────────────────────────────────────────────
-- Барои дедупликатсия ва такрор. Як сатр барои як ҳодиса+гиранда.
CREATE TABLE IF NOT EXISTS notification_delivery (
    -- Калиди идемпотентӣ: ҳамон ҳодиса ду бор огоҳинома намедиҳад.
    dedupe_key  TEXT PRIMARY KEY,
    user_id     TEXT NOT NULL,
    kind        TEXT NOT NULL,
    -- created | sent | failed | skipped
    status      TEXT NOT NULL DEFAULT 'created',
    -- Сабаби рад: preference, quiet_hours, rate_limit, no_token ...
    reason      TEXT NOT NULL DEFAULT '',
    attempts    INTEGER NOT NULL DEFAULT 0,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_notif_delivery_user
    ON notification_delivery(user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_notif_delivery_status
    ON notification_delivery(status, created_at DESC);
`
