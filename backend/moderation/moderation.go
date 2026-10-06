// Package moderation — санҷиши мӯҳтаво ПЕШ аз нашр.
//
// Raonson барномаи оилавист: мӯҳтавои 18+, порнография, урёнӣ ва
// дашноми қабеҳ дар ҳеҷ ҷо — пост, Reel, сторис, шарҳ, паём, bio ва
// линкҳо — набояд нашр шавад.
//
// Як даромадгоҳ: Check(ctx, Item) → Verdict{Allow|Review|Block}.
//
//	Матн   — рӯйхати калимаҳо (data/keywords.txt) бо нормализатсия
//	         (leet, фосила, ҳарфҳои ҳамшакл) + ихтиёрӣ AI (utils.ModerateText).
//	Расм   — classifier-и NSFW аз env: Hugging Face, Sightengine ё
//	         OpenAI omni-moderation. Бе provider — «санҷиданашуда».
//	Видео  — чанд кадр бо ffmpeg (1с, 25%, 50%, 75%) → санҷиши расм.
//	Линк   — рӯйхати доменҳои 18+ (data/adult_domains.txt) + эвристика
//	         + ихтиёрӣ Google Safe Browsing.
//
// Сервер ҳеҷ гоҳ ба суроғаи дилхоҳ дархост намефиристад: медиа танҳо
// аз анбори худи мо (SetMediaFetchAllowed) гирифта мешавад, линкҳо
// умуман кушода намешаванд.
//
// Ин пакет ба база даст намерасонад — сабти strike, навбати admin ва
// маҳдудкунӣ дар handlers/moderation.go аст.
package moderation

import (
	"context"
	"log"
	"os"
	"sort"
	"strconv"
	"strings"
	"sync"
	"time"
)

// Kind — навъи мӯҳтаво.
type Kind string

const (
	KindText  Kind = "text"
	KindImage Kind = "image"
	KindVideo Kind = "video"
	KindLink  Kind = "link"
)

// Action — қарор.
type Action int

const (
	Allow Action = iota
	Review
	Block
)

func (a Action) String() string {
	switch a {
	case Block:
		return "block"
	case Review:
		return "review"
	}
	return "allow"
}

// Категорияҳо.
const (
	CatSexual     = "sexual"
	CatMinors     = "minors"
	CatProfanity  = "profanity"
	CatSuggestive = "suggestive"
	CatNudity     = "nudity"
	CatAdultLink  = "adult_link"
	CatMalicious  = "malicious_link"
	CatUnscanned  = "unscanned"
	CatUncertain  = "uncertain"
)

// Item — як порчаи мӯҳтаво.
type Item struct {
	Kind Kind
	// Text — барои KindText (линкҳо худкор аз матн гирифта мешаванд).
	Text string
	// URL — барои KindImage/KindVideo/KindLink.
	URL string
	// Data — байтҳои расм/видео, агар аллакай дар хотира бошанд
	// (ҳангоми боргузорӣ). Он гоҳ URL лозим нест.
	Data []byte
	// AI — оё матн ба provider-и AI ҳам фиристода шавад (суст ва
	// пулакӣ — барои мӯҳтавои оммавӣ, на барои ҳар паёми чат).
	AI bool
}

// Verdict — натиҷа.
type Verdict struct {
	Action     Action
	Categories []string
	// Score — 0..1, баландтарин холи classifier (барои матн 1 ҳангоми
	// мувофиқат).
	Score float64
	// Severe — кӯдакон: фавран маҳдудкунӣ ва санҷиши admin.
	Severe bool
	// Unscanned — provider-и медиа танзим нашудааст (ё ffmpeg нест):
	// мӯҳтаво иҷозат дода мешавад, вале ба навбати admin меравад.
	Unscanned bool
	// Provider — кадом қабат қарор дод (keywords, links, hf, ...).
	Provider string
	// Reason — шарҳи кӯтоҳ барои log ва admin (ҳеҷ гоҳ калид надорад).
	Reason string
	// MediaCaused — қарор аз худи медиа аст (на аз матн).
	MediaCaused bool
}

