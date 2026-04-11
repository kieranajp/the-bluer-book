package middleware

import (
	"net/http"
	"time"

	"github.com/kieranajp/the-bluer-book/internal/infrastructure/logger"
	"github.com/kieranajp/the-bluer-book/internal/infrastructure/metrics"
)

// AccessLog wraps a handler and logs each request with method, path, status, and duration.
func AccessLog(log logger.Logger, next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		start := time.Now()
		rec := metrics.NewStatusRecorder(w)

		next.ServeHTTP(rec, r)

		log.Info().
			Str("method", r.Method).
			Str("path", r.URL.Path).
			Int("status", rec.StatusCode()).
			Dur("duration", time.Since(start)).
			Msg("request")
	})
}
