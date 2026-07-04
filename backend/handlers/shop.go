package handlers

import (
	"context"
	"net/http"

	"raonson/db"
	mw "raonson/middleware"

	"github.com/gin-gonic/gin"
)

// Комиссияи платформа аз ҳар фуруш (5%).
const commissionRate = 0.05

// ── GET /shop → маҳсулотҳо (маркетплейс) ──────────────────────────
func GetShop(c *gin.Context) {
	page := toInt(c.Query("page"), 1)
	limit := toInt(c.Query("limit"), 30)
	offset := (page - 1) * limit
	rows, err := db.Pool.Query(context.Background(), `
		SELECT p.id, COALESCE(p.product_name,''), COALESCE(p.price,0),
		       COALESCE(p.currency,'TJS'), COALESCE(p.shop_address,''),
		       COALESCE(p.shop_lat,0), COALESCE(p.shop_lng,0),
		       COALESCE(p.caption,''), COALESCE(p.in_stock,TRUE),
		       COALESCE(p.contact_raonson,TRUE), COALESCE(p.shop_whatsapp,''),
		       COALESCE(p.shop_phone,''),
		       COALESCE((SELECT url FROM post_media pm WHERE pm.post_id=p.id
		                 ORDER BY position LIMIT 1),'') AS image,
		       u.id, u.username, COALESCE(u.avatar,''), u.verified,
		       COALESCE(p.featured,FALSE)
		FROM posts p JOIN users u ON u.id=p.user_id
		WHERE p.is_product=TRUE
		ORDER BY p.featured DESC, p.created_at DESC LIMIT $1 OFFSET $2`, limit, offset)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"message": "shop failed"})
		return
	}
	defer rows.Close()
	items := []gin.H{}
	for rows.Next() {
		var pid, pname, currency, addr, caption, image string
		var whatsapp, phone string
		var uid, uname, uavatar string
		var price, lat, lng float64
		var inStock, verified, contactRaonson, featured bool
		rows.Scan(&pid, &pname, &price, &currency, &addr, &lat, &lng,
			&caption, &inStock, &contactRaonson, &whatsapp, &phone,
			&image, &uid, &uname, &uavatar, &verified, &featured)
		items = append(items, gin.H{
			"_id": pid, "productName": pname, "price": price,
			"currency": currency, "shopAddress": addr,
			"shopLat": lat, "shopLng": lng, "caption": caption,
			"inStock": inStock, "image": image, "featured": featured,
			"contactRaonson": contactRaonson,
			"shopWhatsapp": whatsapp, "shopPhone": phone,
			"seller": gin.H{"_id": uid, "username": uname,
				"avatar": uavatar, "verified": verified},
		})
	}
	c.JSON(http.StatusOK, gin.H{"products": items})
}

// ── POST /posts/:id/feature → маҳсулро дар магоза «беҳтарин» кардан ──
func ToggleProductFeature(c *gin.Context) {
	myID := mw.UID(c)
	postID := c.Param("id")
	var featured bool
	err := db.Pool.QueryRow(context.Background(),
		`UPDATE posts SET featured = NOT COALESCE(featured,false)
		 WHERE id=$1 AND user_id=$2 AND is_product=TRUE
		 RETURNING featured`, postID, myID).Scan(&featured)
	if err != nil {
		c.JSON(http.StatusForbidden, gin.H{"message": "Танҳо соҳиби маҳсул"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"featured": featured})
}

// ── POST /posts/:id/order → фармоиш додан ─────────────────────────
func PlaceOrder(c *gin.Context) {
	myID := mw.UID(c)
	postID := c.Param("id")
	var b struct {
		Note string `json:"note"`
	}
	c.ShouldBindJSON(&b)

	var sellerID, currency string
	var price float64
	var isProduct bool
	err := db.Pool.QueryRow(context.Background(),
		`SELECT user_id, COALESCE(price,0), COALESCE(currency,'TJS'),
		        COALESCE(is_product,FALSE) FROM posts WHERE id=$1`,
		postID).Scan(&sellerID, &price, &currency, &isProduct)
	if err != nil || !isProduct {
		c.JSON(http.StatusBadRequest, gin.H{"message": "not a product"})
		return
	}
	if sellerID == myID {
		c.JSON(http.StatusBadRequest, gin.H{"message": "cannot buy your own product"})
		return
	}
	commission := price * commissionRate
	var oid string
	err = db.Pool.QueryRow(context.Background(),
		`INSERT INTO orders(post_id,buyer_id,seller_id,price,commission,currency,note)
		 VALUES($1,$2,$3,$4,$5,$6,$7) RETURNING id`,
		postID, myID, sellerID, price, commission, currency,
		clampRunes(b.Note, 300)).Scan(&oid)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"message": "order failed"})
		return
	}
	notify(sellerID, myID, "order", postID)
	pushNotify(sellerID, myID, "order", postID, "маҳсули шуморо фармоиш дод")

	// Cashback — харидор 5% арзиши харидро ҳамчун ситора мегирад (ҳадди ақал 1).
	cashback := int(price * 0.05)
	if cashback < 1 {
		cashback = 1
	}
	db.Pool.Exec(context.Background(),
		`UPDATE users SET stars_balance = COALESCE(stars_balance,0) + $1 WHERE id=$2`,
		cashback, myID)

	c.JSON(http.StatusCreated, gin.H{
		"_id": oid, "postId": postID, "price": price,
		"commission": commission, "currency": currency, "status": "pending",
		"cashback": cashback,
	})
}

