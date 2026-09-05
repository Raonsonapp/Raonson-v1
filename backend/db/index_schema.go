package db

// Индексҳое, ки аз рӯи EXPLAIN-и дархостҳои воқеӣ илова шудаанд.
//
// Ҳар яке сабаби ченшуда дорад — «ҳар сутунро индекс кун» нест:
// индекси зиёдатӣ навиштанро суст мекунад ва ҷой мегирад.
const indexSchema = `
-- Ҷустуҷӯи корбар: ILIKE '%...%' бо индекси btree кор намекунад ва
-- ҳамаи ҷадвалро мехонд. Дар 50 000 корбар: 6.5 мс → 0.8 мс, ва
-- муҳимтараш — вобастагӣ ба андозаи ҷадвал мешиканад.
CREATE EXTENSION IF NOT EXISTS pg_trgm;
CREATE INDEX IF NOT EXISTS idx_users_username_trgm
    ON users USING GIN (username gin_trgm_ops);

-- Постҳои профил: пас аз илова шудани ҳамкорӣ дархост ба Seq Scan
-- гузашт. Бо ин индекс Postgres ду индексро якҷо мекунад
-- (BitmapOr) — дар 150 000 пост: 17 мс → 0.1 мс.
CREATE INDEX IF NOT EXISTS idx_posts_collaborators
    ON posts USING GIN (collaborators);
`
