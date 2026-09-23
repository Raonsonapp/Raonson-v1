package handlers

import (
	"context"
	"log"
	"net/http"
	"net/url"
	"strings"
	"sync"
	"time"

	"raonson/db"
	mw "raonson/middleware"

	"github.com/gin-gonic/gin"
)

// ══════════════════════════════════════════════════════════════════
//  POST /reels/:id/media-check
//
//  Шикояти корбар: «видеоҳое ки удалит кардаги ва дар барнома
//  нишон намедиҳад, аз барнома наистад — удалит шавад хубтар аст».
//
//  Дар explore плиткаҳои «видео кушода нашуд» мемонданд — бо
//  шумораи тамошо (3, 111), вале бе видео. Сатр дар база буд, файл
//  дар анбор НЕ. Ҳеҷ кас инро намедонист, ва плитка то абад мемонд.
//
//  Ҳоло: вақте телефон видеоро кушода наметавонад, он СЕРВЕРРО
//  огоҳ мекунад. Сервер ба ТЕЛЕФОН бовар НАМЕКУНАД — худаш месанҷад:
//
//    • танҳо суроғаи сабтшуда дар БАЗА (на он чи телефон мефиристад);
//    • танҳо агар он дар АНБОРИ ХУДИ МО бошад (CF_R2_PUBLIC_URL).
//      Суроғаи видео дар вақти сохтан аз корбар омада буд — бе ин
//      шарт сервер метавонист ба суроғаи дохилӣ дархост фиристад
//      (SSRF);
//    • танҳо 404/410 «нест» ҳисоб мешавад. 403, 5xx, timeout —
//      «номаълум», ва ҳеҷ чиз намешавад;
//    • ҳар reel ҳадди аксар як бор дар 10 дақиқа санҷида мешавад.
//
//  Reel нест карда НАМЕШАВАД — `media_missing` мегирад ва аз ҳамаи
//  рӯйхатҳо пинҳон мешавад. Агар анбор муваққатан хато дода бошад,
//  баргардонидан мумкин аст.
// ══════════════════════════════════════════════════════════════════

var (
	mediaCheckMu   sync.Mutex
	mediaCheckSeen = map[string]time.Time{}
)

const mediaCheckEvery = 10 * time.Minute

// mediaCheckClient редиректро пайгирӣ НАМЕКУНАД: вагарна анбор
// метавонист сервери моро ба ҷои дигар фиристад.
var mediaCheckClient = &http.Client{
	Timeout: 8 * time.Second,
	CheckRedirect: func(*http.Request, []*http.Request) error {
		return http.ErrUseLastResponse
	},
}

// onOurStorage — суроға дар анбори ХУДИ МО аст?
func onOurStorage(raw, publicBase string) bool {
	if publicBase == "" || raw == "" {
		return false
	}
	u, err := url.Parse(raw)
	if err != nil || u.Scheme != "https" || u.Host == "" {
		return false
	}
	base, err := url.Parse(publicBase)
	if err != nil || base.Host == "" {
		return false
	}
	return strings.EqualFold(u.Host, base.Host)
}

// mediaGone — анбор возеҳ гуфт «нест»?
//
// Танҳо 404 ва 410. Ҳар ҷавоби дигар — «намедонам».
func mediaGone(status int) bool {
	return status == http.StatusNotFound || status == http.StatusGone
}

// probeMedia ҳолати файлро мегирад. 0 = санҷида нашуд.
func probeMedia(ctx context.Context, raw string) int {
	req, err := http.NewRequestWithContext(ctx, http.MethodHead, raw, nil)
	if err != nil {
		return 0
	}
	res, err := mediaCheckClient.Do(req)
	if err != nil {
		return 0
	}
	res.Body.Close()
	return res.StatusCode
}

// mediaCheckDue — вақти санҷиши ин reel расид? (ва онро қайд мекунад)
func mediaCheckDue(id string, now time.Time) bool {
	mediaCheckMu.Lock()
	defer mediaCheckMu.Unlock()
	if t, ok := mediaCheckSeen[id]; ok && now.Sub(t) < mediaCheckEvery {
		return false
	}
	mediaCheckSeen[id] = now
	// Харитаро хурд нигоҳ медорем.
	if len(mediaCheckSeen) > 5000 {
		for k, t := range mediaCheckSeen {
			if now.Sub(t) >= mediaCheckEvery {
				delete(mediaCheckSeen, k)
			}
		}
	}
	return true
}

func CheckReelMedia(c *gin.Context) {
	rid := c.Param("id")
	if rid == "" {
		c.JSON(http.StatusBadRequest, gin.H{"message": "id лозим"})
		return
	}
	if !mediaCheckDue(rid, time.Now()) {
		c.JSON(http.StatusOK, gin.H{"checked": false, "missing": false})
		return
	}

	var videoURL, ownerID string
	err := db.Pool.QueryRow(context.Background(),
		`SELECT COALESCE(video_url,''), user_id FROM reels WHERE id=$1`,
		rid).Scan(&videoURL, &ownerID)
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"message": "Reel not found"})
		return
	}
	if !onOurStorage(videoURL, r2PublicURL()) {
		// Анбори бегона — ба он дархост намефиристем.
		c.JSON(http.StatusOK, gin.H{"checked": false, "missing": false})
		return
	}

	ctx, cancel := context.WithTimeout(c.Request.Context(), 9*time.Second)
	defer cancel()
	status := probeMedia(ctx, videoURL)
	if !mediaGone(status) {
		c.JSON(http.StatusOK, gin.H{"checked": true, "missing": false})
		return
	}

	db.Pool.Exec(context.Background(),
		`UPDATE reels SET media_missing=TRUE WHERE id=$1`, rid)
	log.Printf("[media-check] reel %s: файл дар анбор нест (HTTP %d) — пинҳон шуд",
		rid, status)
	mw.InvalidateUserCache(ownerID)
	mw.BumpContentEpoch()
	c.JSON(http.StatusOK, gin.H{"checked": true, "missing": true})
}