// ── GET /orders → фармоишҳои ман (харидор) ────────────────────────
func GetMyOrders(c *gin.Context) {
	myID := mw.UID(c)
	rows, err := db.Pool.Query(context.Background(), `
		SELECT o.id, o.post_id, o.price, o.commission, o.currency, o.status,
		       o.created_at, COALESCE(p.product_name,''),
		       u.username, COALESCE(u.avatar,'')
		FROM orders o
		JOIN posts p ON p.id=o.post_id
		JOIN users u ON u.id=o.seller_id
		WHERE o.buyer_id=$1 ORDER BY o.created_at DESC LIMIT 100`, myID)
	c.JSON(http.StatusOK, gin.H{"orders": scanOrders(rows, err, "seller")})
}

// ── GET /orders/selling → фурӯшҳои ман (фурӯшанда) ────────────────
func GetSellingOrders(c *gin.Context) {
	myID := mw.UID(c)
	rows, err := db.Pool.Query(context.Background(), `
		SELECT o.id, o.post_id, o.price, o.commission, o.currency, o.status,
		       o.created_at, COALESCE(p.product_name,''),
		       o.buyer_id, u.username, COALESCE(u.avatar,''),
		       COALESCE((SELECT url FROM post_media pm WHERE pm.post_id=o.post_id
		                 ORDER BY position LIMIT 1),'') AS image
		FROM orders o
		JOIN posts p ON p.id=o.post_id
		JOIN users u ON u.id=o.buyer_id
		WHERE o.seller_id=$1 ORDER BY o.created_at DESC LIMIT 100`, myID)
	out := []gin.H{}
	if err == nil {
		defer rows.Close()
		for rows.Next() {
			var oid, postID, currency, status, pname string
			var buyerID, uname, uavatar, image string
			var price, commission float64
			var createdAt interface{}
			rows.Scan(&oid, &postID, &price, &commission, &currency, &status,
				&createdAt, &pname, &buyerID, &uname, &uavatar, &image)
			out = append(out, gin.H{
				"_id": oid, "id": oid, "postId": postID,
				"price": price, "amount": price, "commission": commission,
				"currency": currency, "status": status, "createdAt": createdAt,
				"productName": pname,
				"buyer":   gin.H{"_id": buyerID, "username": uname, "avatar": uavatar},
				"product": gin.H{"_id": postID, "productName": pname, "image": image},
			})
		}
	}
	c.JSON(http.StatusOK, gin.H{"orders": out})
}

// ── PUT /orders/:id/status → тағйири ҳолати фармоиш (танҳо фурӯшанда) ──
var validOrderStatuses = map[string]bool{
	"pending": true, "confirmed": true, "packed": true, "shipping": true,
	"delivered": true, "returned": true, "refunded": true, "cancelled": true,
}

