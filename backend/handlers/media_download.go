package handlers

import (
	"context"
	"crypto/sha1"
	"encoding/hex"
	"errors"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"strconv"
	"strings"
	"time"

	"raonson/db"
	mw "raonson/middleware"

	"github.com/gin-gonic/gin"
)

// ══════════════════════════════════════════════════════════════════
//  Боргирӣ бо тамғаи Raonson — мисли TikTok ва Instagram.
//
//  Видео ё акси аз Raonson боргирифташуда логотип ва «@номи муаллиф»-ро
//  дорад: касе, ки онро дар WhatsApp ё Telegram мебинад, медонад, ки
//  аз куҷост ва кӣ сохтааст.
//
//  Бехатарӣ:
//    • суроғаи медиа ва номи муаллиф аз БАЗА гирифта мешаванд, на аз
//      барнома — касе наметавонад номи дигар ё суроғаи дигарро гузорад;
//    • танҳо аз анбори худамон (CF_R2_PUBLIC_URL ё MEDIA_ALLOWED_HOSTS)
//      боргирӣ мешавад — сервер ба суроғаҳои дилхоҳ дархост намекунад;
//    • ҳисоби пӯшида, блок ва сторисҳои «Дӯстони наздик» — ҳамон қоидаҳо;
//    • ҳаҷм ва вақт маҳдуд, ҳамзамон на бештар аз 2 коркард.
// ══════════════════════════════════════════════════════════════════

const (
	wmMaxBytes   = 150 << 20 // 150 МБ
	wmTimeout    = 150 * time.Second
	wmCacheTTL   = 2 * time.Hour
	wmConcurrent = 2
)

var (
	wmSlots   = make(chan struct{}, wmConcurrent)
	wmNameRe  = regexp.MustCompile(`^[a-z0-9_.]{1,30}$`)
	wmHTTP    = &http.Client{Timeout: 60 * time.Second}
	errNoMedia = errors.New("media not found")
)

// mediaHostAllowed — танҳо анбори худамон.
func mediaHostAllowed(raw string) bool {
	if onOurStorage(raw, os.Getenv("CF_R2_PUBLIC_URL")) {
		return true
	}
	u, err := url.Parse(raw)
	if err != nil || u.Host == "" {
		return false
	}
	httpOK := u.Scheme == "https" ||
		(u.Scheme == "http" && os.Getenv("MEDIA_ALLOW_HTTP") == "1" && os.Getenv("GIN_MODE") != "release")
	if !httpOK {
		return false
	}
	for _, h := range strings.Split(os.Getenv("MEDIA_ALLOWED_HOSTS"), ",") {
		if h = strings.TrimSpace(h); h != "" && strings.EqualFold(u.Host, h) {
			return true
		}
	}
	return false
}

// resolveDownload — суроға, навъ ва номи муаллиф аз база; ҳуқуқи дидан.
func resolveDownload(viewer, kind, id string, index int) (mediaURL, mediaType, owner string, err error) {
	ctx := context.Background()
	var ownerID string
	switch kind {
	case "post":
		err = db.Pool.QueryRow(ctx, `
			SELECT m.url, COALESCE(m.type,'image'), p.user_id, u.username
			FROM posts p JOIN post_media m ON m.post_id=p.id JOIN users u ON u.id=p.user_id
			WHERE p.id=$1 AND COALESCE(p.hidden,false)=FALSE
			ORDER BY m.position OFFSET $2 LIMIT 1`, id, index).
			Scan(&mediaURL, &mediaType, &ownerID, &owner)
		if err == nil {
			if ok, _ := CanSeeProfileContent(viewer, ownerID); !ok {
				err = errNoMedia
			}
		}
	case "reel":
		mediaType = "video"
		err = db.Pool.QueryRow(ctx, `
			SELECT r.video_url, r.user_id, u.username
			FROM reels r JOIN users u ON u.id=r.user_id WHERE r.id=$1`, id).
			Scan(&mediaURL, &ownerID, &owner)
		if err == nil {
			if ok, _ := CanSeeProfileContent(viewer, ownerID); !ok {
				err = errNoMedia
			}
		}
	case "story":
		if canSeeStory(viewer, id) == "" {
			return "", "", "", errNoMedia
		}
		err = db.Pool.QueryRow(ctx, `
			SELECT s.media_url, COALESCE(s.media_type,'image'), u.username
			FROM stories s JOIN users u ON u.id=s.user_id WHERE s.id=$1`, id).
			Scan(&mediaURL, &mediaType, &owner)
	default:
		return "", "", "", errNoMedia
	}
	if err != nil {
		return "", "", "", errNoMedia
	}
	if mediaType != "video" {
		mediaType = "image"
	}
	return mediaURL, mediaType, owner, nil
}

