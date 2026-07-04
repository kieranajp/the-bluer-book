// Package compliance is the application-layer service for the
// Google-Play-mandated account-deletion and data-export flows. It
// orchestrates across the account, recipe and pantry domains —
// crossing domain boundaries is exactly why this lives in the
// application layer rather than inside any one domain service.
package compliance

import (
	"context"
	"errors"
	"fmt"
	"time"

	"github.com/google/uuid"

	"github.com/kieranajp/the-bluer-book/internal/domain/account"
	"github.com/kieranajp/the-bluer-book/internal/domain/pantry"
	pantryservice "github.com/kieranajp/the-bluer-book/internal/domain/pantry/service"
	"github.com/kieranajp/the-bluer-book/internal/domain/recipe"
	recipeservice "github.com/kieranajp/the-bluer-book/internal/domain/recipe/service"
	"github.com/kieranajp/the-bluer-book/internal/infrastructure/logger"
)

// DeletionResult tells the caller (and the audit log) what actually
// happened. The user row is gone in any successful return; HomesPurged
// is the homes that got wiped because the user was their sole owner,
// HomesLeft is homes that survived because somebody else still owns
// them.
type DeletionResult struct {
	UserID      uuid.UUID   `json:"user_id"`
	Subject     string      `json:"subject"`
	HomesPurged []uuid.UUID `json:"homes_purged"`
	HomesLeft   []uuid.UUID `json:"homes_left"`
}

// ExportPayload is what GET /api/account/export marshals to JSON. The
// per-domain types already carry their own JSON tags from the rest of
// the API, so this is a passive container.
type ExportPayload struct {
	ExportedAt   time.Time                 `json:"exported_at"`
	Home         account.Home              `json:"home"`
	Recipes      []*recipe.Recipe          `json:"recipes"`
	MealPlan     []*recipe.Recipe          `json:"meal_plan"`
	Pantry       []pantry.PantryItem       `json:"pantry"`
	ShoppingList []pantry.ShoppingListItem `json:"shopping_list"`
}

// Service is the door into the compliance flows.
type Service interface {
	// DeleteAccount removes the user from the local database (purging
	// any home where they were the sole owner, leaving homes that have
	// other owners), then asks the upstream IdP to forget their
	// identity. Identity-delete failure is logged but doesn't fail the
	// call — the local data is gone and re-running deletion has no
	// further local effect.
	DeleteAccount(ctx context.Context, userID uuid.UUID) (*DeletionResult, error)

	// ExportData returns a JSON-serialisable snapshot of homeID's
	// data. Caller must be a member of the home; for shared homes
	// (>1 member) only owners may export, to avoid one member
	// exfiltrating everyone else's data.
	ExportData(ctx context.Context, userID, homeID uuid.UUID) (*ExportPayload, error)
}

// Deps groups the dependencies. Account, Admin and Identity are
// required for DeleteAccount; Recipes and Pantry are required for
// ExportData. Log is optional.
type Deps struct {
	Account  account.Repository
	Admin    account.AdminRepository
	Identity account.IdentityDeleter
	Recipes  recipeservice.RecipeService
	Pantry   pantryservice.PantryService
	Log      logger.Logger
}

type service struct {
	account  account.Repository
	admin    account.AdminRepository
	identity account.IdentityDeleter
	recipes  recipeservice.RecipeService
	pantry   pantryservice.PantryService
	log      logger.Logger
	now      func() time.Time
}

// New builds a compliance service. nowFn is for test injection — pass
// nil in production. A nil IdentityDeleter falls back to a no-op so
// the deletion flow works pre-Phase-0 (the local data still goes; the
// upstream identity cleanup is wired in once Kratos admin is reachable).
func New(deps Deps, nowFn func() time.Time) Service {
	if nowFn == nil {
		nowFn = time.Now
	}
	if deps.Identity == nil {
		deps.Identity = account.NoopIdentityDeleter{}
	}
	return &service{
		account:  deps.Account,
		admin:    deps.Admin,
		identity: deps.Identity,
		recipes:  deps.Recipes,
		pantry:   deps.Pantry,
		log:      deps.Log,
		now:      nowFn,
	}
}

