package handlers

import (
	"context"
	"net/http"

	"raonson/db"
	mw "raonson/middleware"

	"github.com/gin-gonic/gin"
)

// POST /comments/:id/report
func ReportComment(c *gin.Context) {
	myID := mw.UID(c)
	cid := c.Param("id")
	var b struct {
		Reason string `json:"reason"`
	}
	c.ShouldBindJSON(&b)
	if b.Reason == "" {
		b.Reason = "spam"
	}
	db.Pool.Exec(context.Background(),
		`INSERT INTO comment_reports(comment_id, user_id, reason, created_at)
		 VALUES($1,$2,$3,NOW()) ON CONFLICT DO NOTHING`, cid, myID, b.Reason)
	c.JSON(http.StatusOK, gin.H{"reported": true})
}

// POST /stories/:id/report
func ReportStory(c *gin.Context) {
	myID := mw.UID(c)
	sid := c.Param("id")
	var b struct {
		Reason string `json:"reason"`
	}
	c.ShouldBindJSON(&b)
	if b.Reason == "" {
		b.Reason = "spam"
	}
	db.Pool.Exec(context.Background(),
		`INSERT INTO story_reports(story_id, user_id, reason, created_at)
		 VALUES($1,$2,$3,NOW()) ON CONFLICT DO NOTHING`, sid, myID, b.Reason)
	c.JSON(http.StatusOK, gin.H{"reported": true})
}

// POST /chat/messages/:id/report
func ReportMessage(c *gin.Context) {
	myID := mw.UID(c)
	mid := c.Param("id")
	var b struct {
		Reason string `json:"reason"`
	}
	c.ShouldBindJSON(&b)
	if b.Reason == "" {
		b.Reason = "spam"
	}
	db.Pool.Exec(context.Background(),
		`INSERT INTO message_reports(message_id, user_id, reason, created_at)
		 VALUES($1,$2,$3,NOW()) ON CONFLICT DO NOTHING`, mid, myID, b.Reason)
	c.JSON(http.StatusOK, gin.H{"reported": true})
}