// Allowed — ҳеҷ чиз ёфт нашуд.
func (v Verdict) Allowed() bool { return v.Action == Allow }

// Strikeable — оё ин манъ ба ҳисоби огоҳиҳо (strike) меравад?
//
// Танҳо 18+ ва кӯдакон. Дашном ва линки зараровар рад мешаванд, вале
// ҳисобро маҳдуд намекунанд — бастани ҳисоб барои як калимаи қабеҳ
// аз ҳад сахт аст.
func (v Verdict) Strikeable() bool {
	if v.Action != Block {
		return false
	}
	if v.Severe {
		return true
	}
	for _, c := range v.Categories {
		switch c {
		case CatSexual, CatMinors, CatNudity, CatAdultLink:
			return true
		}
	}
	return false
}

// ── танзимот ──────────────────────────────────────────────────────

func envFloat(key string, def float64) float64 {
	if v := strings.TrimSpace(os.Getenv(key)); v != "" {
		if f, err := strconv.ParseFloat(v, 64); err == nil && f > 0 && f <= 1 {
			return f
		}
	}
	return def
}

func envInt(key string, def int) int {
	if v := strings.TrimSpace(os.Getenv(key)); v != "" {
		if n, err := strconv.Atoi(v); err == nil && n > 0 {
			return n
		}
	}
	return def
}

// BlockThreshold — аз ин хол боло расм BLOCK мешавад.
func BlockThreshold() float64 { return envFloat("MODERATION_BLOCK_THRESHOLD", 0.85) }

// ReviewThreshold — аз ин хол боло (то BlockThreshold) — REVIEW.
func ReviewThreshold() float64 { return envFloat("MODERATION_REVIEW_THRESHOLD", 0.5) }

// ── дастрасии медиа (SSRF) ─────────────────────────────────────────

var (
	fetchMu      sync.RWMutex
	fetchAllowed = func(string) bool { return false }
)

// SetMediaFetchAllowed — функсияе, ки мегӯяд суроға дар анбори ХУДИ
// МО аст (handlers.mediaHostAllowed). Бе он сервер ҳеҷ медиаро
// намегирад.
func SetMediaFetchAllowed(f func(string) bool) {
	if f == nil {
		return
	}
	fetchMu.Lock()
	fetchAllowed = f
	fetchMu.Unlock()
}

// MediaFetchAllowed — суроға гирифта шуданаш мумкин аст?
func MediaFetchAllowed(raw string) bool {
	fetchMu.RLock()
	f := fetchAllowed
	fetchMu.RUnlock()
	return f(raw)
}

// ── даромадгоҳ ────────────────────────────────────────────────────

// Check — як порчаро месанҷад.
func Check(ctx context.Context, it Item) Verdict {
	switch it.Kind {
	case KindText:
		return checkText(ctx, it.Text, it.AI)
	case KindLink:
		return CheckLinkURL(ctx, it.URL)
	case KindImage:
		if len(it.Data) > 0 {
			return CheckImageBytes(ctx, it.Data)
		}
		return CheckImageURL(ctx, it.URL)
	case KindVideo:
		if len(it.Data) > 0 {
			return CheckVideoBytes(ctx, it.Data)
		}
		return CheckVideoURL(ctx, it.URL)
	}
	return Verdict{Action: Allow}
}

// CheckAll — ҳамаро месанҷад ва қарори сахттаринро бармегардонад.
// Матн пеш аз медиа (арзон аст); BLOCK-и аввал корро қатъ мекунад.
func CheckAll(ctx context.Context, items ...Item) Verdict {
	sorted := make([]Item, len(items))
	copy(sorted, items)
	sort.SliceStable(sorted, func(i, j int) bool {
		return kindCost(sorted[i].Kind) < kindCost(sorted[j].Kind)
	})
	out := Verdict{Action: Allow}
	for _, it := range sorted {
		v := Check(ctx, it)
		out = Merge(out, v)
		if out.Action == Block {
			break
		}
	}
	return out
}

