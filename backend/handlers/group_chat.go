package handlers

import (
	"context"
	"net/http"

	"raonson/db"
	mw "raonson/middleware"

	"github.com/gin-gonic/gin"
)

// ── helpers ───────────────────────────────────────────────────────

func isGroupMember(groupID, userID string) bool {
	var ok bool
	db.Pool.QueryRow(context.Background(),
		`SELECT EXISTS(SELECT 1 FROM group_members WHERE group_id=$1 AND user_id=$2)`,
		groupID, userID).Scan(&ok)
	return ok
}

func isGroupAdmin(groupID, userID string) bool {
	var role string
	db.Pool.QueryRow(context.Background(),
		`SELECT role FROM group_members WHERE group_id=$1 AND user_id=$2`,
		groupID, userID).Scan(&role)
	return role == "admin"
}

// groupMemberIDs — барои broadcast realtime.
func groupMemberIDs(groupID string) []string {
	ids := []string{}
	rows, err := db.Pool.Query(context.Background(),
		`SELECT user_id FROM group_members WHERE group_id=$1`, groupID)
	if err != nil {
		return ids
	}
	defer rows.Close()
	for rows.Next() {
		var id string
		rows.Scan(&id)
		ids = append(ids, id)
	}
	return ids
}

// ── POST /groups  {name, memberIds[]} ─────────────────────────────
func CreateGroup(c *gin.Context) {
	myID := mw.UID(c)
	var b struct {
		Name      string   `json:"name"`
		Avatar    string   `json:"avatar"`
		MemberIDs []string `json:"memberIds"`
	}
	c.ShouldBindJSON(&b)
	b.Name = clampRunes(b.Name, 60)
	if b.Name == "" {
		b.Name = "Гурӯҳ"
	}

	var gid, invite string
	err := db.Pool.QueryRow(context.Background(),
		`INSERT INTO group_chats(name,avatar,owner_id) VALUES($1,$2,$3)
		 RETURNING id, invite_token`,
		b.Name, b.Avatar, myID).Scan(&gid, &invite)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"message": "create failed: " + err.Error()})
		return
	}

	// Соҳиб = админ
	db.Pool.Exec(context.Background(),
		`INSERT INTO group_members(group_id,user_id,role) VALUES($1,$2,'admin')
		 ON CONFLICT DO NOTHING`, gid, myID)
	for _, uid := range b.MemberIDs {
		if uid == "" || uid == myID {
			continue
		}
		db.Pool.Exec(context.Background(),
			`INSERT INTO group_members(group_id,user_id,role) VALUES($1,$2,'member')
			 ON CONFLICT DO NOTHING`, gid, uid)
	}

	c.JSON(http.StatusCreated, gin.H{
		"_id": gid, "name": b.Name, "avatar": b.Avatar,
		"ownerId": myID, "inviteToken": invite,
	})
}

// ── GET /groups → гурӯҳҳои ман ────────────────────────────────────
func GetMyGroups(c *gin.Context) {
	myID := mw.UID(c)
	rows, err := db.Pool.Query(context.Background(), `
		SELECT g.id, g.name, g.avatar,
		       (SELECT COUNT(*) FROM group_members gm2 WHERE gm2.group_id=g.id) AS members,
		       COALESCE((SELECT m.text FROM messages m WHERE m.group_id=g.id ORDER BY m.created_at DESC LIMIT 1),'') AS last_text,
		       COALESCE((SELECT m.type FROM messages m WHERE m.group_id=g.id ORDER BY m.created_at DESC LIMIT 1),'text') AS last_type,
		       (SELECT m.created_at FROM messages m WHERE m.group_id=g.id ORDER BY m.created_at DESC LIMIT 1) AS last_at
		FROM group_chats g
		JOIN group_members gm ON gm.group_id=g.id AND gm.user_id=$1
		ORDER BY last_at DESC NULLS LAST, g.created_at DESC`, myID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"message": "get groups failed"})
		return
	}
	defer rows.Close()

	groups := []gin.H{}
	for rows.Next() {
		var gid, name, avatar, lastText, lastType string
		var members int
		var lastAt interface{}
		rows.Scan(&gid, &name, &avatar, &members, &lastText, &lastType, &lastAt)
		groups = append(groups, gin.H{
			"_id": gid, "name": name, "avatar": avatar, "members": members,
			"lastText": lastText, "lastType": lastType, "lastAt": lastAt,
		})
	}
	c.JSON(http.StatusOK, gin.H{"groups": groups})
}

