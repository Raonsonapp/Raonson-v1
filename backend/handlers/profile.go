package handlers

import (
	"net/url"
	"context"
	"encoding/json"
	"log"
	"net/http"
	"regexp"
	"strings"
	"time"

	"raonson/db"
	mw "raonson/middleware"

	"github.com/gin-gonic/gin"
)

// username: 3–30 char, ҳарфҳои хурд/рақам/`_`/`.`
var usernameRe = regexp.MustCompile(`^[a-z0-9_.]{3,30}$`)

// reservedUsername — номҳое, ки танҳо соҳиби барнома дошта метавонад
// (миграцияи оғоз ба «raonson» ҳуқуқи админ медиҳад).
func reservedUsername(u string) bool {
	switch u {
	case "raonson", "admin", "administrator", "support", "moderator", "raonson.official", "raonson_official":
		return true
	}
	return false
}

func isCurrentUsername(uid, u string) bool {
	var cur string
	db.Pool.QueryRow(context.Background(), `SELECT username FROM users WHERE id=$1`, uid).Scan(&cur)
	return cur == u
}

// normalizeUsernameUpdate — номи нав аз PUT /profile ва PUT /users.
//
// ⚠️ Ин ду роҳ номро БЕ санҷиш менавиштанд. Postgres «RAONSON»-ро аз
// «raonson» фарқ мекунад, пас корбар метавонист номашро «RAONSON»
// гузорад — ва миграцияи оғоз (LOWER(username)='raonson') ӯро админ
// мекард. Акнун ҳама ном хурд, бо ҳамон қоида ва беназир (бе фарқи ҳарф).
func normalizeUsernameUpdate(c *gin.Context, myID string, u *string) bool {
	if u == nil {
		return true
	}
	uname := strings.ToLower(strings.TrimSpace(*u))
	if !usernameRe.MatchString(uname) {
		c.JSON(http.StatusBadRequest, gin.H{"message": "Номи корбарӣ нодуруст аст"})
		return false
	}
	if reservedUsername(uname) && !isCurrentUsername(myID, uname) {
		c.JSON(http.StatusConflict, gin.H{"message": "Username taken"})
		return false
	}
	var taken bool
	db.Pool.QueryRow(context.Background(),
		`SELECT EXISTS(SELECT 1 FROM users WHERE LOWER(username)=$1 AND id<>$2)`,
		uname, myID).Scan(&taken)
	if taken {
		c.JSON(http.StatusConflict, gin.H{"message": "Username taken"})
		return false
	}
	*u = uname
	return true
}

// PUT /profile/username — тағйири номи корбарӣ
func ChangeUsername(c *gin.Context) {
	myID := mw.UID(c)
	var b struct {
		Username string `json:"username"`
	}
	if err := c.ShouldBindJSON(&b); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"message": "Bad request"})
		return
	}
	uname := strings.ToLower(strings.TrimSpace(b.Username))
	if !usernameRe.MatchString(uname) {
		c.JSON(http.StatusBadRequest, gin.H{"message": "Номи корбарӣ нодуруст аст"})
		return
	}
	if reservedUsername(uname) && !isCurrentUsername(myID, uname) {
		c.JSON(http.StatusConflict, gin.H{"message": "Ин ном банд аст"})
		return
	}
	var exists bool
	db.Pool.QueryRow(context.Background(),
		`SELECT EXISTS(SELECT 1 FROM users WHERE LOWER(username)=$1 AND id<>$2)`,
		uname, myID).Scan(&exists)
	if exists {
		c.JSON(http.StatusConflict, gin.H{"message": "Ин ном банд аст"})
		return
	}
	if _, err := db.Pool.Exec(context.Background(),
		`UPDATE users SET username=$1 WHERE id=$2`, uname, myID); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"message": "Update failed"})
		return
	}
	mw.CacheDel("profile:me:" + myID)
	c.JSON(http.StatusOK, gin.H{"username": uname})
}

