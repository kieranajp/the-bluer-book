package compliance

import (
	"context"
	"errors"
	"sync"
	"testing"
	"time"

	"github.com/google/uuid"

	"github.com/kieranajp/the-bluer-book/internal/domain/account"
	"github.com/kieranajp/the-bluer-book/internal/domain/pantry"
	"github.com/kieranajp/the-bluer-book/internal/domain/recipe"
)

// --- in-memory fakes for the account.Repository + AdminRepository ports ---

type memAccountRepo struct {
	mu          sync.Mutex
	users       map[uuid.UUID]account.User
	homes       map[uuid.UUID]account.Home
	memberships map[uuid.UUID]map[uuid.UUID]account.Role // homeID -> userID -> role
}

func newMemAccountRepo() *memAccountRepo {
	return &memAccountRepo{
		users:       map[uuid.UUID]account.User{},
		homes:       map[uuid.UUID]account.Home{},
		memberships: map[uuid.UUID]map[uuid.UUID]account.Role{},
	}
}

func (r *memAccountRepo) addUser(subject string) account.User {
	u := account.User{UUID: uuid.New(), Subject: subject}
	r.users[u.UUID] = u
	return u
}

func (r *memAccountRepo) addHome(name string) account.Home {
	h := account.Home{UUID: uuid.New(), Name: name}
	r.homes[h.UUID] = h
	return h
}

func (r *memAccountRepo) addMember(home account.Home, user account.User, role account.Role) {
	if r.memberships[home.UUID] == nil {
		r.memberships[home.UUID] = map[uuid.UUID]account.Role{}
	}
	r.memberships[home.UUID][user.UUID] = role
}

// account.Repository implementation:

func (r *memAccountRepo) GetUserBySubject(_ context.Context, _ string) (*account.User, error) {
	return nil, account.ErrUserNotFound
}
func (r *memAccountRepo) GetUserByUUID(_ context.Context, id uuid.UUID) (*account.User, error) {
	r.mu.Lock()
	defer r.mu.Unlock()
	u, ok := r.users[id]
	if !ok {
		return nil, account.ErrUserNotFound
	}
	return &u, nil
}
func (r *memAccountRepo) CreateUser(_ context.Context, _, _, _ string) (*account.User, error) {
	return nil, errors.New("not used")
}
func (r *memAccountRepo) CreateHome(_ context.Context, _ string) (*account.Home, error) {
	return nil, errors.New("not used")
}
func (r *memAccountRepo) GetHomeByID(_ context.Context, id uuid.UUID) (*account.Home, error) {
	r.mu.Lock()
	defer r.mu.Unlock()
	h, ok := r.homes[id]
	if !ok {
		return nil, account.ErrHomeNotFound
	}
	return &h, nil
}
func (r *memAccountRepo) GetHomeForUserByID(_ context.Context, _, _ uuid.UUID) (*account.Home, error) {
	return nil, errors.New("not used")
}
func (r *memAccountRepo) GetMostRecentHomeForUser(_ context.Context, _ uuid.UUID) (*account.Home, error) {
	return nil, errors.New("not used")
}
func (r *memAccountRepo) ListHomesForUser(_ context.Context, userID uuid.UUID) ([]account.Membership, error) {
	r.mu.Lock()
	defer r.mu.Unlock()
	var out []account.Membership
	for hid, members := range r.memberships {
		if role, ok := members[userID]; ok {
			out = append(out, account.Membership{Home: r.homes[hid], Role: role})
		}
	}
	return out, nil
}
func (r *memAccountRepo) AddMember(_ context.Context, _, _ uuid.UUID, _ account.Role) error {
	return errors.New("not used")
}
func (r *memAccountRepo) RemoveMember(_ context.Context, _, _ uuid.UUID) error {
	return errors.New("not used")
}
func (r *memAccountRepo) GetMembership(_ context.Context, hid, uid uuid.UUID) (account.Role, error) {
	r.mu.Lock()
	defer r.mu.Unlock()
	role, ok := r.memberships[hid][uid]
	if !ok {
		return "", account.ErrForbidden
	}
	return role, nil
}
func (r *memAccountRepo) ListMembers(_ context.Context, hid uuid.UUID) ([]account.MemberWithUser, error) {
	r.mu.Lock()
	defer r.mu.Unlock()
	var out []account.MemberWithUser
	for uid, role := range r.memberships[hid] {
		out = append(out, account.MemberWithUser{User: r.users[uid], Role: role})
	}
	return out, nil
}
func (r *memAccountRepo) CountOwners(_ context.Context, hid uuid.UUID) (int, error) {
	r.mu.Lock()
	defer r.mu.Unlock()
	n := 0
	for _, role := range r.memberships[hid] {
		if role == account.RoleOwner {
			n++
		}
	}
	return n, nil
}
func (r *memAccountRepo) CreateInvitation(_ context.Context, _ account.Invitation) (*account.Invitation, error) {
	return nil, errors.New("not used")
}
func (r *memAccountRepo) GetInvitationByToken(_ context.Context, _ string) (*account.Invitation, error) {
	return nil, errors.New("not used")
}
func (r *memAccountRepo) MarkInvitationAccepted(_ context.Context, _ uuid.UUID) error {
	return errors.New("not used")
}
func (r *memAccountRepo) ListInvitations(_ context.Context, _ uuid.UUID) ([]account.Invitation, error) {
	return nil, errors.New("not used")
}

