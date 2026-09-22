package handlers

// Тасдиқи почтаи электронӣ.
//
// ── Чаро ин файл пайдо шуд ───────────────────────────────────────
//
// Дар барнома ду экран буданд — `EmailVerifyScreen` ва
// `OtpVerifyScreen`. Онҳо ба `/auth/verify-email` ва
// `/auth/verify-otp` муроҷиат мекарданд.
//
// Ин ду роҳ дар сервер ВУҶУД НАДОШТАНД.
//
// Яъне экранҳо қолиби холӣ буданд: тугма зер мешуд, дархост мерафт,
// 404 бармегашт. Барои ҳамин онҳоро ба меню набароварда буданд — ва
// дар натиҷа барнома тасдиқи почта умуман надошт.
//
// Ин ҷо ҳамон ду роҳ сохта мешавад. Нақша ҳамон нақшаи
// `SendPhoneOTP`/`VerifyPhoneOTP` аст, то як сохт бошад.

import (
	"context"
	"fmt"
	"log"
	"math/rand"
	"net/http"
	"os"
	"regexp"
	"strings"
	"time"

	"github.com/gin-gonic/gin"

	"raonson/db"
	mw "raonson/middleware"
	"raonson/utils"
)

// Санҷиши сода: дар амал почтаро худи мактуб тасдиқ мекунад.
// Вазифаи ин regexp танҳо рад кардани вуруди аниқан нодуруст аст.
var emailRe = regexp.MustCompile(`^[^@\s]+@[^@\s.]+\.[^@\s]{2,}$`)

func emailOTPKey(uid, email string) string {
	return "otp:email:" + uid + ":" + email
}

// POST /auth/verify-email — рамзро ба почта мефиристад.
//
// Вуруд ҳатмӣ: мо почтаро ба ҲИСОБИ МУАЙЯН мебандем. Бе ин ҳар кас
// метавонист барои почтаи бегона рамз дархост кунад.
func SendEmailVerify(c *gin.Context) {
	uid := mw.UID(c)
	if uid == "" {
		c.JSON(http.StatusUnauthorized, gin.H{"message": "Вуруд лозим аст"})
		return
	}

	var b struct {
		Email string `json:"email"`
	}
	c.ShouldBindJSON(&b)
	email := strings.ToLower(strings.TrimSpace(b.Email))

	// Агар почта нависанд — ҳамон; вагарна почтаи ҷории ҳисоб.
	if email == "" {
		db.Pool.QueryRow(context.Background(),
			`SELECT COALESCE(email,'') FROM users WHERE id=$1`, uid).Scan(&email)
		email = strings.ToLower(strings.TrimSpace(email))
	}
	if !emailRe.MatchString(email) {
		c.JSON(http.StatusBadRequest, gin.H{"message": "Почта нодуруст аст"})
		return
	}

	// Почтаи касси дигар гирифта намешавад.
	//
	// Бе ин санҷиш корбар метавонист почтаи ҳисоби бегонаро ба худ
	// бандад ва баъд тавассути «парол фаромӯш шуд» онро гирад.
	var other string
	db.Pool.QueryRow(context.Background(),
		`SELECT id FROM users WHERE LOWER(email)=$1 AND id<>$2 LIMIT 1`,
		email, uid).Scan(&other)
	if other != "" {
		c.JSON(http.StatusConflict,
			gin.H{"message": "Ин почта аллакай ба ҳисоби дигар тааллуқ дорад"})
		return
	}

	otp := fmt.Sprintf("%06d", rand.Intn(1000000))
	mw.CacheSet(emailOTPKey(uid, email), []byte(otp), 10*time.Minute)

	if err := utils.SendEmailOTP(email, otp); err != nil {
		// ⚠️ Пеш ин ҷо 200 бо `error: true` бармегашт — ҳамон
		// камбудие, ки дар OTP-и телефон буд. Барнома 200-ро
		// муваффақият мешумурд, экрани «рамзро ворид кунед»
		// мекушод, ва корбар мактуберо интизор мешуд, ки ҳеҷ гоҳ
		// нафиристода буд.
		//
		// Ин маҳз дар санҷиши ин файл ошкор шуд.
		log.Printf("[SendEmailVerify] send failed: %v", err)
		mw.CacheDel(emailOTPKey(uid, email))

		body := gin.H{
			"error":   true,
			"message": "Рамз фиристода нашуд. Почтаро санҷед ё дертар кӯшиш кунед.",
			"ready":   utils.OTPChannelsReady(),
		}
		if !utils.OTPChannelsReady()["email"] {
			// Барои соҳиби барнома — номи танзимоти норасида, на калид.
			body["setup"] = "BREVO_API_KEY ё SMTP_USER + SMTP_PASS"
		}
		c.JSON(http.StatusBadGateway, body)
		return
	}

	resp := gin.H{"message": "Рамз ба почта фиристода шуд",
		"to": utils.MaskEmail(email)}
	if os.Getenv("OTP_ECHO") == "1" && gin.Mode() != gin.ReleaseMode {
		resp["otp"] = otp
	}
	c.JSON(http.StatusOK, resp)
}

// POST /auth/verify-otp — рамзро тасдиқ мекунад ва почтаро мебандад.
func VerifyEmailOTP(c *gin.Context) {
	uid := mw.UID(c)
	if uid == "" {
		c.JSON(http.StatusUnauthorized, gin.H{"message": "Вуруд лозим аст"})
		return
	}

	var b struct {
		Email string `json:"email"`
		OTP   string `json:"otp"`
	}
	c.ShouldBindJSON(&b)
	email := strings.ToLower(strings.TrimSpace(b.Email))
	otp := strings.TrimSpace(b.OTP)
	if email == "" || otp == "" {
		c.JSON(http.StatusBadRequest, gin.H{"message": "Почта ва рамз лозим аст"})
		return
	}

	key := emailOTPKey(uid, email)
	stored, ok := mw.CacheGet(key)
	if !ok || string(stored) != otp {
		c.JSON(http.StatusUnauthorized, gin.H{"message": "Рамз нодуруст ё кӯҳна"})
		return
	}
	// Як рамз — як бор. Бе ин ҳамон рамз то 10 дақиқа кор мекард.
	mw.CacheDel(key)

	if _, err := db.Pool.Exec(context.Background(),
		`UPDATE users SET email=$1, email_verified=TRUE, updated_at=NOW()
		 WHERE id=$2`, email, uid); err != nil {
		log.Printf("[VerifyEmailOTP] update failed: %v", err)
		c.JSON(http.StatusInternalServerError,
			gin.H{"message": "Нигоҳ доштан нашуд"})
		return
	}

	c.JSON(http.StatusOK, gin.H{"verified": true, "email": email})
}
