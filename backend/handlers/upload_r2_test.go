package handlers

import (
	"mime/multipart"
	"net/textproto"
	"strings"
	"testing"
)

func fakeHeader(declared string) *multipart.FileHeader {
	h := textproto.MIMEHeader{}
	if declared != "" {
		h.Set("Content-Type", declared)
	}
	return &multipart.FileHeader{Filename: "x.jpg", Header: h}
}

// Байтҳои воқеӣ ҳал мекунанд, на сарлавҳаи client.
func TestSniffBeatsClientHeader(t *testing.T) {
	png := []byte("\x89PNG\r\n\x1a\n" + strings.Repeat("\x00", 600))
	// Client дурӯғ мегӯяд, ки ин видео аст.
	ct, ext, ok := safeMediaType(png, fakeHeader("video/mp4"))
	if !ok {
		t.Fatal("PNG рад шуд")
	}
	if ct != "image/png" || ext != ".png" {
		t.Errorf("навъ %q ext %q — байтҳо бартарӣ надоштанд", ct, ext)
	}
}

// Ҳамлаи асосӣ: HTML бо сарлавҳаи бегона.
//
// Агар ин гузарад, CDN онро ҳамчун саҳифа медиҳад ва скрипти бегона
// дар домени мӯҳтаво иҷро мешавад.
func TestHtmlAndScriptsAreRejected(t *testing.T) {
	cases := map[string][]byte{
		"HTML":            []byte("<html><script>alert(1)</script></html>"),
		"SVG":             []byte(`<svg xmlns="http://www.w3.org/2000/svg"><script>alert(1)</script></svg>`),
		"HTML бо DOCTYPE": []byte("<!DOCTYPE html><body>hi</body>"),
		"матн":            []byte("салом"),
		"PDF":             []byte("%PDF-1.4\n%%EOF"),
	}
	for name, data := range cases {
		for _, declared := range []string{"", "image/jpeg", "text/html", "image/svg+xml"} {
			if _, _, ok := safeMediaType(data, fakeHeader(declared)); ok {
				t.Errorf("%s бо эълони %q қабул шуд", name, declared)
			}
		}
	}
}

// Медиаи қонунӣ бояд кор кунад.
func TestRealMediaIsAccepted(t *testing.T) {
	cases := map[string]struct {
		data []byte
		want string
	}{
		"JPEG": {[]byte("\xff\xd8\xff\xe0" + strings.Repeat("\x00", 600)), "image/jpeg"},
		"PNG":  {[]byte("\x89PNG\r\n\x1a\n" + strings.Repeat("\x00", 600)), "image/png"},
		"GIF":  {[]byte("GIF89a" + strings.Repeat("\x00", 600)), "image/gif"},
	}
	for name, c := range cases {
		ct, ext, ok := safeMediaType(c.data, fakeHeader(""))
		if !ok {
			t.Errorf("%s рад шуд", name)
			continue
		}
		if ct != c.want || ext == "" {
			t.Errorf("%s → %q / %q", name, ct, ext)
		}
	}
}

// Видео баъзан ҳамчун octet-stream шинохта мешавад — эълони client
// ТАНҲО аз рӯйхати сафед қабул мешавад.
func TestUnknownBytesFallBackToWhitelistOnly(t *testing.T) {
	blob := []byte(strings.Repeat("\x01\x02\x03\x04", 200))

	// Эълони қонунӣ — қабул.
	if ct, ext, ok := safeMediaType(blob, fakeHeader("video/mp4")); !ok ||
		ct != "video/mp4" || ext != ".mp4" {
		t.Errorf("видеои эъломшуда рад шуд: %q %q %v", ct, ext, ok)
	}
	// Эълони хатарнок — рад.
	for _, bad := range []string{"text/html", "image/svg+xml",
		"application/javascript", "application/x-msdownload", ""} {
		if _, _, ok := safeMediaType(blob, fakeHeader(bad)); ok {
			t.Errorf("эълони %q қабул шуд", bad)
		}
	}
}

// Пасванд ҲАМЕША аз навъи тасдиқшуда меояд, на аз номи файли client.
func TestExtensionNeverComesFromFilename(t *testing.T) {
	png := []byte("\x89PNG\r\n\x1a\n" + strings.Repeat("\x00", 600))
	h := fakeHeader("")
	h.Filename = "../../evil.html"
	_, ext, ok := safeMediaType(png, h)
	if !ok {
		t.Fatal("PNG рад шуд")
	}
	if ext != ".png" {
		t.Errorf("пасванд аз номи файл гирифта шуд: %q", ext)
	}
}

// Файли холӣ ё хеле хурд ба crash намеорад.
func TestTinyInputs(t *testing.T) {
	for _, data := range [][]byte{nil, {}, {0x00}, []byte("ab")} {
		if _, _, ok := safeMediaType(data, fakeHeader("image/jpeg")); ok {
			t.Errorf("вуруди %d байт қабул шуд", len(data))
		}
	}
}
