package core

import (
	"encoding/json"
	"fmt"
	"net/http"
	"os"
	"time"

	"github.com/gin-gonic/gin"
)

// ── Logger (core/logger.js) ───────────────────────────────────────
const serviceName = "Raonson-Backend"

type logEntry struct {
	Service   string      `json:"service"`
	Level     string      `json:"level"`
	Message   string      `json:"message"`
	BaseURL   string      `json:"baseUrl"`
	Timestamp string      `json:"timestamp"`
	Meta      interface{} `json:"meta,omitempty"`
}

var Logger = &logger{}

type logger struct{}

func (l *logger) Info(msg string, meta ...interface{}) {
	l.log("INFO", msg, meta...)
}
func (l *logger) Warn(msg string, meta ...interface{}) {
	l.log("WARN", msg, meta...)
}
func (l *logger) Error(msg string, meta ...interface{}) {
	l.log("ERROR", msg, meta...)
}

func (l *logger) log(level, msg string, meta ...interface{}) {
	e := logEntry{
		Service:   serviceName,
		Level:     level,
		Message:   msg,
		BaseURL:   os.Getenv("BASE_URL"),
		Timestamp: time.Now().Format(time.RFC3339),
	}
	if len(meta) > 0 {
		e.Meta = meta[0]
	}
	b, _ := json.Marshal(e)
	fmt.Println(string(b))
}

// ── Pagination (core/pagination.js) ──────────────────────────────
type Pagination struct {
	Page   int
	Limit  int
	Offset int
}

func GetPagination(c *gin.Context) Pagination {
	page  := 1
	limit := 20

	if p := c.Query("page");  p != "" { fmt.Sscan(p, &page)  }
	if l := c.Query("limit"); l != "" { fmt.Sscan(l, &limit) }

	if page  < 1   { page  = 1   }
	if limit < 1   { limit = 1   }
	if limit > 100 { limit = 100 }

	return Pagination{
		Page:   page,
		Limit:  limit,
		Offset: (page - 1) * limit,
	}
}

// ── Error Handler (core/errorHandler.js) ─────────────────────────
func ErrorHandler() gin.HandlerFunc {
	return func(c *gin.Context) {
		c.Next()

		if len(c.Errors) == 0 {
			return
		}

		err := c.Errors.Last()
		Logger.Error("Unhandled error", err.Error())

		if !c.Writer.Written() {
			c.JSON(http.StatusInternalServerError, gin.H{
				"success": false,
				"error":   "Internal server error",
			})
		}
	}
}

// ── Response Formatter (core/responseFormatter.js) ───────────────
func Success(c *gin.Context, data interface{}, meta ...interface{}) {
	resp := gin.H{"success": true, "data": data}
	if len(meta) > 0 {
		resp["meta"] = meta[0]
	}
	c.JSON(http.StatusOK, resp)
}

func Failure(c *gin.Context, status int, message string) {
	c.JSON(status, gin.H{"success": false, "error": message})
}
