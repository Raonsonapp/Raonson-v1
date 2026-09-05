package handlers

// Даъват — коди корбар ва ҳисоби воқеӣ.
//
// Мансубият ин ҷо сабт НАМЕШАВАД: он танҳо ҳангоми бақайдгирӣ рӯй
// медиҳад (ниг. auth.go). Вагарна ҳар кас метавонист баъд аз як сол
// худро «даъватшуда» эълон кунад.

import (
	"net/http"

	"github.com/gin-gonic/gin"

	"raonson/db"
	mw "raonson/middleware"
	"raonson/referral"
)

// GET /referrals/me — коди даъват ва ҳисоб.
func GetMyReferrals(c *gin.Context) {
	s, err := referral.GetSummary(c.Request.Context(), db.Pool, mw.UID(c), 20)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"message": "Хатои сервер"})
		return
	}
	c.JSON(http.StatusOK, s)
}