type memAdminRepo struct {
	purged  []uuid.UUID
	deleted []uuid.UUID
	repo    *memAccountRepo
}

func (a *memAdminRepo) PurgeHome(_ context.Context, hid uuid.UUID) error {
	a.purged = append(a.purged, hid)
	// Simulate cascade: cut memberships for the home.
	a.repo.mu.Lock()
	delete(a.repo.homes, hid)
	delete(a.repo.memberships, hid)
	a.repo.mu.Unlock()
	return nil
}
func (a *memAdminRepo) DeleteUser(_ context.Context, uid uuid.UUID) error {
	a.deleted = append(a.deleted, uid)
	// Simulate cascade: drop the user and any memberships they had.
	a.repo.mu.Lock()
	delete(a.repo.users, uid)
	for hid, members := range a.repo.memberships {
		delete(members, uid)
		if len(members) == 0 {
			delete(a.repo.memberships, hid)
		}
	}
	a.repo.mu.Unlock()
	return nil
}

type capturingDeleter struct {
	calls []string
	err   error
}

func (d *capturingDeleter) Delete(_ context.Context, subject string) error {
	d.calls = append(d.calls, subject)
	return d.err
}

// --- in-memory stubs for the recipe + pantry services used by export ---

type stubRecipeService struct {
	all      []*recipe.Recipe
	mealPlan []*recipe.Recipe
}

func (s *stubRecipeService) CreateRecipe(_ context.Context, _ recipe.Recipe) (*recipe.Recipe, error) {
	return nil, errors.New("not used")
}
func (s *stubRecipeService) GetRecipe(_ context.Context, _ uuid.UUID) (*recipe.Recipe, error) {
	return nil, errors.New("not used")
}
func (s *stubRecipeService) ListRecipes(_ context.Context, _, _ int, _ string, _ []string, _ string) ([]*recipe.Recipe, int, error) {
	return s.all, len(s.all), nil
}
func (s *stubRecipeService) UpdateRecipe(_ context.Context, _ uuid.UUID, _ recipe.Recipe) (*recipe.Recipe, error) {
	return nil, errors.New("not used")
}
func (s *stubRecipeService) ArchiveRecipe(_ context.Context, _ uuid.UUID) error {
	return errors.New("not used")
}
func (s *stubRecipeService) RestoreRecipe(_ context.Context, _ uuid.UUID) (*recipe.Recipe, error) {
	return nil, errors.New("not used")
}
func (s *stubRecipeService) ListArchivedRecipes(_ context.Context, _, _ int) ([]*recipe.Recipe, int, error) {
	return nil, 0, errors.New("not used")
}
func (s *stubRecipeService) AddToMealPlan(_ context.Context, _ uuid.UUID) error {
	return errors.New("not used")
}
func (s *stubRecipeService) RemoveFromMealPlan(_ context.Context, _ uuid.UUID) error {
	return errors.New("not used")
}
func (s *stubRecipeService) ListMealPlanRecipes(_ context.Context) ([]*recipe.Recipe, error) {
	return s.mealPlan, nil
}
func (s *stubRecipeService) ListLabels(_ context.Context) ([]recipe.LabelSummary, error) {
	return nil, errors.New("not used")
}
func (s *stubRecipeService) ListUnits(_ context.Context) ([]recipe.Unit, error) {
	return nil, errors.New("not used")
}
func (s *stubRecipeService) ListIngredients(_ context.Context) ([]recipe.Ingredient, error) {
	return nil, errors.New("not used")
}

type stubPantryService struct {
	pantry   []pantry.PantryItem
	shopping []pantry.ShoppingListItem
}

