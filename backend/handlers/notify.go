package handlers

import (
	"context"

	"raonson/db"
)

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
