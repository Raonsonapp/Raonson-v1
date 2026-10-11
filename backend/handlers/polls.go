package handlers

// Пурсиш ва викторина дар ПОСТ (на танҳо дар сторис).
//
//   POST /posts {..., poll: {question, options[2..4], correctIndex?, endsAt?}}
//   GET  /posts/:id/poll             — ҳолат барои тамошобин
//   POST /posts/:id/poll/vote        — {option}; як овоз, бозгашт нест
//   GET  /posts/:id/poll/voters      — ?option=N, танҳо муаллиф
//
// Натиҷа танҳо баъди овоз, барои муаллиф ё баъди анҷом нишон дода
// мешавад (features.PollResultsVisible). Ҷавоби дурусти викторина ҳам.
// Ҳар рӯйхати пост танҳо `hasPoll` медиҳад; ҳолати пурраро корт
// алоҳида мегирад, то лента вазнин нашавад ва ҳама ҷо як рақам бошад.

import (
	"context"
	"net/http"
	"strconv"
	"time"

	"raonson/db"
	"raonson/features"
	mw "raonson/middleware"

	"github.com/gin-gonic/gin"
)

// attachPollFlags — ба ҳар пост `hasPoll` илова мекунад (як дархост).
func attachPollFlags(posts []gin.H) {
	if len(posts) == 0 || db.Pool == nil {
		return
	}
	ids := make([]string, 0, len(posts))
	for _, p := range posts {
		if id, ok := p["_id"].(string); ok {
			ids = append(ids, id)
		}
	}
	has := map[string]bool{}
	rows, err := db.Pool.Query(context.Background(),
		`SELECT post_id FROM post_polls WHERE post_id = ANY($1)`, ids)
	if err == nil {
		for rows.Next() {
			var id string
			if rows.Scan(&id) == nil {
				has[id] = true
			}
		}
		rows.Close()
	}
	for _, p := range posts {
		id, _ := p["_id"].(string)
		p["hasPoll"] = has[id]
	}
}

// pollState — ҳолати пурсиш барои тамошобин. ok=false — пурсиш нест.
func pollState(ctx context.Context, postID, viewer string) (gin.H, string, bool) {
	var question, author string
	var options []string
	var correct *int
	var endsAt *time.Time
	if err := db.Pool.QueryRow(ctx, `
		SELECT pp.question, pp.options, pp.correct_index, pp.ends_at, p.user_id
		  FROM post_polls pp JOIN posts p ON p.id = pp.post_id
		 WHERE pp.post_id=$1`, postID).Scan(&question, &options, &correct, &endsAt, &author); err != nil {
		return nil, "", false
	}
	counts := make([]int, len(options))
	rows, err := db.Pool.Query(ctx, `SELECT option_index, COUNT(*) FROM post_poll_votes
		WHERE post_id=$1 GROUP BY option_index`, postID)
	if err == nil {
		for rows.Next() {
			var i, n int
			if rows.Scan(&i, &n) == nil && i >= 0 && i < len(counts) {
				counts[i] = n
			}
		}
		rows.Close()
	}
	myVote := -1
	db.Pool.QueryRow(ctx, `SELECT option_index FROM post_poll_votes WHERE post_id=$1 AND user_id=$2`,
		postID, viewer).Scan(&myVote)

	now := time.Now()
	ended := features.PollEnded(now, endsAt)
	isAuthor := viewer == author
	visible := features.PollResultsVisible(isAuthor, myVote >= 0, ended)
	total := 0
	for _, n := range counts {
		total += n
	}
	pct := features.PollPercents(counts)
	opts := make([]gin.H, len(options))
	for i, o := range options {
		opts[i] = gin.H{"text": o}
		if visible {
			opts[i]["votes"] = counts[i]
			opts[i]["percent"] = pct[i]
		}
	}
	out := gin.H{
		"postId": postID, "question": question, "options": opts,
		"isQuiz": correct != nil, "endsAt": endsAt, "ended": ended,
		"myVote": myVote, "isAuthor": isAuthor, "resultsVisible": visible,
		"canVote": !isAuthor && myVote < 0 && !ended,
	}
	if visible {
		out["totalVotes"] = total
		if correct != nil {
			out["correctIndex"] = *correct
			if myVote >= 0 {
				out["myCorrect"] = myVote == *correct
			}
		}
	}
	return out, author, true
}

