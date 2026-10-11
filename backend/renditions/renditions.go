// Package renditions — нусхаҳои пахши адаптивии Reels (HLS) бо ffmpeg.
//
// Мисли TikTok/Instagram дар интернети суст: видео ба се сифат
// (≈240p/300 kbps, 480p/800 kbps, 720p/1.8 Mbps) бо сегментҳои 2-сонияӣ
// ва кадри калидӣ ҳар 2 сония бурида мешавад. Плеер (ExoPlayer/AVPlayer)
// худаш сифатро аз рӯи суръати интернет иваз мекунад ва видео намеистад.
//
// Илова бар ин:
//   - preview.mp4 — 2 сонияи аввал, хурд (~240p, бе садо), то лента
//     фавран чизе нишон диҳад, ҳатто пеш аз он ки HLS бор шавад;
//   - IsFaststart / Remux — MP4-е, ки moov дар охир дорад, дар
//     интернети суст пеш аз бор шудани ТАМОМИ файл сар намешавад.
//
// Ин баста танҳо бо файлҳои маҳаллӣ кор мекунад (на шабака, на база):
// боргирӣ, анбор ва навбат дар handlers/reel_renditions.go.
package renditions

import (
	"context"
	"encoding/binary"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"math"
	"os"
	"os/exec"
	"path/filepath"
	"sort"
	"strconv"
	"strings"
)

// Variant — як сифати HLS.
type Variant struct {
	Name      string // "240p" — номи папка
	Short     int    // тарафи кӯтоҳ (пиксел)
	VideoKbps int
	MaxKbps   int
	Width     int // пас аз PlanLadder пур мешавад
	Height    int
}

// DefaultLadder — зинаҳои сифат (аз паст ба баланд).
//
// Бо садои AAC 64 kbps маҷмӯъ ≈300 / 800 / 1800 kbps мешавад.
var DefaultLadder = []Variant{
	{Name: "240p", Short: 240, VideoKbps: 236, MaxKbps: 280},
	{Name: "480p", Short: 480, VideoKbps: 736, MaxKbps: 880},
	{Name: "720p", Short: 720, VideoKbps: 1736, MaxKbps: 2080},
}

const (
	AudioKbps      = 64
	SegmentSeconds = 2
	PreviewSeconds = 2
	// Ҳамаи зинаҳо дар Main@4.0 — CODECS дар master.m3u8 бояд дақиқ бошад,
	// вагарна AVPlayer метавонад зинаро рад кунад.
	codecVideo = "avc1.4d4028"
	codecAudio = "mp4a.40.2"
)

// Info — маълумоти ffprobe.
type Info struct {
	Width, Height int
	Duration      float64
	FPS           float64
	HasAudio      bool
	HasVideo      bool
}

// Options — танзими CPU. Пешфарзҳо барои 2 vCPU-и HF Space.
type Options struct {
	Threads int    // -threads (0 → 2)
	Preset  string // x264 preset ("" → veryfast)
	Nice    bool   // ffmpeg бо `nice -n 10` (API бояд ҷавобгӯ монад)
	FFmpeg  string // роҳи ffmpeg ("" → "ffmpeg")
	FFprobe string // роҳи ffprobe ("" → "ffprobe")
}

func (o Options) ffmpeg() string {
	if o.FFmpeg != "" {
		return o.FFmpeg
	}
	return "ffmpeg"
}
func (o Options) ffprobe() string {
	if o.FFprobe != "" {
		return o.FFprobe
	}
	return "ffprobe"
}
func (o Options) threads() int {
	if o.Threads <= 0 {
		return 2
	}
	return o.Threads
}
func (o Options) preset() string {
	switch o.Preset {
	case "ultrafast", "superfast", "veryfast", "faster", "fast", "medium":
		return o.Preset
	}
	return "veryfast"
}

// Available — ffmpeg ва ffprobe дар система ҳастанд?
func Available(o Options) bool {
	if _, err := exec.LookPath(o.ffmpeg()); err != nil {
		return false
	}
	_, err := exec.LookPath(o.ffprobe())
	return err == nil
}

// Result — файлҳои тайёр (роҳҳо нисбат ба outDir, бо "/").
type Result struct {
	Master   string    // "master.m3u8"
	Low      string    // "240p/index.m3u8" — пасттарин зина (Data Saver)
	Preview  string    // "preview.mp4" ё "" (агар нашуд)
	Variants []Variant // зинаҳои воқеан сохташуда
	Files    []string  // ҳамаи файлҳо барои боргузорӣ
	Info     Info
}

