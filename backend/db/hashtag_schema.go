package db

import (
	"context"
	"log"

	"raonson/hashtags"
)

// Хештегҳо — мисли Instagram.
//
// Пеш хештег ҳар дафъа бо регекс аз caption-и ҲАМАИ постҳо ҷустуҷӯ мешуд
// (`caption ~* '#tag'`): Reels умуман дохил намешуданд, `\w` ҳарфҳои
// тоҷикиро намегирифт ва шумора/тренд/обуна имконнопазир буд.
//
// content_hashtags — хештегҳои муқаррарии (ҳарфи хурд) ҳар пост ва Reel,
// аз ҳамон қоидаи ягона (backend/hashtags). created_at — вақти мӯҳтаво,
// на вақти сабт, то тренд аз нав ҳисобкунӣ вайрон нашавад.
const hashtagSchema = `
CREATE TABLE IF NOT EXISTS content_hashtags (
    content_kind TEXT NOT NULL,
    content_id   TEXT NOT NULL,
    tag          TEXT NOT NULL,
    created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (content_kind, content_id, tag),
    CONSTRAINT content_hashtags_kind CHECK (content_kind IN ('post','reel'))
);
-- Саҳифаи хештег (навтаринҳо) ва шумора.
CREATE INDEX IF NOT EXISTS idx_content_hashtags_tag
    ON content_hashtags(tag, created_at DESC);
-- Пешниҳод («#ду…» → «#душанбе»): ҷустуҷӯи пешванд.
CREATE INDEX IF NOT EXISTS idx_content_hashtags_prefix
    ON content_hashtags(tag text_pattern_ops);
-- Тренд: истифодаи 2–4 рӯзи охир.
CREATE INDEX IF NOT EXISTS idx_content_hashtags_recent
    ON content_hashtags(created_at DESC);

-- Обуна ба хештег.
CREATE TABLE IF NOT EXISTS hashtag_follows (
    user_id    TEXT NOT NULL,
    tag        TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (user_id, tag)
);
CREATE INDEX IF NOT EXISTS idx_hashtag_follows_tag ON hashtag_follows(tag);
`

// backfillHashtags — постҳо ва Reels-и мавҷударо як бор индекс мекунад.
// Идемпотент: ON CONFLICT DO NOTHING; хато → дафъаи оянда аз нав.
func backfillHashtags(ctx context.Context) {
	runBackfillFunc(ctx, "content_hashtags_v1", func(ctx context.Context) error {
		for _, kind := range []string{"post", "reel"} {
			table := "posts"
			if kind == "reel" {
				table = "reels"
			}
			last := ""
			for {
				rows, err := Pool.Query(ctx,
					`SELECT id, COALESCE(caption,'') FROM `+table+`
					  WHERE id > $1 AND caption LIKE '%#%'
					  ORDER BY id LIMIT 500`, last)
				if err != nil {
					return err
				}
				var ids, tags []string
				n := 0
				for rows.Next() {
					var id, caption string
					if err := rows.Scan(&id, &caption); err != nil {
						rows.Close()
						return err
					}
					n++
					last = id
					for _, t := range hashtags.Extract(caption) {
						ids = append(ids, id)
						tags = append(tags, t)
					}
				}
				rows.Close()
				if err := rows.Err(); err != nil {
					return err
				}
				if len(ids) > 0 {
					if _, err := Pool.Exec(ctx,
						`INSERT INTO content_hashtags(content_kind, content_id, tag, created_at)
						 SELECT $1, x.id, x.tag, COALESCE(c.created_at, NOW())
						   FROM unnest($2::text[], $3::text[]) AS x(id, tag)
						   LEFT JOIN `+table+` c ON c.id = x.id
						 ON CONFLICT DO NOTHING`, kind, ids, tags); err != nil {
						return err
					}
				}
				if n < 500 {
					break
				}
			}
		}
		return nil
	})
}

// runBackfillFunc — мисли runBackfill, вале бо коди Go (барои қоидаҳое,
// ки дар SQL ифода намешаванд, масалан таҳлили хештег).
func runBackfillFunc(ctx context.Context, name string, fn func(context.Context) error) {
	var exists bool
	if err := Pool.QueryRow(ctx,
		`SELECT EXISTS(SELECT 1 FROM schema_backfills WHERE name=$1)`, name).Scan(&exists); err != nil || exists {
		return
	}
	if err := fn(ctx); err != nil {
		log.Printf("⚠️  backfill %s failed (%v) — дафъаи оянда такрор мешавад", name, err)
		return
	}
	Pool.Exec(ctx, `INSERT INTO schema_backfills(name) VALUES($1)
	                ON CONFLICT DO NOTHING`, name)
	log.Printf("✅ Backfill %s applied", name)
}