// GET /media/download?kind=post|reel|story&id=<id>&index=<n>
func DownloadWithWatermark(c *gin.Context) {
	me := mw.UID(c)
	kind := c.Query("kind")
	id := strings.TrimSpace(c.Query("id"))
	index, _ := strconv.Atoi(c.DefaultQuery("index", "0"))
	if index < 0 || index > 20 {
		index = 0
	}
	src, mtype, owner, err := resolveDownload(me, kind, id, index)
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"message": "Ёфт нашуд"})
		return
	}
	if !mediaHostAllowed(src) || !wmNameRe.MatchString(owner) {
		// Барнома файли аслиро бе тамға захира мекунад.
		c.JSON(http.StatusUnprocessableEntity, gin.H{"message": "Тамға гузошта намешавад", "url": src})
		return
	}

	ext := ".jpg"
	if mtype == "video" {
		ext = ".mp4"
	}
	sum := sha1.Sum([]byte(src + "|" + owner + "|v2"))
	cacheDir := filepath.Join(os.TempDir(), "raonson-wm")
	os.MkdirAll(cacheDir, 0o700)
	out := filepath.Join(cacheDir, hex.EncodeToString(sum[:])+ext)
	fname := fmt.Sprintf("raonson_%s_%s%s", owner, shortID(id), ext)

	if st, e := os.Stat(out); e == nil && time.Since(st.ModTime()) < wmCacheTTL && st.Size() > 0 {
		c.FileAttachment(out, fname)
		return
	}

	select {
	case wmSlots <- struct{}{}:
		defer func() { <-wmSlots }()
	case <-time.After(20 * time.Second):
		c.JSON(http.StatusServiceUnavailable, gin.H{"message": "Сервер банд аст, баъдтар боз кӯшиш кунед", "url": src})
		return
	}

	in, err := fetchToTemp(src, cacheDir)
	if err != nil {
		c.JSON(http.StatusBadGateway, gin.H{"message": "Файл бор нашуд", "url": src})
		return
	}
	defer os.Remove(in)

	if err := watermark(in, out, owner, mtype == "video"); err != nil {
		os.Remove(out)
		c.JSON(http.StatusInternalServerError, gin.H{"message": "Тамға гузошта нашуд", "url": src})
		return
	}
	c.FileAttachment(out, fname)
}

func shortID(id string) string {
	if len(id) > 8 {
		return id[:8]
	}
	return id
}

// fetchToTemp — файлро бо ҳадди ҳаҷм ба диски муваққатӣ мегирад.
func fetchToTemp(src, dir string) (string, error) {
	resp, err := wmHTTP.Get(src)
	if err != nil {
		return "", err
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return "", fmt.Errorf("status %d", resp.StatusCode)
	}
	f, err := os.CreateTemp(dir, "src-*")
	if err != nil {
		return "", err
	}
	n, err := io.Copy(f, io.LimitReader(resp.Body, wmMaxBytes+1))
	f.Close()
	if err != nil || n > wmMaxBytes {
		os.Remove(f.Name())
		return "", errors.New("too large")
	}
	return f.Name(), nil
}

