package handlers

import (
	"bytes"
	"context"
	"fmt"
	"io"
	"log"
	"net/http"
	"os"
	"path/filepath"
	"strings"

	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/credentials"
	"github.com/aws/aws-sdk-go-v2/service/s3"
	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
)

func getR2Client() *s3.Client {
	// Credentials come ONLY from env (set in Render). Never hardcode secrets.
	accountID := os.Getenv("CF_ACCOUNT_ID")
	accessKey  := os.Getenv("CF_R2_ACCESS_KEY")
	secretKey  := os.Getenv("CF_R2_SECRET_KEY")
	if accountID == "" || accessKey == "" || secretKey == "" {
		log.Println("[R2] credentials missing (CF_ACCOUNT_ID/CF_R2_ACCESS_KEY/CF_R2_SECRET_KEY)")
	}

	endpoint := fmt.Sprintf("https://%s.r2.cloudflarestorage.com", accountID)

	return s3.New(s3.Options{
		Region:       "auto",
		BaseEndpoint: aws.String(endpoint),
		UsePathStyle: true,
		Credentials:  aws.NewCredentialsCache(
			credentials.NewStaticCredentialsProvider(accessKey, secretKey, ""),
		),
	})
}

func r2Bucket() string {
	if v := os.Getenv("CF_R2_BUCKET"); v != "" { return v }
	return "raonson"
}

func r2PublicURL() string {
	if v := os.Getenv("CF_R2_PUBLIC_URL"); v != "" { return v }
	log.Println("[R2] CF_R2_PUBLIC_URL not set")
	return ""
}

// POST /upload
func UploadToR2(c *gin.Context) {
	const maxUploadSize = 50 << 20 // 50 MB
	c.Request.Body = http.MaxBytesReader(c.Writer, c.Request.Body, maxUploadSize)

	file, header, err := c.Request.FormFile("file")
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "No file provided"})
		return
	}
	defer file.Close()

	data, err := io.ReadAll(file)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Read failed"})
		return
	}

	contentType := header.Header.Get("Content-Type")
	if contentType == "" { contentType = detectContentType(header.Filename, data) }

	folder := "images"
	if strings.Contains(contentType, "video") { folder = "videos" }
	if strings.Contains(contentType, "audio")  { folder = "audio"  }

	ext := filepath.Ext(header.Filename)
	if ext == "" { ext = extensionFromMime(contentType) }
	key := fmt.Sprintf("%s/%s%s", folder, uuid.New().String(), ext)

	cl := getR2Client()
	cl64 := int64(len(data))
	cacheControl := "public, max-age=31536000, immutable"
	_, err = cl.PutObject(context.Background(), &s3.PutObjectInput{
		Bucket:        aws.String(r2Bucket()),
		Key:           aws.String(key),
		Body:          bytes.NewReader(data),
		ContentType:   aws.String(contentType),
		ContentLength: &cl64,
		CacheControl:  aws.String(cacheControl),
	})
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"error": fmt.Sprintf("R2 upload failed: %v", err),
		})
		return
	}

	url := r2PublicURL() + "/" + key
	c.JSON(http.StatusOK, gin.H{"url": url})
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
	case strings.Contains(mime, "mp4"):       return ".mp4"
	case strings.Contains(mime, "quicktime"): return ".mov"
	case strings.Contains(mime, "mpeg"):      return ".mp3"
	}
	return ".bin"
}
