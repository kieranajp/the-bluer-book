package metrics

import (
	"context"
	"database/sql"
	"encoding/json"
	"errors"
	"net/http"
	"net/http/httptest"
	"os"
	"regexp"
	"strconv"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/prometheus/client_golang/prometheus"
	dto "github.com/prometheus/client_model/go"

	"github.com/kieranajp/the-bluer-book/internal/infrastructure/logger"
	"github.com/kieranajp/the-bluer-book/internal/infrastructure/storage/db"
)

type failingDBTX struct{ db.DBTX }

func (failingDBTX) ExecContext(context.Context, string, ...interface{}) (sql.Result, error) {
	return nil, errors.New("boom")
}

// exerciseEveryProbe gives each vector a child, since a vector with none is
// absent from Gather.
func exerciseEveryProbe(t *testing.T) {
	t.Helper()
	log := logger.New(logger.LogLevelError)
	boom := errors.New("boom")

	r := NewRecipeProbe(log)
	r.RecipeCreated("x")
	r.RecipeUpdated("x")
	r.RecipeArchived("x")
	r.RecipeRestored("x")
	r.MealPlanChanged("add", "x")
	r.RecipeSearched(1)
	r.RecipeError("create", boom)

	p := NewPantryProbe(log)
	p.PantryChanged("add", "x")
	p.PantryError("add", boom)
	p.UnknownIngredient("add", "x")

	c := NewChatProbe(log)
	c.SessionCreated("x")
	c.MessageReceived("x")
	c.ResponseCompleted("x", time.Second, 1)
	c.ChatError(boom)

	a := NewAccountProbe(log)
	a.UserProvisioned("x")
	a.MembershipChanged("add", uuid.New())
	a.InvitationRefused("expired")
	a.AccountError("provision", boom)

	HTTPMetrics(http.NotFoundHandler()).ServeHTTP(httptest.NewRecorder(), httptest.NewRequest(http.MethodGet, "/api/recipes", nil))
	NewInstrumentedDBTX(failingDBTX{}).ExecContext(context.Background(), "-- name: X :exec\nSELECT 1")

	pool, err := sql.Open("postgres", "")
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { pool.Close() })
	RegisterDBStats(pool)
}

type series struct{ labels map[string]map[string]bool }

func (s series) add(name, value string) {
	if s.labels[name] == nil {
		s.labels[name] = map[string]bool{}
	}
	s.labels[name][value] = true
}

func gathered(t *testing.T) map[string]series {
	t.Helper()
	families, err := prometheus.DefaultGatherer.Gather()
	if err != nil {
		t.Fatal(err)
	}
	out := map[string]series{}
	for _, f := range families {
		s := series{labels: map[string]map[string]bool{}}
		for _, m := range f.GetMetric() {
			for _, l := range m.GetLabel() {
				s.add(l.GetName(), l.GetValue())
			}
			for _, q := range m.GetSummary().GetQuantile() {
				s.add("quantile", strconv.FormatFloat(q.GetQuantile(), 'g', -1, 64))
			}
		}
		out[f.GetName()] = s
		if f.GetType() == dto.MetricType_HISTOGRAM || f.GetType() == dto.MetricType_SUMMARY {
			for _, suffix := range []string{"_bucket", "_count", "_sum"} {
				out[f.GetName()+suffix] = s
			}
		}
	}
	return out
}

func dashboardExprs(t *testing.T, v any) []string {
	switch v := v.(type) {
	case map[string]any:
		var out []string
		for k, child := range v {
			if s, ok := child.(string); ok && k == "expr" {
				out = append(out, s)
				continue
			}
			out = append(out, dashboardExprs(t, child)...)
		}
		return out
	case []any:
		var out []string
		for _, child := range v {
			out = append(out, dashboardExprs(t, child)...)
		}
		return out
	}
	return nil
}

var (
	selector     = regexp.MustCompile(`([a-zA-Z_:][a-zA-Z0-9_:]*)\{([^}]*)\}`)
	equalMatcher = regexp.MustCompile(`(\w+)="([^"$]*)"`)
)

func TestDashboardQueriesOnlyMetricsTheServerExports(t *testing.T) {
	raw, err := os.ReadFile("../../../charts/bluer-book/dashboards/dashboard.json")
	if err != nil {
		t.Fatal(err)
	}
	var dashboard any
	if err := json.Unmarshal(raw, &dashboard); err != nil {
		t.Fatal(err)
	}

	exerciseEveryProbe(t)
	exported := gathered(t)

	exprs := dashboardExprs(t, dashboard)
	if len(exprs) == 0 {
		t.Fatal("the dashboard holds no queries")
	}
	for _, expr := range exprs {
		for _, sel := range selector.FindAllStringSubmatch(expr, -1) {
			name, matchers := sel[1], sel[2]
			s, ok := exported[name]
			if !ok {
				t.Errorf("the dashboard queries %s, which the server does not export (or this test never exercises)", name)
				continue
			}
			for _, m := range equalMatcher.FindAllStringSubmatch(matchers, -1) {
				if !s.labels[m[1]][m[2]] {
					t.Errorf("the dashboard matches %s{%s=%q}, which the server never emits", name, m[1], m[2])
				}
			}
		}
	}
}
