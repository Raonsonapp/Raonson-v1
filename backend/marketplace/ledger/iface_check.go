package ledger

import (
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

// Compile-time: ҳам транзаксия ва ҳам pool бояд интерфейси Tx-ро қонеъ
// кунанд — вагарна ledger дар яке аз онҳо кор намекард.
var (
	_ Tx = (pgx.Tx)(nil)
	_ Tx = (*pgxpool.Pool)(nil)
)
