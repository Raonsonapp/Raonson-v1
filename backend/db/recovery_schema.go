package db

// Барқарорсозии ҳисоб (рамзро фаромӯш кардед).
//
//   - password_reset_tokens — token-и якдафъаина, ки баъди тасдиқи рамзи
//     6-рақама (ё баъди тасдиқи admin) дода мешавад. Дар база танҳо
//     HASH-и он (sha256) нигоҳ дошта мешавад — дуздидани база token
//     намедиҳад. Ба user_id баста аст, мӯҳлат дорад ва як бор кор мекунад.
//   - account_recovery_requests — «Кӯмак лозим»: вақте корбар ба почта ва
//     телефон дастрасӣ надорад. Admin дархостро тасдиқ ё рад мекунад; кӣ
//     тасдиқ кард — сабт мешавад. Як ҳисоб — як дархости кушода.
//
// Индексҳо барои ҷустуҷӯи ҳисоб: почта бе фарқи ҳарф ва телефон танҳо аз
// рӯи рақамҳо (+992 / 992 / фосила — ҳама як хел).
const RecoverySchema = `
CREATE TABLE IF NOT EXISTS password_reset_tokens (
    token_hash TEXT PRIMARY KEY,
    user_id    TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    -- 'otp' (рамзи 6-рақама тасдиқ шуд) | 'admin_help' (admin тасдиқ кард)
    purpose    TEXT NOT NULL DEFAULT 'otp',
    expires_at TIMESTAMPTZ NOT NULL,
    used_at    TIMESTAMPTZ,
    created_by TEXT DEFAULT '',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_reset_tokens_user ON password_reset_tokens(user_id);
CREATE INDEX IF NOT EXISTS idx_reset_tokens_exp  ON password_reset_tokens(expires_at);

CREATE TABLE IF NOT EXISTS account_recovery_requests (
    id            TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
    user_id       TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    identifier    TEXT NOT NULL DEFAULT '',
    contact_email TEXT NOT NULL,
    full_name     TEXT NOT NULL DEFAULT '',
    message       TEXT NOT NULL DEFAULT '',
    status        TEXT NOT NULL DEFAULT 'pending',
    ip            TEXT NOT NULL DEFAULT '',
    reviewed_by   TEXT NOT NULL DEFAULT '',
    reviewed_at   TIMESTAMPTZ,
    review_note   TEXT NOT NULL DEFAULT '',
    created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT recovery_status CHECK (status IN ('pending','approved','rejected'))
);
CREATE INDEX IF NOT EXISTS idx_recovery_req_status
    ON account_recovery_requests(status, created_at DESC);
-- Як дархости кушода ба як ҳисоб.
CREATE UNIQUE INDEX IF NOT EXISTS idx_recovery_req_open
    ON account_recovery_requests(user_id) WHERE status = 'pending';

CREATE INDEX IF NOT EXISTS idx_users_email_lower ON users (LOWER(email));
CREATE INDEX IF NOT EXISTS idx_users_phone_digits
    ON users ((regexp_replace(phone, '\D', '', 'g')));
`
