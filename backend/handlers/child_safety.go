package handlers

import (
	"context"
	"fmt"
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
		Reason      string `json:"reason"`
		Description string `json:"description"`
	}
	c.ShouldBindJSON(&b)
	if b.Reason == "" {
		b.Reason = "spam"
	}
	_, err := db.Pool.Exec(context.Background(),
		`INSERT INTO comment_reports(comment_id, user_id, reason, description, created_at)
		 VALUES($1,$2,$3,$4,NOW()) ON CONFLICT DO NOTHING`, cid, myID, b.Reason, b.Description)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"message": "report failed"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"reported": true})
}

// POST /stories/:id/report
func ReportStory(c *gin.Context) {
	myID := mw.UID(c)
	sid := c.Param("id")
	var b struct {
		Reason      string `json:"reason"`
		Description string `json:"description"`
	}
	c.ShouldBindJSON(&b)
	if b.Reason == "" {
		b.Reason = "spam"
	}
	_, err := db.Pool.Exec(context.Background(),
		`INSERT INTO story_reports(story_id, user_id, reason, description, created_at)
		 VALUES($1,$2,$3,$4,NOW()) ON CONFLICT DO NOTHING`, sid, myID, b.Reason, b.Description)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"message": "report failed"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"reported": true})
}

// POST /chat/messages/:id/report
func ReportMessage(c *gin.Context) {
	myID := mw.UID(c)
	mid := c.Param("id")
	var b struct {
		Reason      string `json:"reason"`
		Description string `json:"description"`
	}
	c.ShouldBindJSON(&b)
	if b.Reason == "" {
		b.Reason = "spam"
	}
	_, err := db.Pool.Exec(context.Background(),
		`INSERT INTO message_reports(message_id, user_id, reason, description, created_at)
		 VALUES($1,$2,$3,$4,NOW()) ON CONFLICT DO NOTHING`, mid, myID, b.Reason, b.Description)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"message": "report failed"})
		return
	}
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
		rows, err := db.Pool.Query(context.Background(), `
			SELECT pr.post_id, pr.user_id, pr.reason, COALESCE(pr.description,''),
			       pr.created_at, COALESCE(pr.status,'pending'),
			       u.username, COALESCE(u.avatar,'')
			FROM post_reports pr
			JOIN users u ON u.id = pr.user_id
			WHERE COALESCE(pr.status,'pending') = $1
			ORDER BY pr.created_at DESC LIMIT $2 OFFSET $3`,
			status, limit, offset)
		if err == nil && rows != nil {
			defer rows.Close()
			for rows.Next() {
				var targetID, uid, reason, desc, st, uname, avatar string
				var cat interface{}
				rows.Scan(&targetID, &uid, &reason, &desc, &cat, &st, &uname, &avatar)
				reports = append(reports, gin.H{
					"type": "post", "targetId": targetID,
					"reporterId": uid, "reporter": uname, "reporterAvatar": avatar,
					"reason": reason, "description": desc, "status": st, "createdAt": cat,
				})
			}
		}
	}

	if rtype == "all" || rtype == "reel" {
		rows, err := db.Pool.Query(context.Background(), `
			SELECT rr.reel_id, rr.user_id, rr.reason, COALESCE(rr.description,''),
			       rr.created_at, COALESCE(rr.status,'pending'),
			       u.username, COALESCE(u.avatar,'')
			FROM reel_reports rr
			JOIN users u ON u.id = rr.user_id
			WHERE COALESCE(rr.status,'pending') = $1
			ORDER BY rr.created_at DESC LIMIT $2 OFFSET $3`,
			status, limit, offset)
		if err == nil && rows != nil {
			defer rows.Close()
			for rows.Next() {
				var targetID, uid, reason, desc, st, uname, avatar string
				var cat interface{}
				rows.Scan(&targetID, &uid, &reason, &desc, &cat, &st, &uname, &avatar)
				reports = append(reports, gin.H{
					"type": "reel", "targetId": targetID,
					"reporterId": uid, "reporter": uname, "reporterAvatar": avatar,
					"reason": reason, "description": desc, "status": st, "createdAt": cat,
				})
			}
		}
	}

	if rtype == "all" || rtype == "user" {
		rows, err := db.Pool.Query(context.Background(), `
			SELECT ur.reported_id, ur.user_id, ur.reason, COALESCE(ur.description,''),
			       ur.created_at, COALESCE(ur.status,'pending'),
			       u.username, COALESCE(u.avatar,'')
			FROM user_reports ur
			JOIN users u ON u.id = ur.user_id
			WHERE COALESCE(ur.status,'pending') = $1
			ORDER BY ur.created_at DESC LIMIT $2 OFFSET $3`,
			status, limit, offset)
		if err == nil && rows != nil {
			defer rows.Close()
			for rows.Next() {
				var targetID, uid, reason, desc, st, uname, avatar string
				var cat interface{}
				rows.Scan(&targetID, &uid, &reason, &desc, &cat, &st, &uname, &avatar)
				reports = append(reports, gin.H{
					"type": "user", "targetId": targetID,
					"reporterId": uid, "reporter": uname, "reporterAvatar": avatar,
					"reason": reason, "description": desc, "status": st, "createdAt": cat,
				})
			}
		}
	}

	if rtype == "all" || rtype == "comment" {
		rows, err := db.Pool.Query(context.Background(), `
			SELECT cr.comment_id, cr.user_id, cr.reason, COALESCE(cr.description,''),
			       cr.created_at, COALESCE(cr.status,'pending'),
			       u.username, COALESCE(u.avatar,'')
			FROM comment_reports cr
			JOIN users u ON u.id = cr.user_id
			WHERE COALESCE(cr.status,'pending') = $1
			ORDER BY cr.created_at DESC LIMIT $2 OFFSET $3`,
			status, limit, offset)
		if err == nil && rows != nil {
			defer rows.Close()
			for rows.Next() {
				var targetID, uid, reason, desc, st, uname, avatar string
				var cat interface{}
				rows.Scan(&targetID, &uid, &reason, &desc, &cat, &st, &uname, &avatar)
				reports = append(reports, gin.H{
					"type": "comment", "targetId": targetID,
					"reporterId": uid, "reporter": uname, "reporterAvatar": avatar,
					"reason": reason, "description": desc, "status": st, "createdAt": cat,
				})
			}
		}
	}

	if rtype == "all" || rtype == "story" {
		rows, err := db.Pool.Query(context.Background(), `
			SELECT sr.story_id, sr.user_id, sr.reason, COALESCE(sr.description,''),
			       sr.created_at, COALESCE(sr.status,'pending'),
			       u.username, COALESCE(u.avatar,'')
			FROM story_reports sr
			JOIN users u ON u.id = sr.user_id
			WHERE COALESCE(sr.status,'pending') = $1
			ORDER BY sr.created_at DESC LIMIT $2 OFFSET $3`,
			status, limit, offset)
		if err == nil && rows != nil {
			defer rows.Close()
			for rows.Next() {
				var targetID, uid, reason, desc, st, uname, avatar string
				var cat interface{}
				rows.Scan(&targetID, &uid, &reason, &desc, &cat, &st, &uname, &avatar)
				reports = append(reports, gin.H{
					"type": "story", "targetId": targetID,
					"reporterId": uid, "reporter": uname, "reporterAvatar": avatar,
					"reason": reason, "description": desc, "status": st, "createdAt": cat,
				})
			}
		}
	}

	if rtype == "all" || rtype == "message" {
		rows, err := db.Pool.Query(context.Background(), `
			SELECT mr.message_id, mr.user_id, mr.reason, COALESCE(mr.description,''),
			       mr.created_at, COALESCE(mr.status,'pending'),
			       u.username, COALESCE(u.avatar,'')
			FROM message_reports mr
			JOIN users u ON u.id = mr.user_id
			WHERE COALESCE(mr.status,'pending') = $1
			ORDER BY mr.created_at DESC LIMIT $2 OFFSET $3`,
			status, limit, offset)
		if err == nil && rows != nil {
			defer rows.Close()
			for rows.Next() {
				var targetID, uid, reason, desc, st, uname, avatar string
				var cat interface{}
				rows.Scan(&targetID, &uid, &reason, &desc, &cat, &st, &uname, &avatar)
				reports = append(reports, gin.H{
					"type": "message", "targetId": targetID,
					"reporterId": uid, "reporter": uname, "reporterAvatar": avatar,
					"reason": reason, "description": desc, "status": st, "createdAt": cat,
				})
			}
		}
	}

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
		Action   string `json:"action"` // resolve | remove | ban | under_review | dismiss
	}
	if err := c.ShouldBindJSON(&b); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"message": "bad body"})
		return
	}

	ctx := context.Background()
	newStatus := "resolved"
	switch b.Action {
	case "remove":
		newStatus = "action_taken"
	case "ban":
		newStatus = "action_taken"
	case "under_review":
		newStatus = "under_review"
	case "dismiss":
		newStatus = "dismissed"
	}

	updateSQL := func(table, col string) {
		db.Pool.Exec(ctx,
			fmt.Sprintf(`UPDATE %s SET status=$1, reviewed_at=NOW(), moderator_id=$2 WHERE %s=$3`, table, col),
			newStatus, myID, b.TargetID)
	}

	switch b.Type {
	case "post":
		updateSQL("post_reports", "post_id")
		if b.Action == "remove" {
			db.Pool.Exec(ctx, `UPDATE posts SET hidden=TRUE WHERE id=$1`, b.TargetID)
		}
	case "reel":
		updateSQL("reel_reports", "reel_id")
		if b.Action == "remove" {
			db.Pool.Exec(ctx, `DELETE FROM reels WHERE id=$1`, b.TargetID)
		}
	case "user":
		updateSQL("user_reports", "reported_id")
		if b.Action == "ban" {
			db.Pool.Exec(ctx, `UPDATE users SET banned=TRUE WHERE id=$1`, b.TargetID)
		}
	case "comment":
		updateSQL("comment_reports", "comment_id")
		if b.Action == "remove" {
			db.Pool.Exec(ctx, `DELETE FROM comments WHERE id=$1`, b.TargetID)
		}
	case "story":
		updateSQL("story_reports", "story_id")
		if b.Action == "remove" {
			db.Pool.Exec(ctx, `DELETE FROM stories WHERE id=$1`, b.TargetID)
		}
	case "message":
		updateSQL("message_reports", "message_id")
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

// GET /child-safety — public HTML child safety standards page (no auth required)
func GetChildSafetyPolicy(c *gin.Context) {
	c.Header("Content-Type", "text/html; charset=utf-8")
	c.String(http.StatusOK, childSafetyHTML)
}

// GET /community-guidelines — public HTML community guidelines (no auth)
func GetCommunityGuidelines(c *gin.Context) {
	c.Header("Content-Type", "text/html; charset=utf-8")
	c.String(http.StatusOK, communityGuidelinesHTML)
}

const communityGuidelinesHTML = `<!DOCTYPE html>
<html lang="tg">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Raonson — Community Guidelines</title>
<style>
*{margin:0;padding:0;box-sizing:border-box}
body{font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,sans-serif;background:#0a0a0a;color:#e0e0e0;line-height:1.7;max-width:800px;margin:0 auto;padding:24px 20px}
h1{color:#fff;font-size:28px;margin-bottom:8px}
h2{color:#fff;font-size:20px;margin:32px 0 12px;padding-bottom:8px;border-bottom:1px solid #222}
p{margin-bottom:12px;color:#bbb}
ul{margin:8px 0 16px 24px;color:#bbb}
li{margin-bottom:6px}
a{color:#4fc3f7;text-decoration:none}
a:hover{text-decoration:underline}
.header{background:linear-gradient(135deg,#001a33,#0a0a0a);border:1px solid #4fc3f7;border-radius:16px;padding:24px;margin-bottom:32px}
.header p{color:#81d4fa;margin:0}
.footer{margin-top:48px;padding-top:16px;border-top:1px solid #222;font-size:13px;color:#666}
</style>
</head>
<body>
<div class="header">
<h1>Community Guidelines</h1>
<p>Raonson is committed to building a safe, respectful, and welcoming community for all users.</p>
</div>

<h2>1. Respect and Kindness</h2>
<p>All users must treat each other with respect. Hate speech, insults, mockery, and other forms of harassment are strictly prohibited.</p>

<h2>2. Child Safety</h2>
<p>Raonson has a <strong>zero-tolerance policy</strong> for child sexual abuse and exploitation (CSAE/CSAM).</p>
<ul>
<li>Any content that endangers children is immediately removed</li>
<li>Offending accounts are permanently banned; we cooperate with law enforcement upon valid legal request</li>
<li>Minimum age requirement: 13 years old</li>
<li>Users under 13 are not permitted and their accounts will be terminated</li>
</ul>
<p>For our full child safety policy, visit: <a href="/child-safety">/child-safety</a></p>

<h2>3. Prohibited Content</h2>
<ul>
<li>Pornography and sexually explicit content</li>
<li>Violence, cruelty, and promotion of terrorism</li>
<li>Hate content targeting race, religion, ethnicity, or gender</li>
<li>CSAM/CSAE material (child safety violations)</li>
<li>Personal information of others without consent</li>
<li>Spam, fraud, and misleading content</li>
<li>Promotion of drugs or illegal activities</li>
</ul>

<h2>4. Intellectual Property</h2>
<p>Only post content that you own or have permission to use. Copyright violations will result in content removal and account restrictions.</p>

<h2>5. Spam and Self-Promotion</h2>
<p>Sending repetitive messages, unnecessary links, or automated content is prohibited. Self-promotion should be moderate and within the rules.</p>

<h2>6. Privacy and Personal Information</h2>
<p>Do not publish personal information of others without their consent. This includes photos, phone numbers, addresses, and financial information.</p>

<h2>7. Commerce (Tajikshop)</h2>
<p>Sellers must represent products honestly. Fraud in pricing, quality, or description will result in account restrictions. A 5% commission applies to all sales.</p>

<h2>8. Reporting</h2>
<p>If you see content that violates these guidelines, please report it using the report button available on every post, reel, story, comment, message, and user profile. For child safety concerns, select the "Child Safety" category for immediate priority review.</p>
<p>You can also email us at: <a href="mailto:ehsonmahmadmurodov@gmail.com">ehsonmahmadmurodov@gmail.com</a></p>

<h2>9. Enforcement</h2>
<ul>
<li>Warning for first-time violations</li>
<li>Temporary account suspension for repeated violations</li>
<li>Content removal for serious violations</li>
<li>Permanent account ban for CSAE/CSAM or severe violations</li>
<li>Cooperation with law enforcement upon valid legal request</li>
</ul>

<h2>10. Contact</h2>
<p>For questions or to report violations:</p>
<p>Email: <a href="mailto:ehsonmahmadmurodov@gmail.com">ehsonmahmadmurodov@gmail.com</a></p>

<div class="footer">
<p><strong>Raonson App</strong> — com.raonson.app</p>
<p>Last updated: August 2026</p>
</div>
</body>
</html>`

const childSafetyHTML = `<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Raonson — Child Safety Standards</title>
<style>
*{margin:0;padding:0;box-sizing:border-box}
body{font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,sans-serif;background:#0a0a0a;color:#e0e0e0;line-height:1.7;max-width:800px;margin:0 auto;padding:24px 20px}
h1{color:#fff;font-size:28px;margin-bottom:8px}
h2{color:#fff;font-size:20px;margin:32px 0 12px;padding-bottom:8px;border-bottom:1px solid #222}
h3{color:#ccc;font-size:16px;margin:20px 0 8px}
p{margin-bottom:12px;color:#bbb}
ul{margin:8px 0 16px 24px;color:#bbb}
li{margin-bottom:6px}
a{color:#4fc3f7;text-decoration:none}
a:hover{text-decoration:underline}
.badge{display:inline-block;background:#e53935;color:#fff;padding:4px 12px;border-radius:6px;font-size:12px;font-weight:700;letter-spacing:0.5px;margin-bottom:16px}
.header{background:linear-gradient(135deg,#1a0000,#0a0a0a);border:1px solid #e53935;border-radius:16px;padding:24px;margin-bottom:32px}
.header p{color:#ef9a9a;margin:0}
.contact-box{background:#111;border:1px solid #333;border-radius:12px;padding:20px;margin:16px 0}
.contact-box strong{color:#fff}
.footer{margin-top:48px;padding-top:16px;border-top:1px solid #222;font-size:13px;color:#666}
</style>
</head>
<body>
<div class="header">
<span class="badge">CHILD SAFETY</span>
<h1>Child Safety Standards</h1>
<p>Raonson is committed to protecting children on our platform. We maintain a zero-tolerance policy for any form of child sexual abuse and exploitation (CSAE).</p>
</div>

<h2>1. Zero Tolerance Policy</h2>
<p>Raonson has <strong>zero tolerance</strong> for Child Sexual Abuse and Exploitation (CSAE) content. Any content that sexually exploits or endangers children is strictly prohibited and will result in:</p>
<ul>
<li>Immediate content removal</li>
<li>Permanent account suspension</li>
<li>Cooperation with law enforcement upon valid legal request</li>
</ul>

<h2>2. Prohibited Content</h2>
<p>The following content is strictly prohibited on Raonson:</p>
<ul>
<li>Child Sexual Abuse Material (CSAM) of any kind</li>
<li>Content that sexualizes minors in any way</li>
<li>Grooming or solicitation of minors</li>
<li>Any content that endangers children</li>
<li>Sharing of minors' personal information without parental consent</li>
<li>Content promoting or normalizing inappropriate relationships with minors</li>
</ul>

<h2>3. How to Report</h2>
<p>If you encounter any content that may violate our child safety standards:</p>

<h3>In-App Reporting</h3>
<p>Users can report any content — posts, reels, stories, comments, messages, and user profiles — using the report button available on every content type. Select the <strong>"Child Safety" (Бехатарии кӯдакон)</strong> category for immediate priority review.</p>

<h3>Email Reporting</h3>
<p>You can contact us directly at: <a href="mailto:ehsonmahmadmurodov@gmail.com">ehsonmahmadmurodov@gmail.com</a></p>

<h3>Report Processing</h3>
<ul>
<li>All child safety reports are <strong>prioritized</strong> for prompt review</li>
<li>Reports include a reason category and optional description for context</li>
<li>Moderation workflow: Pending → Under Review → Action Taken / Dismissed</li>
<li>Full audit trail with moderator ID and review timestamps</li>
</ul>

<h2>4. Enforcement Actions</h2>
<p>Upon confirmation of a child safety violation, Raonson takes the following actions:</p>
<ul>
<li>Immediate removal of the violating content</li>
<li>Permanent suspension of the offending account</li>
<li>Cooperation with law enforcement upon valid legal request</li>
<li>Report records (reporter, reason, timestamp, moderator action) are retained for audit</li>
</ul>

<h2>5. Age Requirements</h2>
<ul>
<li>Raonson is <strong>not intended for children under 13</strong> years of age</li>
<li>Users must confirm they are 13 or older during registration</li>
<li>Accounts identified as belonging to users under 13 are immediately terminated</li>
<li>We do not knowingly collect personal information from children under 13</li>
</ul>

<h2>6. Designated Point of Contact</h2>
<div class="contact-box">
<p><strong>Child Safety Contact</strong></p>
<p>Email: <a href="mailto:ehsonmahmadmurodov@gmail.com">ehsonmahmadmurodov@gmail.com</a></p>
<p>Organization: Raonson App</p>
<p>Child safety reports are prioritized for prompt review.</p>
<p>App package: com.raonson.app</p>
</div>

<h2>7. Community Guidelines</h2>
<p>Our community guidelines explicitly address child safety:</p>
<ul>
<li>All users must be 13 years or older</li>
<li>No content depicting, promoting, or facilitating child exploitation</li>
<li>No contact with minors for inappropriate purposes</li>
<li>Users are encouraged to report suspicious behavior immediately</li>
<li>Repeated minor violations result in escalating enforcement</li>
</ul>
<p>For full community guidelines, see the Community Guidelines section in the app settings.</p>

<h2>8. Privacy Protections for Minors</h2>
<ul>
<li>We do not knowingly collect data from users under 13</li>
<li>Accounts of underage users are terminated and their data is deleted</li>
<li>We do not sell or share minor users' data with third parties</li>
<li>Our privacy policy details data handling practices for all users</li>
</ul>

<div class="footer">
<p><strong>Raonson App</strong> — com.raonson.app</p>
<p>Last updated: August 2026</p>
<p>Contact: <a href="mailto:ehsonmahmadmurodov@gmail.com">ehsonmahmadmurodov@gmail.com</a></p>
</div>
</body>
</html>`
