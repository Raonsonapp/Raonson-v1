package handlers

import (
	"context"
	"net/http"
	"strings"
	"unicode"

	"github.com/gin-gonic/gin"

	"raonson/db"
	mw "raonson/middleware"
)

// ══════════════════════════════════════════════════════════════════
//  Калимаҳои пинҳон (Hidden Words).
//
//  Ҳар корбар рӯйхати худро дорад. Шарҳе, ки ин калимаҳоро дорад,
//  РАД НАМЕШАВАД — он пинҳон мешавад.
//
//  ⚠️ Фарқ муҳим аст. Агар шарҳ рад мешуд, муаллифи он фавран
//  мефаҳмид ва роҳи гузаштанро меҷуст («с.а.л.о.м»). Пинҳон кардан
//  ба ӯ намефаҳмонад: ӯ шарҳи ХУДРО мебинад, вале дигарон не.
//
//  Ин аз модератсияи умумӣ фарқ мекунад: он барои ҲАМА як аст ва
//  танҳо чизи возеҳан мамнӯъро мегирад. Ин ҷо ҳар кас метавонад
//  чизеро, ки ба ӯ нохуш аст, пинҳон кунад.
// ══════════════════════════════════════════════════════════════════

const (
	maxHiddenWords    = 100
	maxHiddenWordLen  = 40
)

// GET /profile/hidden-words
func GetHiddenWords(c *gin.Context) {
	myID := mw.UID(c)
	rows, err := db.Pool.Query(c.Request.Context(),
		`SELECT word FROM hidden_words WHERE user_id=$1 ORDER BY word`, myID)
	if err != nil {
		c.JSON(http.StatusOK, gin.H{"words": []string{}})
		return
	}
	defer rows.Close()
	words := []string{}
	for rows.Next() {
		var w string
		if rows.Scan(&w) == nil {
			words = append(words, w)
		}
	}
	c.JSON(http.StatusOK, gin.H{"words": words})
}

// PUT /profile/hidden-words — рӯйхатро пурра иваз мекунад.
func SetHiddenWords(c *gin.Context) {
	myID := mw.UID(c)
	var b struct {
		Words []string `json:"words"`
	}
	if err := c.ShouldBindJSON(&b); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"message": "words required"})
		return
	}

	// Тоза кардан ва маҳдуд кардан. Бе ин як корбар метавонист
	// ҳазорҳо калима гузорад ва ҳар шарҳро суст кунад.
	seen := map[string]bool{}
	clean := []string{}
	for _, w := range b.Words {
		w = normalizeWord(w)
		if w == "" || seen[w] {
			continue
		}
		seen[w] = true
		clean = append(clean, w)
		if len(clean) >= maxHiddenWords {
			break
		}
	}

	ctx := c.Request.Context()
	tx, err := db.Pool.Begin(ctx)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"message": "Хатои сервер"})
		return
	}
	defer tx.Rollback(ctx)

	if _, err := tx.Exec(ctx,
		`DELETE FROM hidden_words WHERE user_id=$1`, myID); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"message": "Хатои сервер"})
		return
	}
	for _, w := range clean {
		tx.Exec(ctx,
			`INSERT INTO hidden_words(user_id, word) VALUES($1,$2)
			 ON CONFLICT DO NOTHING`, myID, w)
	}
	if err := tx.Commit(ctx); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"message": "Хатои сервер"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"words": clean})
}

// normalizeWord калимаро ба шакли муқоиса меорад.
func normalizeWord(w string) string {
	w = strings.ToLower(strings.TrimSpace(w))
	return clampRunes(w, maxHiddenWordLen)
}

// hiddenWordsOf рӯйхати калимаҳои корбарро мегирад.
func hiddenWordsOf(ctx context.Context, userID string) []string {
	if userID == "" {
		return nil
	}
	rows, err := db.Pool.Query(ctx,
		`SELECT word FROM hidden_words WHERE user_id=$1`, userID)
	if err != nil {
		return nil
	}
	defer rows.Close()
	out := []string{}
	for rows.Next() {
		var w string
		if rows.Scan(&w) == nil && w != "" {
			out = append(out, w)
		}
	}
	return out
}

// containsHiddenWord мегӯяд, ки оё матн ягон калимаи рӯйхатро дорад.
//
// Муқоиса бо ҳарфҳои хурд ва бо марзи КАЛИМА мешавад: «кор» набояд
// дар «корбар» мувофиқ ояд. Вагарна корбар рӯйхати оддиро мегузошт
// ва нимаи шарҳҳои беғараз пинҳон мешуданд.
//
// Агар худи калима фосила дошта бошад («хеле бад»), он ҳамчун
// ибораи пурра ҷустуҷӯ мешавад.
func containsHiddenWord(text string, words []string) bool {
	if text == "" || len(words) == 0 {
		return false
	}
	lower := strings.ToLower(text)
	for _, w := range words {
		if w == "" {
			continue
		}
		if strings.Contains(w, " ") {
			// Ибора — ҷои дилхоҳ.
			if strings.Contains(lower, w) {
				return true
			}
			continue
		}
		if hasWholeWord(lower, w) {
			return true
		}
	}
	return false
}

// hasWholeWord калимаро бо марзи калима меҷӯяд.
func hasWholeWord(text, word string) bool {
	runes := []rune(text)
	wordRunes := []rune(word)
	n, m := len(runes), len(wordRunes)
	if m == 0 || m > n {
		return false
	}
	for i := 0; i+m <= n; i++ {
		if string(runes[i:i+m]) != word {
			continue
		}
		// Пеш ва пас аз калима бояд ҳарф набошад.
		if i > 0 && isWordRune(runes[i-1]) {
			continue
		}
		if i+m < n && isWordRune(runes[i+m]) {
			continue
		}
		return true
	}
	return false
}

func isWordRune(r rune) bool {
	return unicode.IsLetter(r) || unicode.IsDigit(r)
}
