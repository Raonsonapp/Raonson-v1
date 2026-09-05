package notify

// Матни огоҳинома ва линки он.
//
// Матн дар СЕРВЕР тарҷума мешавад, чунки push-ро система нишон
// медиҳад — барнома он вақт кор карда наметавонад, ки матнро худаш
// тарҷума кунад.
//
// Забон аз users.language гирифта мешавад.

import "strings"

// Lang — забони дастгирӣшаванда.
type Lang string

const (
	TJ Lang = "tj"
	RU Lang = "ru"
	EN Lang = "en"
)

// NormalizeLang забони номаълумро ба тоҷикӣ мебарад — ҳамон
// пешфарзи барнома.
func NormalizeLang(s string) Lang {
	switch strings.ToLower(strings.TrimSpace(s)) {
	case "ru":
		return RU
	case "en":
		return EN
	default:
		return TJ
	}
}

// bodies — матни огоҳинома барои ҳар намуд ва забон.
//
// {actor} — номи корбар, {n} — шумораи одамони дигар дар гурӯҳ.
var bodies = map[Kind]map[Lang]string{
	Like: {
		TJ: "пости шуморо писандид",
		RU: "понравился ваш пост",
		EN: "liked your post",
	},
	Comment: {
		TJ: "ба пости шумо шарҳ гузошт",
		RU: "прокомментировал(а) ваш пост",
		EN: "commented on your post",
	},
	Reply: {
		TJ: "ба шарҳи шумо ҷавоб дод",
		RU: "ответил(а) на ваш комментарий",
		EN: "replied to your comment",
	},
	Follow: {
		TJ: "ба шумо обуна шуд",
		RU: "подписался(ась) на вас",
		EN: "started following you",
	},
	FollowRequest: {
		TJ: "мехоҳад обуна шавад",
		RU: "хочет подписаться на вас",
		EN: "wants to follow you",
	},
	FollowAccepted: {
		TJ: "дархости шуморо қабул кард",
		RU: "принял(а) вашу заявку",
		EN: "accepted your follow request",
	},
	Mention: {
		TJ: "шуморо зикр кард",
		RU: "упомянул(а) вас",
		EN: "mentioned you",
	},
	Message: {
		TJ: "ба шумо паём фиристод",
		RU: "отправил(а) вам сообщение",
		EN: "sent you a message",
	},
	StoryLike: {
		TJ: "сторисатонро писандид",
		RU: "понравилась ваша история",
		EN: "liked your story",
	},
	StoryReply: {
		TJ: "ба сторисатон ҷавоб дод",
		RU: "ответил(а) на вашу историю",
		EN: "replied to your story",
	},
	ReelLike: {
		TJ: "Reel-и шуморо писандид",
		RU: "понравился ваш Reel",
		EN: "liked your reel",
	},
	ReelReply: {
		TJ: "ба Reel-и шумо шарҳ гузошт",
		RU: "прокомментировал(а) ваш Reel",
		EN: "commented on your reel",
	},
	CollabInvite: {
		TJ: "шуморо ба ҳамкорӣ даъват кард",
		RU: "приглашает вас в соавторы",
		EN: "invited you to collaborate",
	},
	CollabAccepted: {
		TJ: "ҳамкориро қабул кард",
		RU: "принял(а) соавторство",
		EN: "accepted your collaboration",
	},
	CampaignInvite: {
		TJ: "шуморо ба кампания даъват кард",
		RU: "приглашает вас в кампанию",
		EN: "invited you to a campaign",
	},
	CampaignResponse: {
		TJ: "ба пешниҳоди шумо ҷавоб дод",
		RU: "ответил(а) на ваше предложение",
		EN: "responded to your offer",
	},
	Order: {
		TJ: "маҳсули шуморо фармоиш дод",
		RU: "заказал(а) ваш товар",
		EN: "ordered your product",
	},
	EffectSale: {
		TJ: "эффекти шуморо харид",
		RU: "купил(а) ваш эффект",
		EN: "bought your effect",
	},
}

// grouped — матн вақте чанд нафар ҳамон корро карданд.
var grouped = map[Kind]map[Lang]string{
	Like: {
		TJ: "ва {n} нафари дигар пости шуморо писандиданд",
		RU: "и ещё {n} понравился ваш пост",
		EN: "and {n} others liked your post",
	},
	Comment: {
		TJ: "ва {n} нафари дигар ба пости шумо шарҳ гузоштанд",
		RU: "и ещё {n} прокомментировали ваш пост",
		EN: "and {n} others commented on your post",
	},
	Follow: {
		TJ: "ва {n} нафари дигар ба шумо обуна шуданд",
		RU: "и ещё {n} подписались на вас",
		EN: "and {n} others started following you",
	},
	ReelLike: {
		TJ: "ва {n} нафари дигар Reel-и шуморо писандиданд",
		RU: "и ещё {n} понравился ваш Reel",
		EN: "and {n} others liked your reel",
	},
	StoryLike: {
		TJ: "ва {n} нафари дигар сторисатонро писандиданд",
		RU: "и ещё {n} понравилась ваша история",
		EN: "and {n} others liked your story",
	},
}

