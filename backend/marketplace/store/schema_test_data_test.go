package store

// marketplaceTestSchema — нусхаи схемаи marketplace барои тестҳои
// интегратсионӣ. Аз db/marketplace_schema.go гирифта шудааст, то
// тестҳо ба db.Init() (ки DATABASE_URL-и воқеӣ мехоҳад) вобаста набошанд.
const marketplaceTestSchema = `
-- ── Рекламадиҳанда ───────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS advertisers (
    id           TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
    user_id      TEXT NOT NULL UNIQUE,
    company_name TEXT NOT NULL DEFAULT '',
    contact_email TEXT DEFAULT '',
    contact_phone TEXT DEFAULT '',
    country      TEXT DEFAULT '',
    verified     BOOLEAN DEFAULT FALSE,
    created_at   TIMESTAMPTZ DEFAULT NOW(),
    updated_at   TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_advertisers_user ON advertisers(user_id);

-- ── Профили эҷодкор ──────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS creator_profiles (
    creator_id          TEXT PRIMARY KEY,
    audience_country    TEXT DEFAULT '',
    audience_language   TEXT DEFAULT '',
    content_categories  TEXT[] DEFAULT '{}',
    price_minor         BIGINT DEFAULT 0,
    currency            TEXT DEFAULT 'TJS',
    available           BOOLEAN DEFAULT TRUE,
    verification_status TEXT DEFAULT 'NONE',
    created_at          TIMESTAMPTZ DEFAULT NOW(),
    updated_at          TIMESTAMPTZ DEFAULT NOW()
);

-- Метрикаҳо аз маълумоти ВОҚЕӢ ҳисоб мешаванд (jobs), на дастӣ.
-- sample_size ва confidence нишон медиҳанд, ки маълумот чӣ қадар кофист.
CREATE TABLE IF NOT EXISTS creator_metrics (
    creator_id       TEXT PRIMARY KEY,
    followers_count  BIGINT DEFAULT 0,
    total_views      BIGINT DEFAULT 0,
    average_views    BIGINT DEFAULT 0,
    likes            BIGINT DEFAULT 0,
    comments         BIGINT DEFAULT 0,
    shares           BIGINT DEFAULT 0,
    saves            BIGINT DEFAULT 0,
    engagement_rate  DOUBLE PRECISION DEFAULT 0,
    content_count    BIGINT DEFAULT 0,
    campaign_count   BIGINT DEFAULT 0,
    successful_campaign_count BIGINT DEFAULT 0,
    average_campaign_result  DOUBLE PRECISION DEFAULT 0,
    creator_score    DOUBLE PRECISION DEFAULT 0,
    score_confidence DOUBLE PRECISION DEFAULT 0,
    sample_size      BIGINT DEFAULT 0,
    computed_at      TIMESTAMPTZ,
    score_version    INTEGER DEFAULT 0,
    score_params     JSONB DEFAULT '{}'::jsonb,
    score_breakdown  JSONB DEFAULT '{}'::jsonb,
    created_at       TIMESTAMPTZ DEFAULT NOW(),
    updated_at       TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_creator_metrics_score ON creator_metrics(creator_score DESC);

-- ── Кампания ─────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS campaigns (
    id                  TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
    advertiser_id       TEXT NOT NULL,
    title               TEXT NOT NULL,
    description         TEXT DEFAULT '',
    category            TEXT DEFAULT '',
    target_country      TEXT DEFAULT '',
    target_city         TEXT DEFAULT '',
    target_age_min      INTEGER DEFAULT 0,
    target_age_max      INTEGER DEFAULT 0,
    target_gender       TEXT DEFAULT '',
    target_interests    TEXT[] DEFAULT '{}',
    target_language     TEXT DEFAULT '',
    budget_minor        BIGINT NOT NULL,
    currency            TEXT NOT NULL DEFAULT 'TJS',
    campaign_type       TEXT DEFAULT 'POST',
    start_at            TIMESTAMPTZ,
    end_at              TIMESTAMPTZ,
    required_impressions BIGINT DEFAULT 0,
    required_clicks     BIGINT DEFAULT 0,
    creator_count       INTEGER DEFAULT 1,
    status              TEXT NOT NULL DEFAULT 'DRAFT',
    -- Комиссия ҳангоми сохтани кампания ҚУФЛ мешавад: тағйири баъдии
    -- rate ба кампанияи кӯҳна таъсир намерасонад.
    commission_bps      INTEGER NOT NULL DEFAULT 1000,
    created_at          TIMESTAMPTZ DEFAULT NOW(),
    updated_at          TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_campaigns_advertiser ON campaigns(advertiser_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_campaigns_status     ON campaigns(status, created_at DESC);

-- Эҷодкорони кампания (offer). UNIQUE — як эҷодкор дар як кампания
-- танҳо як бор; ин пардохти дукаратаро дар сатҳи DB пешгирӣ мекунад.
CREATE TABLE IF NOT EXISTS campaign_creators (
    id            TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
    campaign_id   TEXT NOT NULL,
    creator_id    TEXT NOT NULL,
    status        TEXT NOT NULL DEFAULT 'INVITED',
    match_score   DOUBLE PRECISION DEFAULT 0,
    match_reasons TEXT[] DEFAULT '{}',
    agreed_minor  BIGINT NOT NULL DEFAULT 0,
    currency      TEXT NOT NULL DEFAULT 'TJS',
    content_id    TEXT DEFAULT '',
    content_type  TEXT DEFAULT '',
    invited_at    TIMESTAMPTZ DEFAULT NOW(),
    responded_at  TIMESTAMPTZ,
    delivered_at  TIMESTAMPTZ,
    created_at    TIMESTAMPTZ DEFAULT NOW(),
    updated_at    TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE (campaign_id, creator_id)
);
CREATE INDEX IF NOT EXISTS idx_campaign_creators_campaign ON campaign_creators(campaign_id, status);
CREATE INDEX IF NOT EXISTS idx_campaign_creators_creator  ON campaign_creators(creator_id, status, created_at DESC);

-- Ҳодисаҳои кампания — audit trail-и пурраи ҳаёти кампания.
CREATE TABLE IF NOT EXISTS campaign_events (
    id          BIGSERIAL PRIMARY KEY,
    campaign_id TEXT NOT NULL,
    creator_id  TEXT DEFAULT '',
    event_type  TEXT NOT NULL,
    from_status TEXT DEFAULT '',
    to_status   TEXT DEFAULT '',
    actor_id    TEXT DEFAULT '',
    payload     JSONB DEFAULT '{}'::jsonb,
    created_at  TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_campaign_events_campaign ON campaign_events(campaign_id, created_at DESC);

-- Метрикаи воқеии кампания (аз ҳодисаҳои воқеӣ ҷамъ мешавад).
CREATE TABLE IF NOT EXISTS campaign_metrics (
    campaign_id TEXT NOT NULL,
    creator_id  TEXT NOT NULL DEFAULT '',
    impressions BIGINT DEFAULT 0,
    views       BIGINT DEFAULT 0,
    likes       BIGINT DEFAULT 0,
    comments    BIGINT DEFAULT 0,
    shares      BIGINT DEFAULT 0,
    saves       BIGINT DEFAULT 0,
    clicks      BIGINT DEFAULT 0,
    updated_at  TIMESTAMPTZ DEFAULT NOW(),
    PRIMARY KEY (campaign_id, creator_id)
);

-- ── Ledger (double-entry) ────────────────────────────────────────
CREATE TABLE IF NOT EXISTS ledger_accounts (
    id         TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
    owner_type TEXT NOT NULL,          -- USER | PLATFORM | PROVIDER
    owner_id   TEXT NOT NULL DEFAULT '',
    purpose    TEXT NOT NULL,          -- WALLET | ESCROW | REVENUE | SETTLEMENT
    currency   TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE (owner_type, owner_id, purpose, currency)
);

CREATE TABLE IF NOT EXISTS ledger_transactions (
    id          TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
    kind        TEXT NOT NULL,
    campaign_id TEXT DEFAULT '',
    reference   TEXT NOT NULL,
    memo        TEXT DEFAULT '',
    created_at  TIMESTAMPTZ DEFAULT NOW(),
    -- Як reference = як транзаксия. Идемпотентии ledger дар сатҳи DB.
    UNIQUE (reference)
);
CREATE INDEX IF NOT EXISTS idx_ledger_tx_campaign ON ledger_transactions(campaign_id, created_at DESC);

-- Сатрҳои дутарафа. Ҷамъи amount_minor дар як транзаксия = 0.
CREATE TABLE IF NOT EXISTS ledger_entries (
    id             BIGSERIAL PRIMARY KEY,
    transaction_id TEXT NOT NULL,
    account_id     TEXT NOT NULL,
    amount_minor   BIGINT NOT NULL,   -- дебет мусбат, кредит манфӣ
    currency       TEXT NOT NULL,
    created_at     TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_ledger_entries_tx      ON ledger_entries(transaction_id);
CREATE INDEX IF NOT EXISTS idx_ledger_entries_account ON ledger_entries(account_id, created_at DESC);

-- ── Пардохт ва payout ────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS payment_orders (
    id                 TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
    campaign_id        TEXT NOT NULL,
    advertiser_id      TEXT NOT NULL,
    amount_minor       BIGINT NOT NULL,
    currency           TEXT NOT NULL,
    status             TEXT NOT NULL DEFAULT 'CREATED',
    provider           TEXT NOT NULL,
    provider_reference TEXT DEFAULT '',
    idempotency_key    TEXT NOT NULL,
    failure_reason     TEXT DEFAULT '',
    created_at         TIMESTAMPTZ DEFAULT NOW(),
    updated_at         TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE (idempotency_key)
);
CREATE INDEX IF NOT EXISTS idx_payment_orders_campaign ON payment_orders(campaign_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_payment_orders_status   ON payment_orders(status, created_at DESC);
CREATE UNIQUE INDEX IF NOT EXISTS uq_payment_orders_provider_ref
    ON payment_orders(provider, provider_reference)
    WHERE provider_reference <> '';

CREATE TABLE IF NOT EXISTS payout_orders (
    id                 TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
    campaign_id        TEXT NOT NULL,
    creator_id         TEXT NOT NULL,
    amount_minor       BIGINT NOT NULL,
    currency           TEXT NOT NULL,
    status             TEXT NOT NULL DEFAULT 'PENDING',
    provider           TEXT NOT NULL,
    provider_reference TEXT DEFAULT '',
    idempotency_key    TEXT NOT NULL,
    failure_reason     TEXT DEFAULT '',
    attempts           INTEGER DEFAULT 0,
    next_attempt_at    TIMESTAMPTZ,
    created_at         TIMESTAMPTZ DEFAULT NOW(),
    updated_at         TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE (idempotency_key),
    -- Як эҷодкор барои як кампания танҳо ЯК payout. Ин пардохти
    -- дукаратаро дар сатҳи DB ғайриимкон мекунад.
    UNIQUE (campaign_id, creator_id)
);
CREATE INDEX IF NOT EXISTS idx_payout_orders_creator ON payout_orders(creator_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_payout_orders_status  ON payout_orders(status, next_attempt_at);
CREATE UNIQUE INDEX IF NOT EXISTS uq_payout_orders_provider_ref
    ON payout_orders(provider, provider_reference)
    WHERE provider_reference <> '';

-- Комиссияи платформа — барои ҳар кампания ҚУФЛшуда нигоҳ дошта мешавад.
CREATE TABLE IF NOT EXISTS platform_fees (
    id             TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
    campaign_id    TEXT NOT NULL,
    commission_bps INTEGER NOT NULL,
    fee_minor      BIGINT NOT NULL,
    currency       TEXT NOT NULL,
    created_at     TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE (campaign_id)
);

-- ── Webhook, idempotency, audit ──────────────────────────────────
-- Як (provider, event_id) танҳо як бор коркард мешавад.
CREATE TABLE IF NOT EXISTS webhook_events (
    id           BIGSERIAL PRIMARY KEY,
    provider     TEXT NOT NULL,
    event_id     TEXT NOT NULL,
    event_type   TEXT DEFAULT '',
    payload      JSONB DEFAULT '{}'::jsonb,
    processed_at TIMESTAMPTZ,
    status       TEXT DEFAULT 'RECEIVED',
    error        TEXT DEFAULT '',
    created_at   TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE (provider, event_id)
);
CREATE INDEX IF NOT EXISTS idx_webhook_events_status ON webhook_events(status, created_at DESC);

CREATE TABLE IF NOT EXISTS idempotency_keys (
    key         TEXT PRIMARY KEY,
    scope       TEXT NOT NULL,
    result_id   TEXT DEFAULT '',
    created_at  TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS marketplace_audit_logs (
    id          BIGSERIAL PRIMARY KEY,
    actor_id    TEXT DEFAULT '',
    actor_role  TEXT DEFAULT '',
    action      TEXT NOT NULL,
    entity_type TEXT NOT NULL,
    entity_id   TEXT NOT NULL,
    payload     JSONB DEFAULT '{}'::jsonb,
    ip          TEXT DEFAULT '',
    created_at  TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_mp_audit_entity ON marketplace_audit_logs(entity_type, entity_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_mp_audit_actor  ON marketplace_audit_logs(actor_id, created_at DESC);

-- Аломатҳои фиреб — flag, на ban-и худкор.
CREATE TABLE IF NOT EXISTS fraud_flags (
    id          BIGSERIAL PRIMARY KEY,
    entity_type TEXT NOT NULL,
    entity_id   TEXT NOT NULL,
    signal      TEXT NOT NULL,
    score       DOUBLE PRECISION DEFAULT 0,
    details     JSONB DEFAULT '{}'::jsonb,
    status      TEXT DEFAULT 'OPEN',
    created_at  TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_fraud_flags_entity ON fraud_flags(entity_type, entity_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_fraud_flags_status ON fraud_flags(status, created_at DESC);

-- Ҳамон ALTER-и идемпотентӣ, ки дар db/marketplace_schema.go аст: то
-- схемаи тест аз схемаи воқеӣ дур наравад.
ALTER TABLE campaigns ADD COLUMN IF NOT EXISTS target_language TEXT DEFAULT '';
ALTER TABLE creator_metrics ADD COLUMN IF NOT EXISTS score_version   INTEGER DEFAULT 0;
ALTER TABLE creator_metrics ADD COLUMN IF NOT EXISTS score_params    JSONB DEFAULT '{}'::jsonb;
ALTER TABLE creator_metrics ADD COLUMN IF NOT EXISTS score_breakdown JSONB DEFAULT '{}'::jsonb;
`
