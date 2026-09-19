package handlers

import (
	"os"
	"strings"
	"testing"
)

func readFileForTest(t *testing.T, path string) string {
	t.Helper()
	b, err := os.ReadFile(path)
	if err != nil {
		t.Fatalf("%s хонда нашуд: %v", path, err)
	}
	return string(b)
}

// Ҳолати «Расид» тамоман вуҷуд надошт.
//
// Тавсиф (бахши 40) чор ҳолатро талаб мекунад:
//
//	Фиристода мешавад → Фиристода шуд → Расид → Хонда шуд
//
// Дар барнома «Расид» ҳеҷ гоҳ намеомад: модел `json['delivered']`-ро
// мехонд, вале сервер онро ҳеҷ гоҳ намедод ва сутуни он набуд.
//
// Фарқи «фиристода шуд» ва «расид» муҳим аст: паём метавонад ба
// телефони хомӯш НАРАСИДА бошад, ва фиристанда бояд инро донад.

func TestDeliveredIsRecordedAndReported(t *testing.T) {
	body := funcBody(t, "story_chat_notif_admin.go", "GetMessages")

	if !strings.Contains(body, "delivered_at IS NOT NULL") {
		t.Error("ҷавоб ҳолати «расид»-ро намедиҳад — " +
			"фиристанда ҳеҷ гоҳ ду тикро намебинад")
	}
	if !strings.Contains(body, `"delivered"`) {
		t.Error("майдони `delivered` ба телефон намеравад")
	}
	if !strings.Contains(body, "markDelivered(") {
		t.Error("расидани паём ҳеҷ гоҳ сабт намешавад")
	}
}

func TestMarkDeliveredOnlyTouchesNewMessages(t *testing.T) {
	body := funcBody(t, "story_chat_notif_admin.go", "markDelivered")

	// Бе ин шарт ҳар кушодани чат ҳамаи паёмҳоро аз нав менавишт ва
	// ба ҳамсӯҳбат селоби сигнал мефиристод.
	if !strings.Contains(body, "delivered_at IS NULL") {
		t.Error("паёмҳои аллакай расида аз нав навишта мешаванд — " +
			"селоби сигнал ба ҳамсӯҳбат")
	}
	if !strings.Contains(body, "chat:delivered") {
		t.Error("фиристанда хабар намегирад")
	}
	// Як сигнал ба ҳар фиристанда, на ба ҳар паём.
	if !strings.Contains(body, "bySender") {
		t.Error("ба ҳар паём сигнали ҷудогона меравад — " +
			"даҳ паём = даҳ сигнал")
	}
}

// Паёми нофиристода набояд ҳамчун фиристодашуда намоён шавад —
// на дар маълумот, на дар экран.
func TestFailedMessageIsNotShownAsSent(t *testing.T) {
	src := readFileForTest(t, "../../lib/chat/room/message_bubble.dart")

	if !strings.Contains(src, "MessageStatus.failed") {
		t.Error("экран ҳолати нокомиро намедонад — паёми нарасида " +
			"ҳамчун тик намоён мешавад")
	}
	// Корбар бояд коре карда тавонад, на танҳо бинад.
	if !strings.Contains(src, "Outbox.instance.drain()") {
		t.Error("паёми ноком аз нав фиристода намешавад — " +
			"корбар мебинад, вале коре карда наметавонад")
	}
}
