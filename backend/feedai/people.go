package feedai

import (
	"context"
	"sort"
)

// Person — натиҷаи «Одамони ман».
type Person struct {
	UserID    string   `json:"userId"`
	Username  string   `json:"username"`
	Avatar    string   `json:"avatar"`
	Bio       string   `json:"bio"`
	Verified  bool     `json:"verified"`
	Followers int      `json:"followersCount"`
	Topics    []string `json:"topics"`
	// Similarity 0..100 — ҳиссаи мавзӯъҳои МУШТАРАК.
	//
	// Ин монандии шахсият НЕСТ ва чунин даъво намешавад: он танҳо
	// мегӯяд, ки мӯҳтавои ин эҷодкор бо шавқи шумо чӣ қадар мувофиқ аст.
	Similarity int `json:"similarity"`
	// Shared — маҳз кадом мавзӯъҳо муштараканд.
	Shared []string `json:"sharedTopics"`
}

// FindPeople эҷодкоронеро меёбад, ки мӯҳтавояшон ба шавқи корбар
// мувофиқ аст.
//
// Монандӣ аз мавзӯъҳои ВОҚЕИИ мӯҳтавои онҳо ҳисоб мешавад, на аз
// тахмин: эҷодкор бояд дар як мавзӯъ мӯҳтаво дошта бошад, то он
// мавзӯъ ба ӯ мансуб дониста шавад.
//
// Корбарони блокшуда, хомӯшкардашуда, бандшуда ва онҳое, ки корбар
// аллакай обуна аст, берун мемонанд.
func FindPeople(ctx context.Context, db DB, userID string,
	wantTopics []string, limit int) ([]Person, error) {

	if limit <= 0 || limit > 50 {
		limit = 20
	}

	// Мавзӯъҳои ҳадаф: он чи корбар навишт, вагарна профили ӯ.
	topics := wantTopics
	if len(topics) == 0 {
		rows, err := db.Query(ctx, `
			SELECT topic_slug FROM feed_topic_prefs
			WHERE user_id=$1 AND score > 0.1
			ORDER BY score DESC LIMIT 8`, userID)
		if err != nil {
			return nil, err
		}
		for rows.Next() {
			var s string
			if err := rows.Scan(&s); err == nil {
				topics = append(topics, s)
			}
		}
		rows.Close()
	}
	if len(topics) == 0 {
		// Ҳеҷ шавқ маълум нест — рӯйхати холӣ. Тахмин намезанем.
		return []Person{}, nil
	}

	// Барои ҳар эҷодкор: чанд мавзӯи ҳадаф дар мӯҳтавояш ҳаст.
	rows, err := db.Query(ctx, `
		WITH creator_topics AS (
		  SELECT p.user_id AS creator_id, ct.topic_slug
		  FROM content_topics ct
		  JOIN posts p ON p.id = ct.content_id AND ct.content_type='post'
		  WHERE ct.topic_slug = ANY($2)
		    AND COALESCE(p.hidden,false)=FALSE
		    AND COALESCE(p.archived,false)=FALSE
		  UNION
		  SELECT r.user_id, ct.topic_slug
		  FROM content_topics ct
		  JOIN reels r ON r.id = ct.content_id AND ct.content_type='reel'
		  WHERE ct.topic_slug = ANY($2)
		)
		SELECT u.id, u.username, COALESCE(u.avatar,''), COALESCE(u.bio,''),
		       COALESCE(u.verified,false), COALESCE(u.followers_count,0),
		       array_agg(DISTINCT ctp.topic_slug) AS shared
		FROM creator_topics ctp
		JOIN users u ON u.id = ctp.creator_id
		WHERE u.id <> $1
		  AND u.banned = FALSE
		  AND COALESCE(u.is_private,false) = FALSE
		  -- Аллакай обуна — «ёфтан» лозим нест.
		  AND NOT EXISTS (SELECT 1 FROM follows f
		        WHERE f.follower_id=$1 AND f.following_id=u.id)
		  AND NOT EXISTS (SELECT 1 FROM blocks b
		        WHERE (b.blocker_id=$1 AND b.blocked_id=u.id)
		           OR (b.blocker_id=u.id AND b.blocked_id=$1))
		  AND NOT EXISTS (SELECT 1 FROM muted_users mu
		        WHERE mu.user_id=$1 AND mu.muted_id=u.id)
		GROUP BY u.id, u.username, u.avatar, u.bio, u.verified, u.followers_count
		ORDER BY COUNT(DISTINCT ctp.topic_slug) DESC,
		         COALESCE(u.followers_count,0) DESC,
		         u.id ASC
		LIMIT $3`, userID, topics, limit)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	out := []Person{}
	for rows.Next() {
		var p Person
		if err := rows.Scan(&p.UserID, &p.Username, &p.Avatar, &p.Bio,
			&p.Verified, &p.Followers, &p.Shared); err != nil {
			continue
		}
		// Ҳиссаи мавзӯъҳои муштарак аз мавзӯъҳои дархостшуда.
		p.Similarity = int(float64(len(p.Shared)) / float64(len(topics)) * 100)
		if p.Similarity > 100 {
			p.Similarity = 100
		}
		p.Topics = p.Shared
		out = append(out, p)
	}
	if err := rows.Err(); err != nil {
		return nil, err
	}

	// Тартиби устувор: монандӣ, баъд пайравон, баъд id.
	sort.SliceStable(out, func(i, j int) bool {
		if out[i].Similarity != out[j].Similarity {
			return out[i].Similarity > out[j].Similarity
		}
		if out[i].Followers != out[j].Followers {
			return out[i].Followers > out[j].Followers
		}
		return out[i].UserID < out[j].UserID
	})
	return out, nil
}