// GET /posts/:id/poll
func GetPostPoll(c *gin.Context) {
	st, _, ok := pollState(c.Request.Context(), c.Param("id"), mw.UID(c))
	if !ok {
		notFound(c)
		return
	}
	c.JSON(http.StatusOK, st)
}

// POST /posts/:id/poll/vote {option}
func VotePostPoll(c *gin.Context) {
	me := mw.UID(c)
	ctx := c.Request.Context()
	pid := c.Param("id")
	st, author, ok := pollState(ctx, pid, me)
	if !ok {
		notFound(c)
		return
	}
	var b struct {
		Option *int `json:"option"`
	}
	if err := c.ShouldBindJSON(&b); err != nil || b.Option == nil {
		badRequest(c, "option лозим аст")
		return
	}
	if me == author {
		c.JSON(http.StatusForbidden, gin.H{"message": "Ба пурсиши худ овоз дода намешавад"})
		return
	}
	if st["ended"] == true {
		c.JSON(http.StatusConflict, gin.H{"message": "Пурсиш тамом шуд", "poll": st})
		return
	}
	opts, _ := st["options"].([]gin.H)
	if *b.Option < 0 || *b.Option >= len(opts) {
		badRequest(c, "Ҷавоби нодуруст")
		return
	}
	tag, err := db.Pool.Exec(ctx, `INSERT INTO post_poll_votes(post_id, user_id, option_index)
		VALUES ($1,$2,$3) ON CONFLICT DO NOTHING`, pid, me, *b.Option)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"message": "Сабт нашуд"})
		return
	}
	if tag.RowsAffected() == 0 {
		st, _, _ = pollState(ctx, pid, me)
		c.JSON(http.StatusConflict, gin.H{"message": "Шумо аллакай овоз додаед", "poll": st})
		return
	}
	notify(author, me, "post_poll_vote", pid)
	pushNotify(author, me, "post_poll_vote", pid, "")
	st, _, _ = pollState(ctx, pid, me)
	c.JSON(http.StatusOK, st)
}

// GET /posts/:id/poll/voters?option=N — танҳо муаллиф.
func GetPostPollVoters(c *gin.Context) {
	me := mw.UID(c)
	ctx := c.Request.Context()
	pid := c.Param("id")
	_, author, ok := pollState(ctx, pid, me)
	if !ok {
		notFound(c)
		return
	}
	if me != author {
		c.JSON(http.StatusForbidden, gin.H{"message": "Танҳо муаллиф овоздиҳандагонро мебинад"})
		return
	}
	opt := -1
	if s := c.Query("option"); s != "" {
		if n, err := strconv.Atoi(s); err == nil {
			opt = n
		}
	}
	rows, err := db.Pool.Query(ctx, `
		SELECT v.option_index, v.created_at, u.id, u.username, COALESCE(u.avatar,''),
		       COALESCE(u.verified,false)
		  FROM post_poll_votes v JOIN users u ON u.id = v.user_id
		 WHERE v.post_id=$1 AND ($2 < 0 OR v.option_index=$2)
		   AND NOT EXISTS (SELECT 1 FROM blocks b
		        WHERE (b.blocker_id=$3 AND b.blocked_id=v.user_id)
		           OR (b.blocker_id=v.user_id AND b.blocked_id=$3))
		 ORDER BY v.created_at DESC LIMIT 500`, pid, opt, me)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"message": "Хато"})
		return
	}
	defer rows.Close()
	list := []gin.H{}
	for rows.Next() {
		var idx int
		var at time.Time
		var uid, uname, avatar string
		var verified bool
		if rows.Scan(&idx, &at, &uid, &uname, &avatar, &verified) != nil {
			continue
		}
		list = append(list, gin.H{"option": idx, "votedAt": at,
			"user": gin.H{"_id": uid, "username": uname, "avatar": avatar, "verified": verified}})
	}
	c.JSON(http.StatusOK, gin.H{"voters": list})
}