// ErrNoVideo — файл видео надорад (ё ffprobe онро намешиносад).
var ErrNoVideo = errors.New("renditions: no video stream")

// Probe — андоза, давомнокӣ, fps ва садо.
func Probe(ctx context.Context, o Options, path string) (Info, error) {
	out, err := exec.CommandContext(ctx, o.ffprobe(), "-v", "error",
		"-show_entries", "stream=codec_type,width,height,avg_frame_rate,r_frame_rate:format=duration",
		"-of", "json", path).Output()
	if err != nil {
		return Info{}, fmt.Errorf("ffprobe: %w", err)
	}
	var p struct {
		Streams []struct {
			CodecType    string `json:"codec_type"`
			Width        int    `json:"width"`
			Height       int    `json:"height"`
			AvgFrameRate string `json:"avg_frame_rate"`
			RFrameRate   string `json:"r_frame_rate"`
		} `json:"streams"`
		Format struct {
			Duration string `json:"duration"`
		} `json:"format"`
	}
	if err := json.Unmarshal(out, &p); err != nil {
		return Info{}, fmt.Errorf("ffprobe json: %w", err)
	}
	var in Info
	for _, s := range p.Streams {
		switch s.CodecType {
		case "video":
			if !in.HasVideo && s.Width > 0 && s.Height > 0 {
				in.HasVideo = true
				in.Width, in.Height = s.Width, s.Height
				in.FPS = parseRate(s.AvgFrameRate)
				if in.FPS <= 0 {
					in.FPS = parseRate(s.RFrameRate)
				}
			}
		case "audio":
			in.HasAudio = true
		}
	}
	in.Duration, _ = strconv.ParseFloat(p.Format.Duration, 64)
	if !in.HasVideo {
		return in, ErrNoVideo
	}
	return in, nil
}

func parseRate(s string) float64 {
	a, b, ok := strings.Cut(s, "/")
	n, err := strconv.ParseFloat(a, 64)
	if err != nil {
		return 0
	}
	if !ok {
		return n
	}
	d, err := strconv.ParseFloat(b, 64)
	if err != nil || d == 0 {
		return 0
	}
	return n / d
}

func even(v float64) int {
	n := int(math.Round(v/2)) * 2
	if n < 2 {
		n = 2
	}
	return n
}

// PlanLadder — зинаҳоро ба андозаи манбаъ мувофиқ мекунад.
//
// Видео калон карда намешавад: зинае, ки аз манбаъ (бо 10% бахшиш)
// калонтар аст, партофта мешавад. Пасттарин зина ҳамеша мемонад.
// Андозаҳо ҷуфт ва таносуби манбаъ нигоҳ дошта мешавад (амудӣ ҳам).
func PlanLadder(w, h int, ladder []Variant) []Variant {
	if w <= 0 || h <= 0 || len(ladder) == 0 {
		return nil
	}
	short := w
	if h < short {
		short = h
	}
	out := []Variant{}
	for i, v := range ladder {
		if i > 0 && float64(short) < float64(v.Short)*0.9 {
			break
		}
		target := v.Short
		if target > short {
			target = short
		}
		scale := float64(target) / float64(short)
		v.Width, v.Height = even(float64(w)*scale), even(float64(h)*scale)
		out = append(out, v)
	}
	return out
}

// MasterPlaylist — master.m3u8 (аз паст ба баланд: AVPlayer бо зинаи
// ЯКУМ сар мекунад — дар интернети суст оғози фаврӣ муҳимтар аст).
func MasterPlaylist(vs []Variant, hasAudio bool, fps float64) string {
	var b strings.Builder
	b.WriteString("#EXTM3U\n#EXT-X-VERSION:3\n#EXT-X-INDEPENDENT-SEGMENTS\n")
	codecs := codecVideo
	audio := 0
	if hasAudio {
		codecs += "," + codecAudio
		audio = AudioKbps
	}
	if fps <= 0 || fps > 30 {
		fps = 30
	}
	for _, v := range vs {
		fmt.Fprintf(&b, "#EXT-X-STREAM-INF:BANDWIDTH=%d,AVERAGE-BANDWIDTH=%d,RESOLUTION=%dx%d,FRAME-RATE=%.3f,CODECS=\"%s\"\n%s/index.m3u8\n",
			(v.MaxKbps+audio)*1100, (v.VideoKbps+audio)*1000, v.Width, v.Height, fps, codecs, v.Name)
	}
	return b.String()
}

