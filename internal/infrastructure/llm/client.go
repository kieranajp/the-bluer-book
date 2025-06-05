package llm

import (
	"context"

	"github.com/kieranajp/the-bluer-book/internal/domain/recipe"
	"github.com/kieranajp/the-bluer-book/internal/infrastructure/trello"
)

type LLMClient interface {
	NormaliseRecipe(ctx context.Context, card trello.Card) (recipe.Recipe, error)
}
