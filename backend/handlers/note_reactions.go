package handlers

// Вокуниш ва ҷавоб ба ёддошт (Notes) — мисли Instagram.
//
// Пеш ёддошти дӯстро танҳо дидан мумкин буд: на лайк, на эмодзи, на
// ҷавоб. Акнун:
//   - POST   /profile/notes/:userId/react  {emoji} — вокуниш (❤️ = лайк)
//   - DELETE /profile/notes/:userId/react          — бекор кардан
//   - POST   /profile/notes/:userId/reply  {text}  — ҷавоб ба DM-и соҳиб
//   - GET    /profile/note/reactions               — соҳиб мебинад кӣ вокуниш дод
//
// Вокунишҳо ба ёддошти ҶОРӢ тааллуқ доранд: SetNote онҳоро пок мекунад
// ва ҳама хониш танҳо ёддошти ҳанӯз фаъолро (note_expires_at > NOW())
// ба назар мегирад.

import (
	"context"
	"net/http"
	"strings"
	"time"

	"raonson/db"
	mw "raonson/middleware"
	ntf "raonson/notify"

	"github.com/gin-gonic/gin"
)

// noteEmojis — эмодзиҳои иҷозатдодашуда. Рӯйхати пӯшида қасдан аст:
// матни дилхоҳ дар огоҳиномаи соҳиб роҳи спам мешуд.
var noteEmojis = map[string]bool{
	"❤️": true, "😂": true, "😮": true, "😢": true, "🔥": true, "👏": true,
	"😍": true, "🙌": true,
}

// noteLike — «лайк»-и ёддошт ҳамон ❤️ аст (як вокуниш аз ҳар корбар).
const noteLike = "❤️"

// visibleNote ёддошти фаъоли owner-ро бармегардонад, агар viewer онро
// дида тавонад: обуначӣ аст (ёддошт танҳо ба онҳо нишон дода мешавад —
// ниг. GetFriendsNotes), блок нест ва худи соҳиб нест.
// ok=false → 404 (мавҷудияти блок/ёддошт ошкор намешавад).
func visibleNote(viewer, owner string) (text, ownerName string, ok bool) {
	if viewer == "" || owner == "" || viewer == owner {
		return "", "", false
	}
	if IsBlockedBetween(viewer, owner) {
		return "", "", false
	}
	var song string
	err := db.Pool.QueryRow(context.Background(), `
		SELECT COALESCE(u.note,''), COALESCE(u.note_song_title,''), u.username
		FROM users u
		WHERE u.id=$1
		  AND u.note_expires_at > NOW()
		  AND (COALESCE(u.note,'') != '' OR COALESCE(u.note_song_title,'') != '')
		  AND EXISTS(SELECT 1 FROM follows f
		             WHERE f.follower_id=$2 AND f.following_id=u.id)`,
		owner, viewer).Scan(&text, &song, &ownerName)
	if err != nil {
		return "", "", false
	}
	if text == "" {
		text = "🎵 " + song
	}
	return text, ownerName, true
}

// POST /profile/notes/:userId/react
func ReactToNote(c *gin.Context) {
	myID := mw.UID(c)
	owner := c.Param("userId")
	var b struct {
		Emoji string `json:"emoji"`
	}
	c.ShouldBindJSON(&b)
	emoji := strings.TrimSpace(b.Emoji)
	if emoji == "" || emoji == "like" {
		emoji = noteLike
	}
	if !noteEmojis[emoji] {
		c.JSON(http.StatusBadRequest, gin.H{"message": "Эмодзи дастгирӣ намешавад"})
		return
	}
	if _, _, ok := visibleNote(myID, owner); !ok {
		c.JSON(http.StatusNotFound, gin.H{"message": "Ёддошт ёфт нашуд"})
		return
	}
	var prev string
	db.Pool.QueryRow(context.Background(),
		`SELECT emoji FROM note_reactions WHERE note_owner_id=$1 AND user_id=$2`,
		owner, myID).Scan(&prev)
	if _, err := db.Pool.Exec(context.Background(), `
		INSERT INTO note_reactions(note_owner_id, user_id, emoji, created_at)
		VALUES($1,$2,$3,NOW())
		ON CONFLICT (note_owner_id, user_id)
		DO UPDATE SET emoji=EXCLUDED.emoji, created_at=NOW()`,
		owner, myID, emoji); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"message": "Вокуниш сабт нашуд"})
		return
	}
	// Огоҳинома танҳо барои вокуниши НАВ ё ИВАЗШУДА — пахши такрорӣ
	// соҳибро бо push-ҳои якхела безор намекунад. Сатри кӯҳна (бо
	// эмодзии дигар) пок мешавад, то дар рӯйхат як сатр монад.
	if prev != emoji {
		db.Pool.Exec(context.Background(), `
			DELETE FROM notifications
			WHERE user_id=$1 AND from_user_id=$2 AND type=$3`,
			owner, myID, string(ntf.NoteReaction))
		notify(owner, myID, string(ntf.NoteReaction), emoji)
		pushNotify(owner, myID, string(ntf.NoteReaction), emoji, "")
	}
	c.JSON(http.StatusOK, gin.H{"reacted": true, "emoji": emoji})
}

