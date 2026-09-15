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

-- Сеансҳои тамошои реклама.
--
-- Yandex Rewarded server-side verification НАДОРАД: пас аз тамошо
-- ҳеҷ кас ба сервери мо занг намезанад. Ягона хабардиҳанда худи
-- барнома аст — яъне манбаи БЕБОВАР.
--
-- Сеанс ин хабарро маҳдуд мекунад. Пеш аз нишон додани реклама
-- сервер сатри 'pending' месозад; пас аз тамошо барнома ҳамон
-- шиносаро бармегардонад. Ҳар сатр ФАҚАТ ЯК БОР ба 'consumed'
-- мегузарад, пас такрори ҳамон дархост дуюм бор ҳисоб намешавад.
--
-- Ин ҷои имзо НАМЕГИРАД — он танҳо арзиши хабари бебоварро паст
-- мекунад. Ниг. ads/session.go.
CREATE TABLE IF NOT EXISTS ad_watch_sessions (
    id          TEXT PRIMARY KEY,
    user_id     TEXT NOT NULL,
    ad_unit_id  TEXT NOT NULL,
    status      TEXT NOT NULL DEFAULT 'pending',
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    expires_at  TIMESTAMPTZ NOT NULL,
    consumed_at TIMESTAMPTZ,
    CONSTRAINT ad_ws_status CHECK (status IN ('pending','consumed')),
    -- Сатри 'consumed' бе вақт маъно надорад: он далели он аст, ки
    -- маҳз кай реклама ҳисоб шуд.
    CONSTRAINT ad_ws_consumed_time CHECK (
        (status = 'consumed') = (consumed_at IS NOT NULL))
);
-- Ҷустуҷӯи сеансҳои кушодаи корбар ва ҳисоби фосила.
CREATE INDEX IF NOT EXISTS idx_ad_ws_user
    ON ad_watch_sessions(user_id, created_at DESC);
-- Барои поккунии сатрҳои кӯҳна (jobs/cleanup.go).
CREATE INDEX IF NOT EXISTS idx_ad_ws_expires
    ON ad_watch_sessions(expires_at);

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
