package handlers

import (
	"context"
	"crypto/sha1"
	"encoding/hex"
	"net/http"
	"strings"

	"raonson/db"
	mw "raonson/middleware"

	"github.com/gin-gonic/gin"
)

// ══════════════════════════════════════════════════════════════════
//  Хатоҳои барнома аз телефонҳо.
//
//  Корбар мегӯяд «профил хатои сурх медиҳад», вале сервер аз он
//  бехабар аст ва stack trace дар телефон мемонад. Ин ҷо барнома ҳар
//  хатои Flutter-ро (як бор, бо шумор) мефиристад ва админ онро дар
//  «Панели админ → Хатоҳои барнома» мебинад.
//
//  Маълумоти шахсӣ фиристода намешавад: танҳо матни хато, stack,
//  номи экран ва версия.
// ══════════════════════════════════════════════════════════════════

// POST /client-errors {message, stack, screen, appVersion, platform}
func ReportClientError(c *gin.Context) {
	var b struct {
		Message    string `json:"message"`
		Stack      string `json:"stack"`
		Screen     string `json:"screen"`
		AppVersion string `json:"appVersion"`
		Platform   string `json:"platform"`
	}
	if c.ShouldBindJSON(&b) != nil || strings.TrimSpace(b.Message) == "" {
		c.JSON(http.StatusBadRequest, gin.H{"message": "message лозим"})
		return
	}
	b.Message = clampRunes(strings.TrimSpace(b.Message), 500)
	b.Stack = clampRunes(b.Stack, 4000)
	b.Screen = clampRunes(b.Screen, 80)
	b.AppVersion = clampRunes(b.AppVersion, 20)
	b.Platform = clampRunes(b.Platform, 20)
	// Як хато — як сатр (бо шумор), на ҳазор сатр.
	firstLine := b.Stack
	if i := strings.Index(firstLine, "package:raonson"); i >= 0 {
		firstLine = firstLine[i:]
		if j := strings.IndexByte(firstLine, '\n'); j > 0 {
			firstLine = firstLine[:j]
		}
	}
	sum := sha1.Sum([]byte(b.Message + "|" + firstLine + "|" + b.AppVersion))
	hash := hex.EncodeToString(sum[:])
	db.Pool.Exec(context.Background(), `
		INSERT INTO client_errors(hash, message, stack, screen, app_version, platform, user_id)
		VALUES($1,$2,$3,$4,$5,$6,NULLIF($7,''))
		ON CONFLICT (hash) DO UPDATE SET count = client_errors.count + 1,
		  last_seen = NOW(), user_id = COALESCE(EXCLUDED.user_id, client_errors.user_id)`,
		hash, b.Message, b.Stack, b.Screen, b.AppVersion, b.Platform, mw.UID(c))
	c.JSON(http.StatusOK, gin.H{"ok": true})
}

// GET /admin/client-errors — охирин хатоҳо (танҳо админ).
func AdminClientErrors(c *gin.Context) {
	rows, err := db.Pool.Query(context.Background(), `
		SELECT hash, message, stack, screen, app_version, platform, count, first_seen, last_seen
		FROM client_errors ORDER BY last_seen DESC LIMIT 100`)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"message": "Хато"})
		return
	}
	defer rows.Close()
	out := []gin.H{}
	for rows.Next() {
		var hash, msg, stack, screen, ver, plat string
		var count int
		var first, last interface{}
		rows.Scan(&hash, &msg, &stack, &screen, &ver, &plat, &count, &first, &last)
		out = append(out, gin.H{"id": hash, "message": msg, "stack": stack, "screen": screen,
			"appVersion": ver, "platform": plat, "count": count,
			"firstSeen": first, "lastSeen": last})
	}
	c.JSON(http.StatusOK, gin.H{"errors": out})
}

// DELETE /admin/client-errors — рӯйхатро пок мекунад (баъди ислоҳ).
func AdminClearClientErrors(c *gin.Context) {
	db.Pool.Exec(context.Background(), `DELETE FROM client_errors`)
	c.JSON(http.StatusOK, gin.H{"ok": true})
}