func kindCost(k Kind) int {
	switch k {
	case KindText, KindLink:
		return 0
	case KindImage:
		return 1
	}
	return 2
}

// Merge — ду қарорро якҷоя мекунад (сахттарин ғолиб).
func Merge(a, b Verdict) Verdict {
	if b.Action > a.Action {
		b.Categories = mergeCats(b.Categories, a.Categories)
		b.Severe = b.Severe || a.Severe
		if a.Score > b.Score {
			b.Score = a.Score
		}
		return b
	}
	if b.Action == a.Action {
		a.Categories = mergeCats(a.Categories, b.Categories)
		a.Severe = a.Severe || b.Severe
		// Ду REVIEW: агар яке «шубҳанок» бошад (на танҳо
		// «санҷиданашуда»), натиҷа шубҳанок аст — пинҳон мемонад.
		a.Unscanned = a.Unscanned && b.Unscanned
		if b.Score > a.Score {
			a.Score = b.Score
		}
		a.MediaCaused = a.MediaCaused || b.MediaCaused
		if a.Provider == "" {
			a.Provider, a.Reason = b.Provider, b.Reason
		}
		return a
	}
	a.Severe = a.Severe || b.Severe
	return a
}

func mergeCats(a, b []string) []string {
	seen := map[string]bool{}
	out := []string{}
	for _, list := range [][]string{a, b} {
		for _, c := range list {
			if c != "" && !seen[c] {
				seen[c] = true
				out = append(out, c)
			}
		}
	}
	return out
}

// ── ҳолати provider-ҳо (барои /health ва log) ──────────────────────

// Status — кадом қабатҳо фаъоланд (танҳо ҲА/НЕ ва ном, бе калид).
type Status struct {
	Keywords      int    `json:"keywords"`
	AdultDomains  int    `json:"adultDomains"`
	ImageProvider string `json:"imageProvider"`
	VideoFrames   bool   `json:"videoFrames"`
	SafeBrowsing  bool   `json:"safeBrowsing"`
}

// CurrentStatus — ҳолати ҷорӣ.
func CurrentStatus() Status {
	p := imageProvider()
	name := ""
	if p != nil {
		name = p.Name()
	}
	return Status{
		Keywords:      len(keywordRules()),
		AdultDomains:  len(adultDomains()),
		ImageProvider: name,
		VideoFrames:   p != nil && ffmpegAvailable(),
		SafeBrowsing:  strings.TrimSpace(os.Getenv("SAFE_BROWSING_KEY")) != "",
	}
}

var logOnce sync.Once

// LogStartup — як бор дар log мегӯяд, ки чӣ кор мекунад ва чӣ не.
func LogStartup() {
	logOnce.Do(func() {
		s := CurrentStatus()
		log.Printf("[moderation] калимаҳо: %d, доменҳои 18+: %d", s.Keywords, s.AdultDomains)
		if s.ImageProvider == "" {
			log.Printf("[moderation] ⚠️ provider-и расм танзим НАШУДААСТ (MODERATION_IMAGE_URL/HF_TOKEN, " +
				"SIGHTENGINE_USER+SIGHTENGINE_SECRET ё OPENAI_API_KEY) — расм ва видео САНҶИДА НАМЕШАВАНД: " +
				"иҷозат дода мешаванд ва ба навбати admin («санҷиданашуда») мераванд")
		} else {
			log.Printf("[moderation] provider-и расм: %s; кадрҳои видео: %v", s.ImageProvider, s.VideoFrames)
		}
		if !s.SafeBrowsing {
			log.Printf("[moderation] Google Safe Browsing хомӯш (SAFE_BROWSING_KEY нест) — танҳо рӯйхати доменҳо")
		}
	})
}

// timeoutCtx — контекст бо ҳадди вақт (агар волид кӯтоҳтар набошад).
func timeoutCtx(ctx context.Context, d time.Duration) (context.Context, context.CancelFunc) {
	if dl, ok := ctx.Deadline(); ok && time.Until(dl) < d {
		return context.WithCancel(ctx)
	}
	return context.WithTimeout(ctx, d)
}
