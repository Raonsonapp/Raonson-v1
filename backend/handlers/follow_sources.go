package handlers

// «Обуначиён аз ин пост» — мисли Instagram Insights («Follows»).
//
// Вақте касе аз корти пост, рилс, Explore ё шарҳҳои ҳамон пост обуна
// мешавад, барнома манбаъро ҳамроҳ мефиристад:
//
//	POST /follow/:id  {"sourceKind":"post"|"reel", "sourceId":"…"}
//
// Як сатр барои ҳар ҷуфти (обуначӣ, муаллиф) — обунаи дубора манбаъро
// иваз мекунад, бекор кардани обуна онро нест мекунад. Ҳисоб танҳо
// обунаҳои ҲОЗИРА-ро мешуморад (JOIN follows), пас дархости радшуда
// ё обунаи бекоршуда рақамро бардурӯғ калон намекунад.
//
// Танҳо соҳиби мундариҷа рақамро мебинад (ниг. GetPostStats,
// GetReelStats). Манбаъ танҳо вақте қабул мешавад, ки пост/рилс воқеан
// аз они ҳамон касе бошад, ки ба ӯ обуна шуданд — вагарна ба пости
// бегона рақам «илова кардан» мумкин мешуд.

import (
	"context"

	"raonson/db"
)

// recordFollowSource манбаи обунаро сабт мекунад (ё нест мекунад, агар
// манбаъ набошад ё нодуруст бошад).
func recordFollowSource(followerID, followeeID, kind, sourceID string) {
	ctx := context.Background()
	if !validFollowSource(ctx, followeeID, kind, sourceID) {
		// Обунаи нав бе манбаъ: сабти кӯҳна (аз обунаи пешина) набояд
		// ба пости дигар ҳисоб шавад.
		db.Pool.Exec(ctx,
			`DELETE FROM follow_sources WHERE follower_id=$1 AND followee_id=$2`,
			followerID, followeeID)
		return
	}
	db.Pool.Exec(ctx, `
		INSERT INTO follow_sources(follower_id, followee_id, source_kind, source_id)
		VALUES ($1,$2,$3,$4)
		ON CONFLICT (follower_id, followee_id) DO UPDATE
		   SET source_kind=EXCLUDED.source_kind,
		       source_id=EXCLUDED.source_id,
		       created_at=NOW()`,
		followerID, followeeID, kind, sourceID)
}

// validFollowSource: танҳо пост/рилси худи муаллиф.
func validFollowSource(ctx context.Context, followeeID, kind, sourceID string) bool {
	if sourceID == "" || len(sourceID) > 64 {
		return false
	}
	var q string
	switch kind {
	case "post":
		q = `SELECT EXISTS(SELECT 1 FROM posts WHERE id=$1 AND user_id=$2)`
	case "reel":
		q = `SELECT EXISTS(SELECT 1 FROM reels WHERE id=$1 AND user_id=$2)`
	default:
		return false
	}
	var ok bool
	if err := db.Pool.QueryRow(ctx, q, sourceID, followeeID).Scan(&ok); err != nil {
		return false
	}
	return ok
}

// followsFromContent — чанд нафар аз ин пост/рилс обуна шуданд ва
// ҳоло ҳам обуначӣ ҳастанд.
func followsFromContent(ctx context.Context, ownerID, kind, sourceID string) int {
	var n int
	db.Pool.QueryRow(ctx, `
		SELECT COUNT(*) FROM follow_sources fs
		  JOIN follows f ON f.follower_id=fs.follower_id
		                AND f.following_id=fs.followee_id
		 WHERE fs.followee_id=$1 AND fs.source_kind=$2 AND fs.source_id=$3`,
		ownerID, kind, sourceID).Scan(&n)
	return n
}

// notifyCommentLike муаллифи шарҳро огоҳ мекунад: «шарҳи шуморо
// писандид». Объекти огоҳинома — пост ё рилс (барои кушодан).
func notifyCommentLike(commentID, authorID, likerID string) {
	if authorID == "" || authorID == likerID {
		return
	}
	go func() {
		ctx := context.Background()
		var postID, reelID string
		db.Pool.QueryRow(ctx,
			`SELECT post_id FROM comments WHERE id=$1`, commentID).Scan(&postID)
		if postID != "" {
			if notifySync(authorID, likerID, "comment_like", postID) {
				pushNotify(authorID, likerID, "comment_like", postID, "")
			}
			return
		}
		db.Pool.QueryRow(ctx,
			`SELECT reel_id FROM reel_comments WHERE id=$1`, commentID).Scan(&reelID)
		if reelID != "" {
			if notifySync(authorID, likerID, "reel_comment_like", reelID) {
				pushNotify(authorID, likerID, "reel_comment_like", reelID, "")
			}
		}
	}()
}
