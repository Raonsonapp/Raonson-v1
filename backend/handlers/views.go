package handlers

import (
	"context"

	"raonson/db"
	mw "raonson/middleware"

	"github.com/gin-gonic/gin"
)

// ── Тамошоҳо: ЯК манбаъ барои ҳар навъ ─────────────────────────────
//
// ⚠️ Пеш як видео дар Explore 8 ва дар профил 5 тамошо нишон медод:
//
//   - Reels-и лента `/reels/:id/watch` мефиристод, ки тамошоро ҲЕҶ
//     ҳисоб намекард — танҳо reel-и аз профил кушодашуда (`/view`)
//     рақамро зиёд мекард;
//   - `AddReelView` (истифоданашуда) бе dedup +1 мекард;
//   - кори тозакунӣ сатрҳои куҳнаи `post_views`-ро нест мекард, ва
//     тамошои постҳо бо мурури вақт КАМ мешуд.
//
// Ҳоло:
//
//	Reel → reels.views_count. Ҳар корбар як бор (reel_views — рӯйхати
//	       dedup). Ҳам /view, ҳам /watch аз ҳамин ҷо мегузаранд.
//	Пост → COUNT(post_views). Ҳар корбар як бор; сатрҳо нест намешаванд.
//
// Ҳамаи endpoint-ҳо ҳамин рақамро бо ду калид медиҳанд: "views" ва
// "viewsCount" (клиентҳои гуногун калидҳои гуногунро мехонанд).

// countReelView — тамошои корбарро як бор ҳисоб мекунад ва шумораи
// ҷориро бармегардонад. Тамошои такрории ҳамон корбар рақамро иваз
// намекунад; танҳо `viewed_at` нав мешавад, то Reels-и smart онро
// 24 соат дубора нишон надиҳад.
func countReelView(ctx context.Context, userID, reelID string) (int, error) {
	if userID == "" || reelID == "" {
		return 0, nil
	}
	// xmax = 0 → сатр НАВ ворид шуд (на UPDATE-и конфликт).
	var inserted bool
	err := db.Pool.QueryRow(ctx, `
		INSERT INTO reel_views (user_id, reel_id, viewed_at)
		SELECT $1, $2, NOW() WHERE EXISTS (SELECT 1 FROM reels WHERE id=$2)
		ON CONFLICT (user_id, reel_id) DO UPDATE SET viewed_at = NOW()
		RETURNING (xmax = 0)`, userID, reelID).Scan(&inserted)
	if err != nil {
		// Reel нест (ҳеҷ сатр) ё хато — рақамро намерасонем.
		return 0, err
	}
	var views int
	if inserted {
		err = db.Pool.QueryRow(ctx, `
			UPDATE reels SET views_count = COALESCE(views_count,0) + 1
			WHERE id=$1 RETURNING views_count`, reelID).Scan(&views)
		// Рақам иваз шуд → ҷавобҳои кэшшуда (профил 3с, Explore ва
		// ҷустуҷӯ 30с) куҳна шуданд. Ниг. bumpOnNewView.
		bumpOnNewView()
	} else {
		err = db.Pool.QueryRow(ctx,
			`SELECT COALESCE(views_count,0) FROM reels WHERE id=$1`, reelID).Scan(&views)
	}
	return views, err
}

// bumpOnNewView — тамошои НАВ (на такрорӣ) рақамро дар ҳамаи экранҳо иваз
// мекунад, пас насли кэш бояд нав шавад.
//
// ⚠️ Пеш роҳҳои /view ва /watch дар `skipBumpRe` буданд (тамошо «рақами
// экранҳои дигарро иваз намекунад»). Аммо тамошо МАҲЗ рақам аст: баъди
// тамошо Explore ва ҷустуҷӯ то 30 сония, профил то 3 сония рақами кӯҳнаро
// аз кэш медоданд — як reel дар як вақт дар ду экран ду рақам дошт.
//
// Танҳо тамошои НАВ (ҳар корбар як бор барои ҳар мундариҷа) насли кэшро
// иваз мекунад — тамошои такрорӣ, ки рақамро иваз намекунад, кэшро
// намепартояд. Ин ҳамон тартиби лайк аст (як корбар → як тағйир).
func bumpOnNewView() { mw.BumpContentEpoch() }

// countPostViews — тамошои корбарро барои постҳо як бор ҳисоб мекунад ва
// шумораи ҷориро (COUNT(post_views)) барои ҳар id бармегардонад.
func countPostViews(ctx context.Context, userID string, ids []string) (map[string]int, error) {
	out := map[string]int{}
	if userID == "" || len(ids) == 0 {
		return out, nil
	}
	// Танҳо постҳои мавҷуда (вагарна id-и нодуруст сатри «ятим» мегузошт).
	tag, err := db.Pool.Exec(ctx, `
		INSERT INTO post_views(user_id, post_id)
		SELECT $1, p.id FROM posts p WHERE p.id = ANY($2::text[])
		ON CONFLICT DO NOTHING`, userID, ids)
	if err != nil {
		return out, err
	}
	if tag.RowsAffected() > 0 {
		bumpOnNewView()
	}
	rows, err := db.Pool.Query(ctx, `
		SELECT p.id, (SELECT COUNT(*) FROM post_views pv WHERE pv.post_id = p.id)
		  FROM posts p WHERE p.id = ANY($1::text[])`, ids)
	if err != nil {
		return out, err
	}
	defer rows.Close()
	for rows.Next() {
		var id string
		var n int
		if rows.Scan(&id, &n) == nil {
			out[id] = n
		}
	}
	return out, rows.Err()
}

// attachReelShares — "sharesCount"-и ҳар reel дар рӯйхати тайёр (як дархост).
//
// ⚠️ Пеш /reels, /reels/smart, саҳифаи ҷой ва хештег sharesCount
// намефиристоданд: клиент 0 мехонд ва ҳамин 0-ро ҳамчун маълумоти нави
// сервер ба ContentSync медод — Reels «0 паҳн» нишон медод, профил ва
// Explore «1».
func attachReelShares(reels []gin.H) {
	ids := make([]string, 0, len(reels))
	for _, r := range reels {
		if r == nil {
			continue
		}
		if _, has := r["sharesCount"]; has {
			continue
		}
		r["sharesCount"] = 0
		if id, _ := r["_id"].(string); id != "" {
			ids = append(ids, id)
		}
	}
	if len(ids) == 0 || db.Pool == nil {
		return
	}
	rows, err := db.Pool.Query(context.Background(), `
		SELECT reel_id, COUNT(*) FROM reel_shares
		 WHERE reel_id = ANY($1::text[]) GROUP BY reel_id`, ids)
	if err != nil {
		return
	}
	defer rows.Close()
	found := map[string]int{}
	for rows.Next() {
		var id string
		var n int
		if rows.Scan(&id, &n) == nil {
			found[id] = n
		}
	}
	for _, r := range reels {
		if r == nil {
			continue
		}
		if id, _ := r["_id"].(string); id != "" {
			if n, ok := found[id]; ok {
				r["sharesCount"] = n
			}
		}
	}
}