// PUT /profile/phone — тағйири рақами телефон
func ChangePhone(c *gin.Context) {
	myID := mw.UID(c)
	var b struct {
		Phone string `json:"phone"`
	}
	if err := c.ShouldBindJSON(&b); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"message": "Bad request"})
		return
	}
	phone := strings.TrimSpace(b.Phone)
	if phone != "" && !regexp.MustCompile(`^\+?[0-9]{7,15}$`).MatchString(phone) {
		c.JSON(http.StatusBadRequest, gin.H{"message": "Рақами телефон нодуруст аст"})
		return
	}
	if phoneTaken(phone, myID) {
		c.JSON(http.StatusConflict, gin.H{"message": "Ин рақам ба ҳисоби дигар тааллуқ дорад"})
		return
	}
	if _, err := db.Pool.Exec(context.Background(),
		`UPDATE users SET phone=$1 WHERE id=$2`, phone, myID); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"message": "Update failed"})
		return
	}
	mw.CacheDel("profile:me:" + myID)
	c.JSON(http.StatusOK, gin.H{"phone": phone})
}

// GET /profile/me — with 30s personal cache
func GetMyProfile(c *gin.Context) {
	myID := mw.UID(c)

	// Personal cache key
	cacheKey := "profile:me:" + myID
	if cached, ok := mw.CacheGet(cacheKey); ok {
		c.Header("X-Cache", "HIT")
		c.Data(http.StatusOK, "application/json", cached)
		return
	}

	row := db.Pool.QueryRow(context.Background(),
		userSelectSQL+" WHERE id=$1", myID)
	u, err := scanFullUser(row)
	if err != nil {
		log.Printf("[Profile] GetMyProfile error: %v", err)
		c.JSON(http.StatusNotFound, gin.H{"message": "User not found"})
		return
	}
	clearExpiredNote(myID, u)
	u["isFollowing"] = false

	// Постҳо ва маълумот якҷо — 1 trip to DB
	posts := postsForUser(myID, 30)
	result := gin.H{"user": u, "posts": posts}

	// Cache барои 30 сония
	if b, err := json.Marshal(result); err == nil {
		mw.CacheSet(cacheKey, b, 30*time.Second)
	}

	c.JSON(http.StatusOK, result)
}

// GET /profile/:username — with cache
func GetProfile(c *gin.Context) {
	username := c.Param("username")
	myID := mw.UID(c)

	cacheKey := "profile:u:" + username + ":" + myID
	if cached, ok := mw.CacheGet(cacheKey); ok {
		c.Header("X-Cache", "HIT")
		c.Data(http.StatusOK, "application/json", cached)
		return
	}

	row := db.Pool.QueryRow(context.Background(),
		userSelectSQL+" WHERE username=$1", username)
	u, err := scanFullUser(row)
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"message": "Profile not found"})
		return
	}

	uid := u["id"].(string)
	// Бастагон профилро умуман намебинанд (мисли Instagram).
	if IsBlockedBetween(myID, uid) {
		c.JSON(http.StatusNotFound, gin.H{"message": "Profile not found"})
		return
	}
	clearExpiredNote(uid, u)
	setIsFollowing(u, myID, uid)
	viewAs(u, myID)

	// Ҳисоби пӯшида: постҳо танҳо ба обунаҳо. Пеш ин ҷо 30 пост ба
	// ҳар кас бармегашт, ҳол он ки GetUserPosts онро месанҷид.
	posts := []gin.H{}
	if ok, _ := CanSeeProfileContent(myID, uid); ok {
		posts = postsForUser(uid, 30)
	}
	result := gin.H{"user": u, "posts": posts}

	if b, err := json.Marshal(result); err == nil {
		mw.CacheSet(cacheKey, b, 30*time.Second)
	}

	c.JSON(http.StatusOK, result)
}

