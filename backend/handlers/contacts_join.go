package handlers

// «<ном> аз мухотибони шумо ба Raonson ҳамроҳ шуд» — мисли TikTok.
//
// Махфият:
//   - Рақами телефони мухотибон ҲЕҶ ГОҲ хом нигоҳ дошта намешавад —
//     танҳо HMAC-SHA256(намак, 9 рақами охир). Намак аз муҳити сервер:
//     CONTACTS_HASH_PEPPER. Агар набошад, намаки доимии барнома
//     истифода мешавад (кор мекунад, вале барои продакшн калиди махфӣ
//     гузоштан лозим аст — бе он хешҳои 9-рақама бо интихоби пурра
//     кушода мешаванд). Ивази намак хешҳои кӯҳнаро бекор мекунад:
//     мувофиқатҳо то боркунии навбатии мухотибон гум мешаванд.
//   - Хеш танҳо бо РОЗИГИИ ошкор нигоҳ дошта мешавад (consent:true дар
//     POST /users/find-by-contacts). Бе он рақамҳо танҳо барои ҷустуҷӯ
//     истифода мешаванд, мисли пеш.
//   - Огоҳинома танҳо ба касе меравад, ки танзими «Ба ман хабар деҳ…»-
//     ро фаъол дорад (пас аз розигӣ худ аз худ фаъол, хомӯшшаванда).
//   - Басташуда (ҳар ду тараф) ва касе, ки аллакай обуна аст, хабар
//     намегирад. Ҳар ҳисоб танҳо ЯК БОР эълон мешавад.
//   - Ба ҳеҷ кас рақами каси дигар нишон дода намешавад: ҷавобҳо танҳо
//     номи корбар ва аватар доранд.

import (
	"context"
	"crypto/hmac"
	"crypto/sha256"
	"encoding/hex"
	"log"
	"net/http"
	"os"
	"sync"

	"raonson/db"
	mw "raonson/middleware"

	"github.com/gin-gonic/gin"
)

// MaxContactHashes — ҳадди мухотибони нигоҳдошташудаи як корбар.
const MaxContactHashes = 1000

// maxJoinFanout — ҳадди огоҳиномаҳо барои як ҳамроҳшавӣ.
const maxJoinFanout = 500

var pepperWarn sync.Once

func contactPepper() []byte {
	if p := os.Getenv("CONTACTS_HASH_PEPPER"); p != "" {
		return []byte(p)
	}
	pepperWarn.Do(func() {
		log.Println("⚠️ CONTACTS_HASH_PEPPER танзим нашудааст — намаки пешфарз истифода мешавад")
	})
	return []byte("raonson-contacts-v1")
}

// normalizeContactPhone рақамро ба 9 рақами охир меорад (ҳамон қоидаи
// FindUsersByContacts: +992…, 0…, 992… як рақаманд). "" — нодуруст.
func normalizeContactPhone(p string) string {
	n := cleanPhone(p)
	if len(n) < 7 {
		return ""
	}
	if len(n) > 9 {
		n = n[len(n)-9:]
	}
	return n
}

// contactHash — хеши рақами муқарраршуда.
func contactHash(normalized string) string {
	m := hmac.New(sha256.New, contactPepper())
	m.Write([]byte(normalized))
	return hex.EncodeToString(m.Sum(nil))
}

// storeContactHashes рӯйхати мухотибонро ИВАЗ мекунад (sync): рақамҳое,
// ки аз телефон нест шуданд, аз сервер ҳам нест мешаванд. Розигӣ
// танзими «хабар деҳ»-ро фаъол мекунад, агар корбар онро худаш хомӯш
// накарда бошад.
func storeContactHashes(ctx context.Context, ownerID string, normalized []string) {
	if len(normalized) > MaxContactHashes {
		normalized = normalized[:MaxContactHashes]
	}
	hashes := make([]string, 0, len(normalized))
	for _, n := range normalized {
		hashes = append(hashes, contactHash(n))
	}
	tx, err := db.Pool.Begin(ctx)
	if err != nil {
		return
	}
	defer tx.Rollback(ctx)
	if _, err := tx.Exec(ctx,
		`DELETE FROM contact_hashes WHERE owner_id=$1`, ownerID); err != nil {
		return
	}
	if _, err := tx.Exec(ctx, `
		INSERT INTO contact_hashes(owner_id, phone_hash)
		SELECT $1, h FROM unnest($2::text[]) AS h
		ON CONFLICT DO NOTHING`, ownerID, hashes); err != nil {
		return
	}
	if _, err := tx.Exec(ctx, `
		UPDATE users SET contacts_join_notify=COALESCE(contacts_join_notify, TRUE)
		 WHERE id=$1`, ownerID); err != nil {
		return
	}
	tx.Commit(ctx)
}