func (s *stubPantryService) AddToPantry(_ context.Context, _ string) error {
	return errors.New("not used")
}
func (s *stubPantryService) RemoveFromPantry(_ context.Context, _ string) error {
	return errors.New("not used")
}
func (s *stubPantryService) ListPantry(_ context.Context) ([]pantry.PantryItem, error) {
	return s.pantry, nil
}
func (s *stubPantryService) ShoppingList(_ context.Context) ([]pantry.ShoppingListItem, error) {
	return s.shopping, nil
}
func (s *stubPantryService) AddCustomShoppingItem(_ context.Context, _ string) error {
	return errors.New("not used")
}
func (s *stubPantryService) RemoveCustomShoppingItem(_ context.Context, _ string) error {
	return errors.New("not used")
}

// --- tests ---

func TestDeleteAccount_SoleOwnerHomeIsPurged(t *testing.T) {
	repo := newMemAccountRepo()
	user := repo.addUser("kratos-id-1")
	home := repo.addHome("Solo")
	repo.addMember(home, user, account.RoleOwner)

	admin := &memAdminRepo{repo: repo}
	deleter := &capturingDeleter{}
	svc := New(Deps{Account: repo, Admin: admin, Identity: deleter}, nil)

	result, err := svc.DeleteAccount(context.Background(), user.UUID)
	if err != nil {
		t.Fatalf("DeleteAccount: %v", err)
	}
	if len(result.HomesPurged) != 1 || result.HomesPurged[0] != home.UUID {
		t.Fatalf("HomesPurged = %v, want [%s]", result.HomesPurged, home.UUID)
	}
	if len(result.HomesLeft) != 0 {
		t.Fatalf("HomesLeft = %v, want empty", result.HomesLeft)
	}
	if len(admin.purged) != 1 || admin.purged[0] != home.UUID {
		t.Fatalf("admin.purged = %v, want [%s]", admin.purged, home.UUID)
	}
	if len(admin.deleted) != 1 || admin.deleted[0] != user.UUID {
		t.Fatalf("admin.deleted = %v, want [%s]", admin.deleted, user.UUID)
	}
	if len(deleter.calls) != 1 || deleter.calls[0] != "kratos-id-1" {
		t.Fatalf("identity.Delete calls = %v, want [kratos-id-1]", deleter.calls)
	}
}

func TestDeleteAccount_SharedHomeSurvives(t *testing.T) {
	repo := newMemAccountRepo()
	leaving := repo.addUser("kratos-leaving")
	other := repo.addUser("kratos-other")
	home := repo.addHome("Shared")
	repo.addMember(home, leaving, account.RoleOwner)
	repo.addMember(home, other, account.RoleOwner)

	admin := &memAdminRepo{repo: repo}
	svc := New(Deps{Account: repo, Admin: admin, Identity: &capturingDeleter{}}, nil)

	result, err := svc.DeleteAccount(context.Background(), leaving.UUID)
	if err != nil {
		t.Fatalf("DeleteAccount: %v", err)
	}
	if len(result.HomesPurged) != 0 {
		t.Fatalf("HomesPurged = %v, want empty (home has another owner)", result.HomesPurged)
	}
	if len(result.HomesLeft) != 1 || result.HomesLeft[0] != home.UUID {
		t.Fatalf("HomesLeft = %v, want [%s]", result.HomesLeft, home.UUID)
	}
	if len(admin.purged) != 0 {
		t.Fatalf("admin.PurgeHome should not have been called, got %v", admin.purged)
	}
	if _, ok := repo.homes[home.UUID]; !ok {
		t.Fatalf("home should still exist after sharing-user deletion")
	}
}

func TestDeleteAccount_MemberOnlyJustLosesMembership(t *testing.T) {
	repo := newMemAccountRepo()
	owner := repo.addUser("owner")
	member := repo.addUser("member")
	home := repo.addHome("Family")
	repo.addMember(home, owner, account.RoleOwner)
	repo.addMember(home, member, account.RoleMember)

	admin := &memAdminRepo{repo: repo}
	svc := New(Deps{Account: repo, Admin: admin, Identity: &capturingDeleter{}}, nil)

	result, err := svc.DeleteAccount(context.Background(), member.UUID)
	if err != nil {
		t.Fatalf("DeleteAccount: %v", err)
	}
	if len(result.HomesPurged) != 0 || len(result.HomesLeft) != 1 {
		t.Fatalf("unexpected result: %+v", result)
	}
	if _, stillThere := repo.memberships[home.UUID][member.UUID]; stillThere {
		t.Fatalf("member's membership should be gone")
	}
	if repo.memberships[home.UUID][owner.UUID] != account.RoleOwner {
		t.Fatalf("owner's membership should survive")
	}
}

