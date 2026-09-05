package handlers

// Ташхиси умумии система.
//
// Як ҷо, ки ба саволи «оё чизе вайрон аст?» ҷавоб медиҳад — пеш аз
// он ки корбарон шикоят кунанд.
//
// Ҳеҷ сир бармегардад: танҳо «танзим шудааст / не», host ва рақам.

import (
	"context"
	"net/http"
	"os"
	"runtime"
	"time"

	"github.com/gin-gonic/gin"

	"raonson/db"
	mw "raonson/middleware"
	"raonson/push"
)

// GET /admin/system/health
func SystemHealth(c *gin.Context) {
	ctx, cancel := context.WithTimeout(c.Request.Context(), 5*time.Second)
	defer cancel()

	out := gin.H{"checkedAt": time.Now().UTC().Format(time.RFC3339)}

	out["database"] = databaseHealth(ctx)
	out["cache"] = cacheHealth()
	out["push"] = gin.H{
		"configured": push.Configured(),
		"projectId":  push.ProjectID(),
	}
	out["ai"] = aiConfigured()
	out["storage"] = storageConfigured()
	out["runtime"] = runtimeHealth()

	c.JSON(http.StatusOK, out)
}

// databaseHealth — ҳолати база ва пул.
//
// Маҳз ин ҷо маълум мешавад, ки оё пул наздик ба тамом шудан аст:
// пури пул маънои «тамоми API меистад»-ро дорад.
func databaseHealth(ctx context.Context) gin.H {
	h := gin.H{"ok": false}
	if db.Pool == nil {
		return h
	}

	start := time.Now()
	var one int
	err := db.Pool.QueryRow(ctx, `SELECT 1`).Scan(&one)
	h["latencyMs"] = time.Since(start).Milliseconds()
	h["ok"] = err == nil && one == 1

	s := db.Pool.Stat()
	total := int(s.TotalConns())
	h["pool"] = gin.H{
		"max":      s.MaxConns(),
		"total":    total,
		"acquired": s.AcquiredConns(),
		"idle":     s.IdleConns(),
		// Дархостҳое, ки барои пайваст интизор шуданд. Рақами
		// калон маънои камии пулро дорад.
		"emptyAcquireCount": s.EmptyAcquireCount(),
		"canceledAcquire":   s.CanceledAcquireCount(),
	}

	// Маҳдудияти вақт воқеан татбиқ шудааст?
	var st, idleTx string
	db.Pool.QueryRow(ctx, `SHOW statement_timeout`).Scan(&st)
	db.Pool.QueryRow(ctx, `SHOW idle_in_transaction_session_timeout`).Scan(&idleTx)
	h["statementTimeout"] = st
	h["idleTxTimeout"] = idleTx
	// «0» маънои беохир дорад — як дархости суст пайвастро абадӣ
	// нигоҳ медорад.
	h["timeoutsEnforced"] = st != "0" && st != ""

	return h
}

func cacheHealth() gin.H {
	return gin.H{
		"entries": mw.LocalSize(),
		"redis":   mw.RedisConfigured(),
	}
}

// aiConfigured — оё калид ҳаст. Худи калид ҳеҷ гоҳ бармегардад.
func aiConfigured() gin.H {
	has := func(keys ...string) bool {
		for _, k := range keys {
			if os.Getenv(k) != "" {
				return true
			}
		}
		return false
	}
	return gin.H{
		"configured": has("AI_API_KEY", "TUTOR_API_KEY", "OPENAI_API_KEY"),
		"moderation": has("OPENAI_API_KEY"),
	}
}

func storageConfigured() gin.H {
	return gin.H{
		"r2": os.Getenv("R2_ACCESS_KEY_ID") != "" &&
			os.Getenv("R2_SECRET_ACCESS_KEY") != "",
		"bucket": os.Getenv("R2_BUCKET") != "",
	}
}

func runtimeHealth() gin.H {
	var m runtime.MemStats
	runtime.ReadMemStats(&m)
	return gin.H{
		"goroutines": runtime.NumGoroutine(),
		"heapMB":     m.HeapAlloc / 1024 / 1024,
		"sysMB":      m.Sys / 1024 / 1024,
		"gc":         m.NumGC,
		"cpus":       runtime.NumCPU(),
	}
}
