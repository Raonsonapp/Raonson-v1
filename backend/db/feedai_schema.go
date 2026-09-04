package db

// Схемаи «Лентаи AI» — қабати идорашавандаи тавсия.
//
// Ин система рейтинги мавҷударо ИВАЗ НАМЕКУНАД. GetSmartFeed ва
// GetSmartReels ҳамон тавре кор мекунанд; ин ҷадвалҳо як қабати
// иловагии холгузорӣ медиҳанд, ки корбар онро худаш идора мекунад.
//
// Тарҳ:
//   - мавзӯъҳо (topics) васеъшавандаанд — рӯйхати сахткодшуда нест
//   - афзалиятҳои корбар аз ДУ манбаъ меоянд: возеҳ (худаш гуфт) ва
//     омӯхта (аз рафтор). Онҳо ҷудо нигоҳ дошта мешаванд, то «reset»
//     танҳо омӯхтаро тоза кунад ва интихоби возеҳи корбар нахобад.
//   - ҳодисаҳо (feed_events) хом мемонанд; ҷамъбаст дар профил аст,
//     то query-и лента ҳеҷ гоҳ ҷадвали калони ҳодисаҳоро сканд накунад.
const feedAISchema = `
-- ── Мавзӯъҳо ─────────────────────────────────────────────────────
-- slug — калиди мошинӣ; номҳо тарҷумашаванда.
CREATE TABLE IF NOT EXISTS feed_topics (
    slug       TEXT PRIMARY KEY,
    name_tj    TEXT NOT NULL DEFAULT '',
    name_ru    TEXT NOT NULL DEFAULT '',
    name_en    TEXT NOT NULL DEFAULT '',
    -- Калидвожаҳо барои муайян кардани мавзӯи мӯҳтаво (hashtag/матн).
    keywords   TEXT[] NOT NULL DEFAULT '{}',
    active     BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ── Мавзӯи мӯҳтаво ───────────────────────────────────────────────
-- Дар паснамо пур мешавад (job), на дар вақти дархости лента.
CREATE TABLE IF NOT EXISTS content_topics (
    content_type TEXT NOT NULL,          -- 'post' | 'reel'
    content_id   TEXT NOT NULL,
    topic_slug   TEXT NOT NULL REFERENCES feed_topics(slug) ON DELETE CASCADE,
    -- 0..1 — чӣ қадар мӯҳтаво ба ин мавзӯъ мансуб аст.
    weight       REAL NOT NULL DEFAULT 1,
    created_at   TIMESTAMPTZ DEFAULT NOW(),
    PRIMARY KEY (content_type, content_id, topic_slug)
);
CREATE INDEX IF NOT EXISTS idx_content_topics_topic
    ON content_topics(topic_slug, content_type);

-- Забони мӯҳтаво — барои мувофиқати забонӣ. Аз матн муайян мешавад.
CREATE TABLE IF NOT EXISTS content_language (
    content_type TEXT NOT NULL,
    content_id   TEXT NOT NULL,
    lang         TEXT NOT NULL DEFAULT '',
    PRIMARY KEY (content_type, content_id)
);

-- ── Афзалиятҳои умумии корбар ────────────────────────────────────
CREATE TABLE IF NOT EXISTS feed_prefs (
    user_id            TEXT PRIMARY KEY,
    -- Забонҳои афзалиятнок бо тартиб: аввалӣ муҳимтар.
    languages          TEXT[] NOT NULL DEFAULT '{}',
    prefer_local       BOOLEAN NOT NULL DEFAULT FALSE,
    prefer_original    BOOLEAN NOT NULL DEFAULT FALSE,
    prefer_following   BOOLEAN NOT NULL DEFAULT FALSE,
    -- Корбар метавонад тавсияро кам кунад — лента бештар аз обунаҳо.
    fewer_recommendations BOOLEAN NOT NULL DEFAULT FALSE,
    updated_at         TIMESTAMPTZ DEFAULT NOW()
);

-- ── Афзалияти мавзӯъ ─────────────────────────────────────────────
-- score: -1..+1. Манфӣ = камтар нишон деҳ.
-- source: 'explicit' (корбар худаш гуфт) ё 'learned' (аз рафтор).
CREATE TABLE IF NOT EXISTS feed_topic_prefs (
    user_id    TEXT NOT NULL,
    topic_slug TEXT NOT NULL REFERENCES feed_topics(slug) ON DELETE CASCADE,
    score      REAL NOT NULL DEFAULT 0,
    source     TEXT NOT NULL DEFAULT 'learned',
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    PRIMARY KEY (user_id, topic_slug),
    CONSTRAINT feed_topic_prefs_score_range CHECK (score >= -1 AND score <= 1),
    CONSTRAINT feed_topic_prefs_source CHECK (source IN ('explicit','learned'))
);
CREATE INDEX IF NOT EXISTS idx_feed_topic_prefs_user
    ON feed_topic_prefs(user_id, score DESC);

-- ── Афзалияти эҷодкор ────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS feed_creator_prefs (
    user_id    TEXT NOT NULL,
    creator_id TEXT NOT NULL,
    score      REAL NOT NULL DEFAULT 0,
    source     TEXT NOT NULL DEFAULT 'learned',
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    PRIMARY KEY (user_id, creator_id),
    CONSTRAINT feed_creator_prefs_score_range CHECK (score >= -1 AND score <= 1),
    CONSTRAINT feed_creator_prefs_source CHECK (source IN ('explicit','learned'))
);
CREATE INDEX IF NOT EXISTS idx_feed_creator_prefs_user
    ON feed_creator_prefs(user_id, score DESC);

-- ── Ҳодисаҳои тавсия ─────────────────────────────────────────────
-- Ҷадвали калон. Query-и лента ба он даст намерасонад — job онро
-- ҷамъбаст мекунад ва feed_topic_prefs / feed_creator_prefs-ро нав мекунад.
CREATE TABLE IF NOT EXISTS feed_events (
    id           BIGSERIAL PRIMARY KEY,
    user_id      TEXT NOT NULL,
    content_type TEXT NOT NULL DEFAULT '',
    content_id   TEXT NOT NULL DEFAULT '',
    creator_id   TEXT NOT NULL DEFAULT '',
    event        TEXT NOT NULL,
    -- Вазни ҳодиса ҳангоми сабт ҳисоб мешавад (ниг. feedai/signals.go).
    weight       REAL NOT NULL DEFAULT 0,
    -- processed: job онро ба профил ҷамъ кард ё не.
    processed    BOOLEAN NOT NULL DEFAULT FALSE,
    created_at   TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_feed_events_unprocessed
    ON feed_events(created_at) WHERE processed = FALSE;
CREATE INDEX IF NOT EXISTS idx_feed_events_user
    ON feed_events(user_id, created_at DESC);
-- Барои «Чаро инро мебинам?» — ҳодисаҳои корбар аз рӯи мӯҳтаво.
CREATE INDEX IF NOT EXISTS idx_feed_events_user_content
    ON feed_events(user_id, content_type, content_id);

-- ── Мавзӯъҳои пешфарз ────────────────────────────────────────────
-- Ин рӯйхат ниҳоӣ НЕСТ: ҷадвал васеъ мешавад ва админ метавонад
-- мавзӯи нав илова кунад. Калидвожаҳо се забонро дарбар мегиранд,
-- зеро корбарони Raonson дар як пост тоҷикӣ, русӣ ва англисӣ
-- омехта менависанд.
INSERT INTO feed_topics(slug, name_tj, name_ru, name_en, keywords) VALUES
 ('gaming',     'Бозиҳо',      'Игры',        'Gaming',
  ARRAY['gaming','game','бозӣ','бози','игра','игры','геймер','gamer','pubg','dota','cs2','minecraft','freefire']),
 ('football',   'Футбол',      'Футбол',      'Football',
  ARRAY['football','футбол','soccer','гол','goal','messi','ronaldo','лига','league','варзиш']),
 ('anime',      'Аниме',       'Аниме',       'Anime',
  ARRAY['anime','аниме','manga','манга','naruto','onepiece','otaku']),
 ('technology', 'Технология',  'Технологии',  'Technology',
  ARRAY['tech','технология','технологии','гаджет','gadget','iphone','android','ai','coding','программист','барнома']),
 ('education',  'Таълим',      'Образование', 'Education',
  ARRAY['education','таълим','омӯзиш','learn','обучение','урок','дарс','study','школа','мактаб','университет']),
 ('music',      'Мусиқӣ',      'Музыка',      'Music',
  ARRAY['music','мусиқӣ','мусики','музыка','суруд','песня','song','concert','консерт']),
 ('comedy',     'Хандовар',    'Юмор',        'Comedy',
  ARRAY['comedy','юмор','хандовар','смешно','прикол','funny','мем','meme','шӯхӣ']),
 ('news',       'Ахбор',       'Новости',     'News',
  ARRAY['news','ахбор','хабар','новости','политика','сиёсат']),
 ('travel',     'Сафар',       'Путешествия', 'Travel',
  ARRAY['travel','сафар','путешествие','туризм','tourism','кӯҳ','памир','pamir','горы']),
 ('fashion',    'Мӯд',         'Мода',        'Fashion',
  ARRAY['fashion','мӯд','мода','стиль','style','либос','одежда','beauty','зебоӣ']),
 ('business',   'Тиҷорат',     'Бизнес',      'Business',
  ARRAY['business','тиҷорат','бизнес','маркетинг','marketing','стартап','startup','пул','деньги']),
 ('art',        'Санъат',      'Искусство',   'Art',
  ARRAY['art','санъат','искусство','рисунок','наққошӣ','draw','design','дизайн']),
 ('food',       'Хӯрок',       'Еда',         'Food',
  ARRAY['food','хӯрок','хурок','еда','рецепт','дастур','cooking','пухтупаз','ош','plov']),
 ('sport',      'Варзиш',      'Спорт',       'Sport',
  ARRAY['sport','варзиш','спорт','fitness','фитнес','gym','бокс','кураш','wrestling'])
ON CONFLICT (slug) DO NOTHING;
`