// GET /admin/reports?status=pending&type=all&page=1
func AdminGetReports(c *gin.Context) {
	myID := mw.UID(c)
	var role string
	db.Pool.QueryRow(context.Background(),
		`SELECT COALESCE(role,'user') FROM users WHERE id=$1`, myID).Scan(&role)
	if role != "admin" {
		c.JSON(http.StatusForbidden, gin.H{"message": "Admin only"})
		return
	}

	status := c.DefaultQuery("status", "pending")
	rtype := c.DefaultQuery("type", "all")
	page := toInt(c.Query("page"), 1)
	limit := 30
	offset := (page - 1) * limit

	reports := []gin.H{}

	if rtype == "all" || rtype == "post" {
		rows, _ := db.Pool.Query(context.Background(), `
			SELECT pr.post_id, pr.user_id, pr.reason, pr.created_at,
			       COALESCE(pr.status,'pending'),
			       u.username, COALESCE(u.avatar,'')
			FROM post_reports pr
			JOIN users u ON u.id = pr.user_id
			WHERE COALESCE(pr.status,'pending') = $1
			ORDER BY pr.created_at DESC LIMIT $2 OFFSET $3`,
			status, limit, offset)
		if rows != nil {
			defer rows.Close()
			for rows.Next() {
				var targetID, uid, reason, st, uname, avatar string
				var cat interface{}
				rows.Scan(&targetID, &uid, &reason, &cat, &st, &uname, &avatar)
				reports = append(reports, gin.H{
					"type": "post", "targetId": targetID,
					"reporterId": uid, "reporter": uname, "reporterAvatar": avatar,
					"reason": reason, "status": st, "createdAt": cat,
				})
			}
		}
	}

	if rtype == "all" || rtype == "reel" {
		rows, _ := db.Pool.Query(context.Background(), `
			SELECT rr.reel_id, rr.user_id, rr.reason, rr.created_at,
			       COALESCE(rr.status,'pending'),
			       u.username, COALESCE(u.avatar,'')
			FROM reel_reports rr
			JOIN users u ON u.id = rr.user_id
			WHERE COALESCE(rr.status,'pending') = $1
			ORDER BY rr.created_at DESC LIMIT $2 OFFSET $3`,
			status, limit, offset)
		if rows != nil {
			defer rows.Close()
			for rows.Next() {
				var targetID, uid, reason, st, uname, avatar string
				var cat interface{}
				rows.Scan(&targetID, &uid, &reason, &cat, &st, &uname, &avatar)
				reports = append(reports, gin.H{
					"type": "reel", "targetId": targetID,
					"reporterId": uid, "reporter": uname, "reporterAvatar": avatar,
					"reason": reason, "status": st, "createdAt": cat,
				})
			}
		}
	}

	if rtype == "all" || rtype == "user" {
		rows, _ := db.Pool.Query(context.Background(), `
			SELECT ur.reported_id, ur.user_id, ur.reason, ur.created_at,
			       COALESCE(ur.status,'pending'),
			       u.username, COALESCE(u.avatar,'')
			FROM user_reports ur
			JOIN users u ON u.id = ur.user_id
			WHERE COALESCE(ur.status,'pending') = $1
			ORDER BY ur.created_at DESC LIMIT $2 OFFSET $3`,
			status, limit, offset)
		if rows != nil {
			defer rows.Close()
			for rows.Next() {
				var targetID, uid, reason, st, uname, avatar string
				var cat interface{}
				rows.Scan(&targetID, &uid, &reason, &cat, &st, &uname, &avatar)
				reports = append(reports, gin.H{
					"type": "user", "targetId": targetID,
					"reporterId": uid, "reporter": uname, "reporterAvatar": avatar,
					"reason": reason, "status": st, "createdAt": cat,
				})
			}
		}
	}

	if rtype == "all" || rtype == "comment" {
		rows, _ := db.Pool.Query(context.Background(), `
			SELECT cr.comment_id, cr.user_id, cr.reason, cr.created_at,
			       COALESCE(cr.status,'pending'),
			       u.username, COALESCE(u.avatar,'')
			FROM comment_reports cr
			JOIN users u ON u.id = cr.user_id
			WHERE COALESCE(cr.status,'pending') = $1
			ORDER BY cr.created_at DESC LIMIT $2 OFFSET $3`,
			status, limit, offset)
		if rows != nil {
			defer rows.Close()
			for rows.Next() {
				var targetID, uid, reason, st, uname, avatar string
				var cat interface{}
				rows.Scan(&targetID, &uid, &reason, &cat, &st, &uname, &avatar)
				reports = append(reports, gin.H{
					"type": "comment", "targetId": targetID,
					"reporterId": uid, "reporter": uname, "reporterAvatar": avatar,
					"reason": reason, "status": st, "createdAt": cat,
				})
			}
		}
	}

	if rtype == "all" || rtype == "story" {
		rows, _ := db.Pool.Query(context.Background(), `
			SELECT sr.story_id, sr.user_id, sr.reason, sr.created_at,
			       COALESCE(sr.status,'pending'),
			       u.username, COALESCE(u.avatar,'')
			FROM story_reports sr
			JOIN users u ON u.id = sr.user_id
			WHERE COALESCE(sr.status,'pending') = $1
			ORDER BY sr.created_at DESC LIMIT $2 OFFSET $3`,
			status, limit, offset)
		if rows != nil {
			defer rows.Close()
			for rows.Next() {
				var targetID, uid, reason, st, uname, avatar string
				var cat interface{}
				rows.Scan(&targetID, &uid, &reason, &cat, &st, &uname, &avatar)
				reports = append(reports, gin.H{
					"type": "story", "targetId": targetID,
					"reporterId": uid, "reporter": uname, "reporterAvatar": avatar,
					"reason": reason, "status": st, "createdAt": cat,
				})
			}
		}
	}

	if rtype == "all" || rtype == "message" {
		rows, _ := db.Pool.Query(context.Background(), `
			SELECT mr.message_id, mr.user_id, mr.reason, mr.created_at,
			       COALESCE(mr.status,'pending'),
			       u.username, COALESCE(u.avatar,'')
			FROM message_reports mr
			JOIN users u ON u.id = mr.user_id
			WHERE COALESCE(mr.status,'pending') = $1
			ORDER BY mr.created_at DESC LIMIT $2 OFFSET $3`,
			status, limit, offset)
		if rows != nil {
			defer rows.Close()
			for rows.Next() {
				var targetID, uid, reason, st, uname, avatar string
				var cat interface{}
				rows.Scan(&targetID, &uid, &reason, &cat, &st, &uname, &avatar)
				reports = append(reports, gin.H{
					"type": "message", "targetId": targetID,
					"reporterId": uid, "reporter": uname, "reporterAvatar": avatar,
					"reason": reason, "status": st, "createdAt": cat,
				})
			}
		}
	}

	// Count pending child_safety reports across all tables
	var csCount int
	db.Pool.QueryRow(context.Background(), `
		SELECT
			(SELECT COUNT(*) FROM post_reports WHERE reason='child_safety' AND COALESCE(status,'pending')='pending') +
			(SELECT COUNT(*) FROM reel_reports WHERE reason='child_safety' AND COALESCE(status,'pending')='pending') +
			(SELECT COUNT(*) FROM user_reports WHERE reason='child_safety' AND COALESCE(status,'pending')='pending') +
			(SELECT COUNT(*) FROM comment_reports WHERE reason='child_safety' AND COALESCE(status,'pending')='pending') +
			(SELECT COUNT(*) FROM story_reports WHERE reason='child_safety' AND COALESCE(status,'pending')='pending') +
			(SELECT COUNT(*) FROM message_reports WHERE reason='child_safety' AND COALESCE(status,'pending')='pending')
	`).Scan(&csCount)

	c.JSON(http.StatusOK, gin.H{
		"reports":            reports,
		"childSafetyPending": csCount,
	})
}

