package handlers

// Саҳифаи пешнамоиш — маҳз ҳамин чизест, ки WhatsApp ва Telegram
// ҳангоми мубодила мехонанд.
//
// Хатои ин ҷо ба таври хомӯш зоҳир мешавад: гиранда ба ҷои видео
// сатри урёнро мебинад ва ҳеҷ кас намедонад чаро.

import (
	"strings"
	"testing"
)

func render(d previewData) string { return string(renderPreview(d)) }

func hasMeta(html, prop, val string) bool {
	return strings.Contains(html,
		`property="`+prop+`" content="`+val+`"`) ||
		strings.Contains(html, `name="`+prop+`" content="`+val+`"`)
}

// Барои ВИДЕО тегҳои og:video лозиманд.
//
// Бе онҳо мессенҷер видеоро пахш карда наметавонад — маҳз ҳамин
// сабаби шикояти «линк мефиристад, на видео» буд.
func TestVideoGetsVideoTags(t *testing.T) {
	h := render(previewData{
		Kind: "reel", ID: "r1", Username: "ali",
		MediaURL: "https://cdn.test/v.mp4", MediaType: "video",
		Thumbnail: "https://cdn.test/t.jpg", Caption: "салом",
	})
	must := map[string]string{
		"og:video":            "https://cdn.test/v.mp4",
		"og:video:secure_url": "https://cdn.test/v.mp4",
		"og:video:type":       "video/mp4",
		"og:type":             "video.other",
		"twitter:card":        "player",
	}
	for k, v := range must {
		if !hasMeta(h, k, v) {
			t.Errorf("теги %s=%s нест", k, v)
		}
	}
}

// og:image бояд РАСМ бошад, на mp4.
//
// Ҳеҷ мессенҷер mp4-ро ҳамчун расм кушода наметавонад: он вақт корти
// пешнамоиш бе тасвир мемонад.
func TestVideoImageIsThumbnailNotVideo(t *testing.T) {
	h := render(previewData{
		Kind: "reel", ID: "r1", Username: "ali",
		MediaURL: "https://cdn.test/v.mp4", MediaType: "video",
		Thumbnail: "https://cdn.test/t.jpg",
	})
	if !hasMeta(h, "og:image", "https://cdn.test/t.jpg") {
		t.Error("og:image ба thumbnail ишора намекунад")
	}
	if hasMeta(h, "og:image", "https://cdn.test/v.mp4") {
		t.Error("og:image ба худи видео ишора мекунад — мессенҷер онро " +
			"ҳамчун расм хонда наметавонад")
	}
}

// Видеои бе thumbnail: og:image набояд ба mp4 афтад.
func TestVideoWithoutThumbnailHasNoFakeImage(t *testing.T) {
	h := render(previewData{
		Kind: "reel", ID: "r1", Username: "ali",
		MediaURL: "https://cdn.test/v.mp4", MediaType: "video",
	})
	if strings.Contains(h, `property="og:image" content="https://cdn.test/v.mp4"`) {
		t.Error("бе thumbnail og:image ба видео гузошта шуд")
	}
	// Видео бояд боз ҳам тегҳои худро дошта бошад.
	if !hasMeta(h, "og:video", "https://cdn.test/v.mp4") {
		t.Error("og:video гум шуд")
	}
}

// Акс корти оддии тасвирӣ мегирад.
func TestImageGetsSummaryCard(t *testing.T) {
	h := render(previewData{
		Kind: "post", ID: "p1", Username: "ali",
		MediaURL: "https://cdn.test/i.jpg", MediaType: "image",
	})
	if !hasMeta(h, "twitter:card", "summary_large_image") {
		t.Error("корти тасвирӣ нест")
	}
	if !hasMeta(h, "og:image", "https://cdn.test/i.jpg") {
		t.Error("og:image нест")
	}
	if strings.Contains(h, "og:video") {
		t.Error("акс тегҳои видео гирифт")
	}
}

