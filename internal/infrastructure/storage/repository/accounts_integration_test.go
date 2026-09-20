package repository

// ProvisionUser is the only place a subject becomes a user and lands in a
// home, and a cold start can fire two or three requests for the same subject
// at once. LockSubject (pg_advisory_xact_lock(hashtext(subject))) exists to
// stop each of those from creating its own home; nothing here proves that
// without going through a real database, so these tests do.

import (
	"context"
	"database/sql"
	"sync"
	"testing"

	"github.com/google/uuid"

	"github.com/kieranajp/the-bluer-book/internal/domain/account"
	"github.com/kieranajp/the-bluer-book/internal/domain/account/service"
	"github.com/kieranajp/the-bluer-book/internal/infrastructure/logger"
	"github.com/kieranajp/the-bluer-book/internal/infrastructure/metrics"
	"github.com/kieranajp/the-bluer-book/internal/infrastructure/storage/db"
)

// newAccountRepo builds the repository under test on a plain pooled
// connection. The identity tables it reads and writes carry no row-level
// security, so this works whether BLUER_BOOK_TEST_DSN names the owner or the
// restricted application role.
func newAccountRepo(sqlDB *sql.DB) account.Repository {
	return NewAccountRepository(db.New(sqlDB), sqlDB, logger.New(logger.LogLevelError))
}

// uniqueSubject returns a subject distinctive enough that a leaked row is
// obvious: every value this suite creates carries the provision-test prefix
// plus a fresh UUID, so cleanup failures and real accounts never collide.
func uniqueSubject(label string) string {
	return "provision-test-" + label + "-" + uuid.New().String()
}

// cleanupProvisioned removes everything ProvisionUser wrote for one user: its
// membership row (including, if the subject was a founder subject, the one it
// added to the founder home), the home itself when that home isn't the
// founder home, and the user row. home_members cascades from homes, so this
// only deletes home_members explicitly for the founder-home case.
func cleanupProvisioned(t *testing.T, sqlDB *sql.DB, userID, homeID uuid.UUID) {
	t.Helper()
	t.Cleanup(func() {
		if _, err := sqlDB.Exec(`DELETE FROM home_members WHERE user_id = $1`, userID); err != nil {
			t.Errorf("clean up membership for user %s: %v", userID, err)
		}
		if homeID != account.FounderHomeID {
			if _, err := sqlDB.Exec(`DELETE FROM homes WHERE uuid = $1`, homeID); err != nil {
				t.Errorf("clean up home %s: %v", homeID, err)
			}
		}
		if _, err := sqlDB.Exec(`DELETE FROM users WHERE uuid = $1`, userID); err != nil {
			t.Errorf("clean up user %s: %v", userID, err)
		}
	})
}

