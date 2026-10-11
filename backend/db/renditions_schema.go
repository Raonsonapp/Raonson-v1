package db

// Нусхаҳои HLS-и Reels (ниг. handlers/reel_renditions.go).
//
// reels.hls_url        — master.m3u8 (240p/480p/720p, пахши адаптивӣ);
// reels.hls_low_url    — танҳо пасттарин зина (Data Saver);
// reels.preview_url    — 2 сонияи аввал, хурд, барои оғози фаврӣ;
// reels.renditions_ready — ҳамаи боло тайёранд.
//
// reel_renditions — навбати коргар: ҳолат, кӯшишҳо, таъхир, хато.
const renditionsSchema = `
ALTER TABLE reels ADD COLUMN IF NOT EXISTS hls_url          TEXT DEFAULT '';
ALTER TABLE reels ADD COLUMN IF NOT EXISTS hls_low_url      TEXT DEFAULT '';
ALTER TABLE reels ADD COLUMN IF NOT EXISTS preview_url      TEXT DEFAULT '';
ALTER TABLE reels ADD COLUMN IF NOT EXISTS renditions_ready BOOLEAN DEFAULT FALSE;

CREATE TABLE IF NOT EXISTS reel_renditions (
	reel_id         TEXT PRIMARY KEY REFERENCES reels(id) ON DELETE CASCADE,
	source_url      TEXT NOT NULL,
	status          TEXT NOT NULL DEFAULT 'pending'
	                CHECK (status IN ('pending','processing','ready','failed','skipped')),
	attempts        INTEGER NOT NULL DEFAULT 0,
	last_error      TEXT DEFAULT '',
	variants        TEXT DEFAULT '',
	duration_sec    DOUBLE PRECISION DEFAULT 0,
	next_attempt_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
	locked_at       TIMESTAMPTZ,
	created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
	updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
	finished_at     TIMESTAMPTZ
);
CREATE INDEX IF NOT EXISTS idx_reel_renditions_due
	ON reel_renditions(next_attempt_at) WHERE status IN ('pending','processing');
`
