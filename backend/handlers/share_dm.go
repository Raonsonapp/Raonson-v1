package handlers

import (
	"context"
	"log"

	"raonson/db"
)

// Паёмҳои системавии Direct — мисли Instagram.
//
// Вақте A шуморо ба ҳамкорӣ дар пост даъват мекунад ё дар сторис зикр
// мекунад, ғайр аз огоҳинома дар Direct ҳам корти пост/сторис аз номи
// A меояд. Агар B ба A пайравӣ накунад, паём (мисли ҳар паёми дигар)
// ба «Дархостҳо» меафтад — логикаи inbox тағйир намеёбад.
const (
	CollabInviteDMText = "Шуморо ба ҳамкорӣ дар пост даъват кард"
	StoryMentionDMText = "Шуморо дар сторис зикр кард"
)

// sendShareDM паёми навъи 'share'-ро аз `from` ба `to` мегузорад.
//
// Такрор намешавад: агар ҳамин фиристанда ба ҳамин гиранда аллакай
// корти ҳамин мӯҳтаворо (share_id + share_kind + матн) фиристода бошад,
// ҳеҷ чиз намекунад. Бастагон ҳеҷ гоҳ паём намегиранд.
//
// Огоҳиномаи телефон алоҳида НАМЕРАВАД: даъват/зикр худаш push-и худро
// дорад, ва дуто push барои як ҳодиса ташвиш аст. Сокет («chat:new»)
// меравад, то inbox ва чати кушода фавран нав шаванд.
func sendShareDM(ctx context.Context, from, to, kind, shareID, thumb, text string) string {
	if from == "" || to == "" || from == to || shareID == "" {
		return ""
	}
	if IsBlockedBetween(from, to) {
		return ""
	}
	var exists bool
	db.Pool.QueryRow(ctx, `
		SELECT EXISTS(SELECT 1 FROM messages
		  WHERE sender_id=$1 AND receiver_id=$2 AND share_id=$3
		    AND share_kind=$4 AND text=$5)`,
		from, to, shareID, kind, text).Scan(&exists)
	if exists {
		return ""
	}
	var uname string
	db.Pool.QueryRow(ctx, `SELECT username FROM users WHERE id=$1`, from).Scan(&uname)

	chatID := sortedChatID(from, to)
	var msgID string
	if err := db.Pool.QueryRow(ctx, `
		INSERT INTO messages (chat_id, sender_id, receiver_id, text, type,
		                      share_id, share_kind, share_thumb, share_user,
		                      created_at, updated_at)
		VALUES ($1,$2,$3,$4,'share',$5,$6,NULLIF($7,''),NULLIF($8,''),NOW(),NOW())
		RETURNING id`,
		chatID, from, to, text, shareID, kind, thumb, uname).Scan(&msgID); err != nil {
		log.Printf("[ShareDM] insert failed: %v", err)
		return ""
	}
	if m, err := fetchMessageByID(msgID, to); err == nil {
		emitChat("chat:new", m, to, from)
	}
	return msgID
}

// postThumb — расми аввали пост (барои корт).
func postThumb(ctx context.Context, postID string) string {
	var u string
	db.Pool.QueryRow(ctx, `
		SELECT COALESCE((SELECT m.url FROM post_media m WHERE m.post_id=p.id
		                 ORDER BY m.position LIMIT 1), '')
		FROM posts p WHERE p.id=$1`, postID).Scan(&u)
	return u
}

// storyThumb — медиаи сторис (барои корт).
func storyThumb(ctx context.Context, storyID string) string {
	var u string
	db.Pool.QueryRow(ctx,
		`SELECT COALESCE(media_url,'') FROM stories WHERE id::text=$1`, storyID).Scan(&u)
	return u
}
