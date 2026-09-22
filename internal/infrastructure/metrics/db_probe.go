package metrics

import (
	"context"
	"database/sql"
	"errors"
	"regexp"
	"time"

	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/collectors"
	"github.com/prometheus/client_golang/prometheus/promauto"

	"github.com/kieranajp/the-bluer-book/internal/infrastructure/storage/db"
)

var (
	dbQueryDuration = promauto.NewHistogramVec(prometheus.HistogramOpts{
		Name:    "bluerbook_db_query_duration_seconds",
		Help:    "Database query duration in seconds, labelled by sqlc query name.",
		Buckets: []float64{0.001, 0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1, 2.5},
	}, []string{"query"})

	dbQueryErrors = promauto.NewCounterVec(prometheus.CounterOpts{
		Name: "bluerbook_db_query_errors_total",
		Help: "Total database query errors, labelled by sqlc query name.",
	}, []string{"query"})
)

// queryNamePattern pulls a low-cardinality label out of sqlc's `-- name: X
// :kind` header, rather than using the full SQL text as the label.
var queryNamePattern = regexp.MustCompile(`--\s*name:\s*(\w+)`)

func queryName(query string) string {
	if m := queryNamePattern.FindStringSubmatch(query); m != nil {
		return m[1]
	}
	return "unknown"
}

// InstrumentedDBTX wraps every sqlc query for duration and error count.
// Account provisioning's own *sql.Tx isn't covered.
type InstrumentedDBTX struct {
	inner db.DBTX
}

var _ db.DBTX = (*InstrumentedDBTX)(nil)

// NewInstrumentedDBTX wraps inner with Prometheus query instrumentation.
func NewInstrumentedDBTX(inner db.DBTX) *InstrumentedDBTX {
	return &InstrumentedDBTX{inner: inner}
}

func (i *InstrumentedDBTX) observe(query string, start time.Time, err error) {
	name := queryName(query)
	dbQueryDuration.WithLabelValues(name).Observe(time.Since(start).Seconds())
	// sql.ErrNoRows is an ordinary "not found", not a query failure.
	if err != nil && !errors.Is(err, sql.ErrNoRows) {
		dbQueryErrors.WithLabelValues(name).Inc()
	}
}

func (i *InstrumentedDBTX) ExecContext(ctx context.Context, query string, args ...interface{}) (sql.Result, error) {
	start := time.Now()
	res, err := i.inner.ExecContext(ctx, query, args...)
	i.observe(query, start, err)
	return res, err
}

func (i *InstrumentedDBTX) PrepareContext(ctx context.Context, query string) (*sql.Stmt, error) {
	start := time.Now()
	stmt, err := i.inner.PrepareContext(ctx, query)
	i.observe(query, start, err)
	return stmt, err
}

func (i *InstrumentedDBTX) QueryContext(ctx context.Context, query string, args ...interface{}) (*sql.Rows, error) {
	start := time.Now()
	rows, err := i.inner.QueryContext(ctx, query, args...)
	i.observe(query, start, err)
	return rows, err
}

func (i *InstrumentedDBTX) QueryRowContext(ctx context.Context, query string, args ...interface{}) *sql.Row {
	start := time.Now()
	row := i.inner.QueryRowContext(ctx, query, args...)
	// *sql.Row defers its error to Scan, so we can only time the call here.
	i.observe(query, start, nil)
	return row
}

// RegisterDBStats exposes pool stats as go_sql_* metrics. Call once —
// MustRegister panics on a duplicate collector.
func RegisterDBStats(pool *sql.DB) {
	prometheus.MustRegister(collectors.NewDBStatsCollector(pool, "bluerbook"))
}
