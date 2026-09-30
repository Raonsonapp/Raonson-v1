package handlers

import (
	"context"

	"raonson/db"
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
	} else {
		err = db.Pool.QueryRow(ctx,
			`SELECT COALESCE(views_count,0) FROM reels WHERE id=$1`, reelID).Scan(&views)
	}
	return views, err
}