// standalone — огоҳиномаҳое, ки муаллиф надоранд (аз худи барнома).
var standalone = map[Kind]map[Lang][2]string{
	WeeklyRecap: {
		TJ: {"Ҳафтаи шумо тайёр аст", "Бинед, ки ҳафта чӣ гуна гузашт"},
		RU: {"Итоги недели готовы", "Посмотрите, как прошла ваша неделя"},
		EN: {"Your week is ready", "See how your week went"},
	},
	CreatorRecap: {
		TJ: {"Ҳафтаи эҷодкории шумо тайёр аст", "Натиҷаҳои ҳафтаи шумо"},
		RU: {"Ваша неделя как автора готова", "Результаты вашей недели"},
		EN: {"Your creator week is ready", "Your results for the week"},
	},
	Achievement: {
		TJ: {"Нишони нав", "Шумо нишони нав гирифтед"},
		RU: {"Новый значок", "Вы получили новый значок"},
		EN: {"New badge", "You earned a new badge"},
	},
	LevelChanged: {
		TJ: {"Зинаи нав", "Зинаи эҷодкории шумо баланд шуд"},
		RU: {"Новый уровень", "Ваш уровень автора вырос"},
		EN: {"New level", "Your creator level went up"},
	},
	ReferralJoined: {
		TJ: {"Даъвати шумо кор кард", "Касе бо линки шумо ҳамроҳ шуд"},
		RU: {"Ваше приглашение сработало", "Кто-то присоединился по вашей ссылке"},
		EN: {"Your invite worked", "Someone joined through your link"},
	},
	CampaignPayout: {
		TJ: {"Пардохт", "Ҳолати пардохти шумо тағйир ёфт"},
		RU: {"Выплата", "Статус вашей выплаты изменился"},
		EN: {"Payout", "Your payout status changed"},
	},
}

// Text матни огоҳиномаро месозад.
//
// actor — номи корбари амалкунанда (бе @). others — шумораи одамони
// ИЛОВАГӢ дар гурӯҳ (0 = танҳо як нафар).
//
// Агар матн барои ин намуд набошад, сарлавҳа ва матни холӣ
// бармегардад — беҳтар аз фиристодани рамзи техникӣ ба корбар.
func Text(k Kind, lang Lang, actor string, others int) (title, body string) {
	if s, ok := standalone[k]; ok {
		if t, ok := s[lang]; ok {
			return t[0], t[1]
		}
		return s[TJ][0], s[TJ][1]
	}

	if actor == "" {
		return "", ""
	}
	title = "@" + actor

	if others > 0 {
		if g, ok := grouped[k]; ok {
			return title, fillCount(pick(g, lang), others)
		}
	}
	b, ok := bodies[k]
	if !ok {
		return "", ""
	}
	return title, pick(b, lang)
}

func pick(m map[Lang]string, lang Lang) string {
	if s, ok := m[lang]; ok && s != "" {
		return s
	}
	return m[TJ]
}

func fillCount(s string, n int) string {
	return strings.ReplaceAll(s, "{n}", itoa(n))
}

func itoa(n int) string {
	if n == 0 {
		return "0"
	}
	neg := n < 0
	if neg {
		n = -n
	}
	var b [20]byte
	i := len(b)
	for n > 0 {
		i--
		b[i] = byte('0' + n%10)
		n /= 10
	}
	if neg {
		i--
		b[i] = '-'
	}
	return string(b[i:])
}

// Link роҳи дохилиро барои намуд ва объект месозад.
//
// Ҳамон роҳҳое, ки DeepLinks дар барнома мефаҳмад — routing-и дуюм
// сохта намешавад. Роҳи холӣ маънои «ҷои мушаххас нест» дорад ва
// барнома маркази огоҳиномаҳоро мекушояд.
func Link(k Kind, targetID, actorName string) string {
	switch k {
	case Like, Comment, Reply, Mention:
		if targetID != "" {
			return "/post/" + targetID
		}
	case ReelLike, ReelReply:
		if targetID != "" {
			return "/reel/" + targetID
		}
	case Follow, FollowRequest, FollowAccepted:
		if actorName != "" {
			return "/profile/" + actorName
		}
	case CollabInvite, CollabAccepted:
		if targetID != "" {
			return "/post/" + targetID
		}
	case TrendingTopic:
		if targetID != "" {
			return "/topic/" + targetID
		}
	case RecommendedCreator:
		if actorName != "" {
			return "/profile/" + actorName
		}
	}
	return ""
}
