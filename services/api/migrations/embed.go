// Package migrations embeds the SQL files applied on startup, in name order.
package migrations

import "embed"

//go:embed *.sql
var FS embed.FS