// wmLogo / wmFont — дар Docker (alpine) ва Debian роҳҳо гуногунанд.
func wmLogo() string {
	for _, p := range []string{os.Getenv("WATERMARK_LOGO"), "assets/watermark_logo.png",
		"/app/assets/watermark_logo.png", "backend/assets/watermark_logo.png"} {
		if p != "" {
			if _, err := os.Stat(p); err == nil {
				return p
			}
		}
	}
	return ""
}

func wmFont() string {
	for _, p := range []string{
		"/usr/share/fonts/dejavu/DejaVuSans-Bold.ttf",
		"/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",
		"/usr/share/fonts/TTF/DejaVuSans-Bold.ttf",
	} {
		if _, err := os.Stat(p); err == nil {
			return p
		}
	}
	return ""
}

// watermarkFilter — логотип + «Raonson» + «@ном» дар кунҷи чапи поён.
// Андозаҳо аз паҳнои/баландии худи файл (ffprobe) бо рақами дақиқ, то
// тамға дар видеои амудӣ ва акси мураббаъ якхела менамояд.
func watermarkFilter(owner, font string, w, h int) string {
	short := w
	if h < short {
		short = h
	}
	logo := short * 11 / 100 // ~11% тарафи кӯтоҳ
	if logo < 28 {
		logo = 28
	}
	margin := short * 4 / 100
	big := logo * 42 / 100
	small := logo * 36 / 100
	x := margin
	y := h - margin - logo
	tx := x + logo + logo/5
	txt := func(text string, size, ty int) string {
		return fmt.Sprintf("drawtext=fontfile=%s:text='%s':fontsize=%d:fontcolor=white@0.95:"+
			"shadowcolor=black@0.6:shadowx=2:shadowy=2:x=%d:y=%d", font, text, size, tx, ty)
	}
	return fmt.Sprintf("[1:v]scale=%d:%d[lg];[0:v][lg]overlay=%d:%d,", logo, logo, x, y) +
		txt("Raonson", big, y+logo/10) + "," +
		txt("@"+owner, small, y+logo/10+big+logo/8) + "[out]"
}

// probeSize — паҳно ва баландии файл.
func probeSize(path string) (int, int) {
	ctx, cancel := context.WithTimeout(context.Background(), 20*time.Second)
	defer cancel()
	b, err := exec.CommandContext(ctx, "ffprobe", "-v", "error", "-select_streams", "v:0",
		"-show_entries", "stream=width,height", "-of", "csv=p=0:s=x", path).Output()
	if err != nil {
		return 720, 1280
	}
	var w, h int
	if _, err := fmt.Sscanf(strings.TrimSpace(string(b)), "%dx%d", &w, &h); err != nil || w <= 0 || h <= 0 {
		return 720, 1280
	}
	return w, h
}

func watermark(in, out, owner string, video bool) error {
	logo, font := wmLogo(), wmFont()
	if logo == "" || font == "" {
		return errors.New("logo or font missing")
	}
	w, h := probeSize(in)
	ctx, cancel := context.WithTimeout(context.Background(), wmTimeout)
	defer cancel()
	args := []string{"-y", "-hide_banner", "-loglevel", "error", "-i", in, "-i", logo,
		"-filter_complex", watermarkFilter(owner, font, w, h), "-map", "[out]"}
	if video {
		args = append(args, "-map", "0:a?", "-c:v", "libx264", "-preset", "veryfast",
			"-crf", "23", "-c:a", "copy", "-movflags", "+faststart", out)
	} else {
		args = append(args, "-frames:v", "1", "-q:v", "3", out)
	}
	cmd := exec.CommandContext(ctx, "ffmpeg", args...)
	if b, err := cmd.CombinedOutput(); err != nil {
		return fmt.Errorf("ffmpeg: %v: %s", err, strings.TrimSpace(string(b)))
	}
	return nil
}
