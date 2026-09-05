package db

// Ҷадвалҳои даъват.
//
// Мансубият як бор ҳангоми бақайдгирӣ сабт мешавад ва баъдан тағйир
// намеёбад: PRIMARY KEY(invitee_id) кафолат медиҳад, ки як корбар
// танҳо як даъваткунанда дошта бошад.
const referralSchema = `
CREATE TABLE IF NOT EXISTS referral_codes (
    user_id    TEXT PRIMARY KEY,
    code       TEXT NOT NULL UNIQUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS referrals (
    -- Як сатр барои ҳар корбари нав: даъваткунанда иваз намешавад.
    invitee_id TEXT PRIMARY KEY,
    inviter_id TEXT NOT NULL,
    code       TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    -- Худдаъваткунӣ дар сатҳи база низ манъ аст.
    CONSTRAINT referral_not_self CHECK (invitee_id <> inviter_id)
);
CREATE INDEX IF NOT EXISTS idx_referrals_inviter
    ON referrals(inviter_id, created_at DESC);
`
