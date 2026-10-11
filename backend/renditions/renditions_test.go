package renditions

import (
	"context"
	"os"
	"os/exec"
	"path/filepath"
	"strconv"
	"strings"
	"testing"
	"time"
)

func needFFmpeg(t *testing.T) Options {
	t.Helper()
	o := Options{Threads: 2, Preset: "ultrafast"}
	if !Available(o) {
		t.Skip("ffmpeg/ffprobe нест — тест гузаронида шуд")
	}
	return o
}

// makeVideo — видеои санҷишии 3-сонияӣ (амудӣ, бо садо), moov дар охир.
func makeVideo(t *testing.T, dir string, w, h int, audio bool) string {
	t.Helper()
	out := filepath.Join(dir, "src.mp4")
	args := []string{"-hide_banner", "-loglevel", "error", "-y",
		"-f", "lavfi", "-i", "testsrc2=size=" + strconv.Itoa(w) + "x" + strconv.Itoa(h) + ":rate=30:duration=3"}
	if audio {
		args = append(args, "-f", "lavfi", "-i", "sine=frequency=440:duration=3")
	}
	args = append(args, "-c:v", "libx264", "-preset", "ultrafast", "-pix_fmt", "yuv420p")
	if audio {
		args = append(args, "-c:a", "aac", "-shortest")
	}
	args = append(args, out) // бе +faststart — moov дар охир
	if b, err := exec.Command("ffmpeg", args...).CombinedOutput(); err != nil {
		t.Fatalf("ffmpeg testsrc: %v %s", err, b)
	}
	return out
}

func TestPlanLadderPortraitNoUpscale(t *testing.T) {
	vs := PlanLadder(720, 1280, DefaultLadder)
	if len(vs) != 3 {
		t.Fatalf("want 3 variants, got %d", len(vs))
	}
	want := [][2]int{{240, 426}, {480, 854}, {720, 1280}}
	for i, v := range vs {
		if v.Width != want[i][0] || v.Height != want[i][1] {
			t.Errorf("%s: got %dx%d want %v", v.Name, v.Width, v.Height, want[i])
		}
		if v.Width%2 != 0 || v.Height%2 != 0 {
			t.Errorf("%s: odd size", v.Name)
		}
	}
	// 360p манбаъ: танҳо 240p (480p калон кардан мешуд).
	vs = PlanLadder(360, 640, DefaultLadder)
	if len(vs) != 1 || vs[0].Name != "240p" {
		t.Fatalf("360p source → %v", vs)
	}
	// Манбаи хеле хурд: пасттарин зина бо андозаи худи манбаъ.
	vs = PlanLadder(160, 284, DefaultLadder)
	if len(vs) != 1 || vs[0].Width != 160 || vs[0].Height != 284 {
		t.Fatalf("tiny source → %+v", vs)
	}
	// Уфуқӣ 1920x1080 → тарафи кӯтоҳ баландӣ аст.
	vs = PlanLadder(1920, 1080, DefaultLadder)
	if len(vs) != 3 || vs[2].Height != 720 || vs[2].Width != 1280 {
		t.Fatalf("landscape → %+v", vs)
	}
}

func TestMasterPlaylistOrderAndCodecs(t *testing.T) {
	m := MasterPlaylist(PlanLadder(720, 1280, DefaultLadder), true, 60)
	if !strings.HasPrefix(m, "#EXTM3U\n") || strings.Count(m, "#EXT-X-STREAM-INF") != 3 {
		t.Fatalf("bad master:\n%s", m)
	}
	if strings.Index(m, "240p/index.m3u8") > strings.Index(m, "720p/index.m3u8") {
		t.Fatal("lowest variant must be first (fast start)")
	}
	if !strings.Contains(m, `CODECS="avc1.4d4028,mp4a.40.2"`) || !strings.Contains(m, "FRAME-RATE=30.000") {
		t.Fatalf("codecs/fps:\n%s", m)
	}
	if strings.Contains(MasterPlaylist(PlanLadder(720, 1280, DefaultLadder), false, 30), "mp4a") {
		t.Fatal("no audio → no mp4a codec")
	}
}

