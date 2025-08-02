package recipe

import (
	"errors"
	"fmt"

	"github.com/google/uuid"
)

// Domain-specific errors
var (
	// ErrRecipeNotFound indicates that a recipe could not be found
	ErrRecipeNotFound = errors.New("recipe not found")

	// ErrRecipeAlreadyArchived indicates that a recipe is already archived
	ErrRecipeAlreadyArchived = errors.New("recipe is already archived")

	// ErrArchivedRecipeNotFound indicates that an archived recipe could not be found
	ErrArchivedRecipeNotFound = errors.New("archived recipe not found")
)

// RecipeNotFoundError provides context about which recipe was not found
type RecipeNotFoundError struct {
	ID uuid.UUID
}

func (e RecipeNotFoundError) Error() string {
	return fmt.Sprintf("recipe with ID %s not found", e.ID)
}

func (e RecipeNotFoundError) Is(target error) bool {
	return target == ErrRecipeNotFound
}

// RecipeAlreadyArchivedError provides context about which recipe is already archived
type RecipeAlreadyArchivedError struct {
	ID uuid.UUID
}

func (e RecipeAlreadyArchivedError) Error() string {
	return fmt.Sprintf("recipe with ID %s is already archived", e.ID)
}

func (e RecipeAlreadyArchivedError) Is(target error) bool {
	return target == ErrRecipeAlreadyArchived
}

// ArchivedRecipeNotFoundError provides context about which archived recipe was not found
type ArchivedRecipeNotFoundError struct {
	ID uuid.UUID
}

func (e ArchivedRecipeNotFoundError) Error() string {
	return fmt.Sprintf("archived recipe with ID %s not found", e.ID)
}

func (e ArchivedRecipeNotFoundError) Is(target error) bool {
	return target == ErrArchivedRecipeNotFound
}