// Ҳар арзиши аз БД бояд escape шавад.
//
// Тавсифи пост аз КОРБАР меояд — бе escape ин саҳифа роҳи ҳамла
// мешуд.
func TestUserContentIsEscaped(t *testing.T) {
	evil := `</title><script>alert(1)</script><img src=x onerror=alert(2)>`
	h := render(previewData{
		Kind: "post", ID: "p1", Username: evil, Caption: evil,
		MediaURL: `https://cdn.test/"onload="alert(3)`, MediaType: "image",
		Avatar: evil,
	})
	// Хосияти дақиқ: матни корбар бояд ТАНҲО дар шакли escape-шуда
	// бошад. Агар он айнан пайдо шавад, теге сохта шудааст.
	//
	// Ба теги `<img` умуман нигоҳ кардан хатост: худи шаблон аватарро
	// бо ҳамин тег мекашад.
	if strings.Contains(h, evil) {
		t.Error("матни корбар бе escape ба саҳифа афтод")
	}
	for _, raw := range []string{"<script>", "</script>", "<img src=x"} {
		if strings.Contains(h, raw) {
			t.Errorf("теги хатарнок аз матни корбар сохта шуд: %q", raw)
		}
	}
	// Баромадан аз атрибут: нохунак бояд escape шавад.
	if strings.Contains(h, `/"onload=`) {
		t.Error("аз атрибут баромадан имконпазир аст")
	}
	// Вале матн бояд ҳамчун МАТН боқӣ монад.
	if !strings.Contains(h, "&lt;script&gt;") {
		t.Error("матн умуман нест шуд — бояд escape шавад, на партофта")
	}
}

// Тавсифи дароз буриш мешавад: мессенҷерҳо онро ҳарчанд маҳдуд
// мекунанд ва теги азим фоида надорад.
func TestLongCaptionIsTruncated(t *testing.T) {
	long := strings.Repeat("матни хеле дароз ", 100)
	h := render(previewData{
		Kind: "post", ID: "p1", Username: "ali", Caption: long,
		MediaURL: "https://cdn.test/i.jpg", MediaType: "image",
	})
	start := strings.Index(h, `property="og:description" content="`)
	if start < 0 {
		t.Fatal("og:description нест")
	}
	rest := h[start+len(`property="og:description" content="`):]
	end := strings.Index(rest, `"`)
	if end > 400 {
		t.Errorf("тавсиф %d аломат — хеле дароз", end)
	}
}

// Мӯҳтавои бе тавсиф бояд боз ҳам тавсифи маънодор дошта бошад.
func TestEmptyCaptionStillDescribes(t *testing.T) {
	h := render(previewData{
		Kind: "reel", ID: "r1", Username: "ali",
		MediaURL: "https://cdn.test/v.mp4", MediaType: "video",
	})
	if strings.Contains(h, `property="og:description" content=""`) {
		t.Error("тавсиф холӣ монд")
	}
}

// Линки чуқур бояд ба ҳамон мӯҳтаво барад.
func TestDeepLinkMatchesContent(t *testing.T) {
	cases := map[string]string{
		"post": "raonson://post/abc",
		"reel": "raonson://reel/abc",
	}
	for kind, want := range cases {
		h := render(previewData{Kind: kind, ID: "abc", Username: "ali"})
		if !strings.Contains(h, want) {
			t.Errorf("%s: линки %q нест", kind, want)
		}
	}
}

// Мӯҳтавои бе медиа набояд саҳифаи шикастаро диҳад.
func TestMissingMediaStillRenders(t *testing.T) {
	h := render(previewData{Kind: "post", ID: "p1", Username: "ali"})
	if !strings.Contains(h, "<html") || !strings.Contains(h, "</html>") {
		t.Error("саҳифаи нопурра")
	}
	if strings.Contains(h, `content=""`) &&
		strings.Contains(h, `og:image`) {
		t.Error("og:image-и холӣ гузошта шуд")
	}
}

func TestTruncate(t *testing.T) {
	if got := truncate("салом дунё", 100); got != "салом дунё" {
		t.Errorf("матни кӯтоҳ тағйир ёфт: %q", got)
	}
	if got := truncate("аб\nвг", 100); strings.Contains(got, "\n") {
		t.Errorf("сатри нав намонд: %q", got)
	}
	long := strings.Repeat("а", 300)
	if got := truncate(long, 160); len([]rune(got)) > 161 {
		t.Errorf("буриш кор накард: %d аломат", len([]rune(got)))
	}
}
