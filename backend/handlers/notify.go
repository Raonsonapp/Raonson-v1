package handlers

import (
	"context"
	"regexp"
	"strings"
	"time"

	"raonson/db"
)

// mentionRe як @username-ро аз матн ҷудо мекунад (2..30 аломат: ҳарф, рақам, _ ё .).
var mentionRe = regexp.MustCompile(`@([a-zA-Z0-9_.]{2,30})`)

// notifyMentions ҳар корбари @зикршударо дар матн (шарҳ ё тавсиф) огоҳ мекунад.
//   - Ҳамаи @username-ҳоро мегирад, такрориро нест мекунад ва то 10-то маҳдуд.
//   - Барои ҳар як username id-ро меёбад; агар ёфт шуд ва id != fromID бошад,
//     pushNotify (row дохилӣ + FCM) мефиристад.
//   - Best-effort: дар background иҷро мешавад ва хатогиҳоро фуру мебарад.
func notifyMentions(fromID, ntype, targetID, text, bodyTmpl string) {
	if text == "" {
		return
	}
	go func() {
		matches := mentionRe.FindAllStringSubmatch(text, -1)
		if len(matches) == 0 {
			return
		}
		seen := make(map[string]bool)
		var unames []string
		for _, m := range matches {
			uname := strings.ToLower(m[1])
			if seen[uname] {
				continue
			}
			seen[uname] = true
			unames = append(unames, uname)
			if len(unames) >= 10 {
				break
			}
		}
		for _, uname := range unames {
			var resolvedID string
			if err := db.Pool.QueryRow(context.Background(),
				`SELECT id FROM users WHERE lower(username)=lower($1)`, uname).Scan(&resolvedID); err != nil {
				continue
			}
			if resolvedID != "" && resolvedID != fromID {
				pushNotify(resolvedID, fromID, ntype, targetID, bodyTmpl)
			}
		}
	}()
}

// notify як огоҳии дохилиро месозад (follow / like / comment ва ғ.).
//   - Худи коратарро огоҳ намекунад (userID == fromID → skip)
//   - Дар background иҷро мешавад, то ҷавоби лайк/коммент/обуна тезтар бошад
//     (дар миқёси калон барнома шах намешавад).
//   - Барои ҳамон (гиранда, фиристанда, навъ, объект) дубликат намесозад.
func notify(userID, fromID, ntype, targetID string) {
	if userID == "" || userID == fromID {
		return
	}
	go func() {
		ct, err := db.Pool.Exec(context.Background(), `
			UPDATE notifications
			   SET created_at=NOW(), read=FALSE, is_read=FALSE
			 WHERE user_id=$1 AND from_user_id=$2 AND type=$3
			   AND COALESCE(target_id,'')=COALESCE($4,'')`,
			userID, fromID, ntype, targetID)
		if err == nil && ct.RowsAffected() > 0 {
			return
		}
		db.Pool.Exec(context.Background(), `
			INSERT INTO notifications(user_id, from_user_id, type, target_id)
			VALUES($1,$2,$3,$4)`, userID, fromID, ntype, targetID)
	}()
}

// pushNotify як push-notification-и FCM мефиристад (Instagram-барин).
//   - Худи коратарро push намекунад (userID == fromID → skip), мисли notify.
//   - Дар background иҷро мешавад, то ҷавоби амал тезтар бошад.
//   - title = @username-и коратар (OS-и телефон номи/иконаи Raonson-ро зам мекунад).
//   - data map калидҳои "type" ва "targetId"-ро дорад, то барнома deep-link кунад.
func pushNotify(userID, fromID, ntype, targetID, body string) {
	if userID == "" || userID == fromID {
		return
	}
	go func() {
		// Сабти огоҳинома аллакай дар notify() шуд; ин ҷо танҳо
		// ларзиши телефон санҷида мешавад (ниг. notify_policy.go).
		if !allowPush(userID, ntype, time.Now()) {
			return
		}
		var username string
		db.Pool.QueryRow(context.Background(),
			`SELECT username FROM users WHERE id=$1`, fromID).Scan(&username)
		if username == "" {
			return
		}
		SendPushToUser(userID, "@"+username, body, map[string]string{
			"type":     ntype,
			"targetId": targetID,
		})
	}()
}
