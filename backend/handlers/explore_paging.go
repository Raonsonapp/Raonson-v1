package handlers

import "strings"

// Саҳифабандии Explore.
//
// Пеш /explore ҳамеша ҳамон 40 пост ва 20 reel-ро бармегардонд ва
// `page`-ро нодида мегирифт; барнома онҳоро омехта мекард. Натиҷа:
// саҳифаи 2 айнан саҳифаи 1 буд ва лентаи Explore «тамом» намешуд.

const (
	explorePostsPerPage = 30
	exploreReelsPerPage = 12
)

// exploreSeed — калиди ҷаласа аз барнома: танҳо ҳарф/рақам, то 32.
// Ҳар чизи дигар → "" (тартиби маъмулият).
func exploreSeed(s string) string {
	s = strings.TrimSpace(s)
	if len(s) > 32 {
		s = s[:32]
	}
	for _, r := range s {
		if !(r >= 'a' && r <= 'z' || r >= 'A' && r <= 'Z' || r >= '0' && r <= '9') {
			return ""
		}
	}
	return s
}

// exploreOrderSQL — ORDER BY-и устувор барои Explore.
//
// Бе seed: маъмултаринҳо, сипас навтаринҳо. Бо seed: ҳар ҷаласа тартиби
// худро дорад (hash(id, seed)), вале маъмултаринҳо бештар болотар
// меафтанд. Дар ҳарду ҳолат охирин калид аз id вобаста аст — бе ин ду
// сатри баробар метавонистанд дар саҳифаҳои гуногун ҷой иваз кунанд
// (такрор ё гумшавӣ байни саҳифаҳо).
//
// seedParam ҳамеша дар SQL истифода мешавад (ҳатто холӣ), то Postgres
// навъи параметрро донад.
func exploreOrderSQL(idCol, likesCol, commentsCol, createdCol, seedParam string) string {
	hash := `md5(` + idCol + `::text || ` + seedParam + `::text)`
	// 0..1 аз 8 рақами аввали hash.
	frac := `(('x' || substr(` + hash + `, 1, 8))::bit(32)::bigint::float8 / 4294967296.0)`
	pop := `ln(2.0 + GREATEST(COALESCE(` + likesCol + `,0),0) + 2*GREATEST(COALESCE(` + commentsCol + `,0),0))`
	return `CASE WHEN ` + seedParam + `::text = '' THEN 0
	             ELSE ` + frac + ` * ` + pop + ` END DESC,
	        COALESCE(` + likesCol + `,0) DESC, ` + createdCol + ` DESC, ` + hash
}