// TestProvisionConcurrentSameSubject is the scenario LockSubject exists for: a
// cold start fires several requests for one subject at once. Without the
// advisory lock, each would find no user, race past that check, and create
// its own home, leaving the caller a member of several. Every goroutine below
// waits on a closed channel so they genuinely race into ProvisionUser
// together.
func TestProvisionConcurrentSameSubject(t *testing.T) {
	sqlDB := openTestDB(t)
	repo := newAccountRepo(sqlDB)

	subject := uniqueSubject("concurrent")
	id := account.Identity{Subject: subject, Email: subject + "@example.com", DisplayName: "Concurrent Test"}
	target := account.HomeTarget{Name: "Concurrent Book"}

	const goroutines = 8
	var wg sync.WaitGroup
	start := make(chan struct{})
	users := make([]account.User, goroutines)
	homes := make([]account.Home, goroutines)
	errs := make([]error, goroutines)

	for i := 0; i < goroutines; i++ {
		wg.Add(1)
		go func(i int) {
			defer wg.Done()
			<-start
			users[i], homes[i], errs[i] = repo.ProvisionUser(context.Background(), id, target)
		}(i)
	}
	close(start)
	wg.Wait()

	for i, err := range errs {
		if err != nil {
			t.Fatalf("goroutine %d: ProvisionUser: %v", i, err)
		}
	}
	cleanupProvisioned(t, sqlDB, users[0].UUID, homes[0].UUID)

	t.Run("every goroutine settles on the same user and home", func(t *testing.T) {
		for i := 1; i < goroutines; i++ {
			if users[i].UUID != users[0].UUID {
				t.Errorf("goroutine %d returned user %s, want %s", i, users[i].UUID, users[0].UUID)
			}
			if homes[i].UUID != homes[0].UUID {
				t.Errorf("goroutine %d returned home %s, want %s", i, homes[i].UUID, homes[0].UUID)
			}
		}
	})

	t.Run("the database holds exactly one user and one membership", func(t *testing.T) {
		var userCount int
		if err := sqlDB.QueryRow(`SELECT count(*) FROM users WHERE subject = $1`, subject).Scan(&userCount); err != nil {
			t.Fatalf("count users: %v", err)
		}
		if userCount != 1 {
			t.Errorf("%d rows in users for subject %q, want 1", userCount, subject)
		}

		var memberCount int
		if err := sqlDB.QueryRow(`SELECT count(*) FROM home_members WHERE user_id = $1`, users[0].UUID).Scan(&memberCount); err != nil {
			t.Fatalf("count home_members: %v", err)
		}
		if memberCount != 1 {
			t.Errorf("%d rows in home_members for user %s, want 1", memberCount, users[0].UUID)
		}
	})
}

// TestProvisionIdempotent covers the sequential case LockSubject's comment
// calls out alongside the concurrent one: a subject that already has a user
// and a home must get the same pair back, not a second home and membership.
func TestProvisionIdempotent(t *testing.T) {
	sqlDB := openTestDB(t)
	repo := newAccountRepo(sqlDB)

	subject := uniqueSubject("idempotent")
	id := account.Identity{Subject: subject, Email: subject + "@example.com", DisplayName: "Idempotent Test"}
	target := account.HomeTarget{Name: "Idempotent Book"}

	user1, home1, err := repo.ProvisionUser(context.Background(), id, target)
	if err != nil {
		t.Fatalf("first ProvisionUser: %v", err)
	}
	cleanupProvisioned(t, sqlDB, user1.UUID, home1.UUID)

	user2, home2, err := repo.ProvisionUser(context.Background(), id, target)
	if err != nil {
		t.Fatalf("second ProvisionUser: %v", err)
	}

	t.Run("the same user and home come back", func(t *testing.T) {
		if user2.UUID != user1.UUID {
			t.Errorf("second provision returned user %s, want %s", user2.UUID, user1.UUID)
		}
		if home2.UUID != home1.UUID {
			t.Errorf("second provision returned home %s, want %s", home2.UUID, home1.UUID)
		}
	})

	t.Run("no second home or membership appears", func(t *testing.T) {
		var homeCount int
		if err := sqlDB.QueryRow(`SELECT count(*) FROM homes WHERE name = $1`, target.Name).Scan(&homeCount); err != nil {
			t.Fatalf("count homes: %v", err)
		}
		if homeCount != 1 {
			t.Errorf("%d rows in homes named %q, want 1", homeCount, target.Name)
		}

		var memberCount int
		if err := sqlDB.QueryRow(`SELECT count(*) FROM home_members WHERE user_id = $1`, user1.UUID).Scan(&memberCount); err != nil {
			t.Fatalf("count home_members: %v", err)
		}
		if memberCount != 1 {
			t.Errorf("%d rows in home_members for user %s, want 1", memberCount, user1.UUID)
		}
	})
}

