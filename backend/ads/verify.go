package ads

// Санҷиши callback-и шабакаи реклама.
//
// Шабака (Yandex, AdMob ва ғайра) пас аз ДИДАНИ ВОҚЕИИ реклама ба
// сервери мо дархост мефиристад. Ҳамон дархост — ягона далели он, ки
// реклама воқеан дида шуд.
//
// Бе имзо ин дархостро ҳар кас сохта метавонад: кушодани терминал ва
// 1200 бор curl — галочка ройгон. Аз ин рӯ имзо ҲАТМӢ аст.
//
// Усул: HMAC-SHA256 аз сатри дархост бо сирри муштарак. Ҳамин усул
// дар Yandex S2S rewards истифода мешавад ва барои шабакаҳои дигар
// низ мувофиқ аст.

import (
	"crypto/hmac"
	"crypto/sha256"
	"encoding/hex"
	"errors"
	"os"
	"sort"
	"strconv"
	"strings"
	"time"
)

var (
	// ErrNotConfigured — сирри callback гузошта нашудааст.
	//
	// Дар ин ҳолат реклама ҳисоб НАМЕШАВАД. Ин қасдан аст: беҳтар
	// аст, ки хусусият хомӯш бошад, назар ба он ки ҳар кас галочкаро
	// ройгон гирад.
	ErrNotConfigured = errors.New("ads: сирри callback танзим нашудааст")

	// ErrBadSignature — имзо мувофиқ нест.
	ErrBadSignature = errors.New("ads: имзо нодуруст")

	// ErrStale — дархост кӯҳна аст.
	ErrStale = errors.New("ads: дархост кӯҳна")
)

// secret сирри муштаракро мегирад.
func secret() string { return os.Getenv("ADS_CALLBACK_SECRET") }

// Configured мегӯяд, ки оё ҳисоби реклама кор карда метавонад.
func Configured() bool { return secret() != "" }

// maxSkew — фарқи иҷозатшудаи вақт.
//
// Бе он дархости як бор гирифташуда абадӣ такрор мешуд. Бо он
// такрор танҳо дар доираи кӯтоҳ имконпазир аст, ва impression_id-и
// беназир онро ҳам мебандад.
const maxSkew = 10 * time.Minute

// Verify имзои callback-ро месанҷад.
//
// params — ҳамаи параметрҳои дархост ба ғайр аз худи имзо.
// Сатри имзошаванда: калидҳо аз рӯи алифбо, "k=v", бо "&" пайваст.
// Ин тартиб ҳатмист — вагарна ҳамон дархост имзои дигар медод.
func Verify(params map[string]string, signature string, now time.Time) error {
	key := secret()
	if key == "" {
		return ErrNotConfigured
	}
	if signature == "" {
		return ErrBadSignature
	}

	// Вақт: дархости кӯҳна қабул намешавад.
	ts := params["timestamp"]
	if ts == "" {
		return ErrStale
	}
	sec, err := strconv.ParseInt(ts, 10, 64)
	if err != nil {
		return ErrStale
	}
	diff := now.Sub(time.Unix(sec, 0))
	if diff < 0 {
		diff = -diff
	}
	if diff > maxSkew {
		return ErrStale
	}

	keys := make([]string, 0, len(params))
	for k := range params {
		if k == "signature" {
			continue
		}
		keys = append(keys, k)
	}
	sort.Strings(keys)

	var b strings.Builder
	for i, k := range keys {
		if i > 0 {
			b.WriteByte('&')
		}
		b.WriteString(k)
		b.WriteByte('=')
		b.WriteString(params[k])
	}

	mac := hmac.New(sha256.New, []byte(key))
	mac.Write([]byte(b.String()))
	want := mac.Sum(nil)

	got, err := hex.DecodeString(signature)
	if err != nil {
		return ErrBadSignature
	}
	// Муқоисаи доимӣ-вақт: вагарна имзоро ҳарф ба ҳарф ёфтан мумкин
	// мешуд.
	if !hmac.Equal(got, want) {
		return ErrBadSignature
	}
	return nil
}

// Sign сатри имзоро месозад.
//
// Дар сервер лозим нест — он барои ТЕСТ ва барои танзими шабака аст,
// то шакли имзо возеҳ бошад.
func Sign(params map[string]string, key string) string {
	keys := make([]string, 0, len(params))
	for k := range params {
		if k == "signature" {
			continue
		}
		keys = append(keys, k)
	}
	sort.Strings(keys)

	var b strings.Builder
	for i, k := range keys {
		if i > 0 {
			b.WriteByte('&')
		}
		b.WriteString(k)
		b.WriteByte('=')
		b.WriteString(params[k])
	}
	mac := hmac.New(sha256.New, []byte(key))
	mac.Write([]byte(b.String()))
	return hex.EncodeToString(mac.Sum(nil))
}
