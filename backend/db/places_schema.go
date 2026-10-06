package db

// «Ҷой»-и сохторӣ барои пост (мисли Instagram).
//
// posts.location (матни озод) боқӣ мемонад — постҳои кӯҳна ва
// барномаҳои кӯҳна бо он кор мекунанд. Постҳои нав иловатан id-и ҷойро
// аз рӯйхати places (backend/places) ва координатаҳои ХУДИ ҶОЙ-ро
// (на GPS-и корбар) нигоҳ медоранд.
const placesSchema = `
ALTER TABLE posts ADD COLUMN IF NOT EXISTS location_id  TEXT DEFAULT '';
ALTER TABLE posts ADD COLUMN IF NOT EXISTS location_lat DOUBLE PRECISION;
ALTER TABLE posts ADD COLUMN IF NOT EXISTS location_lon DOUBLE PRECISION;
-- Саҳифаи ҷой: постҳо аз рӯи id, навтаринҳо аввал.
CREATE INDEX IF NOT EXISTS idx_posts_location_id
    ON posts(location_id, created_at DESC) WHERE location_id <> '';
-- Постҳои кӯҳна бо ҳамон матн (бе id).
CREATE INDEX IF NOT EXISTS idx_posts_location_text
    ON posts(location, created_at DESC)
    WHERE location <> '' AND COALESCE(location_id,'') = '';
`