func (o Options) command(ctx context.Context, args ...string) *exec.Cmd {
	if o.Nice {
		if nice, err := exec.LookPath("nice"); err == nil {
			return exec.CommandContext(ctx, nice, append([]string{"-n", "10", o.ffmpeg()}, args...)...)
		}
	}
	return exec.CommandContext(ctx, o.ffmpeg(), args...)
}

func run(cmd *exec.Cmd) error {
	b, err := cmd.CombinedOutput()
	if err != nil {
		msg := strings.TrimSpace(string(b))
		if len(msg) > 600 {
			msg = msg[len(msg)-600:]
		}
		return fmt.Errorf("ffmpeg: %v: %s", err, msg)
	}
	return nil
}

// Transcode — HLS (ҳамаи зинаҳо дар ЯК гузариш: видео як бор кушода
// мешавад) + preview.mp4. outDir бояд холӣ бошад.
func Transcode(ctx context.Context, o Options, in, outDir string) (*Result, error) {
	info, err := Probe(ctx, o, in)
	if err != nil {
		return nil, err
	}
	vs := PlanLadder(info.Width, info.Height, DefaultLadder)
	if len(vs) == 0 {
		return nil, ErrNoVideo
	}
	for _, v := range vs {
		if err := os.MkdirAll(filepath.Join(outDir, v.Name), 0o755); err != nil {
			return nil, err
		}
	}

	pre := ""
	if info.FPS > 31 {
		pre = "fps=30,"
	}
	var fc strings.Builder
	fmt.Fprintf(&fc, "[0:v]%ssplit=%d", pre, len(vs))
	for i := range vs {
		fmt.Fprintf(&fc, "[s%d]", i)
	}
	for i, v := range vs {
		fmt.Fprintf(&fc, ";[s%d]scale=%d:%d:flags=bilinear,setsar=1[v%d]", i, v.Width, v.Height, i)
	}

	args := []string{"-hide_banner", "-loglevel", "error", "-y", "-i", in,
		"-filter_complex", fc.String()}
	streamMap := make([]string, 0, len(vs))
	for i, v := range vs {
		args = append(args, "-map", fmt.Sprintf("[v%d]", i))
		if info.HasAudio {
			args = append(args, "-map", "0:a:0")
			streamMap = append(streamMap, fmt.Sprintf("v:%d,a:%d,name:%s", i, i, v.Name))
		} else {
			streamMap = append(streamMap, fmt.Sprintf("v:%d,name:%s", i, v.Name))
		}
	}
	args = append(args,
		"-c:v", "libx264", "-preset", o.preset(), "-profile:v", "main", "-level:v", "4.0",
		"-pix_fmt", "yuv420p", "-threads", strconv.Itoa(o.threads()),
		// Кадри калидӣ ҳар 2 сония — ҳар сегмент мустақилан сар мешавад
		// ва ивази сифат бе «шах шудан» мегузарад.
		"-force_key_frames", fmt.Sprintf("expr:gte(t,n_forced*%d)", SegmentSeconds),
		"-sc_threshold", "0")
	for i, v := range vs {
		args = append(args,
			fmt.Sprintf("-b:v:%d", i), fmt.Sprintf("%dk", v.VideoKbps),
			fmt.Sprintf("-maxrate:v:%d", i), fmt.Sprintf("%dk", v.MaxKbps),
			fmt.Sprintf("-bufsize:v:%d", i), fmt.Sprintf("%dk", v.MaxKbps*2))
	}
	if info.HasAudio {
		args = append(args, "-c:a", "aac", "-b:a", fmt.Sprintf("%dk", AudioKbps), "-ac", "2", "-ar", "44100")
	}
	args = append(args,
		"-f", "hls", "-hls_time", strconv.Itoa(SegmentSeconds), "-hls_playlist_type", "vod",
		"-hls_flags", "independent_segments", "-hls_segment_type", "mpegts",
		"-hls_segment_filename", filepath.Join(outDir, "%v", "seg_%03d.ts"),
		"-var_stream_map", strings.Join(streamMap, " "),
		filepath.Join(outDir, "%v", "index.m3u8"))
	if err := run(o.command(ctx, args...)); err != nil {
		return nil, err
	}

	if err := os.WriteFile(filepath.Join(outDir, "master.m3u8"),
		[]byte(MasterPlaylist(vs, info.HasAudio, info.FPS)), 0o644); err != nil {
		return nil, err
	}

	res := &Result{Master: "master.m3u8", Low: vs[0].Name + "/index.m3u8", Variants: vs, Info: info}
	// Preview — иловагӣ: агар нашавад, HLS бе он ҳам кор мекунад.
	if err := Preview(ctx, o, in, filepath.Join(outDir, "preview.mp4"), info); err == nil {
		res.Preview = "preview.mp4"
	}
	files, err := listFiles(outDir)
	if err != nil {
		return nil, err
	}
	res.Files = files
	for _, v := range vs {
		if !contains(files, v.Name+"/index.m3u8") || !contains(files, v.Name+"/seg_000.ts") {
			return nil, fmt.Errorf("renditions: variant %s missing", v.Name)
		}
	}
	return res, nil
}

