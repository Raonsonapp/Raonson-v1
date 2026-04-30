-- Chat v2 Migration — Reactions + Extended Messages

-- 1. Extend messages table
ALTER TABLE messages
  ADD COLUMN IF NOT EXISTS type         VARCHAR(20)  NOT NULL DEFAULT 'text',
  ADD COLUMN IF NOT EXISTS media_url    TEXT,
  ADD COLUMN IF NOT EXISTS reply_to_id  UUID REFERENCES messages(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS is_deleted   BOOLEAN      NOT NULL DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS status       VARCHAR(20)  NOT NULL DEFAULT 'sent',
  ADD COLUMN IF NOT EXISTS updated_at   TIMESTAMPTZ  NOT NULL DEFAULT NOW();

-- 2. Create message_reactions table
CREATE TABLE IF NOT EXISTS message_reactions (
  id          UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  message_id  UUID        NOT NULL REFERENCES messages(id) ON DELETE CASCADE,
  user_id     UUID        NOT NULL REFERENCES users(id)    ON DELETE CASCADE,
  emoji       VARCHAR(10) NOT NULL,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (message_id, user_id)
);

-- 3. Indexes
CREATE INDEX IF NOT EXISTS idx_messages_chat_id      ON messages(chat_id);
CREATE INDEX IF NOT EXISTS idx_messages_reply_to_id  ON messages(reply_to_id);
CREATE INDEX IF NOT EXISTS idx_msg_reactions_msg_id  ON message_reactions(message_id);

-- 4. Unread count view
CREATE OR REPLACE VIEW chat_unread AS
  SELECT chat_id, receiver_id AS user_id, COUNT(*) AS unread_count
  FROM messages
  WHERE is_deleted=FALSE AND status!='read'
  GROUP BY chat_id, receiver_id;