// PUT /profile/ — invalidate cache after update
func UpdateProfile(c *gin.Context) {
	myID := mw.UID(c)
	var b struct {
		Bio       *string `json:"bio"`
		Avatar    *string `json:"avatar"`
		IsPrivate *bool   `json:"isPrivate"`
		Username  *string `json:"username"`
		Website   *string `json:"website"`
		Location  *string `json:"location"`
		FullName  *string `json:"fullName"`
		Phone     *string `json:"phone"`
		BioSong   *json.RawMessage `json:"bioSong"`
		CoverUrl  *string `json:"coverUrl"`
		Links     *[]struct {
			Title string `json:"title"`
			URL   string `json:"url"`
		} `json:"links"`
		ActivityStatus *bool `json:"activityStatus"`
		AllowComments  *bool `json:"allowComments"`
		AllowMentions  *bool `json:"allowMentions"`
		TwoFactor      *bool `json:"twoFactor"`
		// Ҷонишинҳо — то 4 адад, ҳар кадом то 12 ҳарф (қоидаи Instagram).
		Pronouns       *string `json:"pronouns"`
	}
	if err := c.ShouldBindJSON(&b); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"message": "Bad request"})
		return
	}
	if b.Bio != nil {
		clamped := clampRunes(*b.Bio, 150)
		b.Bio = &clamped
	}
	if !normalizeUsernameUpdate(c, myID, b.Username) {
		return
	}
	if b.Phone != nil && phoneTaken(strings.TrimSpace(*b.Phone), myID) {
		c.JSON(http.StatusConflict, gin.H{"message": "Ин рақам ба ҳисоби дигар тааллуқ дорад"})
		return
	}
	changingUsername, allowed := usernameChangeAllowed(myID, b.Username)
	if !allowed {
		c.JSON(http.StatusUnprocessableEntity, gin.H{
			"message":    "Username can only be changed once every 14 days",
			"retryAfter": 14 * 24 * 3600,
		})
		return
	}
	if b.Pronouns != nil {
		p := normalizePronouns(*b.Pronouns)
		b.Pronouns = &p
	}
	var bioSongStr *string
	if b.BioSong != nil {
		s := string(*b.BioSong)
		bioSongStr = &s
	}
	// Майдонҳои матнӣ ва URL-ҳо. Пеш дарозӣ маҳдуд набуд ва линк бо ҳар
	// нақша (javascript:, file:, intent:) қабул мешуд.
	clampPtr := func(p *string, n int) {
		if p != nil {
			v := clampRunes(strings.TrimSpace(*p), n)
			*p = v
		}
	}
	clampPtr(b.Bio, 150)
	clampPtr(b.FullName, 60)
	clampPtr(b.Location, 60)
	clampPtr(b.Website, 200)
	// «raonson.tj» бе нақша — https:// илова мекунем (одамон ҳамин тавр менависанд).
	if b.Website != nil && *b.Website != "" && !strings.Contains(*b.Website, "://") {
		w := "https://" + *b.Website
		b.Website = &w
	}
	for _, u := range []*string{b.Website, b.Avatar, b.CoverUrl} {
		if u != nil && *u != "" && !isWebURL(*u) {
			c.JSON(http.StatusBadRequest, gin.H{"message": "Линк бояд бо https:// сар шавад"})
			return
		}
	}
	// links → re-serialize to JSON string; cap at 20 links.
	var bioLinksStr *string
	if b.Links != nil {
		links := *b.Links
		if len(links) > 20 {
			links = links[:20]
		}
		clean := links[:0]
		for _, l := range links {
			if isWebURL(l.URL) {
				l.Title = clampRunes(l.Title, 40)
				clean = append(clean, l)
			}
		}
		links = clean
		if raw, err := json.Marshal(links); err == nil {
			s := string(raw)
			bioLinksStr = &s
		}
	}
	_, err := db.Pool.Exec(context.Background(), `
		UPDATE users SET
		  bio        = COALESCE($1, bio),
		  avatar     = COALESCE($2, avatar),
		  is_private = COALESCE($3, is_private),
		  username   = COALESCE($4, username),
		  website    = COALESCE($5, website),
		  location   = COALESCE($6, location),
		  full_name  = COALESCE($7, full_name),
		  phone      = COALESCE($8, phone),
		  bio_song   = COALESCE($10::jsonb, bio_song),
		  cover_url  = COALESCE($12, cover_url),
		  bio_links  = COALESCE($13, bio_links),
		  activity_status = COALESCE($14, activity_status),
		  allow_comments  = COALESCE($15, allow_comments),
		  allow_mentions  = COALESCE($16, allow_mentions),
		  two_factor      = COALESCE($17, two_factor),
		  pronouns        = COALESCE($18, pronouns),
		  username_changed_at = CASE WHEN $11 THEN NOW() ELSE username_changed_at END,
		  updated_at = NOW()
		WHERE id=$9`,
		b.Bio, b.Avatar, b.IsPrivate, b.Username,
		b.Website, b.Location, b.FullName, b.Phone, myID, bioSongStr, changingUsername,
		b.CoverUrl, bioLinksStr,
		b.ActivityStatus, b.AllowComments, b.AllowMentions, b.TwoFactor,
		b.Pronouns)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"message": "Update failed"})
		return
	}
	// Кэшро нест кун
	mw.CacheDel("profile:me:"+myID)
	mw.InvalidateUserCache(myID)

	// Return updated profile
	row := db.Pool.QueryRow(context.Background(),
		userSelectSQL+" WHERE id=$1", myID)
	u, _ := scanFullUser(row)
	c.JSON(http.StatusOK, gin.H{"user": u})
}

