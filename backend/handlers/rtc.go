package handlers

import (
	"context"
	"crypto/sha256"
	"encoding/hex"
	"net/http"
	"os"
	"sort"
	"strings"

	"raonson/db"
	mw "raonson/middleware"

	rtc "github.com/AgoraIO/Tools/DynamicKey/AgoraDynamicKey/go/src/rtctokenbuilder2"
	"github.com/gin-gonic/gin"
)

// Занги аудио/видео ва Live бо Agora.
//
// Ду мушкил пештар зангро вайрон мекард:
//  1. Номи канал = "uuid_uuid" (73 аломат), вале Agora танҳо то 64 байт
//     қабул мекунад — joinChannel рад мешуд ва ҳарду тараф то абад
//     «Пайваст мешавад…» медиданд.
//  2. Token холӣ фиристода мешуд. Лоиҳаи Agora бо App Certificate
//     (ҳолати пешфарзи лоиҳаҳои нав) бе token пайвастро рад мекунад.
//
// Акнун сервер номи кӯтоҳ ва token медиҳад. Certificate ФАҚАТ дар env
// (AGORA_APP_CERTIFICATE) аст — ҳеҷ гоҳ дар барнома ё дар git.

const rtcTokenTTL = 2 * 60 * 60 // 2 соат

// callChannel — номи канал барои ду нафар: якхела барои ҳарду тараф,
// кӯтоҳтар аз 64 байт ва аз он ID-ҳоро хондан намешавад.
func callChannel(a, b string) string {
	ids := []string{a, b}
	sort.Strings(ids)
	sum := sha256.Sum256([]byte(strings.Join(ids, "_")))
	return "call_" + hex.EncodeToString(sum[:16])
}

// rtcToken — token барои канал. Бе certificate холӣ (ҳолати санҷишии
// Agora, ки танҳо App ID мехоҳад).
func rtcToken(channel string, publisher bool) (string, error) {
	appID := strings.TrimSpace(os.Getenv("AGORA_APP_ID"))
	cert := strings.TrimSpace(os.Getenv("AGORA_APP_CERTIFICATE"))
	if appID == "" || cert == "" {
		return "", nil
	}
	var role rtc.Role = rtc.RoleSubscriber
	if publisher {
		role = rtc.RolePublisher
	}
	// uid 0 — token барои ҳар uid дар ҳамин канал (барнома uid 0 мефиристад).
	return rtc.BuildTokenWithUid(appID, cert, channel, 0, role, rtcTokenTTL, rtcTokenTTL)
}

// POST /calls/token {peerId} → {channel, token}
func CallToken(c *gin.Context) {
	me := mw.UID(c)
	var b struct {
		PeerID string `json:"peerId"`
	}
	_ = c.ShouldBindJSON(&b)
	peer := strings.TrimSpace(b.PeerID)
	if peer == "" || peer == me {
		c.JSON(http.StatusBadRequest, gin.H{"message": "peerId лозим"})
		return
	}
	var exists bool
	_ = db.Pool.QueryRow(context.Background(),
		`SELECT EXISTS(SELECT 1 FROM users WHERE id=$1)`, peer).Scan(&exists)
	if !exists {
		c.JSON(http.StatusNotFound, gin.H{"message": "корбар ёфт нашуд"})
		return
	}
	if IsBlockedBetween(me, peer) {
		c.JSON(http.StatusForbidden, gin.H{"message": "занг имконнопазир аст"})
		return
	}
	ch := callChannel(me, peer)
	tok, err := rtcToken(ch, true)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"message": "token сохта нашуд"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"channel": ch, "token": tok})
}

// POST /live/:id/token → {channel, token, host}
// Ҳост — publisher; дигарон — танҳо тамошобин (subscriber).
func LiveToken(c *gin.Context) {
	me := mw.UID(c)
	var channel, hostID string
	err := db.Pool.QueryRow(context.Background(),
		`SELECT channel, host_id FROM live_streams WHERE id=$1 AND active=TRUE`,
		c.Param("id")).Scan(&channel, &hostID)
	if err != nil || channel == "" {
		c.JSON(http.StatusNotFound, gin.H{"message": "эфир ёфт нашуд"})
		return
	}
	isHost := hostID == me
	if !isHost && IsBlockedBetween(me, hostID) {
		c.JSON(http.StatusNotFound, gin.H{"message": "эфир ёфт нашуд"})
		return
	}
	tok, err := rtcToken(channel, isHost)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"message": "token сохта нашуд"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"channel": channel, "token": tok, "host": isHost})
}
