package pantry

import (
	"errors"
	"fmt"
)

// Domain-specific errors
var (
	// ErrIngredientNotFound indicates a pantry operation named an ingredient no
	// recipe in the book uses. Pantry entries reference the ingredients table,
	// so there is nothing for such an entry to point at — the operation is a
	// reportable failure, not a no-op.
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
