package db

// Таърихи зангҳо (мисли «Зангҳо»-и WhatsApp). Идемпотент.
//
// Ҳар `call:offer`-и сокет як сатр месозад; `call:answer`, `call:decline`
// ва `call:end` онро пур мекунанд. Сатри кушода (ended_at IS NULL), ки
// дигар ҳеҷ ҳодиса нагирифт (телефон хомӯш шуд, барнома афтид), ҳангоми
// хондан аз рӯи вақт тасниф мешавад (ниг. calllog.Classify) — сервер
// ҳеҷ таймер нигоҳ намедорад.
//
// hidden_for_*: «аз таърих нест кардан» танҳо барои худи корбар; ҳамсӯҳбат
// сабти худро нигоҳ медорад.
const callLogSchema = `
CREATE TABLE IF NOT EXISTS call_logs (
    id                TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
    caller_id         TEXT NOT NULL,
    callee_id         TEXT NOT NULL,
    call_type         TEXT NOT NULL DEFAULT 'voice'
                      CHECK (call_type IN ('voice','video')),
    video_used        BOOLEAN NOT NULL DEFAULT FALSE,
    started_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    answered_at       TIMESTAMPTZ,
    ended_at          TIMESTAMPTZ,
    end_reason        TEXT,
    hidden_for_caller BOOLEAN NOT NULL DEFAULT FALSE,
    hidden_for_callee BOOLEAN NOT NULL DEFAULT FALSE
);
CREATE INDEX IF NOT EXISTS idx_call_logs_caller
    ON call_logs(caller_id, started_at DESC, id DESC);
CREATE INDEX IF NOT EXISTS idx_call_logs_callee
    ON call_logs(callee_id, started_at DESC, id DESC);
CREATE INDEX IF NOT EXISTS idx_call_logs_open
    ON call_logs(caller_id, callee_id) WHERE ended_at IS NULL;
`