// PUT /profile/settings — theme + language нигоҳ медорад (cross-device sync)
func UpdateSettings(c *gin.Context) {
	myID := mw.UID(c)
	var b struct {
		Theme    *string `json:"theme"`
		Language *string `json:"language"`
	}
	if err := c.ShouldBindJSON(&b); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"message": "Bad request"})
		return
	}
	_, err := db.Pool.Exec(context.Background(), `
		UPDATE users SET
		  theme      = COALESCE($1, theme),
		  language   = COALESCE($2, language),
		  updated_at = NOW()
		WHERE id=$3`, b.Theme, b.Language, myID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"message": "Update failed"})
		return
	}
	mw.CacheDel("profile:me:" + myID)
	c.JSON(http.StatusOK, gin.H{"ok": true})
}

func SetNote(c *gin.Context) {
	myID := mw.UID(c)
	var b struct {
		Note string                 `json:"note"`
		Song map[string]interface{} `json:"song"`
	}
	c.ShouldBindJSON(&b)

	text := b.Note
	if len([]rune(text)) > 60 {
		text = string([]rune(text)[:60])
	}

	var (
		title, artist, artUrl, previewUrl string
		trackMs, startMs, endMs           int
	)
	endMs = 30000
	if b.Song != nil {
		title, _      = b.Song["title"].(string)
		artist, _     = b.Song["artist"].(string)
		artUrl, _     = b.Song["artUrl"].(string)
		previewUrl, _ = b.Song["previewUrl"].(string)
		if v, ok := b.Song["trackMs"].(float64); ok { trackMs = int(v) }
		if v, ok := b.Song["startMs"].(float64); ok { startMs = int(v) }
		if v, ok := b.Song["endMs"].(float64);   ok { endMs   = int(v) }
	}

	hasContent := text != "" || title != ""
	var expires interface{}
	if hasContent {
		expires = time.Now().Add(24 * time.Hour)
	}

	db.Pool.Exec(context.Background(), `
		UPDATE users SET
		  note=$1, note_expires_at=$2,
		  note_song_title=$3, note_song_artist=$4, note_song_art_url=$5,
		  note_song_preview_url=$6, note_song_track_ms=$7,
		  note_song_start_ms=$8, note_song_end_ms=$9
		WHERE id=$10`,
		text, expires, title, artist, artUrl, previewUrl,
		trackMs, startMs, endMs, myID)

	c.JSON(http.StatusOK, gin.H{"note": text})
}

// GET /profile/notes/friends
func GetFriendsNotes(c *gin.Context) {
	myID := mw.UID(c)
	log.Printf("[Profile] GetFriendsNotes userID=%s", myID)

	rows, err := db.Pool.Query(context.Background(), `
		SELECT u.id,u.username,u.avatar,u.verified,
		       u.note,u.note_expires_at,
		       u.note_song_title,u.note_song_artist,u.note_song_art_url,
		       u.note_song_preview_url,u.note_song_track_ms,
		       u.note_song_start_ms,u.note_song_end_ms
		FROM follows f JOIN users u ON u.id=f.following_id
		WHERE f.follower_id=$1
		  AND u.note_expires_at > NOW()
		  AND (u.note != '' OR u.note_song_title != '')`,
		myID)
	if err != nil {
		log.Printf("[Profile] GetFriendsNotes error: %v", err)
		c.JSON(http.StatusInternalServerError, gin.H{"message": "Get notes failed"})
		return
	}
	defer rows.Close()

	friends := []gin.H{}
	for rows.Next() {
		var id, uname, avatar, note, stTitle, stArtist, stArtUrl, stPreviewUrl string
		var verified bool
		var noteExp interface{}
		var stTrackMs, stStartMs, stEndMs int
		rows.Scan(&id, &uname, &avatar, &verified, &note, &noteExp,
			&stTitle, &stArtist, &stArtUrl, &stPreviewUrl,
			&stTrackMs, &stStartMs, &stEndMs)
		friends = append(friends, gin.H{
			"_id": id, "username": uname, "avatar": avatar, "verified": verified,
			"note": note, "noteExpiresAt": noteExp,
			"noteSong": gin.H{
				"title": stTitle, "artist": stArtist, "artUrl": stArtUrl,
				"previewUrl": stPreviewUrl, "trackMs": stTrackMs,
				"startMs": stStartMs, "endMs": stEndMs,
			},
		})
	}
	c.JSON(http.StatusOK, gin.H{"notes": friends})
}

