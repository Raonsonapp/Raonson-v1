package push

import (
	"encoding/json"
	"strings"
	"testing"
)

// Шакли payload бе шабака санҷида мешавад: хатои сохтори он FCM-ро
// водор мекунад огоҳиномаро партояд ва мо инро намебинем.
func TestPayloadShape(t *testing.T) {
	b, err := json.Marshal(buildPayload(Message{
		Token:     "TOK",
		Title:     "@ali",
		Body:      "пости шуморо писандид",
		ChannelID: "social",
		Data:      map[string]string{"link": "/post/p1"},
	}))
	if err != nil {
		t.Fatal(err)
	}
	var out struct {
		Message struct {
			Token        string            `json:"token"`
			Notification map[string]string `json:"notification"`
			Data         map[string]string `json:"data"`
			Android      struct {
				Priority     string         `json:"priority"`
				Notification map[string]any `json:"notification"`
			} `json:"android"`
			APNS struct {
				Headers map[string]string `json:"headers"`
				Payload struct {
					APS map[string]any `json:"aps"`
				} `json:"payload"`
			} `json:"apns"`
		} `json:"message"`
	}
	if err := json.Unmarshal(b, &out); err != nil {
		t.Fatal(err)
	}
	m := out.Message
	if m.Token != "TOK" {
		t.Errorf("токен: %q", m.Token)
	}
	if m.Notification["title"] != "@ali" || m.Notification["body"] == "" {
		t.Errorf("огоҳинома: %v", m.Notification)
	}
	if m.Data["link"] != "/post/p1" {
		t.Errorf("linki чуқур гум шуд: %v", m.Data)
	}
	if m.Android.Notification["channel_id"] != "social" {
		t.Errorf("канал: %v", m.Android.Notification)
	}
}

// Аҳамияти баланд танҳо вақте, ки мо онро возеҳ талаб кардем.
// Сӯиистифода аз HIGH боиси маҳдудкунии FCM мешавад.
func TestPriorityDefaultsToNormal(t *testing.T) {
	normal := buildPayload(Message{Token: "T"})
	if got := normal["message"].(map[string]any)["android"].(map[string]any)["priority"]; got != "NORMAL" {
		t.Errorf("пешфарз %v, интизори NORMAL", got)
	}
	high := buildPayload(Message{Token: "T", HighPriority: true})
	if got := high["message"].(map[string]any)["android"].(map[string]any)["priority"]; got != "HIGH" {
		t.Errorf("баланд %v, интизори HIGH", got)
	}
	// APNs низ бояд мувофиқ бошад.
	h := high["message"].(map[string]any)["apns"].(map[string]any)["headers"].(map[string]any)
	if h["apns-priority"] != "10" {
		t.Errorf("apns-priority: %v", h["apns-priority"])
	}
}

func TestBadgeOnlyWhenSet(t *testing.T) {
	aps := func(m Message) map[string]any {
		return buildPayload(m)["message"].(map[string]any)["apns"].(map[string]any)["payload"].(map[string]any)["aps"].(map[string]any)
	}
	if _, ok := aps(Message{Token: "T"})["badge"]; ok {
		t.Error("badge бе арзиш набояд фиристода шавад")
	}
	if aps(Message{Token: "T", Badge: 4})["badge"] != 4 {
		t.Error("badge гузошта нашуд")
	}
}

// Ин муҳимтарин ҷадвали пакет аст: хатои таснифот ё токени солимро
// нобуд мекунад, ё токени мурдаро абадӣ нигоҳ медорад.
func TestClassify(t *testing.T) {
	cases := []struct {
		name   string
		status int
		body   string
		want   Result
	}{
		{"қабул шуд", 200, `{"name":"projects/x/messages/1"}`, Sent},
		{"дастгоҳ нест", 404, `{"error":{"status":"NOT_FOUND"}}`, TokenDead},
		{"токени нодуруст", 400,
			`{"error":{"status":"INVALID_ARGUMENT","message":"Invalid registration token"}}`,
			TokenDead},
		// Хатои payload — айби мо, на дастгоҳ.
		{"payload нодуруст", 400,
			`{"error":{"status":"INVALID_ARGUMENT","message":"Invalid JSON payload received"}}`,
			ConfigError},
		{"аслнома рад шуд", 401, `{"error":{"status":"UNAUTHENTICATED"}}`, ConfigError},
		{"иҷозат нест", 403, `{"error":{"status":"PERMISSION_DENIED"}}`, ConfigError},
		{"хеле зиёд", 429, `{}`, Retry},
		{"сервер афтод", 500, `{}`, Retry},
		{"сервер дастнорас", 503, `{}`, Retry},
	}
	for _, c := range cases {
		if got := classify(c.status, []byte(c.body)); got != c.want {
			t.Errorf("%s (HTTP %d): %v, интизори %v",
				c.name, c.status, got, c.want)
		}
	}
}

// Хатои аслнома НАБОЯД токенҳоро нобуд кунад: як калиди нодуруст
// метавонист ҳамаи дастгоҳҳои ҳама корбаронро хомӯш кунад.
func TestCredentialErrorNeverKillsTokens(t *testing.T) {
	for _, status := range []int{401, 403, 500, 502, 503, 429} {
		if got := classify(status, []byte(`{"error":{"message":"token"}}`)); got == TokenDead {
			t.Errorf("HTTP %d токенро нобуд кард", status)
		}
	}
}

// Бе танзимот push хомӯшона «муваффақ» ҳисоб нашавад.
func TestNotConfigured(t *testing.T) {
	t.Setenv("FCM_SERVICE_ACCOUNT_JSON", "")
	t.Setenv("FCM_SERVICE_ACCOUNT_FILE", "")
	ResetForTest()
	defer ResetForTest()
	if Configured() {
		t.Error("бе аслнома Configured бояд false бошад")
	}
}

// Аслномаи вайрон набояд ба хатои норавшан оварад.
func TestBrokenServiceAccount(t *testing.T) {
	t.Setenv("FCM_SERVICE_ACCOUNT_JSON", `{"project_id":"x"}`)
	ResetForTest()
	defer ResetForTest()
	if Configured() {
		t.Error("аслномаи нопурра қабул шуд")
	}
}

// Сир набояд ба матни хато барояд.
func TestErrorsCarryNoSecret(t *testing.T) {
	const secret = "-----BEGIN PRIVATE KEY-----SECRET-----END PRIVATE KEY-----"
	t.Setenv("FCM_SERVICE_ACCOUNT_JSON",
		`{"project_id":"p","client_email":"a@b.c","private_key":"`+secret+`"`)
	ResetForTest()
	defer ResetForTest()
	_, err := loadServiceAccount()
	if err == nil {
		t.Fatal("JSON-и вайрон бояд хато диҳад")
	}
	if got := err.Error(); got == "" || strings.Contains(got, "SECRET") {
		t.Errorf("хато сирро ошкор кард: %q", got)
	}
}
