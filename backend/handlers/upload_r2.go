package handlers

import (
	"bytes"
	"crypto/hmac"
	"crypto/sha256"
	"encoding/hex"
	"fmt"
	"io"
	"net/http"
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
)

// ── R2 Credentials (env-dan oladi, default = haqiqiy qiymatlar) ──
func r2AccountID() string {
	if v := os.Getenv("CF_ACCOUNT_ID"); v != "" { return v }
	return "4362a439e21a5c003fe9a49560b370b6"
}
func r2AccessKey() string {
	if v := os.Getenv("CF_R2_ACCESS_KEY"); v != "" { return v }
	return "fed4dc11c0cedd66329d545cc5e286a1"
}
func r2SecretKey() string {
	if v := os.Getenv("CF_R2_SECRET_KEY"); v != "" { return v }
	return "49aa55246ee4c4423946217f9b5127672d4555f09b6116fbdf45a12beeb74297"
}
func r2Bucket() string {
	if v := os.Getenv("CF_R2_BUCKET"); v != "" { return v }
	return "raonson-media"
}
func r2PublicURL() string { return os.Getenv("CF_R2_PUBLIC_URL") }

// POST /upload
func UploadToR2(c *gin.Context) {
	file, header, err := c.Request.FormFile("file")
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "No file uploaded"})
		return
	}
	defer file.Close()

	data, err := io.ReadAll(file)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Read failed"})
		return
	}

	contentType := header.Header.Get("Content-Type")
	if contentType == "" {
		contentType = detectContentType(header.Filename, data)
	}

	folder := "images"
	if strings.Contains(contentType, "video") { folder = "videos" }
	if strings.Contains(contentType, "audio") { folder = "audio"  }

	ext := filepath.Ext(header.Filename)
	if ext == "" { ext = extensionFromMime(contentType) }

	key := fmt.Sprintf("%s/%s%s", folder, uuid.New().String(), ext)

	url, err := uploadToR2(key, data, contentType)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Upload failed: " + err.Error()})
		return
	}
	c.JSON(http.StatusOK, gin.H{"url": url})
}

func uploadToR2(key string, data []byte, contentType string) (string, error) {
	accountID := r2AccountID()
	accessKey := r2AccessKey()
	secretKey := r2SecretKey()
	bucket    := r2Bucket()
	endpoint  := fmt.Sprintf("https://%s.r2.cloudflarestorage.com", accountID)

	now     := time.Now().UTC()
	dateStr := now.Format("20060102")
	timeStr := now.Format("20060102T150405Z")

	objPath := fmt.Sprintf("/%s/%s", bucket, key)
	host    := fmt.Sprintf("%s.r2.cloudflarestorage.com", accountID)
	payHash := sha256Hex(data)

	canonHeaders := fmt.Sprintf(
		"content-length:%d\ncontent-type:%s\nhost:%s\nx-amz-content-sha256:%s\nx-amz-date:%s\n",
		len(data), contentType, host, payHash, timeStr)
	signedH := "content-length;content-type;host;x-amz-content-sha256;x-amz-date"

	canonReq := "PUT\n" + objPath + "\n\n" + canonHeaders + "\n" + signedH + "\n" + payHash

	credScope   := dateStr + "/auto/s3/aws4_request"
	stringToSign := "AWS4-HMAC-SHA256\n" + timeStr + "\n" + credScope + "\n" + sha256Hex([]byte(canonReq))

	sigKey := hmacSHA256(
		hmacSHA256(hmacSHA256(hmacSHA256([]byte("AWS4"+secretKey),
			[]byte(dateStr)), []byte("auto")), []byte("s3")), []byte("aws4_request"))

	sig      := hex.EncodeToString(hmacSHA256(sigKey, []byte(stringToSign)))
	authHdr  := fmt.Sprintf("AWS4-HMAC-SHA256 Credential=%s/%s, SignedHeaders=%s, Signature=%s",
		accessKey, credScope, signedH, sig)

	req, err := http.NewRequest("PUT", endpoint+objPath, bytes.NewReader(data))
	if err != nil { return "", err }
	req.Header.Set("Content-Type",        contentType)
	req.Header.Set("Content-Length",      strconv.Itoa(len(data)))
	req.Header.Set("X-Amz-Date",          timeStr)
	req.Header.Set("X-Amz-Content-Sha256", payHash)
	req.Header.Set("Authorization",       authHdr)

	resp, err := http.DefaultClient.Do(req)
	if err != nil { return "", fmt.Errorf("R2 request: %w", err) }
	defer resp.Body.Close()

	if resp.StatusCode >= 300 {
		b, _ := io.ReadAll(resp.Body)
		return "", fmt.Errorf("R2 %d: %s", resp.StatusCode, string(b))
	}

	if pub := r2PublicURL(); pub != "" {
		return pub + "/" + key, nil
	}
	return fmt.Sprintf("%s/%s/%s", endpoint, bucket, key), nil
}

func sha256Hex(data []byte) string {
	h := sha256.Sum256(data); return hex.EncodeToString(h[:])
}
func hmacSHA256(key, data []byte) []byte {
	h := hmac.New(sha256.New, key); h.Write(data); return h.Sum(nil)
}
func detectContentType(filename string, data []byte) string {
	switch strings.ToLower(filepath.Ext(filename)) {
	case ".jpg", ".jpeg": return "image/jpeg"
	case ".png":          return "image/png"
	case ".gif":          return "image/gif"
	case ".webp":         return "image/webp"
	case ".mp4":          return "video/mp4"
	case ".mov":          return "video/quicktime"
	case ".mp3":          return "audio/mpeg"
	}
	if len(data) > 2 && data[0] == 0xFF && data[1] == 0xD8 { return "image/jpeg" }
	if len(data) > 2 && data[0] == 0x89 && data[1] == 0x50 { return "image/png" }
	return "application/octet-stream"
}
func extensionFromMime(mime string) string {
	switch {
	case strings.Contains(mime, "jpeg"):      return ".jpg"
	case strings.Contains(mime, "png"):       return ".png"
	case strings.Contains(mime, "gif"):       return ".gif"
	case strings.Contains(mime, "webp"):      return ".webp"
	case strings.Contains(mime, "mp4"):       return ".mp4"
	case strings.Contains(mime, "quicktime"): return ".mov"
	case strings.Contains(mime, "mpeg"):      return ".mp3"
	}
	return ".bin"
}