// announceContactJoined касонеро, ки рақами ин корбарро дар мухотибон
// доранд, огоҳ мекунад. Танҳо як бор барои ҳар ҳисоб; дар background.
func announceContactJoined(userID string) {
	if userID == "" {
		return
	}
	go func() {
		ctx := context.Background()
		var phone string
		// Атомӣ: ду дархости ҳамзамон ду бор эълон намекунанд.
		if err := db.Pool.QueryRow(ctx, `
			UPDATE users SET contacts_announced=TRUE
			 WHERE id=$1 AND contacts_announced=FALSE
			   AND COALESCE(phone,'')<>'' AND COALESCE(banned,false)=FALSE
			RETURNING phone`, userID).Scan(&phone); err != nil {
			return
		}
		n := normalizeContactPhone(phone)
		if n == "" {
			return
		}
		rows, err := db.Pool.Query(ctx, `
			SELECT ch.owner_id
			  FROM contact_hashes ch
			  JOIN users o ON o.id=ch.owner_id
			 WHERE ch.phone_hash=$1 AND ch.owner_id<>$2
			   AND o.contacts_join_notify IS TRUE
			   AND COALESCE(o.banned,false)=FALSE
			   AND NOT EXISTS (SELECT 1 FROM blocks b
			        WHERE (b.blocker_id=ch.owner_id AND b.blocked_id=$2)
			           OR (b.blocker_id=$2 AND b.blocked_id=ch.owner_id))
			   AND NOT EXISTS (SELECT 1 FROM follows f
			        WHERE f.follower_id=ch.owner_id AND f.following_id=$2)
			 LIMIT $3`, contactHash(n), userID, maxJoinFanout)
		if err != nil {
			return
		}
		var owners []string
		for rows.Next() {
			var id string
			if rows.Scan(&id) == nil {
				owners = append(owners, id)
			}
		}
		rows.Close()
		for _, o := range owners {
			if notifySync(o, userID, "contact_joined", userID) {
				pushNotify(o, userID, "contact_joined", userID, "")
			}
		}
	}()
}

// GET /contacts/settings
//
// {consent, notifyJoined, stored} — stored: шумораи мухотибони
// нигоҳдошташуда (худи рақамҳо ҳеҷ гоҳ бармегарданд).
func GetContactSettings(c *gin.Context) {
	myID := mw.UID(c)
	var pref *bool
	var stored int
	db.Pool.QueryRow(c.Request.Context(), `
		SELECT contacts_join_notify,
		       (SELECT COUNT(*) FROM contact_hashes WHERE owner_id=$1)
		  FROM users WHERE id=$1`, myID).Scan(&pref, &stored)
	c.JSON(http.StatusOK, gin.H{
		"consent":      pref != nil,
		"notifyJoined": pref != nil && *pref,
		"stored":       stored,
	})
}

// PUT /contacts/settings {notifyJoined}
//
// Бе розигӣ (мухотибон ҳеҷ гоҳ бор нашудаанд) фаъол карда намешавад —
// аввал бояд иҷозати мухотибон дода шавад.
func UpdateContactSettings(c *gin.Context) {
	myID := mw.UID(c)
	var b struct {
		NotifyJoined *bool `json:"notifyJoined"`
	}
	if err := c.ShouldBindJSON(&b); err != nil || b.NotifyJoined == nil {
		c.JSON(http.StatusBadRequest, gin.H{"message": "notifyJoined лозим аст"})
		return
	}
	tag, err := db.Pool.Exec(c.Request.Context(), `
		UPDATE users SET contacts_join_notify=$2
		 WHERE id=$1 AND contacts_join_notify IS NOT NULL`, myID, *b.NotifyJoined)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"message": "Нигоҳ дошта нашуд"})
		return
	}
	if tag.RowsAffected() == 0 {
		c.JSON(http.StatusConflict, gin.H{
			"message": "Аввал мухотибонро пайваст кунед", "needsConsent": true})
		return
	}
	c.JSON(http.StatusOK, gin.H{"notifyJoined": *b.NotifyJoined})
}

// DELETE /contacts — розигиро бозпас мегирад: ҳамаи хешҳо нест,
// танзим ба ҳолати «розигӣ нест».
func DeleteContacts(c *gin.Context) {
	myID := mw.UID(c)
	ctx := c.Request.Context()
	db.Pool.Exec(ctx, `DELETE FROM contact_hashes WHERE owner_id=$1`, myID)
	db.Pool.Exec(ctx,
		`UPDATE users SET contacts_join_notify=NULL WHERE id=$1`, myID)
	c.JSON(http.StatusOK, gin.H{"deleted": true})
}
