package pantry

import (
	"errors"
	"fmt"
)

// Domain-specific errors
var (
	// ErrIngredientNotFound means no recipe in the book uses the named
	// ingredient; pantry entries can only reference existing ingredients.
	ErrIngredientNotFound = errors.New("ingredient not found")
)

// IngredientNotFoundError provides context about which ingredient name could
// not be resolved.
type IngredientNotFoundError struct {
	Name string
}

func (e IngredientNotFoundError) Error() string {
	return fmt.Sprintf("no ingredient named %q", e.Name)
}

func (e IngredientNotFoundError) Is(target error) bool {
	return target == ErrIngredientNotFound
}