// TestProvisionFounderSubject exercises AccountService's homeTarget branch: a
// subject matching the service's configured founder subject attaches to
// account.FounderHomeID (the home that predates multitenancy) instead of
// getting a fresh one, and nobody else does.
func TestProvisionFounderSubject(t *testing.T) {
	sqlDB := openTestDB(t)
	repo := newAccountRepo(sqlDB)

	founderSubject := uniqueSubject("founder")
	svc := service.NewAccountService(repo, founderSubject, metrics.NoopAccountProbe{})

	t.Run("the founder subject attaches to the founder home", func(t *testing.T) {
		user, err := svc.ProvisionFromSubject(context.Background(), account.Identity{
			Subject: founderSubject,
			Email:   "founder@example.com",
		})
		if err != nil {
			t.Fatalf("ProvisionFromSubject: %v", err)
		}
		// Only a membership was added; the founder home itself is never ours to
		// delete.
		t.Cleanup(func() {
			if _, err := sqlDB.Exec(`DELETE FROM home_members WHERE user_id = $1`, user.UUID); err != nil {
				t.Errorf("clean up founder membership: %v", err)
			}
			if _, err := sqlDB.Exec(`DELETE FROM users WHERE uuid = $1`, user.UUID); err != nil {
				t.Errorf("clean up founder user: %v", err)
			}
		})

		home, err := svc.ResolveActiveHome(context.Background(), user, uuid.Nil)
		if err != nil {
			t.Fatalf("ResolveActiveHome: %v", err)
		}
		if home.UUID != account.FounderHomeID {
			t.Errorf("founder subject landed in home %s, want the founder home %s", home.UUID, account.FounderHomeID)
		}
	})

	t.Run("a different subject lands somewhere else", func(t *testing.T) {
		subject := uniqueSubject("non-founder")
		user, err := svc.ProvisionFromSubject(context.Background(), account.Identity{
			Subject: subject,
			Email:   subject + "@example.com",
		})
		if err != nil {
			t.Fatalf("ProvisionFromSubject: %v", err)
		}
		home, err := svc.ResolveActiveHome(context.Background(), user, uuid.Nil)
		if err != nil {
			t.Fatalf("ResolveActiveHome: %v", err)
		}
		cleanupProvisioned(t, sqlDB, user.UUID, home.UUID)

		if home.UUID == account.FounderHomeID {
			t.Errorf("a non-founder subject landed in the founder home")
		}
	})
}

// TestProvisionHomeNaming covers AccountService.homeName: a fresh home is
// named after the local part of the caller's email, or "My Book" when there is
// no usable email to build a name from.
func TestProvisionHomeNaming(t *testing.T) {
	sqlDB := openTestDB(t)
	repo := newAccountRepo(sqlDB)
	svc := service.NewAccountService(repo, "", metrics.NoopAccountProbe{})

	t.Run("an email names the home after its local part", func(t *testing.T) {
		subject := uniqueSubject("naming-email")
		user, err := svc.ProvisionFromSubject(context.Background(), account.Identity{
			Subject: subject,
			Email:   "ada@example.com",
		})
		if err != nil {
			t.Fatalf("ProvisionFromSubject: %v", err)
		}
		home, err := svc.ResolveActiveHome(context.Background(), user, uuid.Nil)
		if err != nil {
			t.Fatalf("ResolveActiveHome: %v", err)
		}
		cleanupProvisioned(t, sqlDB, user.UUID, home.UUID)

		if want := "ada's Book"; home.Name != want {
			t.Errorf("home named %q, want %q", home.Name, want)
		}
	})

	t.Run("no email falls back to a generic name", func(t *testing.T) {
		subject := uniqueSubject("naming-noemail")
		user, err := svc.ProvisionFromSubject(context.Background(), account.Identity{
			Subject: subject,
		})
		if err != nil {
			t.Fatalf("ProvisionFromSubject: %v", err)
		}
		home, err := svc.ResolveActiveHome(context.Background(), user, uuid.Nil)
		if err != nil {
			t.Fatalf("ResolveActiveHome: %v", err)
		}
		cleanupProvisioned(t, sqlDB, user.UUID, home.UUID)

		if want := "My Book"; home.Name != want {
			t.Errorf("home named %q, want %q", home.Name, want)
		}
	})
}
