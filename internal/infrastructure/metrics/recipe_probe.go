package metrics

import (
	"github.com/kieranajp/the-bluer-book/internal/infrastructure/logger"
	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/promauto"
)

var (
	recipeOps = promauto.NewCounterVec(prometheus.CounterOpts{
		Name: "bluerbook_recipe_operations_total",
		Help: "Total recipe operations by type.",
	}, []string{"operation"})

	mealPlanChanges = promauto.NewCounterVec(prometheus.CounterOpts{
		Name: "bluerbook_meal_plan_changes_total",
		Help: "Total meal plan changes by action.",
	}, []string{"action"})

	recipeSearchResults = promauto.NewHistogram(prometheus.HistogramOpts{
		Name:    "bluerbook_recipe_search_results",
		Help:    "Distribution of recipe search result counts.",
		Buckets: []float64{0, 1, 5, 10, 20, 50, 100},
	})

	recipeErrors = promauto.NewCounterVec(prometheus.CounterOpts{
		Name: "bluerbook_recipe_errors_total",
		Help: "Total recipe operation errors by operation.",
	}, []string{"operation"})
)

// RecipeProbe implements recipe.Probe with Prometheus metrics and structured logging.
type RecipeProbe struct {
	logger logger.Logger
}

func NewRecipeProbe(log logger.Logger) *RecipeProbe {
	return &RecipeProbe{logger: log}
}

func (p *RecipeProbe) RecipeCreated(name string) {
	recipeOps.WithLabelValues("created").Inc()
	p.logger.Info().Str("probe", "recipe").Str("name", name).Msg("recipe created")
}

func (p *RecipeProbe) RecipeUpdated(name string) {
	recipeOps.WithLabelValues("updated").Inc()
	p.logger.Info().Str("probe", "recipe").Str("name", name).Msg("recipe updated")
}

func (p *RecipeProbe) RecipeArchived(id string) {
	recipeOps.WithLabelValues("archived").Inc()
	p.logger.Info().Str("probe", "recipe").Str("recipe_id", id).Msg("recipe archived")
}

func (p *RecipeProbe) RecipeRestored(id string) {
	recipeOps.WithLabelValues("restored").Inc()
	p.logger.Info().Str("probe", "recipe").Str("recipe_id", id).Msg("recipe restored")
}

func (p *RecipeProbe) MealPlanChanged(action string, recipeID string) {
	mealPlanChanges.WithLabelValues(action).Inc()
	p.logger.Info().Str("probe", "recipe").Str("action", action).Str("recipe_id", recipeID).Msg("meal plan changed")
}

func (p *RecipeProbe) RecipeSearched(resultCount int) {
	recipeSearchResults.Observe(float64(resultCount))
	p.logger.Debug().Str("probe", "recipe").Int("result_count", resultCount).Msg("recipe search performed")
}

func (p *RecipeProbe) RecipeError(operation string, err error) {
	recipeErrors.WithLabelValues(operation).Inc()
	p.logger.Error().Str("probe", "recipe").Str("operation", operation).Err(err).Msg("recipe operation failed")
}
