package handlers

import (
	"strings"
	"testing"
)

// Ҳамкорӣ ҲЕҶ ГОҲ кор намекард.
//
// Барнома НОМИ корбарро мефиристад: корбар «@ehson» менависад ва
// ҳамон сатр ба сервер меравад. Сервер бошад `WHERE id=$1` мекард —
// яъне ШИНОСАИ корбарро интизор мешуд.
//
// Муқоисаи ном бо шиноса ҳеҷ гоҳ мувофиқ намеояд. Даъват хомӯшона
// партофта мешуд: на хато, на огоҳинома, на сатр дар база. Корбар
// тугмаро медид, коллаборатор илова мекард, пост нашр мешуд — ва
// ҳеҷ чиз намешуд.
//
// ⚠️ Ин камбудии «хомӯш» аст: ҳеҷ чиз намешиканад, танҳо хусусият
// вуҷуд надорад. Барои ҳамин он то ҳол дида нашуда буд.

func TestCollabAcceptsUsernameNotOnlyID(t *testing.T) {
	body := funcBody(t, "collab.go", "inviteCollaborators")

	// Муқоисаи хушку холии шиноса набояд бошад.
	if strings.Contains(body, "FROM users WHERE id=$1)") {
		t.Error("даъват танҳо бо шиносаи корбар кор мекунад, вале " +
			"барнома НОМИ корбарро мефиристад — ҳар даъват партофта мешавад")
	}
	if !strings.Contains(body, "resolveUserRef(") {
		t.Error("сатри воридотӣ ба шиносаи корбар табдил намешавад")
	}

	resolve := funcBody(t, "collab.go", "resolveUserRef")
	if !strings.Contains(resolve, "lower(username)=lower($1)") {
		t.Error("номи корбар ҷустуҷӯ намешавад")
	}
	// «@ehson» ва «ehson» бояд якхела кор кунанд.
	if !strings.Contains(resolve, `TrimPrefix`) {
		t.Error("«@» аз аввали ном бурида намешавад")
	}
}

// Одамони дар АКС зикршуда огоҳинома намегирифтанд.
//
// `notifyMentions` танҳо МАТНи постро таҳлил мекард. Агар шумо
// касеро дар худи акс нишон диҳед («На этом фото»), ӯ ҳеҷ гоҳ
// намедонист.
func TestTaggedUsersAreNotified(t *testing.T) {
	body := funcBody(t, "post.go", "CreatePost")

	if !strings.Contains(body, "b.TaggedUsers") {
		t.Fatal("одамони зикршуда хонда намешаванд — тест кӯҳна шудааст")
	}
	// Дар қисми огоҳинома бояд истифода шаванд, на танҳо дар сабт.
	i := strings.Index(body, "notifyMentions(")
	if i < 0 {
		t.Fatal("notifyMentions ёфт нашуд")
	}
	if !strings.Contains(body[i:], "b.TaggedUsers") {
		t.Error("одамони дар АКС зикршуда огоҳинома намегиранд — " +
			"танҳо зикр дар матн хабар медиҳад")
	}
}
