// Package notify намудҳои огоҳинома ва қоидаҳои онҳоро муайян мекунад.
//
// Ҳар намуд се чиз дорад: аҳамият, канали Android ва танзиме, ки
// корбар метавонад онро хомӯш кунад. Ин ҷо ягона ҷои ҳақиқат аст —
// вагарна ҳар handler қоидаи худро месохт.
package notify

// Kind — намуди огоҳинома.
type Kind string

// Намудҳо.
//
// Қиматҳо ҲАМОН сатрҳое ҳастанд, ки аллакай дар ҷадвали
// notifications нигоҳ дошта мешаванд ва барнома онҳоро мефаҳмад.
// Тағйир додани онҳо огоҳиномаҳои кӯҳнаро номаълум мекард.
const (
	// Иҷтимоӣ.
	Like           Kind = "like"
	Comment        Kind = "comment"
	Reply          Kind = "reply"
	Follow         Kind = "follow"
	FollowRequest  Kind = "follow_request"
	FollowAccepted Kind = "follow_accepted"
	Mention        Kind = "mention"

	// Чат.
	Message Kind = "message"

	// Сторис ва рилс.
	StoryLike  Kind = "story_like"
	StoryReply Kind = "story_reply"
	ReelLike   Kind = "reel_like"
	ReelReply  Kind = "reel_comment"

	// Эҷодкор.
	CreatorMilestone Kind = "creator_milestone"
	CreatorRecap     Kind = "creator_recap"
	Achievement      Kind = "achievement"
	LevelChanged     Kind = "creator_level"

	// Ҷамъбасти бинанда.
	WeeklyRecap Kind = "weekly_recap"

	// Ҳамкорӣ.
	CollabInvite   Kind = "collab_invite"
	CollabAccepted Kind = "collab_accepted"

	// Даъват.
	ReferralJoined Kind = "referral_joined"

	// Бозор.
	CampaignInvite   Kind = "campaign_invite"
	CampaignResponse Kind = "campaign_offer_response"
	CampaignPayout   Kind = "campaign_payout"

	// Мағоза.
	Order      Kind = "order"
	EffectSale Kind = "effect_sale"

	// Кашфиёт.
	RecommendedCreator Kind = "recommended_creator"
	TrendingTopic      Kind = "trending_topic"
)

// Priority — аҳамияти огоҳинома.
type Priority int

const (
	// Low — метавонад интизор шавад ва гурӯҳбандӣ шавад.
	Low Priority = iota
	// Normal — фаъолияти муқаррарии иҷтимоӣ.
	Normal
	// High — одам онро фавран интизор аст ё пул ба он вобаста аст.
	High
)

// Channel — канали Android.
//
// Каналҳо кам нигоҳ дошта мешаванд: даҳҳо канал корбарро дар
// танзимоти система гум мекунад.
type Channel string

const (
	ChannelMessages    Channel = "messages"
	ChannelSocial      Channel = "social"
	ChannelCreator     Channel = "creator"
	ChannelDiscovery   Channel = "discovery"
	ChannelMarketplace Channel = "marketplace"
)

// Rule — қоидаҳои як намуд.
type Rule struct {
	Priority Priority
	Channel  Channel
	// PrefKey — калиди танзимоти корбар. Холӣ = хомӯш карда
	// намешавад (масалан ҳисоб ва пул).
	PrefKey string
	// Groupable — оё чанд ҳодисаи якхела ба як огоҳинома ҷамъ шаванд.
	Groupable bool
}

// rules — ягона ҷадвали қоидаҳо.
var rules = map[Kind]Rule{
	Like:           {Normal, ChannelSocial, "likes", true},
	Comment:        {Normal, ChannelSocial, "comments", true},
	Reply:          {Normal, ChannelSocial, "comments", true},
	Follow:         {Normal, ChannelSocial, "followers", true},
	FollowRequest:  {Normal, ChannelSocial, "followers", false},
	FollowAccepted: {Normal, ChannelSocial, "followers", false},
	Mention:        {Normal, ChannelSocial, "mentions", false},

	// Паём ҳеҷ гоҳ ҷамъ ё таъхир намешавад.
	Message: {High, ChannelMessages, "messages", false},

	StoryLike:  {Normal, ChannelSocial, "likes", true},
	StoryReply: {Normal, ChannelSocial, "messages", false},
	ReelLike:   {Normal, ChannelSocial, "likes", true},
	ReelReply:  {Normal, ChannelSocial, "comments", true},

	CreatorMilestone: {Low, ChannelCreator, "creator", false},
	CreatorRecap:     {Low, ChannelCreator, "creator", false},
	Achievement:      {Low, ChannelCreator, "achievements", false},
	LevelChanged:     {Low, ChannelCreator, "achievements", false},
	WeeklyRecap:      {Low, ChannelCreator, "creator", false},

	CollabInvite:   {High, ChannelSocial, "", false},
	CollabAccepted: {Normal, ChannelSocial, "", false},

	ReferralJoined: {Low, ChannelSocial, "", false},

	// Пул ва ӯҳдадорӣ — хомӯш карда намешаванд.
	CampaignInvite:   {High, ChannelMarketplace, "", false},
	CampaignResponse: {High, ChannelMarketplace, "", false},
	CampaignPayout:   {High, ChannelMarketplace, "", false},
	Order:            {High, ChannelMarketplace, "", false},
	EffectSale:       {Normal, ChannelMarketplace, "", false},

	RecommendedCreator: {Low, ChannelDiscovery, "recommendations", false},
	TrendingTopic:      {Low, ChannelDiscovery, "recommendations", false},
}

// RuleFor қоидаи намудро мегирад.
//
// Намуди номаълум қоидаи бехатартаринро мегирад: аҳамияти паст,
// канали иҷтимоӣ ва имкони хомӯш кардан. Намуди нав набояд ногаҳон
// телефони касро бедор кунад.
func RuleFor(k Kind) Rule {
	if r, ok := rules[k]; ok {
		return r
	}
	return Rule{Low, ChannelSocial, "", false}
}

// Known мегӯяд, ки оё намуд дар ҷадвал ҳаст.
func Known(k Kind) bool {
	_, ok := rules[k]
	return ok
}

// AllKinds ҳамаи намудҳои маълумро бармегардонад (барои тест).
func AllKinds() []Kind {
	out := make([]Kind, 0, len(rules))
	for k := range rules {
		out = append(out, k)
	}
	return out
}