func clearExpiredNote(uid string, u gin.H) {
	if exp, ok := u["noteExpiresAt"]; ok && exp != nil {
		if t, ok := exp.(time.Time); ok && t.Before(time.Now()) {
			db.Pool.Exec(context.Background(), `
				UPDATE users SET note='', note_expires_at=NULL WHERE id=$1`, uid)
			u["note"] = ""
			u["noteExpiresAt"] = nil
		}
	}
}

// PUT /profile/email — иваз кардани почтаи электронӣ.
// Барнома ин endpoint-ро мезад, вале он вуҷуд надошт — иваз кардани
// почта хомӯшона кор намекард (404 дар catch фурӯ бурда мешуд).
func ChangeEmail(c *gin.Context) {
	myID := mw.UID(c)
	var b struct {
		Email string `json:"email"`
	}
	if err := c.ShouldBindJSON(&b); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"message": "Bad request"})
		return
	}
	email := strings.ToLower(strings.TrimSpace(b.Email))
	if email == "" ||
		!regexp.MustCompile(`^[^@\s]+@[^@\s]+\.[^@\s]{2,}$`).MatchString(email) {
		c.JSON(http.StatusBadRequest, gin.H{"message": "Почтаи электронӣ нодуруст аст"})
		return
	}
	// Почта дар ҷадвал ягона аст — тафтиш мекунем, то хатои DB
	// ба корбар ҳамчун «Update failed» нарасад.
	var taken bool
	db.Pool.QueryRow(context.Background(),
		`SELECT EXISTS(SELECT 1 FROM users WHERE LOWER(email)=$1 AND id<>$2::text)`,
		email, myID).Scan(&taken)
	if taken {
		c.JSON(http.StatusConflict,
			gin.H{"message": "Ин почта аллакай истифода мешавад"})
		return
	}
	if _, err := db.Pool.Exec(context.Background(),
		// Почтаи нав ҳанӯз тасдиқ нашудааст — пеш парчами «тасдиқшуда»
		// аз почтаи кӯҳна мемонд.
		`UPDATE users SET email=$1, email_verified=FALSE, updated_at=NOW()
		 WHERE id=$2 AND LOWER(COALESCE(email,'')) <> $1`, email, myID); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"message": "Update failed"})
		return
	}
	mw.CacheDel("profile:me:" + myID)
	mw.InvalidateUserCache(myID)
	c.JSON(http.StatusOK, gin.H{"email": email})
}

// normalizePronouns — «ӯ / вай, she/her» → то 4 ҷонишини тоза.
//
// Instagram то 4 ҷонишин иҷозат медиҳад. Ҷудокунанда — «/», «,» ё
// фосила; ҳар кадом то 12 ҳарф; такрорҳо хориҷ.
func normalizePronouns(raw string) string {
	f := func(r rune) bool { return r == '/' || r == ',' || r == ' ' || r == '|' }
	seen := map[string]bool{}
	out := []string{}
	for _, part := range strings.FieldsFunc(raw, f) {
		part = clampRunes(strings.TrimSpace(part), 12)
		k := strings.ToLower(part)
		if part == "" || seen[k] {
			continue
		}
		seen[k] = true
		out = append(out, part)
		if len(out) == 4 {
			break
		}
	}
	return strings.Join(out, "/")
}

// phoneTaken — рақам аллакай дар ҳисоби дигар ҳаст?
//
// Пеш ҳар кас метавонист рақами каси дигарро ба ҳисоби худ гузорад:
// воридшавӣ бо рақам ҳисоби НОДУРУСТро меёфт ва соҳиби аслӣ ворид
// шуда наметавонист.
func phoneTaken(phone, myID string) bool {
	if phone == "" {
		return false
	}
	var taken bool
	db.Pool.QueryRow(context.Background(),
		`SELECT EXISTS(SELECT 1 FROM users WHERE phone=$1 AND id<>$2::text)`,
		phone, myID).Scan(&taken)
	return taken
}

// isWebURL — танҳо http(s) бо ҳост.
func isWebURL(raw string) bool {
	u, err := url.Parse(strings.TrimSpace(raw))
	return err == nil && (u.Scheme == "https" || u.Scheme == "http") &&
		u.Host != "" && len(raw) <= 500
}