func TestDeleteAccount_IdentityFailureDoesNotFailCall(t *testing.T) {
	repo := newMemAccountRepo()
	user := repo.addUser("kratos-flaky")
	home := repo.addHome("Solo")
	repo.addMember(home, user, account.RoleOwner)

	admin := &memAdminRepo{repo: repo}
	deleter := &capturingDeleter{err: errors.New("kratos down")}
	svc := New(Deps{Account: repo, Admin: admin, Identity: deleter}, nil)

	if _, err := svc.DeleteAccount(context.Background(), user.UUID); err != nil {
		t.Fatalf("DeleteAccount should swallow identity-delete error, got %v", err)
	}
	if _, stillThere := repo.users[user.UUID]; stillThere {
		t.Fatalf("local user should be deleted even when IdP delete fails")
	}
}

func TestExportData_MemberInSoloHomeCanExport(t *testing.T) {
	repo := newMemAccountRepo()
	user := repo.addUser("u")
	home := repo.addHome("Solo")
	repo.addMember(home, user, account.RoleOwner)

	recipes := []*recipe.Recipe{{UUID: uuid.New(), Name: "Pancakes"}}
	mealPlan := []*recipe.Recipe{recipes[0]}
	pantryItems := []pantry.PantryItem{{Ingredient: "eggs"}}
	shopping := []pantry.ShoppingListItem{{Name: "milk", Source: pantry.ShoppingSourceMealPlan}}

	fakeNow := time.Date(2026, 6, 4, 12, 0, 0, 0, time.UTC)
	svc := New(Deps{
		Account: repo,
		Recipes: &stubRecipeService{all: recipes, mealPlan: mealPlan},
		Pantry:  &stubPantryService{pantry: pantryItems, shopping: shopping},
	}, func() time.Time { return fakeNow })

	payload, err := svc.ExportData(context.Background(), user.UUID, home.UUID)
	if err != nil {
		t.Fatalf("ExportData: %v", err)
	}
	if !payload.ExportedAt.Equal(fakeNow) {
		t.Errorf("ExportedAt = %s, want %s", payload.ExportedAt, fakeNow)
	}
	if payload.Home.UUID != home.UUID {
		t.Errorf("Home.UUID = %s, want %s", payload.Home.UUID, home.UUID)
	}
	if len(payload.Recipes) != 1 || payload.Recipes[0].Name != "Pancakes" {
		t.Errorf("Recipes = %+v, want one Pancakes", payload.Recipes)
	}
	if len(payload.MealPlan) != 1 {
		t.Errorf("MealPlan length = %d, want 1", len(payload.MealPlan))
	}
	if len(payload.Pantry) != 1 || payload.Pantry[0].Ingredient != "eggs" {
		t.Errorf("Pantry = %+v, want one eggs", payload.Pantry)
	}
	if len(payload.ShoppingList) != 1 || payload.ShoppingList[0].Name != "milk" {
		t.Errorf("ShoppingList = %+v, want one milk", payload.ShoppingList)
	}
}

func TestExportData_NonOwnerInSharedHomeIsRefused(t *testing.T) {
	repo := newMemAccountRepo()
	owner := repo.addUser("owner")
	member := repo.addUser("member")
	home := repo.addHome("Family")
	repo.addMember(home, owner, account.RoleOwner)
	repo.addMember(home, member, account.RoleMember)

	svc := New(Deps{
		Account: repo,
		Recipes: &stubRecipeService{},
		Pantry:  &stubPantryService{},
	}, nil)

	if _, err := svc.ExportData(context.Background(), member.UUID, home.UUID); !errors.Is(err, account.ErrForbidden) {
		t.Fatalf("ExportData by member of shared home: got %v, want ErrForbidden", err)
	}
}

func TestExportData_OwnerInSharedHomeCanExport(t *testing.T) {
	repo := newMemAccountRepo()
	owner := repo.addUser("owner")
	member := repo.addUser("member")
	home := repo.addHome("Family")
	repo.addMember(home, owner, account.RoleOwner)
	repo.addMember(home, member, account.RoleMember)

	svc := New(Deps{
		Account: repo,
		Recipes: &stubRecipeService{},
		Pantry:  &stubPantryService{},
	}, nil)

	if _, err := svc.ExportData(context.Background(), owner.UUID, home.UUID); err != nil {
		t.Fatalf("owner export of shared home failed: %v", err)
	}
}

func TestExportData_NonMemberRefused(t *testing.T) {
	repo := newMemAccountRepo()
	outsider := repo.addUser("outsider")
	home := repo.addHome("Stranger's home")

	svc := New(Deps{
		Account: repo,
		Recipes: &stubRecipeService{},
		Pantry:  &stubPantryService{},
	}, nil)

	if _, err := svc.ExportData(context.Background(), outsider.UUID, home.UUID); !errors.Is(err, account.ErrForbidden) {
		t.Fatalf("non-member export: got %v, want ErrForbidden", err)
	}
}
