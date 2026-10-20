package api

import (
	"context"
	"errors"
	"net/http"
	"strings"
	"time"

	"github.com/google/uuid"

	"github.com/kieranajp/the-bluer-book/internal/domain/account"
	"github.com/kieranajp/the-bluer-book/internal/domain/recipe"
	"github.com/kieranajp/the-bluer-book/internal/domain/recipe/service"
	"github.com/kieranajp/the-bluer-book/internal/infrastructure/auth"
	"github.com/kieranajp/the-bluer-book/internal/infrastructure/logger"
)

// LinkResolver turns a link token into the one home it may read.
type LinkResolver interface {
	ResolveLink(ctx context.Context, token string) (account.Link, error)
}

type linkKey struct{}

// LinkMiddleware takes the home from the bearer link token alone. It reads no
// identity or home header, so a caller cannot name another home.
func LinkMiddleware(links LinkResolver, log logger.Logger) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			token, ok := bearerToken(r)
			if !ok {
				w.Header().Set("WWW-Authenticate", "Bearer")
				writeAPIError(w, http.StatusUnauthorized, "unauthenticated", "Request carries no link token")
				return
			}

			link, err := links.ResolveLink(r.Context(), token)
			if errors.Is(err, account.ErrLinkNotFound) {
				w.Header().Set("WWW-Authenticate", `Bearer error="invalid_token"`)
				writeAPIError(w, http.StatusUnauthorized, "invalid_link", "Link token is unknown or revoked")
				return
			}
			if err != nil {
				log.Error().Err(err).Msg("Failed to resolve link token")
				writeAPIError(w, http.StatusInternalServerError, "link_unresolved", "Failed to resolve the link token")
				return
			}

			ctx := auth.WithHome(context.WithValue(r.Context(), linkKey{}, link), link.HomeID)
			next.ServeHTTP(w, r.WithContext(ctx))
		})
	}
}

// bearerToken refuses a second Authorization header rather than pick one.
func bearerToken(r *http.Request) (string, bool) {
	values := r.Header.Values("Authorization")
	if len(values) != 1 {
		return "", false
	}
	scheme, token, found := strings.Cut(strings.TrimSpace(values[0]), " ")
	if !found || !strings.EqualFold(scheme, "Bearer") {
		return "", false
	}
	token = strings.TrimSpace(token)
	return token, token != ""
}

// LinkHandler serves the read-only surface a linked app uses.
type LinkHandler struct {
	recipeService service.RecipeService
	recipes       *RecipeHandler
	logger        logger.Logger
}

func NewLinkHandler(recipeService service.RecipeService, logger logger.Logger) *LinkHandler {
	return &LinkHandler{
		recipeService: recipeService,
		recipes:       NewRecipeHandler(recipeService, logger),
		logger:        logger,
	}
}

type linkHome struct {
	ID   uuid.UUID `json:"id"`
	Name string    `json:"name"`
}

type linkLabel struct {
	Type recipe.LabelType `json:"type"`
	Name string           `json:"name"`
}

type linkIndexEntry struct {
	ID        uuid.UUID   `json:"id"`
	Name      string      `json:"name"`
	Labels    []linkLabel `json:"labels"`
	MainPhoto *string     `json:"mainPhoto"`
	URL       string      `json:"url"`
	UpdatedAt time.Time   `json:"updatedAt"`
}

// GET /link/v1/recipes
func (h *LinkHandler) RecipeIndex(w http.ResponseWriter, r *http.Request) {
	link, _ := r.Context().Value(linkKey{}).(account.Link)

	entries, err := h.recipeService.RecipeIndex(r.Context())
	if err != nil {
		h.logger.Error().Err(err).Str("link_id", link.UUID.String()).Msg("Failed to list the recipe index")
		writeAPIError(w, http.StatusInternalServerError, "listing_failed", "Failed to list recipes")
		return
	}

	out := make([]linkIndexEntry, len(entries))
	for i, e := range entries {
		labels := make([]linkLabel, len(e.Labels))
		for j, l := range e.Labels {
			labels[j] = linkLabel{Type: l.Type, Name: l.Name}
		}
		var photo *string
		if e.MainPhotoURL != "" {
			photo = &e.MainPhotoURL
		}
		out[i] = linkIndexEntry{
			ID:        e.UUID,
			Name:      e.Name,
			Labels:    labels,
			MainPhoto: photo,
			URL:       e.Url,
			UpdatedAt: e.UpdatedAt,
		}
	}

	writeJSON(w, http.StatusOK, map[string]any{
		"home":    linkHome{ID: link.HomeID, Name: link.HomeName},
		"recipes": out,
	})
}

// GET /link/v1/recipes/{id}
func (h *LinkHandler) GetRecipe(w http.ResponseWriter, r *http.Request) {
	h.recipes.GetRecipe(w, r)
}

// GET /link/v1/meal-plan
func (h *LinkHandler) MealPlan(w http.ResponseWriter, r *http.Request) {
	recipes, err := h.recipeService.ListMealPlanRecipes(r.Context())
	if err != nil {
		h.logger.Error().Err(err).Msg("Failed to list meal plan recipes for a link")
		writeAPIError(w, http.StatusInternalServerError, "listing_failed", "Failed to list meal plan recipes")
		return
	}
	if recipes == nil {
		recipes = []*recipe.Recipe{}
	}

	writeJSON(w, http.StatusOK, map[string]any{"recipes": recipes})
}
