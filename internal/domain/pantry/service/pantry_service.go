package service

import (
	"context"
	"fmt"
	"strings"

	"github.com/kieranajp/the-bluer-book/internal/domain/pantry"
	"github.com/kieranajp/the-bluer-book/internal/infrastructure/storage/repository"
)

// PantryService is the single door into the pantry domain. REST handlers (and
// future MCP tools) call this rather than the repository directly.
type PantryService interface {
	AddToPantry(ctx context.Context, ingredient string) error
	RemoveFromPantry(ctx context.Context, ingredient string) error
	ListPantry(ctx context.Context) ([]pantry.PantryItem, error)
	// ShoppingList returns everything to buy: the ingredients a planned recipe
	// needs but the pantry lacks, plus any free-text custom items.
	ShoppingList(ctx context.Context) ([]pantry.ShoppingListItem, error)
	// AddCustomShoppingItem adds a free-text item (not a recipe ingredient) to
	// the shopping list, e.g. "washing-up liquid".
	AddCustomShoppingItem(ctx context.Context, name string) error
	// RemoveCustomShoppingItem removes a previously added custom item.
	RemoveCustomShoppingItem(ctx context.Context, name string) error
}

type pantryService struct {
	repo  repository.PantryRepository
	probe pantry.Probe
}

func NewPantryService(repo repository.PantryRepository, probe pantry.Probe) PantryService {
	return &pantryService{
		repo:  repo,
		probe: probe,
	}
}

func (s *pantryService) AddToPantry(ctx context.Context, ingredient string) error {
	if err := s.repo.AddToPantry(ctx, ingredient); err != nil {
		s.probe.PantryError("add", err)
		return err
	}
	s.probe.PantryChanged("add", ingredient)
	return nil
}

func (s *pantryService) RemoveFromPantry(ctx context.Context, ingredient string) error {
	if err := s.repo.RemoveFromPantry(ctx, ingredient); err != nil {
		s.probe.PantryError("remove", err)
		return err
	}
	s.probe.PantryChanged("remove", ingredient)
	return nil
}

func (s *pantryService) ListPantry(ctx context.Context) ([]pantry.PantryItem, error) {
	return s.repo.ListPantry(ctx)
}

func (s *pantryService) ShoppingList(ctx context.Context) ([]pantry.ShoppingListItem, error) {
	mealPlan, err := s.repo.ShoppingList(ctx)
	if err != nil {
		s.probe.PantryError("shopping_list", err)
		return nil, err
	}
	custom, err := s.repo.ListCustomShoppingItems(ctx)
	if err != nil {
		s.probe.PantryError("shopping_list", err)
		return nil, err
	}

	// Meal-plan ingredients first, then custom extras — both already sorted by
	// name by the queries.
	items := make([]pantry.ShoppingListItem, 0, len(mealPlan)+len(custom))
	for _, name := range mealPlan {
		items = append(items, pantry.ShoppingListItem{Name: name, Source: pantry.ShoppingSourceMealPlan})
	}
	for _, name := range custom {
		items = append(items, pantry.ShoppingListItem{Name: name, Source: pantry.ShoppingSourceCustom})
	}
	return items, nil
}

func (s *pantryService) AddCustomShoppingItem(ctx context.Context, name string) error {
	name = strings.TrimSpace(name)
	if name == "" {
		return fmt.Errorf("shopping list item name is required")
	}
	if err := s.repo.AddCustomShoppingItem(ctx, name); err != nil {
		s.probe.PantryError("shopping_add_custom", err)
		return err
	}
	s.probe.PantryChanged("shopping_add_custom", name)
	return nil
}

func (s *pantryService) RemoveCustomShoppingItem(ctx context.Context, name string) error {
	name = strings.TrimSpace(name)
	if name == "" {
		return fmt.Errorf("shopping list item name is required")
	}
	if err := s.repo.RemoveCustomShoppingItem(ctx, name); err != nil {
		s.probe.PantryError("shopping_remove_custom", err)
		return err
	}
	s.probe.PantryChanged("shopping_remove_custom", name)
	return nil
}