// DELETE /profile/notes/:userId/react
func UnreactToNote(c *gin.Context) {
	myID := mw.UID(c)
	owner := c.Param("userId")
	db.Pool.Exec(context.Background(),
		`DELETE FROM note_reactions WHERE note_owner_id=$1 AND user_id=$2`,
		owner, myID)
	// Мисли бекор кардани лайк — огоҳинома ҳам нопадид мешавад.
	db.Pool.Exec(context.Background(), `
		DELETE FROM notifications
		WHERE user_id=$1 AND from_user_id=$2 AND type=$3`,
		owner, myID, string(ntf.NoteReaction))
	c.JSON(http.StatusOK, gin.H{"reacted": false})
}

// POST /profile/notes/:userId/reply — ҷавоб ҳамчун DM ба соҳиб меравад.
//
// Паём share_kind='note' дорад ва share_thumb матни ёддоштро (нусха дар
// лаҳзаи ҷавоб) нигоҳ медорад — то дар чат «ба ёддошти шумо ҷавоб дод»
// бо иқтибос нишон дода шавад, ҳатто баъди иваз/гузаштани ёддошт.
func ReplyToNote(c *gin.Context) {
	myID := mw.UID(c)
	owner := c.Param("userId")
	var b struct {
		Text string `json:"text"`
	}
	c.ShouldBindJSON(&b)
	text := strings.TrimSpace(clampRunes(b.Text, 1000))
	if text == "" {
		c.JSON(http.StatusBadRequest, gin.H{"message": "text required"})
		return
	}
	noteText, ownerName, ok := visibleNote(myID, owner)
	if !ok {
		c.JSON(http.StatusNotFound, gin.H{"message": "Ёддошт ёфт нашуд"})
		return
	}
	chatID := sortedChatID(myID, owner)
	var msgID string
	if err := db.Pool.QueryRow(context.Background(), `
		INSERT INTO messages
		  (chat_id, sender_id, receiver_id, text, type,
		   share_id, share_kind, share_thumb, share_user, created_at, updated_at)
		VALUES ($1,$2,$3,$4,'text',$5,'note',$6,$7,NOW(),NOW())
		RETURNING id`,
		chatID, myID, owner, text, owner, noteText, ownerName).Scan(&msgID); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"message": "Send failed"})
		return
	}
	msg, err := fetchMessageByID(msgID, myID)
	if err != nil {
		c.JSON(http.StatusCreated, gin.H{"_id": msgID, "chatId": chatID})
		return
	}
	emitChat("chat:new", msg, owner)
	if !chatMuted(owner, myID) {
		pushNotify(owner, myID, string(ntf.Message), chatID, "")
	}
	c.JSON(http.StatusCreated, msg)
}

// GET /profile/note/reactions — соҳиб мебинад, кӣ ба ёддошташ вокуниш дод.
func GetMyNoteReactions(c *gin.Context) {
	myID := mw.UID(c)
	// Ёддошт гузашт → вокунишҳо низ (ва ҷадвал калон намешавад).
	var active bool
	db.Pool.QueryRow(context.Background(), `
		SELECT COALESCE(note_expires_at > NOW(), false) FROM users WHERE id=$1`,
		myID).Scan(&active)
	if !active {
		db.Pool.Exec(context.Background(),
			`DELETE FROM note_reactions WHERE note_owner_id=$1`, myID)
		c.JSON(http.StatusOK, gin.H{"reactions": []gin.H{}, "count": 0})
		return
	}
	rows, err := db.Pool.Query(context.Background(), `
		SELECT u.id, u.username, COALESCE(u.avatar,''), COALESCE(u.verified,false),
		       nr.emoji, nr.created_at
		FROM note_reactions nr JOIN users u ON u.id = nr.user_id
		WHERE nr.note_owner_id=$1
		  AND NOT EXISTS(SELECT 1 FROM blocks b
		     WHERE (b.blocker_id=$1 AND b.blocked_id=nr.user_id)
		        OR (b.blocker_id=nr.user_id AND b.blocked_id=$1))
		ORDER BY nr.created_at DESC
		LIMIT 200`, myID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"message": "failed"})
		return
	}
	defer rows.Close()
	out := []gin.H{}
	for rows.Next() {
		var id, uname, avatar, emoji string
		var verified bool
		var at time.Time
		if rows.Scan(&id, &uname, &avatar, &verified, &emoji, &at) != nil {
			continue
		}
		out = append(out, gin.H{
			"user":  gin.H{"_id": id, "username": uname, "avatar": avatar, "verified": verified},
			"emoji": emoji, "createdAt": at,
		})
	}
	c.JSON(http.StatusOK, gin.H{"reactions": out, "count": len(out)})
}

// clearNoteReactions — ҳангоми иваз/тоза кардани ёддошт.
func clearNoteReactions(ownerID string) {
	db.Pool.Exec(context.Background(),
		`DELETE FROM note_reactions WHERE note_owner_id=$1`, ownerID)
}