// POST /admin/reports/resolve
func AdminResolveReport(c *gin.Context) {
	myID := mw.UID(c)
	var role string
	db.Pool.QueryRow(context.Background(),
		`SELECT COALESCE(role,'user') FROM users WHERE id=$1`, myID).Scan(&role)
	if role != "admin" {
		c.JSON(http.StatusForbidden, gin.H{"message": "Admin only"})
		return
	}

	var b struct {
		Type     string `json:"type"`
		TargetID string `json:"targetId"`
		Action   string `json:"action"` // resolve | remove | ban
	}
	if err := c.ShouldBindJSON(&b); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"message": "bad body"})
		return
	}

	ctx := context.Background()
	newStatus := "resolved"
	if b.Action == "remove" || b.Action == "ban" {
		newStatus = "actioned"
	}

	switch b.Type {
	case "post":
		db.Pool.Exec(ctx,
			`UPDATE post_reports SET status=$1 WHERE post_id=$2`, newStatus, b.TargetID)
		if b.Action == "remove" {
			db.Pool.Exec(ctx, `UPDATE posts SET hidden=TRUE WHERE id=$1`, b.TargetID)
		}
	case "reel":
		db.Pool.Exec(ctx,
			`UPDATE reel_reports SET status=$1 WHERE reel_id=$2`, newStatus, b.TargetID)
		if b.Action == "remove" {
			db.Pool.Exec(ctx, `DELETE FROM reels WHERE id=$1`, b.TargetID)
		}
	case "user":
		db.Pool.Exec(ctx,
			`UPDATE user_reports SET status=$1 WHERE reported_id=$2`, newStatus, b.TargetID)
		if b.Action == "ban" {
			db.Pool.Exec(ctx, `UPDATE users SET banned=TRUE WHERE id=$1`, b.TargetID)
		}
	case "comment":
		db.Pool.Exec(ctx,
			`UPDATE comment_reports SET status=$1 WHERE comment_id=$2`, newStatus, b.TargetID)
		if b.Action == "remove" {
			db.Pool.Exec(ctx, `DELETE FROM comments WHERE id=$1`, b.TargetID)
		}
	case "story":
		db.Pool.Exec(ctx,
			`UPDATE story_reports SET status=$1 WHERE story_id=$2`, newStatus, b.TargetID)
		if b.Action == "remove" {
			db.Pool.Exec(ctx, `DELETE FROM stories WHERE id=$1`, b.TargetID)
		}
	case "message":
		db.Pool.Exec(ctx,
			`UPDATE message_reports SET status=$1 WHERE message_id=$2`, newStatus, b.TargetID)
		if b.Action == "remove" {
			db.Pool.Exec(ctx, `UPDATE messages SET is_deleted=TRUE WHERE id=$1`, b.TargetID)
		}
	default:
		c.JSON(http.StatusBadRequest, gin.H{"message": "unknown type"})
		return
	}

	c.JSON(http.StatusOK, gin.H{"resolved": true, "status": newStatus})
}