// Preview — 2 сонияи аввал, ~240p, бе садо, +faststart (чанд даҳ КБ).
func Preview(ctx context.Context, o Options, in, out string, info Info) error {
	vs := PlanLadder(info.Width, info.Height, DefaultLadder[:1])
	if len(vs) == 0 {
		return ErrNoVideo
	}
	v := vs[0]
	return run(o.command(ctx, "-hide_banner", "-loglevel", "error", "-y",
		"-i", in, "-t", strconv.Itoa(PreviewSeconds), "-an",
		"-vf", fmt.Sprintf("fps=24,scale=%d:%d:flags=bilinear,setsar=1", v.Width, v.Height),
		"-c:v", "libx264", "-preset", o.preset(), "-profile:v", "main", "-level:v", "4.0",
		"-pix_fmt", "yuv420p", "-crf", "30", "-maxrate", "300k", "-bufsize", "600k",
		"-threads", strconv.Itoa(o.threads()),
		"-movflags", "+faststart", out))
}

// Remux — MP4-ро бе рамзгузории нав бо moov дар аввал менависад.
func Remux(ctx context.Context, o Options, in, out string) error {
	return run(o.command(ctx, "-hide_banner", "-loglevel", "error", "-y", "-i", in,
		"-map", "0", "-c", "copy", "-movflags", "+faststart", "-f", "mp4", out))
}

// IsFaststart — moov пеш аз mdat аст? Барои файли ғайри-MP4 (WebM)
// true бармегардонад: ин мафҳум ба онҳо дахл надорад.
func IsFaststart(path string) (bool, error) {
	f, err := os.Open(path)
	if err != nil {
		return false, err
	}
	defer f.Close()
	st, err := f.Stat()
	if err != nil {
		return false, err
	}
	size := st.Size()
	var off int64
	first := true
	hdr := make([]byte, 16)
	for off+8 <= size {
		if _, err := f.ReadAt(hdr[:8], off); err != nil {
			return false, err
		}
		boxSize := int64(binary.BigEndian.Uint32(hdr[:4]))
		typ := string(hdr[4:8])
		if first {
			first = false
			if typ != "ftyp" {
				return true, nil // MP4 нест
			}
		}
		switch typ {
		case "moov":
			return true, nil
		case "mdat":
			return false, nil
		}
		switch boxSize {
		case 0:
			return false, nil // қуттии охирин то EOF, moov ёфт нашуд
		case 1:
			if _, err := f.ReadAt(hdr[8:16], off+8); err != nil {
				return false, err
			}
			boxSize = int64(binary.BigEndian.Uint64(hdr[8:16]))
		}
		if boxSize < 8 {
			return false, errors.New("renditions: corrupt mp4 box")
		}
		off += boxSize
	}
	return false, io.ErrUnexpectedEOF
}

func listFiles(root string) ([]string, error) {
	var out []string
	err := filepath.Walk(root, func(p string, fi os.FileInfo, err error) error {
		if err != nil {
			return err
		}
		if fi.IsDir() {
			return nil
		}
		rel, err := filepath.Rel(root, p)
		if err != nil {
			return err
		}
		out = append(out, filepath.ToSlash(rel))
		return nil
	})
	sort.Strings(out)
	return out, err
}

func contains(xs []string, s string) bool {
	for _, x := range xs {
		if x == s {
			return true
		}
	}
	return false
}

// ContentType — навъи файл барои анбор (CDN бояд m3u8/ts-ро дуруст диҳад).
func ContentType(name string) string {
	switch strings.ToLower(filepath.Ext(name)) {
	case ".m3u8":
		return "application/vnd.apple.mpegurl"
	case ".ts":
		return "video/mp2t"
	case ".mp4":
		return "video/mp4"
	}
	return "application/octet-stream"
}