// ── GET /groups/:id → маълумот + аъзоён ───────────────────────────
func GetGroupInfo(c *gin.Context) {
	myID := mw.UID(c)
	gid := c.Param("id")
	if !isGroupMember(gid, myID) {
		c.JSON(http.StatusForbidden, gin.H{"message": "not a member"})
		return
	}
	var name, avatar, ownerID, invite string
	err := db.Pool.QueryRow(context.Background(),
		`SELECT name,avatar,owner_id,invite_token FROM group_chats WHERE id=$1`,
		gid).Scan(&name, &avatar, &ownerID, &invite)
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"message": "group not found"})
		return
	}
	rows, _ := db.Pool.Query(context.Background(), `
		SELECT u.id,u.username,COALESCE(u.avatar,''),u.verified,gm.role
		FROM group_members gm JOIN users u ON u.id=gm.user_id
		WHERE gm.group_id=$1
		ORDER BY (gm.role='admin') DESC, gm.joined_at ASC`, gid)
	members := []gin.H{}
	if rows != nil {
		defer rows.Close()
		for rows.Next() {
			var uid, uname, uavatar, role string
			var verified bool
			rows.Scan(&uid, &uname, &uavatar, &verified, &role)
			members = append(members, gin.H{
				"_id": uid, "username": uname, "avatar": uavatar,
				"verified": verified, "role": role,
			})
		}
	}
	c.JSON(http.StatusOK, gin.H{
		"_id": gid, "name": name, "avatar": avatar, "ownerId": ownerID,
		"inviteToken": invite, "isAdmin": isGroupAdmin(gid, myID),
		"members": members,
	})
}

// ── POST /groups/:id/members {userIds[]} (админ) ──────────────────
func AddGroupMembers(c *gin.Context) {
	myID := mw.UID(c)
	gid := c.Param("id")
	if !isGroupAdmin(gid, myID) {
		c.JSON(http.StatusForbidden, gin.H{"message": "admin only"})
		return
	}
	var b struct {
		UserIDs []string `json:"userIds"`
	}
	c.ShouldBindJSON(&b)
	for _, uid := range b.UserIDs {
		if uid == "" {
			continue
		}
		db.Pool.Exec(context.Background(),
			`INSERT INTO group_members(group_id,user_id,role) VALUES($1,$2,'member')
			 ON CONFLICT DO NOTHING`, gid, uid)
	}
	c.JSON(http.StatusOK, gin.H{"ok": true})
}

// ── DELETE /groups/:id/members/:userId (админ) ────────────────────
func RemoveGroupMember(c *gin.Context) {
	myID := mw.UID(c)
	gid := c.Param("id")
	target := c.Param("userId")
	if !isGroupAdmin(gid, myID) {
		c.JSON(http.StatusForbidden, gin.H{"message": "admin only"})
		return
	}
	// Соҳибро хориҷ кардан мумкин нест.
	var ownerID string
	db.Pool.QueryRow(context.Background(),
		`SELECT owner_id FROM group_chats WHERE id=$1`, gid).Scan(&ownerID)
	if target == ownerID {
		c.JSON(http.StatusForbidden, gin.H{"message": "cannot remove owner"})
		return
	}
	db.Pool.Exec(context.Background(),
		`DELETE FROM group_members WHERE group_id=$1 AND user_id=$2`, gid, target)
	c.JSON(http.StatusOK, gin.H{"ok": true})
}

// ── POST /groups/:id/leave ────────────────────────────────────────
func LeaveGroup(c *gin.Context) {
	myID := mw.UID(c)
	gid := c.Param("id")
	db.Pool.Exec(context.Background(),
		`DELETE FROM group_members WHERE group_id=$1 AND user_id=$2`, gid, myID)
	// Агар ягон аъзо намонад — гурӯҳро нест кун.
	var cnt int
	db.Pool.QueryRow(context.Background(),
		`SELECT COUNT(*) FROM group_members WHERE group_id=$1`, gid).Scan(&cnt)
	if cnt == 0 {
		db.Pool.Exec(context.Background(), `DELETE FROM group_chats WHERE id=$1`, gid)
	}
	c.JSON(http.StatusOK, gin.H{"ok": true})
}