func TestTranscodeProducesMasterVariantsPreview(t *testing.T) {
	o := needFFmpeg(t)
	dir := t.TempDir()
	src := makeVideo(t, dir, 720, 1280, true)
	out := filepath.Join(dir, "out")
	ctx, cancel := context.WithTimeout(context.Background(), 3*time.Minute)
	defer cancel()
	res, err := Transcode(ctx, o, src, out)
	if err != nil {
		t.Fatalf("Transcode: %v", err)
	}
	if res.Master != "master.m3u8" || res.Low != "240p/index.m3u8" || res.Preview != "preview.mp4" {
		t.Fatalf("result: %+v", res)
	}
	master, _ := os.ReadFile(filepath.Join(out, "master.m3u8"))
	if strings.Count(string(master), "#EXT-X-STREAM-INF") != 3 {
		t.Fatalf("master:\n%s", master)
	}
	for _, v := range []string{"240p", "480p", "720p"} {
		pl, err := os.ReadFile(filepath.Join(out, v, "index.m3u8"))
		if err != nil {
			t.Fatalf("%s playlist: %v", v, err)
		}
		s := string(pl)
		if !strings.Contains(s, "#EXT-X-PLAYLIST-TYPE:VOD") || !strings.Contains(s, "#EXT-X-ENDLIST") {
			t.Errorf("%s: not VOD:\n%s", v, s)
		}
		// 3 сония / сегментҳои 2-сонияӣ → 2 сегмент, ҳеҷ кадом > 2.1 с.
		if n := strings.Count(s, ".ts"); n < 2 {
			t.Errorf("%s: want ≥2 segments, got %d", v, n)
		}
		if strings.Contains(s, "#EXT-X-TARGETDURATION:") &&
			!strings.Contains(s, "#EXT-X-TARGETDURATION:2") {
			t.Errorf("%s: target duration not 2s:\n%s", v, s)
		}
		info, err := Probe(ctx, o, filepath.Join(out, v, "seg_000.ts"))
		if err != nil {
			t.Fatalf("%s probe: %v", v, err)
		}
		if !info.HasAudio {
			t.Errorf("%s: audio missing", v)
		}
		short := info.Width
		if info.Height < short {
			short = info.Height
		}
		if v[:3] != strconv.Itoa(short) {
			t.Errorf("%s: short side %d", v, short)
		}
	}
	pi, err := Probe(ctx, o, filepath.Join(out, "preview.mp4"))
	if err != nil || pi.HasAudio || pi.Duration > 2.2 || pi.Width != 240 {
		t.Fatalf("preview: %+v %v", pi, err)
	}
	if fs, _ := IsFaststart(filepath.Join(out, "preview.mp4")); !fs {
		t.Error("preview must be faststart")
	}
	if st, _ := os.Stat(filepath.Join(out, "preview.mp4")); st == nil || st.Size() > 200<<10 {
		t.Errorf("preview too big: %v", st)
	}
	if len(res.Files) < 1+3*3+1 {
		t.Errorf("files: %v", res.Files)
	}
}

func TestTranscodeWithoutAudio(t *testing.T) {
	o := needFFmpeg(t)
	dir := t.TempDir()
	src := makeVideo(t, dir, 480, 854, false)
	res, err := Transcode(context.Background(), o, src, filepath.Join(dir, "out"))
	if err != nil {
		t.Fatalf("Transcode: %v", err)
	}
	if len(res.Variants) != 2 {
		t.Fatalf("480p source → 2 variants, got %d", len(res.Variants))
	}
	m, _ := os.ReadFile(filepath.Join(dir, "out", "master.m3u8"))
	if strings.Contains(string(m), "mp4a") {
		t.Fatal("no-audio master lists mp4a")
	}
}

func TestFaststartDetectAndRemux(t *testing.T) {
	o := needFFmpeg(t)
	dir := t.TempDir()
	src := makeVideo(t, dir, 320, 568, true)
	fs, err := IsFaststart(src)
	if err != nil || fs {
		t.Fatalf("plain ffmpeg mp4 should have moov at end: fs=%v err=%v", fs, err)
	}
	out := filepath.Join(dir, "fast.mp4")
	if err := Remux(context.Background(), o, src, out); err != nil {
		t.Fatal(err)
	}
	if fs, err := IsFaststart(out); err != nil || !fs {
		t.Fatalf("remuxed: fs=%v err=%v", fs, err)
	}
	// Файли ғайри-MP4 — «мафҳум дахл надорад».
	junk := filepath.Join(dir, "x.webm")
	os.WriteFile(junk, []byte("\x1a\x45\xdf\xa3 webm header padding"), 0o644)
	if fs, err := IsFaststart(junk); err != nil || !fs {
		t.Fatalf("non-mp4: fs=%v err=%v", fs, err)
	}
}

func TestProbeRejectsNonVideo(t *testing.T) {
	o := needFFmpeg(t)
	p := filepath.Join(t.TempDir(), "a.txt")
	os.WriteFile(p, []byte("hello"), 0o644)
	if _, err := Probe(context.Background(), o, p); err == nil {
		t.Fatal("text file accepted as video")
	}
}

func TestContentType(t *testing.T) {
	for in, want := range map[string]string{
		"master.m3u8": "application/vnd.apple.mpegurl", "240p/seg_000.ts": "video/mp2t",
		"preview.mp4": "video/mp4", "x.bin": "application/octet-stream"} {
		if got := ContentType(in); got != want {
			t.Errorf("%s: %s", in, got)
		}
	}
}
