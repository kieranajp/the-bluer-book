package service

import (
	"context"

	"github.com/kieranajp/the-bluer-book/internal/domain/pantry"
	"github.com/kieranajp/the-bluer-book/internal/infrastructure/storage/repository"
)

// PantryService is the single door into the pantry domain. REST handlers (and
// future MCP tools) call this rather than the repository directly.
type PantryService interface {
	AddToPantry(ctx context.Context, ingredient string) error
	RemoveFromPantry(ctx context.Context, ingredient string) error
	ListPantry(ctx context.Context) ([]pantry.PantryItem, error)
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
