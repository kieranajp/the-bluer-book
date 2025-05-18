package mapper

import (
	"database/sql"
	"time"
)

func NullStringToString(ns sql.NullString) string {
	if ns.Valid {
		return ns.String
	}
	return ""
}

func NullInt64ToDuration(ni sql.NullInt64) time.Duration {
	if ni.Valid {
		return time.Duration(ni.Int64) * time.Minute // adjust unit if needed
	}
	return 0
}

func NullInt16ToInt16(ni sql.NullInt16) int16 {
	if ni.Valid {
		return ni.Int16
	}
	return 0
}
