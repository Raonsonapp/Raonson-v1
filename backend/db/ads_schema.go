package db

// Ҷадвалҳои реклама ва галочка.
//
// impression_id калиди асосист: ҳамон нишондиҳӣ ду бор ҳисоб
// намешавад, ҳатто агар шабака callback-ро такрор фиристад.
const adsSchema = `
CREATE TABLE IF NOT EXISTS ad_rewards (
    impression_id TEXT PRIMARY KEY,
    user_id       TEXT NOT NULL,
    network       TEXT NOT NULL DEFAULT '',
    created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_ad_rewards_user
    ON ad_rewards(user_id, created_at DESC);

CREATE TABLE IF NOT EXISTS verification_state (
    user_id    TEXT PRIMARY KEY,
    -- Ҳадафи корбар: 3d | 7d | 30d
    goal       TEXT NOT NULL DEFAULT '3d',
    -- Рекламаҳое, ки аллакай ба мӯҳлат табдил шудаанд.
    ads_spent  INTEGER NOT NULL DEFAULT 0,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT verification_goal CHECK (goal IN ('3d','7d','30d')),
    CONSTRAINT verification_spent_nonneg CHECK (ads_spent >= 0)
);
`
