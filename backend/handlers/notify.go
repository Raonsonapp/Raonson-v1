package handlers

import (
	"context"

	"raonson/db"
)

// notify як огоҳии дохилиро месозад (follow / like / comment ва ғ.).
//   - Худи коратарро огоҳ намекунад (userID == fromID → skip)
//   - Барои ҳамон (гиранда, фиристанда, навъ, объект) дубликат намесозад;
//     ба ҷои он вақташро нав мекунад, то дар сари рӯйхат барояд (мисли Instagram).
func notify(userID, fromID, ntype, targetID string) {
	if userID == "" || userID == fromID {
		return
	}
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
}
