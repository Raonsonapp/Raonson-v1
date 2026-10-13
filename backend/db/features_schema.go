package db

// Схемаи панҷ имконияти нав (ниг. backend/features). Идемпотент.
//
//   - invite_events, event_* — «Даъватнома»: чорабинӣ, мизбонон, даъватшудагон
//     бо ҷавоб (Меоям/Шояд/Намеоям) ва албоми муштарак;
//   - post_polls*        — пурсиш ва викторина дар пост, як овоз;
//   - profile_questions  — «Савол ба ман» (asker_id ҳамеша сабт мешавад,
//     ҳатто барои саволи беном — модератсия бояд донад);
//   - time_capsules      — «Мактуб ба оянда»: мӯҳр то санаи кушодан;
//   - challenges*        — «Чаленҷ» дар атрофи хештег, ғолибон ва нишон.
const featuresSchema = `
CREATE TABLE IF NOT EXISTS invite_events (
    id           TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
    host_id      TEXT NOT NULL,
    title        TEXT NOT NULL,
    kind         TEXT NOT NULL DEFAULT 'other',
    description  TEXT NOT NULL DEFAULT '',
    cover_url    TEXT NOT NULL DEFAULT '',
    starts_at    TIMESTAMPTZ NOT NULL,
    ends_at      TIMESTAMPTZ,
    place_name   TEXT NOT NULL DEFAULT '',
    place_id     TEXT NOT NULL DEFAULT '',
    place_lat    DOUBLE PRECISION,
    place_lon    DOUBLE PRECISION,
    is_public    BOOLEAN NOT NULL DEFAULT FALSE,
    max_plus     INTEGER NOT NULL DEFAULT 3,
    invite_code  TEXT NOT NULL DEFAULT substr(md5(random()::text), 1, 10),
    cancelled    BOOLEAN NOT NULL DEFAULT FALSE,
    hidden       BOOLEAN NOT NULL DEFAULT FALSE,
    reminded_day BOOLEAN NOT NULL DEFAULT FALSE,
    reminded_2h  BOOLEAN NOT NULL DEFAULT FALSE,
    created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_invite_events_host ON invite_events(host_id, starts_at DESC);
CREATE INDEX IF NOT EXISTS idx_invite_events_reminders ON invite_events(starts_at)
    WHERE cancelled = FALSE AND (reminded_day = FALSE OR reminded_2h = FALSE);
CREATE INDEX IF NOT EXISTS idx_invite_events_public ON invite_events(starts_at)
    WHERE is_public = TRUE AND cancelled = FALSE AND hidden = FALSE;

CREATE TABLE IF NOT EXISTS event_cohosts (
    event_id TEXT NOT NULL,
    user_id  TEXT NOT NULL,
    PRIMARY KEY (event_id, user_id)
);
CREATE INDEX IF NOT EXISTS idx_event_cohosts_user ON event_cohosts(user_id);

CREATE TABLE IF NOT EXISTS event_guests (
    event_id     TEXT NOT NULL,
    user_id      TEXT NOT NULL,
    invited_by   TEXT NOT NULL DEFAULT '',
    rsvp         TEXT NOT NULL DEFAULT 'pending',
    plus         INTEGER NOT NULL DEFAULT 0,
    invited_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    responded_at TIMESTAMPTZ,
    PRIMARY KEY (event_id, user_id),
    CONSTRAINT event_guests_rsvp CHECK (rsvp IN ('pending','going','maybe','declined'))
);
CREATE INDEX IF NOT EXISTS idx_event_guests_user ON event_guests(user_id);

CREATE TABLE IF NOT EXISTS event_photos (
    id         TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
    event_id   TEXT NOT NULL,
    user_id    TEXT NOT NULL,
    url        TEXT NOT NULL,
    hidden     BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_event_photos_event ON event_photos(event_id, created_at DESC);

CREATE TABLE IF NOT EXISTS post_polls (
    post_id       TEXT PRIMARY KEY,
    question      TEXT NOT NULL DEFAULT '',
    options       TEXT[] NOT NULL,
    correct_index INTEGER,
    ends_at       TIMESTAMPTZ,
    created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE TABLE IF NOT EXISTS post_poll_votes (
    post_id      TEXT NOT NULL,
    user_id      TEXT NOT NULL,
    option_index INTEGER NOT NULL,
    created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (post_id, user_id)
);
CREATE INDEX IF NOT EXISTS idx_post_poll_votes_opt ON post_poll_votes(post_id, option_index);

ALTER TABLE users ADD COLUMN IF NOT EXISTS qa_mode TEXT NOT NULL DEFAULT 'followers';
CREATE TABLE IF NOT EXISTS profile_questions (
    id          TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
    owner_id    TEXT NOT NULL,
    asker_id    TEXT NOT NULL,
    text        TEXT NOT NULL,
    anonymous   BOOLEAN NOT NULL DEFAULT FALSE,
    answer      TEXT NOT NULL DEFAULT '',
    status      TEXT NOT NULL DEFAULT 'pending',
    hidden      BOOLEAN NOT NULL DEFAULT FALSE,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    answered_at TIMESTAMPTZ,
    CONSTRAINT profile_questions_status CHECK (status IN ('pending','answered'))
);
CREATE INDEX IF NOT EXISTS idx_profile_questions_owner
    ON profile_questions(owner_id, status, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_profile_questions_asker ON profile_questions(asker_id);
-- «Дигар савол нафиристад»: бастани ПИНҲОНИИ савoлдиҳандаи беном.
-- Ба blocks навишта намешавад — вагарна рӯйхати «Басташудагон» номи
-- савoлдиҳандаи беномро ба соҳиб фош мекард.
CREATE TABLE IF NOT EXISTS qa_blocks (
    owner_id   TEXT NOT NULL,
    asker_id   TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (owner_id, asker_id)
);

CREATE TABLE IF NOT EXISTS time_capsules (
    id           TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
    author_id    TEXT NOT NULL,
    audience     TEXT NOT NULL DEFAULT 'self',
    recipient_id TEXT NOT NULL DEFAULT '',
    note         TEXT NOT NULL DEFAULT '',
    text         TEXT NOT NULL DEFAULT '',
    media        JSONB NOT NULL DEFAULT '[]'::jsonb,
    unlock_at    TIMESTAMPTZ NOT NULL,
    released     BOOLEAN NOT NULL DEFAULT FALSE,
    hidden       BOOLEAN NOT NULL DEFAULT FALSE,
    created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT time_capsules_audience CHECK (audience IN ('self','friend','followers'))
);
CREATE INDEX IF NOT EXISTS idx_time_capsules_author ON time_capsules(author_id, unlock_at);
CREATE INDEX IF NOT EXISTS idx_time_capsules_recipient ON time_capsules(recipient_id, unlock_at)
    WHERE recipient_id <> '';
CREATE INDEX IF NOT EXISTS idx_time_capsules_release ON time_capsules(unlock_at) WHERE released = FALSE;

CREATE TABLE IF NOT EXISTS challenges (
    id         TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
    creator_id TEXT NOT NULL,
    tag        TEXT NOT NULL UNIQUE,
    title      TEXT NOT NULL,
    rules      TEXT NOT NULL DEFAULT '',
    cover_url  TEXT NOT NULL DEFAULT '',
    starts_at  TIMESTAMPTZ NOT NULL,
    ends_at    TIMESTAMPTZ NOT NULL,
    hidden     BOOLEAN NOT NULL DEFAULT FALSE,
    finalized  BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_challenges_window ON challenges(ends_at DESC, starts_at);
CREATE TABLE IF NOT EXISTS challenge_winners (
    challenge_id TEXT NOT NULL,
    user_id      TEXT NOT NULL,
    rank         INTEGER NOT NULL,
    score        INTEGER NOT NULL DEFAULT 0,
    content_kind TEXT NOT NULL DEFAULT '',
    content_id   TEXT NOT NULL DEFAULT '',
    created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (challenge_id, user_id)
);
CREATE INDEX IF NOT EXISTS idx_challenge_winners_user ON challenge_winners(user_id);
-- Ҷадвали чаленҷ лайкҳоро дар ДАВРАИ чаленҷ ҳисоб мекунад; лайки Reel
-- вақт надошт (сатрҳои кӯҳна вақти ҳамин миграцияро мегиранд).
ALTER TABLE reel_likes ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ DEFAULT NOW();
`