func (s *service) DeleteAccount(ctx context.Context, userID uuid.UUID) (*DeletionResult, error) {
	if s.account == nil || s.admin == nil {
		return nil, errors.New("compliance: account + admin deps required")
	}

	user, err := s.account.GetUserByUUID(ctx, userID)
	if err != nil {
		return nil, err
	}

	memberships, err := s.account.ListHomesForUser(ctx, userID)
	if err != nil {
		return nil, err
	}

	// Classify each home: sole-ownership goes to the purge list, everything
	// else just sheds this user's membership when the user row is deleted
	// (home_members FKs users(uuid) ON DELETE CASCADE).
	var toPurge, toLeave []uuid.UUID
	for _, m := range memberships {
		if m.Role != account.RoleOwner {
			toLeave = append(toLeave, m.Home.UUID)
			continue
		}
		owners, err := s.account.CountOwners(ctx, m.Home.UUID)
		if err != nil {
			return nil, err
		}
		if owners <= 1 {
			toPurge = append(toPurge, m.Home.UUID)
		} else {
			toLeave = append(toLeave, m.Home.UUID)
		}
	}

	// Local state first. If anything below fails the user can re-attempt
	// and we don't leave them in the worst-case half-deleted-at-IdP state.
	for _, hid := range toPurge {
		if err := s.admin.PurgeHome(ctx, hid); err != nil {
			return nil, fmt.Errorf("purge home %s: %w", hid, err)
		}
	}
	if err := s.admin.DeleteUser(ctx, userID); err != nil {
		return nil, fmt.Errorf("delete user %s: %w", userID, err)
	}

	// IdP last. Failure here is recoverable: the local data is gone, so a
	// future login from the same subject reads as a fresh user. Log and
	// move on rather than 500ing.
	if err := s.identity.Delete(ctx, user.Subject); err != nil {
		if s.log != nil {
			s.log.Error().Err(err).
				Str("user_id", userID.String()).
				Str("subject", user.Subject).
				Msg("local account deleted but upstream identity delete failed; retry manually")
		}
	}

	return &DeletionResult{
		UserID:      userID,
		Subject:     user.Subject,
		HomesPurged: toPurge,
		HomesLeft:   toLeave,
	}, nil
}

func (s *service) ExportData(ctx context.Context, userID, homeID uuid.UUID) (*ExportPayload, error) {
	if s.recipes == nil || s.pantry == nil {
		return nil, errors.New("compliance: recipe/pantry deps required")
	}

	// Membership check. For shared homes, only owners can export — a
	// casual member shouldn't be able to walk away with a full dump.
	role, err := s.account.GetMembership(ctx, homeID, userID)
	if err != nil {
		return nil, err
	}
	members, err := s.account.ListMembers(ctx, homeID)
	if err != nil {
		return nil, err
	}
	if len(members) > 1 && role != account.RoleOwner {
		return nil, account.ErrForbidden
	}

	home, err := s.account.GetHomeByID(ctx, homeID)
	if err != nil {
		return nil, err
	}

	// ctx is the authenticated request ctx, so InHomeTx inside the recipe
	// and pantry repos will set app.home_id correctly and only the active
	// home's rows come back.
	const exportLimit = 100000

	recipes, _, err := s.recipes.ListRecipes(ctx, exportLimit, 0, "", nil, "")
	if err != nil {
		return nil, fmt.Errorf("list recipes: %w", err)
	}

	mealPlan, err := s.recipes.ListMealPlanRecipes(ctx)
	if err != nil {
		return nil, fmt.Errorf("list meal plan: %w", err)
	}

	pantryItems, err := s.pantry.ListPantry(ctx)
	if err != nil {
		return nil, fmt.Errorf("list pantry: %w", err)
	}

	shoppingList, err := s.pantry.ShoppingList(ctx)
	if err != nil {
		return nil, fmt.Errorf("list shopping list: %w", err)
	}

	return &ExportPayload{
		ExportedAt:   s.now().UTC(),
		Home:         *home,
		Recipes:      recipes,
		MealPlan:     mealPlan,
		Pantry:       pantryItems,
		ShoppingList: shoppingList,
	}, nil
}