// ── GET /groups/:id/messages ──────────────────────────────────────
func GetGroupMessages(c *gin.Context) {
	myID := mw.UID(c)
	gid := c.Param("id")
	if !isGroupMember(gid, myID) {
		c.JSON(http.StatusForbidden, gin.H{"message": "not a member"})
		return
	}
	page := toInt(c.Query("page"), 1)
	limit := toInt(c.Query("limit"), 30)
	offset := (page - 1) * limit
	rows, err := db.Pool.Query(context.Background(), `
		SELECT m.id, m.text, COALESCE(m.type,'text'), COALESCE(m.media_url,''),
		       m.created_at, u.id, u.username, COALESCE(u.avatar,''), u.verified
		FROM messages m JOIN users u ON u.id=m.sender_id
		WHERE m.group_id=$1
		ORDER BY m.created_at DESC LIMIT $2 OFFSET $3`, gid, limit, offset)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"message": "get messages failed"})
		return
	}
	defer rows.Close()
	msgs := []gin.H{}
	for rows.Next() {
		var mid, text, mtype, murl, uid, uname, uavatar string
		var verified bool
		var createdAt interface{}
		rows.Scan(&mid, &text, &mtype, &murl, &createdAt, &uid, &uname, &uavatar, &verified)
		msgs = append(msgs, gin.H{
			"_id": mid, "groupId": gid, "text": text, "type": mtype,
			"mediaUrl": murl, "createdAt": createdAt,
			"sender": gin.H{"_id": uid, "username": uname, "avatar": uavatar, "verified": verified},
		})
	}
	c.JSON(http.StatusOK, gin.H{"messages": msgs, "page": page, "limit": limit})
}

// ── POST /groups/:id/messages {text,type,mediaUrl} ────────────────
func SendGroupMessage(c *gin.Context) {
	myID := mw.UID(c)
	gid := c.Param("id")
	if !isGroupMember(gid, myID) {
		c.JSON(http.StatusForbidden, gin.H{"message": "not a member"})
		return
	}
	var b struct {
		Text     string `json:"text"`
		Type     string `json:"type"`
		MediaURL string `json:"mediaUrl"`
	}
	c.ShouldBindJSON(&b)
	b.Text = clampRunes(b.Text, 1000)
	if b.Type == "" {
		b.Type = "text"
	}
	if b.Text == "" && b.MediaURL == "" {
		c.JSON(http.StatusBadRequest, gin.H{"message": "empty message"})
		return
	}
	var mid string
	var createdAt interface{}
	err := db.Pool.QueryRow(context.Background(),
		`INSERT INTO messages(chat_id,group_id,sender_id,receiver_id,text,type,media_url)
		 VALUES($1,$1,$2,'',$3,$4,$5) RETURNING id,created_at`,
		gid, myID, b.Text, b.Type, b.MediaURL).Scan(&mid, &createdAt)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"message": "send failed: " + err.Error()})
		return
	}
	var uname, uavatar string
	var verified bool
	db.Pool.QueryRow(context.Background(),
		`SELECT username,COALESCE(avatar,''),verified FROM users WHERE id=$1`, myID,
	).Scan(&uname, &uavatar, &verified)

	msg := gin.H{
		"_id": mid, "groupId": gid, "text": b.Text, "type": b.Type,
		"mediaUrl": b.MediaURL, "createdAt": createdAt,
		"sender": gin.H{"_id": myID, "username": uname, "avatar": uavatar, "verified": verified},
	}
	// Realtime — ба ҳамаи аъзоён (ғайр аз фиристанда).
	for _, uid := range groupMemberIDs(gid) {
		if uid != myID {
			emitChat("group:new", msg, uid)
		}
	}
	c.JSON(http.StatusCreated, msg)
}

// ── POST /group-join/:token → ҳамроҳ шудан бо линки даъват ────────
func JoinGroupByToken(c *gin.Context) {
	myID := mw.UID(c)
	token := c.Param("token")
	var gid, name string
	err := db.Pool.QueryRow(context.Background(),
		`SELECT id,name FROM group_chats WHERE invite_token=$1`, token).Scan(&gid, &name)
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"message": "invalid invite"})
		return
	}
	db.Pool.Exec(context.Background(),
		`INSERT INTO group_members(group_id,user_id,role) VALUES($1,$2,'member')
		 ON CONFLICT DO NOTHING`, gid, myID)
	c.JSON(http.StatusOK, gin.H{"_id": gid, "name": name})
}
