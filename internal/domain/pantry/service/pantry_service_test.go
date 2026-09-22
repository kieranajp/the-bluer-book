package service

import (
	"context"
	"errors"
	"testing"

	"github.com/kieranajp/the-bluer-book/internal/domain/pantry"
)

type stubPantryRepo struct {
	added   []string
	removed []string
	stapled []string
	err     error
}

func (s *stubPantryRepo) AddToPantry(_ context.Context, ingredient string) error {
	s.added = append(s.added, ingredient)
	return s.err
}

func (s *stubPantryRepo) RemoveFromPantry(_ context.Context, ingredient string) error {
	s.removed = append(s.removed, ingredient)
	return s.err
}

func (s *stubPantryRepo) SetStaple(_ context.Context, ingredient string, staple bool) error {
	s.stapled = append(s.stapled, ingredient)
	return s.err
}

func (s *stubPantryRepo) ListPantry(context.Context) ([]pantry.PantryItem, error) {
	return nil, s.err
}

func (s *stubPantryRepo) ShoppingList(context.Context) ([]string, error) { return nil, s.err }

func (s *stubPantryRepo) AddCustomShoppingItem(context.Context, string) error    { return s.err }
func (s *stubPantryRepo) RemoveCustomShoppingItem(context.Context, string) error { return s.err }
func (s *stubPantryRepo) ListCustomShoppingItems(context.Context) ([]string, error) {
	return nil, s.err
}

type recordingProbe struct {
	changed  []string
	failed   []string
	unknowns []string
}

func (p *recordingProbe) PantryChanged(action, ingredient string) {
	p.changed = append(p.changed, action+":"+ingredient)
}

func (p *recordingProbe) PantryError(operation string, _ error) {
	p.failed = append(p.failed, operation)
}

func (p *recordingProbe) UnknownIngredient(action, ingredient string) {
	p.unknowns = append(p.unknowns, action+":"+ingredient)
}

func TestPantryMutationsTrimNames(t *testing.T) {
	repo := &stubPantryRepo{}
	probe := &recordingProbe{}
	svc := NewPantryService(repo, probe)

	if err := svc.AddToPantry(context.Background(), "  plain flour \n"); err != nil {
		t.Fatalf("AddToPantry() error = %v", err)
	}
	if err := svc.RemoveFromPantry(context.Background(), " salt "); err != nil {
		t.Fatalf("RemoveFromPantry() error = %v", err)
	}

	if len(repo.added) != 1 || repo.added[0] != "plain flour" {
		t.Errorf("added = %v, want [plain flour]", repo.added)
	}
	if len(repo.removed) != 1 || repo.removed[0] != "salt" {
		t.Errorf("removed = %v, want [salt]", repo.removed)
	}
	if len(probe.changed) != 2 {
		t.Errorf("probe changes = %v, want two", probe.changed)
	}
}

func TestPantryMutationsRejectBlankNames(t *testing.T) {
	repo := &stubPantryRepo{}
	svc := NewPantryService(repo, &recordingProbe{})

	if err := svc.AddToPantry(context.Background(), "   "); err == nil {
		t.Error("AddToPantry() error = nil, want required-field error")
	}
	if err := svc.RemoveFromPantry(context.Background(), ""); err == nil {
		t.Error("RemoveFromPantry() error = nil, want required-field error")
	}
	if len(repo.added) != 0 || len(repo.removed) != 0 {
		t.Errorf("repository was called for a blank name: added=%v removed=%v", repo.added, repo.removed)
	}
}

// An ingredient the book doesn't have is the caller's mistake. It must not land
// in the error counter, or a chat agent guessing names looks like an outage.
func TestUnknownIngredientIsNotCountedAsAnError(t *testing.T) {
	repo := &stubPantryRepo{err: pantry.IngredientNotFoundError{Name: "unobtainium"}}
	probe := &recordingProbe{}
	svc := NewPantryService(repo, probe)

	err := svc.AddToPantry(context.Background(), "unobtainium")
	if !errors.Is(err, pantry.ErrIngredientNotFound) {
		t.Fatalf("AddToPantry() error = %v, want ErrIngredientNotFound", err)
	}
	if len(probe.failed) != 0 {
		t.Errorf("probe errors = %v, want none", probe.failed)
	}
	if len(probe.unknowns) != 1 || probe.unknowns[0] != "add:unobtainium" {
		t.Errorf("probe unknowns = %v, want [add:unobtainium]", probe.unknowns)
	}
	if len(probe.changed) != 0 {
		t.Errorf("probe changes = %v, want none — nothing changed", probe.changed)
	}
}

func TestRepositoryFaultIsCountedAsAnError(t *testing.T) {
	repo := &stubPantryRepo{err: errors.New("db down")}
	probe := &recordingProbe{}
	svc := NewPantryService(repo, probe)

	if err := svc.RemoveFromPantry(context.Background(), "salt"); err == nil {
		t.Fatal("RemoveFromPantry() error = nil, want the repository fault")
	}
	if len(probe.failed) != 1 || probe.failed[0] != "remove" {
		t.Errorf("probe errors = %v, want [remove]", probe.failed)
	}
	if len(probe.unknowns) != 0 {
		t.Errorf("probe unknowns = %v, want none", probe.unknowns)
	}
}

func TestSetStapleTrimsAndReportsAction(t *testing.T) {
	repo := &stubPantryRepo{}
	probe := &recordingProbe{}
	svc := NewPantryService(repo, probe)

	if err := svc.SetStaple(context.Background(), "  olive oil ", true); err != nil {
		t.Fatalf("SetStaple() error = %v", err)
	}
	if len(repo.stapled) != 1 || repo.stapled[0] != "olive oil" {
		t.Errorf("stapled = %v, want [olive oil]", repo.stapled)
	}
	if len(probe.changed) != 1 || probe.changed[0] != "set_staple:olive oil" {
		t.Errorf("probe changes = %v, want [set_staple:olive oil]", probe.changed)
	}

	if err := svc.SetStaple(context.Background(), "olive oil", false); err != nil {
		t.Fatalf("SetStaple(false) error = %v", err)
	}
	if probe.changed[1] != "unset_staple:olive oil" {
		t.Errorf("probe changes = %v, want an unset_staple entry", probe.changed)
	}
}

func TestSetStapleRejectsBlankName(t *testing.T) {
	repo := &stubPantryRepo{}
	svc := NewPantryService(repo, &recordingProbe{})

	if err := svc.SetStaple(context.Background(), "  ", true); err == nil {
		t.Error("SetStaple() error = nil, want required-field error")
	}
	if len(repo.stapled) != 0 {
		t.Errorf("repository was called for a blank name: %v", repo.stapled)
	}
}

// A staple toggle naming an unknown ingredient is a caller mistake, same as the
// pantry mutations — it must not land in the error counter.
func TestSetStapleUnknownIngredientIsNotAnError(t *testing.T) {
	repo := &stubPantryRepo{err: pantry.IngredientNotFoundError{Name: "unobtainium"}}
	probe := &recordingProbe{}
	svc := NewPantryService(repo, probe)

	err := svc.SetStaple(context.Background(), "unobtainium", true)
	if !errors.Is(err, pantry.ErrIngredientNotFound) {
		t.Fatalf("SetStaple() error = %v, want ErrIngredientNotFound", err)
	}
	if len(probe.failed) != 0 {
		t.Errorf("probe errors = %v, want none", probe.failed)
	}
	if len(probe.unknowns) != 1 || probe.unknowns[0] != "set_staple:unobtainium" {
		t.Errorf("probe unknowns = %v, want [set_staple:unobtainium]", probe.unknowns)
	}
}
