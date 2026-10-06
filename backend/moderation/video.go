package moderation

import (
	"context"
	"errors"
	"fmt"
	"io"
	"log"
	"math"
	"os"
	"os/exec"
	"strconv"
	"strings"
	"sync"
	"time"
)

// Видео: чанд кадр (1с, 25%, 50%, 75%) бо ffmpeg → санҷиши расм.
//
// ffmpeg дар Docker-и сервер ҳаст (барои тамғаи Raonson дар
// media_download.go). Агар набошад, видео «санҷиданашуда» мемонад.

var (
	ffOnce sync.Once
	ffOK   bool
)

func ffmpegAvailable() bool {
	ffOnce.Do(func() {
		_, e1 := exec.LookPath("ffmpeg")
		_, e2 := exec.LookPath("ffprobe")
		ffOK = e1 == nil && e2 == nil
	})
	return ffOK
}

func maxVideoBytes() int64 { return int64(envInt("MODERATION_VIDEO_MAX_MB", 100)) << 20 }

func videoTimeout() time.Duration {
	return time.Duration(envInt("MODERATION_VIDEO_TIMEOUT_SECONDS", 45)) * time.Second
}

// CheckVideoURL — видео аз анбори худи мо.
func CheckVideoURL(ctx context.Context, raw string) Verdict {
	p := imageProvider()
	if p == nil {
		return unscanned("no_image_provider")
	}
	if strings.TrimSpace(raw) == "" {
		return Verdict{Action: Allow}
	}
	if !ffmpegAvailable() {
		log.Printf("[moderation] ffmpeg нест — видео санҷида намешавад")
		return unscanned("no_ffmpeg")
	}
	cctx, cancel := timeoutCtx(ctx, videoTimeout())
	defer cancel()
	path, err := fetchToTemp(cctx, raw, maxVideoBytes())
	if err != nil {
		if errors.Is(err, errForeignHost) {
			return uncertain(p.Name(), "foreign_host", 0)
		}
		log.Printf("[moderation] видео гирифта нашуд: %v", err)
		return uncertain(p.Name(), "fetch_failed", 0)
	}
	defer os.Remove(path)
	return checkVideoFile(cctx, p, path)
}

// CheckVideoBytes — видео дар хотира (ҳангоми боргузорӣ).
func CheckVideoBytes(ctx context.Context, data []byte) Verdict {
	p := imageProvider()
	if p == nil {
		return unscanned("no_image_provider")
	}
	if !ffmpegAvailable() {
		return unscanned("no_ffmpeg")
	}
	f, err := os.CreateTemp("", "rmod-*.bin")
	if err != nil {
		return uncertain(p.Name(), "tempfile", 0)
	}
	defer os.Remove(f.Name())
	_, err = f.Write(data)
	f.Close()
	if err != nil {
		return uncertain(p.Name(), "tempfile", 0)
	}
	cctx, cancel := timeoutCtx(ctx, videoTimeout())
	defer cancel()
	return checkVideoFile(cctx, p, f.Name())
}

func fetchToTemp(ctx context.Context, raw string, max int64) (string, error) {
	resp, err := openMedia(ctx, raw)
	if err != nil {
		return "", err
	}
	defer resp.Body.Close()
	f, err := os.CreateTemp("", "rmod-*.bin")
	if err != nil {
		return "", err
	}
	n, err := io.Copy(f, io.LimitReader(resp.Body, max+1))
	f.Close()
	if err != nil || n > max {
		os.Remove(f.Name())
		if err == nil {
			err = errors.New("too large")
		}
		return "", err
	}
	return f.Name(), nil
}

// FrameTimes — лаҳзаҳои кадрҳо: ~1с, 25%, 50%, 75% (бе такрор).
func FrameTimes(duration float64) []float64 {
	if duration <= 0 || math.IsNaN(duration) {
		return []float64{0, 1}
	}
	cands := []float64{1, duration * 0.25, duration * 0.5, duration * 0.75}
	out := []float64{}
	seen := map[int]bool{}
	for _, t := range cands {
		if t >= duration {
			t = duration / 2
		}
		if t < 0 {
			t = 0
		}
		k := int(math.Round(t * 4)) // 0.25с дақиқӣ
		if seen[k] {
			continue
		}
		seen[k] = true
		out = append(out, t)
	}
	return out
}

func probeDuration(ctx context.Context, path string) float64 {
	b, err := exec.CommandContext(ctx, "ffprobe", "-v", "error",
		"-protocol_whitelist", "file",
		"-show_entries", "format=duration", "-of", "csv=p=0", path).Output()
	if err != nil {
		return 0
	}
	d, err := strconv.ParseFloat(strings.TrimSpace(string(b)), 64)
	if err != nil {
		return 0
	}
	return d
}

// extractFrame — як кадр ҳамчун JPEG (то 640px).
func extractFrame(ctx context.Context, path string, at float64) ([]byte, error) {
	cmd := exec.CommandContext(ctx, "ffmpeg", "-nostdin", "-hide_banner", "-loglevel", "error",
		"-protocol_whitelist", "file,pipe",
		"-ss", fmt.Sprintf("%.2f", at), "-i", path,
		"-frames:v", "1", "-vf", "scale='min(640,iw)':-2",
		"-f", "image2", "-c:v", "mjpeg", "-q:v", "4", "pipe:1")
	out, err := cmd.Output()
	if err != nil {
		return nil, err
	}
	if len(out) == 0 {
		return nil, errors.New("empty frame")
	}
	return out, nil
}

func checkVideoFile(ctx context.Context, p ImageProvider, path string) Verdict {
	times := FrameTimes(probeDuration(ctx, path))
	v := Verdict{Action: Allow, Provider: p.Name(), MediaCaused: true}
	got := 0
	for _, t := range times {
		frame, err := extractFrame(ctx, path, t)
		if err != nil {
			continue
		}
		got++
		fv := classify(ctx, p, frame)
		if fv.Action != Allow {
			fv.Reason = fmt.Sprintf("frame@%.1fs %s", t, fv.Reason)
		}
		v = Merge(v, fv)
		if v.Action == Block {
			return v
		}
	}
	if got == 0 {
		return uncertain(p.Name(), "no_frames", 0)
	}
	return v
}
