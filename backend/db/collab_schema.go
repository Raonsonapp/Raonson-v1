package db

// Даъвати ҳамкорӣ.
//
// Пеш аз ин, ҳар кас метавонист номи ҳар касро ҳамчун «ҳамкор» дар
// пости худ нависад — бе иҷозати ӯ. Ин номи каси дигарро ба мӯҳтавое
// мебаст, ки ӯ надида буд.
//
// Акнун posts.collaborators танҳо ҳамкорони ТАСДИҚШУДА-ро нигоҳ
// медорад, ва даъватҳо ин ҷо интизор мешаванд.
const collabSchema = `
CREATE TABLE IF NOT EXISTS post_collab_invites (
    post_id    TEXT NOT NULL,
    user_id    TEXT NOT NULL,
    -- 'pending' | 'accepted' | 'declined'
    status     TEXT NOT NULL DEFAULT 'pending',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (post_id, user_id),
    CONSTRAINT collab_status CHECK (status IN ('pending','accepted','declined'))
);
CREATE INDEX IF NOT EXISTS idx_collab_invites_user
    ON post_collab_invites(user_id, status, created_at DESC);
`
