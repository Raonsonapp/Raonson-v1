package utils

import (
	"crypto/hmac"
	"crypto/rand"
	"crypto/sha256"
	"encoding/hex"
	"path/filepath"
	"regexp"
	"strings"
	"time"
)

// ── Crypto Utils (crypto.util.js) ────────────────────────────────

func RandomToken(length int) string {
	b := make([]byte, length)
	rand.Read(b)
	return hex.EncodeToString(b)
}

func Hash(value string) string {
	h := sha256.Sum256([]byte(value))
	return hex.EncodeToString(h[:])
}

func CompareHash(raw, hashed string) bool {
	return Hash(raw) == hashed
}

func SignHMAC(data, secret string) string {
	mac := hmac.New(sha256.New, []byte(secret))
	mac.Write([]byte(data))
	return hex.EncodeToString(mac.Sum(nil))
}

// ── Date Utils (date.util.js) ─────────────────────────────────────

func Now() time.Time { return time.Now() }

func AddHours(t time.Time, hours int) time.Time {
	return t.Add(time.Duration(hours) * time.Hour)
}

func IsExpired(t time.Time) bool {
	return t.Before(time.Now())
}

func FromNow(t time.Time) string {
	diff := time.Since(t)
	switch {
	case diff.Seconds() < 60:
		return "ҳозир"
	case diff.Minutes() < 60:
		return strings.Replace(
			"Xm пеш", "X", itoa(int(diff.Minutes())), 1)
	case diff.Hours() < 24:
		return strings.Replace(
			"Xс пеш", "X", itoa(int(diff.Hours())), 1)
	default:
		return strings.Replace(
			"Xр пеш", "X", itoa(int(diff.Hours()/24)), 1)
	}
}

// ── File Utils (file.util.js) ─────────────────────────────────────

var imageTypes = map[string]bool{
	"image/jpeg": true, "image/png": true,
	"image/webp": true, "image/gif": true,
}
var videoTypes = map[string]bool{
	"video/mp4": true, "video/quicktime": true,
	"video/webm": true,
}

func IsImage(mime string) bool { return imageTypes[mime] }
func IsVideo(mime string) bool { return videoTypes[mime] }

func ValidateFile(size int64, mime string, maxSizeMB int) error {
	sizeMB := int(size / 1024 / 1024)
	if sizeMB > maxSizeMB {
		return errorf("File too large: %dMB (max %dMB)", sizeMB, maxSizeMB)
	}
	if !IsImage(mime) && !IsVideo(mime) {
		return errorf("Unsupported file type: %s", mime)
	}
	return nil
}

func ExtractExtension(filename string) string {
	return strings.ToLower(strings.TrimPrefix(filepath.Ext(filename), "."))
}

// ── Slug Utils (slug.util.js) ─────────────────────────────────────

var nonAlphaNum = regexp.MustCompile(`[^\w\s-]`)
var spaces      = regexp.MustCompile(`[\s_-]+`)
var trim        = regexp.MustCompile(`^-+|-+$`)

func Slugify(text string) string {
	s := strings.ToLower(strings.TrimSpace(text))
	s = nonAlphaNum.ReplaceAllString(s, "")
	s = spaces.ReplaceAllString(s, "-")
	s = trim.ReplaceAllString(s, "")
	return s
}

func UniqueSlug(base string, exists func(string) bool) string {
	slug := Slugify(base)
	counter := 1
	for exists(slug) {
		slug = Slugify(base) + "-" + itoa(counter)
		counter++
	}
	return slug
}

// ── helpers ───────────────────────────────────────────────────────
func itoa(n int) string {
	if n == 0 { return "0" }
	s := ""
	for n > 0 {
		s = string(rune('0'+n%10)) + s
		n /= 10
	}
	return s
}

type appError struct{ msg string }
func (e *appError) Error() string { return e.msg }
func errorf(format string, args ...interface{}) error {
	msg := format
	for _, a := range args {
		switch v := a.(type) {
		case string: msg = strings.Replace(msg, "%s", v, 1)
		case int:    msg = strings.Replace(msg, "%d", itoa(v), 1)
		}
	}
	return &appError{msg}
}