// GET /admin/reports/count
func AdminReportCount(c *gin.Context) {
	myID := mw.UID(c)
	var role string
	db.Pool.QueryRow(context.Background(),
		`SELECT COALESCE(role,'user') FROM users WHERE id=$1`, myID).Scan(&role)
	if role != "admin" {
		c.JSON(http.StatusForbidden, gin.H{"message": "Admin only"})
		return
	}

	ctx := context.Background()
	var total, csafe int
	db.Pool.QueryRow(ctx, `
		SELECT
			(SELECT COUNT(*) FROM post_reports WHERE COALESCE(status,'pending')='pending') +
			(SELECT COUNT(*) FROM reel_reports WHERE COALESCE(status,'pending')='pending') +
			(SELECT COUNT(*) FROM user_reports WHERE COALESCE(status,'pending')='pending') +
			(SELECT COUNT(*) FROM comment_reports WHERE COALESCE(status,'pending')='pending') +
			(SELECT COUNT(*) FROM story_reports WHERE COALESCE(status,'pending')='pending') +
			(SELECT COUNT(*) FROM message_reports WHERE COALESCE(status,'pending')='pending')
	`).Scan(&total)
	db.Pool.QueryRow(ctx, `
		SELECT
			(SELECT COUNT(*) FROM post_reports WHERE reason='child_safety' AND COALESCE(status,'pending')='pending') +
			(SELECT COUNT(*) FROM reel_reports WHERE reason='child_safety' AND COALESCE(status,'pending')='pending') +
			(SELECT COUNT(*) FROM user_reports WHERE reason='child_safety' AND COALESCE(status,'pending')='pending') +
			(SELECT COUNT(*) FROM comment_reports WHERE reason='child_safety' AND COALESCE(status,'pending')='pending') +
			(SELECT COUNT(*) FROM story_reports WHERE reason='child_safety' AND COALESCE(status,'pending')='pending') +
			(SELECT COUNT(*) FROM message_reports WHERE reason='child_safety' AND COALESCE(status,'pending')='pending')
	`).Scan(&csafe)

	c.JSON(http.StatusOK, gin.H{
		"pendingTotal":       total,
		"childSafetyPending": csafe,
	})
}

// GET /child-safety — published child safety standards (public, no auth)
func GetChildSafetyPolicy(c *gin.Context) {
	c.JSON(http.StatusOK, gin.H{
		"appName":     "Raonson",
		"packageName": "com.raonson.app",
		"contact":     "ehsonmahmadmurodov@gmail.com",
		"lastUpdated": "2026-08-20",
		"policy": map[string]interface{}{
			"summary": "Raonson has zero tolerance for Child Sexual Abuse and Exploitation (CSAE) content. Any content that sexually exploits or endangers children is strictly prohibited and will result in immediate content removal, account suspension, and reporting to relevant authorities including the National Center for Missing & Exploited Children (NCMEC).",
			"prohibitedContent": []string{
				"Child Sexual Abuse Material (CSAM) of any kind",
				"Content that sexualizes minors",
				"Grooming or solicitation of minors",
				"Any content that endangers children",
				"Sharing of minors' personal information",
			},
			"reportingMechanism": map[string]interface{}{
				"inApp":   "Users can report any content (posts, reels, stories, comments, messages, profiles) using the report button with the 'Child Safety' category for immediate priority review.",
				"email":   "ehsonmahmadmurodov@gmail.com",
				"process": "All child safety reports are prioritized and reviewed within 24 hours. Content is removed immediately upon confirmation, and the offending account is permanently banned.",
			},
			"enforcement": []string{
				"Immediate content removal upon confirmed violation",
				"Permanent account suspension for offenders",
				"Reporting to law enforcement and NCMEC",
				"Cooperation with authorities for investigations",
				"Preservation of evidence for law enforcement",
			},
			"agePolicy": map[string]interface{}{
				"minimumAge":           13,
				"ageVerification":      "Users must confirm they are 13 or older during registration.",
				"underageAccountAction": "Accounts identified as belonging to users under 13 are terminated.",
			},
			"contactInformation": map[string]interface{}{
				"childSafetyContact": "ehsonmahmadmurodov@gmail.com",
				"responseTime":      "Within 24 hours for child safety reports",
				"organization":      "Raonson App",
			},
		},
	})
}
