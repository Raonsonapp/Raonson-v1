package db

// Шарҳҳои часпонидашуда (pinned) — мисли Instagram: соҳиби пост/Reel то
// 3 шарҳро дар болои рӯйхат мечаспонад.
const pinnedCommentsSchema = `
ALTER TABLE comments      ADD COLUMN IF NOT EXISTS pinned_at TIMESTAMPTZ;
ALTER TABLE reel_comments ADD COLUMN IF NOT EXISTS pinned_at TIMESTAMPTZ;
CREATE INDEX IF NOT EXISTS idx_comments_pinned
    ON comments(post_id, pinned_at DESC) WHERE pinned_at IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_reel_comments_pinned
    ON reel_comments(reel_id, pinned_at DESC) WHERE pinned_at IS NOT NULL;
`