func UpdateOrderStatus(c *gin.Context) {
	myID := mw.UID(c)
	orderID := c.Param("id")
	var b struct {
		Status string `json:"status"`
	}
	if err := c.ShouldBindJSON(&b); err != nil || !validOrderStatuses[b.Status] {
		c.JSON(http.StatusBadRequest, gin.H{"message": "invalid status"})
		return
	}
	tag, err := db.Pool.Exec(context.Background(),
		`UPDATE orders SET status=$1 WHERE id=$2 AND seller_id=$3`,
		b.Status, orderID, myID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"message": "update failed"})
		return
	}
	if tag.RowsAffected() == 0 {
		c.JSON(http.StatusForbidden, gin.H{"message": "not your order"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"status": b.Status})
}

// ── GET /shop/customers → CRM: харидорони фурӯшанда ────────────────
func GetCustomers(c *gin.Context) {
	myID := mw.UID(c)
	rows, err := db.Pool.Query(context.Background(), `
		SELECT o.buyer_id, u.username, COALESCE(u.avatar,''),
		       COUNT(*)                         AS orders_count,
		       COALESCE(SUM(o.price),0)         AS total_spent,
		       MAX(o.created_at)                AS last_order_at
		FROM orders o
		JOIN users u ON u.id=o.buyer_id
		WHERE o.seller_id=$1
		GROUP BY o.buyer_id, u.username, u.avatar
		ORDER BY total_spent DESC LIMIT 200`, myID)
	out := []gin.H{}
	if err == nil {
		defer rows.Close()
		for rows.Next() {
			var buyerID, uname, uavatar string
			var ordersCount int
			var totalSpent float64
			var lastOrderAt interface{}
			rows.Scan(&buyerID, &uname, &uavatar, &ordersCount, &totalSpent, &lastOrderAt)
			out = append(out, gin.H{
				"_id": buyerID, "username": uname, "avatar": uavatar,
				"ordersCount": ordersCount, "totalSpent": totalSpent,
				"lastOrderAt": lastOrderAt,
			})
		}
	}
	c.JSON(http.StatusOK, gin.H{"customers": out})
}

func scanOrders(rows interface {
	Next() bool
	Scan(...interface{}) error
	Close()
}, err error, party string) []gin.H {
	out := []gin.H{}
	if err != nil {
		return out
	}
	defer rows.Close()
	for rows.Next() {
		var oid, postID, currency, status, pname, uname, uavatar string
		var price, commission float64
		var createdAt interface{}
		rows.Scan(&oid, &postID, &price, &commission, &currency, &status,
			&createdAt, &pname, &uname, &uavatar)
		out = append(out, gin.H{
			"_id": oid, "postId": postID, "price": price,
			"commission": commission, "currency": currency, "status": status,
			"createdAt": createdAt, "productName": pname,
			party: gin.H{"username": uname, "avatar": uavatar},
		})
	}
	return out
}

// ── GET /admin/orders → ҳамаи фармоишҳо + комиссияи умумӣ (соҳиб) ──
func AdminOrders(c *gin.Context) {
	var total float64
	var count int
	db.Pool.QueryRow(context.Background(),
		`SELECT COALESCE(SUM(commission),0), COUNT(*) FROM orders`).Scan(&total, &count)
	rows, err := db.Pool.Query(context.Background(), `
		SELECT o.id, o.price, o.commission, o.currency, o.status, o.created_at,
		       COALESCE(p.product_name,''), bs.username, ss.username
		FROM orders o
		JOIN posts p ON p.id=o.post_id
		JOIN users bs ON bs.id=o.buyer_id
		JOIN users ss ON ss.id=o.seller_id
		ORDER BY o.created_at DESC LIMIT 200`)
	list := []gin.H{}
	if err == nil {
		defer rows.Close()
		for rows.Next() {
			var oid, currency, status, pname, buyer, seller string
			var price, commission float64
			var createdAt interface{}
			rows.Scan(&oid, &price, &commission, &currency, &status,
				&createdAt, &pname, &buyer, &seller)
			list = append(list, gin.H{
				"_id": oid, "price": price, "commission": commission,
				"currency": currency, "status": status, "createdAt": createdAt,
				"productName": pname, "buyer": buyer, "seller": seller,
			})
		}
	}
	c.JSON(http.StatusOK, gin.H{
		"totalCommission": total, "orderCount": count, "orders": list,
	})
}
