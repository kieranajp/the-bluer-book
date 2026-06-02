package metrics

import (
	"github.com/kieranajp/the-bluer-book/internal/infrastructure/logger"
	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/promauto"
)

var (
	pantryChanges = promauto.NewCounterVec(prometheus.CounterOpts{
		Name: "bluerbook_pantry_changes_total",
		Help: "Total pantry changes by action.",
	}, []string{"action"})

	pantryErrors = promauto.NewCounterVec(prometheus.CounterOpts{
		Name: "bluerbook_pantry_errors_total",
		Help: "Total pantry operation errors by operation.",
	}, []string{"operation"})
)

// PantryProbe implements pantry.Probe with Prometheus metrics and structured logging.
type PantryProbe struct {
	logger logger.Logger
}

func NewPantryProbe(log logger.Logger) *PantryProbe {
	return &PantryProbe{logger: log}
}

func (p *PantryProbe) PantryChanged(action string, ingredient string) {
	pantryChanges.WithLabelValues(action).Inc()
	p.logger.Info().Str("probe", "pantry").Str("action", action).Str("ingredient", ingredient).Msg("pantry changed")
}

func (p *PantryProbe) PantryError(operation string, err error) {
	pantryErrors.WithLabelValues(operation).Inc()
	p.logger.Error().Str("probe", "pantry").Str("operation", operation).Err(err).Msg("pantry operation failed")
}
