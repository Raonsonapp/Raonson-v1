package db

// Паёми худкор ба Direct аз рӯи калимаи шарҳ (мисли ManyChat).
//
// Як қоида барои ҳар пост ё рилс. auto_dm_sent кафолат медиҳад, ки ҳар
// шарҳнавис барои ҳамин мундариҷа танҳо ЯК бор паём мегирад — ҳатто
// агар даҳ шарҳ бо калимаи калидӣ нависад.
const autoDMSchema = `
CREATE TABLE IF NOT EXISTS auto_dm_rules (
    kind       TEXT NOT NULL CHECK (kind IN ('post','reel')),
    content_id TEXT NOT NULL,
    owner_id   TEXT NOT NULL,
    keywords   TEXT[] NOT NULL DEFAULT '{}',
    any_word   BOOLEAN NOT NULL DEFAULT FALSE,
    message    TEXT NOT NULL,
    link       TEXT NOT NULL DEFAULT '',
    enabled    BOOLEAN NOT NULL DEFAULT TRUE,
    sent_count INT NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (kind, content_id)
);
CREATE INDEX IF NOT EXISTS idx_auto_dm_owner ON auto_dm_rules(owner_id);

CREATE TABLE IF NOT EXISTS auto_dm_sent (
    kind       TEXT NOT NULL,
    content_id TEXT NOT NULL,
    user_id    TEXT NOT NULL,
    owner_id   TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (kind, content_id, user_id)
);
CREATE INDEX IF NOT EXISTS idx_auto_dm_sent_owner ON auto_dm_sent(owner_id, created_at DESC);
`
