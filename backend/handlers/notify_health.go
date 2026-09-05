package handlers

// Ташхиси огоҳиномаҳо.
//
// Саволи асосӣ, ки ин ҷо ҷавоб мегирад: «чаро огоҳинома намеояд?»
//
// Бе ин, нокомии провайдер хомӯш мемонад ва танҳо аз шикояти
// корбарон маълум мешавад.
//
// Ҳеҷ сир, ҳеҷ токен ва ҳеҷ маълумоти шахсӣ бармегардад.

import (
	"net/http"
	"time"

	"github.com/gin-gonic/gin"

	"raonson/db"
	"raonson/push"
)

// GET /admin/notifications/health
func NotificationHealth(c *gin.Context) {
	ctx := c.Request.Context()

	out := gin.H{
		// Оё аслнома ҳаст. Худи калид ҳеҷ гоҳ бармегардад.
		"pushConfigured": push.Configured(),
		"projectId":      push.ProjectID(),
	}

	// Дастгоҳҳо.
	var active, disabled int
	db.Pool.QueryRow(ctx,
		`SELECT COUNT(*) FILTER (WHERE enabled),
		        COUNT(*) FILTER (WHERE NOT enabled)
		 FROM device_tokens`).Scan(&active, &disabled)
	out["devices"] = gin.H{"active": active, "disabled": disabled}

	// Натиҷаи 24 соати охир.
	rows, err := db.Pool.Query(ctx, `
		SELECT status, COALESCE(NULLIF(reason,''),'-'), COUNT(*)
		FROM notification_delivery
		WHERE created_at > NOW() - INTERVAL '24 hours'
		GROUP BY 1,2 ORDER BY 3 DESC LIMIT 30`)
	if err == nil {
		defer rows.Close()
		stats := []gin.H{}
		total, sent := 0, 0
		for rows.Next() {
			var status, reason string
			var n int
			if err := rows.Scan(&status, &reason, &n); err != nil {
				continue
			}
			stats = append(stats, gin.H{
				"status": status, "reason": reason, "count": n,
			})
			total += n
			if status == "sent" {
				sent += n
			}
		}
		out["last24h"] = stats
		out["total"] = total
		if total > 0 {
			// Фоизи қабулшуда аз ҷониби ПРОВАЙДЕР. Ин кафолати
			// расидан ба дастгоҳ НЕСТ — инро танҳо худи Android/iOS
			// медонад.
			out["providerAcceptedPct"] = sent * 100 / total
		}
	}

	// Сабабҳои радшавӣ — барои фаҳмидани он, ки чӣ хомӯш мекунад.
	out["checkedAt"] = time.Now().UTC().Format(time.RFC3339)
	c.JSON(http.StatusOK, out)
}
