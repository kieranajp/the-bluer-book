package repository

// Invitations and the last-owner rule are the two places where the account
// repository decides something the database cannot be asked again afterwards:
// a token is good once, and a home never loses its last owner. Both guards are
// statements about concurrent callers, so both are proved here against a real
// postgres rather than a mock.

import (
	"context"
	"database/sql"
	"errors"
	"strings"
	"sync"
	"testing"
	"time"

	"github.com/google/uuid"

	"github.com/kieranajp/the-bluer-book/internal/domain/account"
)

// membershipUser inserts a user row directly, because these suites care about
// memberships rather than about how a user came to exist. home_members
// cascades from users, so removing the user removes everything it joined.
func membershipUser(t *testing.T, sqlDB *sql.DB, label string) account.User {
	t.Helper()

	subject := uniqueSubject("membership-" + label)
	var user account.User
	err := sqlDB.QueryRow(
		`INSERT INTO users (subject, email, display_name) VALUES ($1, $2, $3)
		 RETURNING uuid, subject, email, display_name`,
		subject, subject+"@example.com", "Membership "+label,
	).Scan(&user.UUID, &user.Subject, &user.Email, &user.DisplayName)
	if err != nil {
		t.Fatalf("create user %s: %v", label, err)
	}
	t.Cleanup(func() {
		if _, err := sqlDB.Exec(`DELETE FROM users WHERE uuid = $1`, user.UUID); err != nil {
			t.Errorf("clean up user %s: %v", user.UUID, err)
		}
	})
	return user
}

// membershipHome creates a home under a name no other run can collide with.
// Deleting it cascades to its members and its invitations.
func membershipHome(t *testing.T, sqlDB *sql.DB, label string) uuid.UUID {
	t.Helper()
	return makeHome(t, sqlDB, "membership test "+label+" "+uuid.New().String())
}

// addMembership puts a user in a home without going through the repository, so
// a test can arrange the standing it wants to act on.
func addMembership(t *testing.T, sqlDB *sql.DB, homeID, userID uuid.UUID, role account.Role) {
	t.Helper()

	_, err := sqlDB.Exec(
		`INSERT INTO home_members (home_id, user_id, role) VALUES ($1, $2, $3::home_role)`,
		homeID, userID, string(role),
	)
	if err != nil {
		t.Fatalf("add %s as %s: %v", userID, role, err)
	}
}

// invite creates an invitation through the repository and returns the token
// only the invitee ever sees. The hash is what reaches storage.
func invite(t *testing.T, repo account.Repository, homeID, inviterID uuid.UUID, role account.Role) (token string, inv account.Invitation) {
	t.Helper()

	token, hash, err := account.NewInvitationToken()
	if err != nil {
		t.Fatalf("new invitation token: %v", err)
	}
	inv, err = repo.CreateInvitation(context.Background(), account.Invitation{
		HomeID:    homeID,
		Email:     "invitee-" + uuid.New().String() + "@example.com",
		Role:      role,
		InvitedBy: inviterID,
		ExpiresAt: time.Now().Add(time.Hour),
	}, hash)
	if err != nil {
		t.Fatalf("create invitation: %v", err)
	}
	return token, inv
}

// expiredInvitation writes the row itself: the service always stamps a future
// expiry, so a past one can only be arranged behind it.
func expiredInvitation(t *testing.T, sqlDB *sql.DB, homeID uuid.UUID) (token string) {
	t.Helper()

	token, hash, err := account.NewInvitationToken()
	if err != nil {
		t.Fatalf("new invitation token: %v", err)
	}
	_, err = sqlDB.Exec(
		`INSERT INTO invitations (home_id, email, token_hash, role, expires_at)
		 VALUES ($1, $2, $3, 'member', now() - interval '1 hour')`,
		homeID, "expired-"+uuid.New().String()+"@example.com", hash,
	)
	if err != nil {
		t.Fatalf("create expired invitation: %v", err)
	}
	return token
}

// countRows answers a single-column count query, so an assertion about what the
// database holds reads as one line.
func countRows(t *testing.T, sqlDB *sql.DB, query string, args ...any) int {
	t.Helper()

	var n int
	if err := sqlDB.QueryRow(query, args...).Scan(&n); err != nil {
		t.Fatalf("count (%s): %v", query, err)
	}
	return n
}

// holdRowLock opens a transaction holding a row lock and hands back the release.
// Releasing rolls back, so the lock changes nothing — it exists only to park
// every racer on one row at once.
//
// Simply releasing goroutines together does not reproduce a race here: each
// one's first statement costs a connection handshake, so the leader routinely
// commits before the rest have read anything, and a read-then-write redemption
// then passes. Parking them on a lock the test releases collapses that
// staggering, and the interleaving under test happens every run rather than
// occasionally.
func holdRowLock(t *testing.T, sqlDB *sql.DB, query string, args ...any) (release func()) {
	t.Helper()

	tx, err := sqlDB.Begin()
	if err != nil {
		t.Fatalf("begin the lock holder: %v", err)
	}
	var locked int
	if err := tx.QueryRow(query, args...).Scan(&locked); err != nil {
		tx.Rollback()
		t.Fatalf("take the row lock: %v", err)
	}

	var once sync.Once
	release = func() { once.Do(func() { tx.Rollback() }) }
	t.Cleanup(release)
	return release
}

// lockWaiters counts backends parked on a lock, which is how a test sees that
// its racers have all arrived.
func lockWaiters(t *testing.T, sqlDB *sql.DB) int {
	t.Helper()
	return countRows(t, sqlDB,
		`SELECT count(*) FROM pg_stat_activity
		 WHERE datname = current_database() AND wait_event_type = 'Lock'`)
}

// waitFor polls a condition to a deadline, so a race that never assembles fails
// as a timeout rather than hanging.
func waitFor(t *testing.T, what string, cond func() bool) {
	t.Helper()

	deadline := time.Now().Add(10 * time.Second)
	for time.Now().Before(deadline) {
		if cond() {
			return
		}
		time.Sleep(2 * time.Millisecond)
	}
	t.Fatalf("timed out waiting for %s", what)
}

// TestMembershipInvitationTokenIsHashed proves the invitations table cannot
// admit anybody to a home on its own. Redemption works from a hash either way,
// so every behavioural test in this file passes against a schema that also
// keeps the plaintext beside it; only reading the row back catches that.
func TestMembershipInvitationTokenIsHashed(t *testing.T) {
	sqlDB := openTestDB(t)
	repo := newAccountRepo(sqlDB)

	inviter := membershipUser(t, sqlDB, "hash-inviter")
	homeID := membershipHome(t, sqlDB, "hash")
	addMembership(t, sqlDB, homeID, inviter.UUID, account.RoleOwner)

	token, inv := invite(t, repo, homeID, inviter.UUID, account.RoleMember)

	t.Run("no row stores the plaintext token", func(t *testing.T) {
		if n := countRows(t, sqlDB, `SELECT count(*) FROM invitations WHERE token_hash = $1`, token); n != 0 {
			t.Errorf("%d invitations hold the plaintext token in token_hash, want 0", n)
		}

		// Any column at all, not only the one named token_hash: a column added
		// later would otherwise carry the credential past this suite unnoticed.
		var row string
		if err := sqlDB.QueryRow(`SELECT to_jsonb(i)::text FROM invitations i WHERE uuid = $1`, inv.UUID).Scan(&row); err != nil {
			t.Fatalf("read invitation row: %v", err)
		}
		if strings.Contains(row, token) {
			t.Errorf("the stored invitation row contains the plaintext token")
		}
	})

	t.Run("token_hash is the token's hash", func(t *testing.T) {
		var stored string
		if err := sqlDB.QueryRow(`SELECT token_hash FROM invitations WHERE uuid = $1`, inv.UUID).Scan(&stored); err != nil {
			t.Fatalf("read token_hash: %v", err)
		}
		if want := account.HashInvitationToken(token); stored != want {
			t.Errorf("token_hash is %q, want %q", stored, want)
		}
	})

	t.Run("the schema has no token column", func(t *testing.T) {
		n := countRows(t, sqlDB,
			`SELECT count(*) FROM information_schema.columns
			 WHERE table_schema = 'public' AND table_name = 'invitations' AND column_name = 'token'`)
		if n != 0 {
			t.Errorf("invitations has a token column: a migration has reintroduced plaintext storage")
		}
	})
}

// TestMembershipInvitationExpiresAtIsTimestamptz pins the column type. A naked
// timestamp compares against now() differently depending on the session's
// TimeZone, so a credential's lifetime would depend on who is asking — and
// every expiry test here would still pass on a UTC session.
func TestMembershipInvitationExpiresAtIsTimestamptz(t *testing.T) {
	sqlDB := openTestDB(t)

	var dataType string
	err := sqlDB.QueryRow(
		`SELECT data_type FROM information_schema.columns
		 WHERE table_schema = 'public' AND table_name = 'invitations' AND column_name = 'expires_at'`,
	).Scan(&dataType)
	if err != nil {
		t.Fatalf("read expires_at's type: %v", err)
	}
	if want := "timestamp with time zone"; dataType != want {
		t.Errorf("invitations.expires_at is %q, want %q", dataType, want)
	}
}

// TestMembershipExpiredInvitationRefused proves the expiry is enforced where
// the token is spent. An implementation that never compares expires_at admits
// the holder and passes every other invitation test in this file.
func TestMembershipExpiredInvitationRefused(t *testing.T) {
	sqlDB := openTestDB(t)
	repo := newAccountRepo(sqlDB)

	homeID := membershipHome(t, sqlDB, "expired")
	invitee := membershipUser(t, sqlDB, "expired-invitee")
	token := expiredInvitation(t, sqlDB, homeID)

	_, _, err := repo.RedeemInvitation(context.Background(), account.HashInvitationToken(token), invitee.UUID)
	if !errors.Is(err, account.ErrInvitationExpired) {
		t.Errorf("RedeemInvitation on an expired token returned %v, want %v", err, account.ErrInvitationExpired)
	}

	if n := countRows(t, sqlDB, `SELECT count(*) FROM home_members WHERE user_id = $1`, invitee.UUID); n != 0 {
		t.Errorf("the refused invitee holds %d memberships, want 0", n)
	}
}

// TestMembershipInvitationRedeemedOnce proves an invitation is spent by being
// used. A redemption that leaves accepted_at alone lets one link admit a crowd.
func TestMembershipInvitationRedeemedOnce(t *testing.T) {
	sqlDB := openTestDB(t)
	repo := newAccountRepo(sqlDB)

	inviter := membershipUser(t, sqlDB, "once-inviter")
	homeID := membershipHome(t, sqlDB, "once")
	addMembership(t, sqlDB, homeID, inviter.UUID, account.RoleOwner)

	first := membershipUser(t, sqlDB, "once-first")
	second := membershipUser(t, sqlDB, "once-second")
	token, _ := invite(t, repo, homeID, inviter.UUID, account.RoleMember)
	hash := account.HashInvitationToken(token)

	if _, _, err := repo.RedeemInvitation(context.Background(), hash, first.UUID); err != nil {
		t.Fatalf("first RedeemInvitation: %v", err)
	}
	before := countRows(t, sqlDB, `SELECT count(*) FROM home_members WHERE home_id = $1`, homeID)

	_, _, err := repo.RedeemInvitation(context.Background(), hash, second.UUID)
	if !errors.Is(err, account.ErrInvitationUsed) {
		t.Errorf("second RedeemInvitation returned %v, want %v", err, account.ErrInvitationUsed)
	}

	if after := countRows(t, sqlDB, `SELECT count(*) FROM home_members WHERE home_id = $1`, homeID); after != before {
		t.Errorf("the home holds %d members after the refused redemption, want %d", after, before)
	}
}

// TestMembershipUnknownTokenRefused separates "no such invitation" from the
// refusals that follow a real one, so the caller is told which happened.
func TestMembershipUnknownTokenRefused(t *testing.T) {
	sqlDB := openTestDB(t)
	repo := newAccountRepo(sqlDB)

	invitee := membershipUser(t, sqlDB, "unknown-invitee")
	token, _, err := account.NewInvitationToken()
	if err != nil {
		t.Fatalf("new invitation token: %v", err)
	}

	_, _, err = repo.RedeemInvitation(context.Background(), account.HashInvitationToken(token), invitee.UUID)
	if !errors.Is(err, account.ErrInvitationNotFound) {
		t.Errorf("RedeemInvitation on an unstored token returned %v, want %v", err, account.ErrInvitationNotFound)
	}
}

// TestMembershipRedemptionIsAtomic proves the two halves of a redemption land
// together. Assertions read the database rather than the return value, because
// a redemption that marks the invitation and then fails to add the member
// returns exactly the same pair as one that did both.
func TestMembershipRedemptionIsAtomic(t *testing.T) {
	sqlDB := openTestDB(t)
	repo := newAccountRepo(sqlDB)

	inviter := membershipUser(t, sqlDB, "atomic-inviter")
	homeID := membershipHome(t, sqlDB, "atomic")
	addMembership(t, sqlDB, homeID, inviter.UUID, account.RoleOwner)

	invitee := membershipUser(t, sqlDB, "atomic-invitee")
	token, inv := invite(t, repo, homeID, inviter.UUID, account.RoleMember)

	if _, _, err := repo.RedeemInvitation(context.Background(), account.HashInvitationToken(token), invitee.UUID); err != nil {
		t.Fatalf("RedeemInvitation: %v", err)
	}

	var acceptedAt sql.NullTime
	if err := sqlDB.QueryRow(`SELECT accepted_at FROM invitations WHERE uuid = $1`, inv.UUID).Scan(&acceptedAt); err != nil {
		t.Fatalf("read accepted_at: %v", err)
	}
	if !acceptedAt.Valid {
		t.Errorf("the invitation is still unaccepted after a successful redemption")
	}

	var role string
	err := sqlDB.QueryRow(
		`SELECT role FROM home_members WHERE home_id = $1 AND user_id = $2`, homeID, invitee.UUID,
	).Scan(&role)
	if errors.Is(err, sql.ErrNoRows) {
		t.Fatalf("the invitee holds no membership after a successful redemption")
	}
	if err != nil {
		t.Fatalf("read membership: %v", err)
	}
	if want := string(account.RoleMember); role != want {
		t.Errorf("the invitee joined as %q, want %q", role, want)
	}
}

// TestMembershipConcurrentRedemption is the case the conditional UPDATE exists
// for. A read-then-check-then-mark redemption passes every sequential test
// above: each transaction reads the invitation as unaccepted, and the one that
// marks it last still wins its own admission, so the whole queue gets in.
//
// Every racer is parked on the invitation row before any of them may write it,
// which is what makes the interleaving happen on every run. The conditional
// UPDATE re-checks accepted_at as it takes the row, so the losers match
// nothing; an UPDATE keyed on the invitation's id, decided in Go beforehand,
// matches regardless of what the winner just wrote.
//
// The racers are distinct users on purpose: with one user repeated,
// AddHomeMember's ON CONFLICT DO NOTHING collapses several admissions into one
// row and hides the breach.
func TestMembershipConcurrentRedemption(t *testing.T) {
	sqlDB := openTestDB(t)
	repo := newAccountRepo(sqlDB)

	inviter := membershipUser(t, sqlDB, "race-inviter")
	homeID := membershipHome(t, sqlDB, "race")
	addMembership(t, sqlDB, homeID, inviter.UUID, account.RoleOwner)

	const goroutines = 8
	invitees := make([]uuid.UUID, goroutines)
	for i := range invitees {
		invitees[i] = membershipUser(t, sqlDB, "race-invitee").UUID
	}

	token, inv := invite(t, repo, homeID, inviter.UUID, account.RoleMember)
	hash := account.HashInvitationToken(token)

	release := holdRowLock(t, sqlDB, `SELECT 1 FROM invitations WHERE uuid = $1 FOR UPDATE`, inv.UUID)

	var wg sync.WaitGroup
	start := make(chan struct{})
	errs := make([]error, goroutines)
	for i := 0; i < goroutines; i++ {
		wg.Add(1)
		go func(i int) {
			defer wg.Done()
			<-start
			_, _, errs[i] = repo.RedeemInvitation(context.Background(), hash, invitees[i])
		}(i)
	}
	close(start)

	waitFor(t, "every racer to queue on the invitation", func() bool {
		return lockWaiters(t, sqlDB) >= goroutines
	})
	release()
	wg.Wait()

	t.Run("exactly one redemption is admitted", func(t *testing.T) {
		admitted := 0
		for i, err := range errs {
			switch {
			case err == nil:
				admitted++
			case errors.Is(err, account.ErrInvitationUsed):
			default:
				t.Errorf("goroutine %d: RedeemInvitation returned %v, want nil or %v", i, err, account.ErrInvitationUsed)
			}
		}
		if admitted != 1 {
			t.Errorf("%d goroutines were admitted on one token, want 1", admitted)
		}
	})

	t.Run("the home gained exactly one member", func(t *testing.T) {
		n := countRows(t, sqlDB,
			`SELECT count(*) FROM home_members WHERE home_id = $1 AND user_id <> $2`, homeID, inviter.UUID)
		if n != 1 {
			t.Errorf("the home holds %d invited members, want 1", n)
		}
	})

	t.Run("the invitation is accepted once", func(t *testing.T) {
		n := countRows(t, sqlDB,
			`SELECT count(*) FROM invitations WHERE uuid = $1 AND accepted_at IS NOT NULL`, inv.UUID)
		if n != 1 {
			t.Errorf("%d accepted rows for the invitation, want 1", n)
		}
	})
}

// TestMembershipLastOwnerSurvivesRemoval proves a home cannot be left with
// nobody who can administer it. Removal is otherwise an ordinary DELETE and
// succeeds happily.
func TestMembershipLastOwnerSurvivesRemoval(t *testing.T) {
	sqlDB := openTestDB(t)
	repo := newAccountRepo(sqlDB)

	owner := membershipUser(t, sqlDB, "last-owner")
	member := membershipUser(t, sqlDB, "last-owner-member")
	homeID := membershipHome(t, sqlDB, "last-owner")
	addMembership(t, sqlDB, homeID, owner.UUID, account.RoleOwner)
	addMembership(t, sqlDB, homeID, member.UUID, account.RoleMember)

	err := repo.RemoveMember(context.Background(), homeID, owner.UUID)
	if !errors.Is(err, account.ErrLastOwner) {
		t.Errorf("removing the sole owner returned %v, want %v", err, account.ErrLastOwner)
	}

	// A plain member alongside them is not a substitute: the rule counts owners.
	n := countRows(t, sqlDB,
		`SELECT count(*) FROM home_members WHERE home_id = $1 AND user_id = $2 AND role = 'owner'`, homeID, owner.UUID)
	if n != 1 {
		t.Errorf("the refused owner's row is gone: %d rows, want 1", n)
	}
}

// TestMembershipOwnerRemovableBesideAnotherOwner proves the last-owner rule
// counts rather than forbidding owner removal outright.
func TestMembershipOwnerRemovableBesideAnotherOwner(t *testing.T) {
	sqlDB := openTestDB(t)
	repo := newAccountRepo(sqlDB)

	first := membershipUser(t, sqlDB, "two-owners-a")
	second := membershipUser(t, sqlDB, "two-owners-b")
	homeID := membershipHome(t, sqlDB, "two-owners")
	addMembership(t, sqlDB, homeID, first.UUID, account.RoleOwner)
	addMembership(t, sqlDB, homeID, second.UUID, account.RoleOwner)

	if err := repo.RemoveMember(context.Background(), homeID, first.UUID); err != nil {
		t.Fatalf("removing one of two owners: %v", err)
	}

	if n := countRows(t, sqlDB, `SELECT count(*) FROM home_members WHERE home_id = $1 AND user_id = $2`, homeID, first.UUID); n != 0 {
		t.Errorf("the removed owner still holds %d rows, want 0", n)
	}
	if n := countRows(t, sqlDB, `SELECT count(*) FROM home_members WHERE home_id = $1 AND role = 'owner'`, homeID); n != 1 {
		t.Errorf("the home has %d owners, want 1", n)
	}
}

// TestMembershipNonOwnerRemovable proves the rule reaches only owners: a
// member is removable however few owners the home has.
func TestMembershipNonOwnerRemovable(t *testing.T) {
	sqlDB := openTestDB(t)
	repo := newAccountRepo(sqlDB)

	owner := membershipUser(t, sqlDB, "member-removal-owner")
	member := membershipUser(t, sqlDB, "member-removal-member")
	homeID := membershipHome(t, sqlDB, "member-removal")
	addMembership(t, sqlDB, homeID, owner.UUID, account.RoleOwner)
	addMembership(t, sqlDB, homeID, member.UUID, account.RoleMember)

	if err := repo.RemoveMember(context.Background(), homeID, member.UUID); err != nil {
		t.Fatalf("removing a member from a home with one owner: %v", err)
	}
	if n := countRows(t, sqlDB, `SELECT count(*) FROM home_members WHERE home_id = $1 AND user_id = $2`, homeID, member.UUID); n != 0 {
		t.Errorf("the removed member still holds %d rows, want 0", n)
	}
}

// TestMembershipConcurrentOwnerRemoval is the case LockHome exists for. The
// last-owner rule is a statement about the whole membership, so counting owners
// and then deleting one is only safe while nobody else is deleting: two owners
// leaving at once each count two and each proceed, leaving a home nobody can
// administer. Every other last-owner test here is sequential and passes either
// way.
//
// The test holds both membership rows, so neither removal can commit until both
// racers have arrived. Holding only one lets the other finish first and see an
// honest count, which makes the race intermittent. Under LockHome the second
// removal never reaches its DELETE at all: it waits on the home, then finds one
// owner. Without it, both removals read two owners, both delete, and the home
// has none.
func TestMembershipConcurrentOwnerRemoval(t *testing.T) {
	sqlDB := openTestDB(t)
	repo := newAccountRepo(sqlDB)

	first := membershipUser(t, sqlDB, "race-owner-a")
	second := membershipUser(t, sqlDB, "race-owner-b")
	homeID := membershipHome(t, sqlDB, "race-owners")
	addMembership(t, sqlDB, homeID, first.UUID, account.RoleOwner)
	addMembership(t, sqlDB, homeID, second.UUID, account.RoleOwner)

	release := holdRowLock(t, sqlDB,
		`SELECT count(*) FROM (SELECT 1 FROM home_members WHERE home_id = $1 FOR UPDATE) held`, homeID)

	owners := []uuid.UUID{first.UUID, second.UUID}
	var wg sync.WaitGroup
	start := make(chan struct{})
	errs := make([]error, len(owners))
	for i := range owners {
		wg.Add(1)
		go func(i int) {
			defer wg.Done()
			<-start
			errs[i] = repo.RemoveMember(context.Background(), homeID, owners[i])
		}(i)
	}
	close(start)

	// One racer parks on a membership row, the other on that row or on the home,
	// depending on which took the home first. Either way both are waiting.
	waitFor(t, "both racers to park", func() bool {
		return lockWaiters(t, sqlDB) >= len(owners)
	})
	release()
	wg.Wait()

	removed := 0
	for i, err := range errs {
		switch {
		case err == nil:
			removed++
		case errors.Is(err, account.ErrLastOwner):
		default:
			t.Errorf("goroutine %d: RemoveMember returned %v, want nil or %v", i, err, account.ErrLastOwner)
		}
	}
	if removed != 1 {
		t.Errorf("%d of two simultaneous owner removals succeeded, want 1", removed)
	}
	if n := countRows(t, sqlDB, `SELECT count(*) FROM home_members WHERE home_id = $1 AND role = 'owner'`, homeID); n != 1 {
		t.Errorf("the home has %d owners after two simultaneous removals, want 1", n)
	}
}

// TestMembershipRemoveUnknownTargets proves the two ways a removal names
// nothing are told apart, so a caller is not left reading "not a member" about
// a home that never existed.
func TestMembershipRemoveUnknownTargets(t *testing.T) {
	sqlDB := openTestDB(t)
	repo := newAccountRepo(sqlDB)

	owner := membershipUser(t, sqlDB, "unknown-target-owner")
	stranger := membershipUser(t, sqlDB, "unknown-target-stranger")
	homeID := membershipHome(t, sqlDB, "unknown-target")
	addMembership(t, sqlDB, homeID, owner.UUID, account.RoleOwner)

	t.Run("a non-member", func(t *testing.T) {
		err := repo.RemoveMember(context.Background(), homeID, stranger.UUID)
		if !errors.Is(err, account.ErrMemberNotFound) {
			t.Errorf("removing a non-member returned %v, want %v", err, account.ErrMemberNotFound)
		}
	})

	t.Run("a home that does not exist", func(t *testing.T) {
		err := repo.RemoveMember(context.Background(), uuid.New(), owner.UUID)
		if !errors.Is(err, account.ErrHomeNotFound) {
			t.Errorf("removing from an absent home returned %v, want %v", err, account.ErrHomeNotFound)
		}
	})
}

// TestMembershipFindHomeForUser is the guard that stops X-Home naming somebody
// else's home. The negative uses a real second user and a real second home,
// because a random uuid proves only that missing homes are missing — the
// interesting failure is a home that exists and is not yours.
func TestMembershipFindHomeForUser(t *testing.T) {
	sqlDB := openTestDB(t)
	repo := newAccountRepo(sqlDB)

	mine := membershipUser(t, sqlDB, "scope-mine")
	theirs := membershipUser(t, sqlDB, "scope-theirs")
	myHome := membershipHome(t, sqlDB, "scope-mine")
	theirHome := membershipHome(t, sqlDB, "scope-theirs")
	addMembership(t, sqlDB, myHome, mine.UUID, account.RoleOwner)
	addMembership(t, sqlDB, theirHome, theirs.UUID, account.RoleOwner)

	t.Run("a member is given their home", func(t *testing.T) {
		home, err := repo.FindHomeForUser(context.Background(), mine.UUID, myHome)
		if err != nil {
			t.Fatalf("FindHomeForUser: %v", err)
		}
		if home.UUID != myHome {
			t.Errorf("FindHomeForUser returned home %s, want %s", home.UUID, myHome)
		}
	})

	t.Run("a non-member is given nothing", func(t *testing.T) {
		_, err := repo.FindHomeForUser(context.Background(), mine.UUID, theirHome)
		if !errors.Is(err, account.ErrHomeNotFound) {
			t.Errorf("FindHomeForUser on somebody else's home returned %v, want %v", err, account.ErrHomeNotFound)
		}
	})
}

// TestMembershipFindRole proves the standing a request is authorised against
// is the stored one, and that a non-member has none. Returning a default role
// for a stranger would hand them a member's authority everywhere.
func TestMembershipFindRole(t *testing.T) {
	sqlDB := openTestDB(t)
	repo := newAccountRepo(sqlDB)

	owner := membershipUser(t, sqlDB, "role-owner")
	member := membershipUser(t, sqlDB, "role-member")
	stranger := membershipUser(t, sqlDB, "role-stranger")
	homeID := membershipHome(t, sqlDB, "role")
	otherHome := membershipHome(t, sqlDB, "role-other")
	addMembership(t, sqlDB, homeID, owner.UUID, account.RoleOwner)
	addMembership(t, sqlDB, homeID, member.UUID, account.RoleMember)
	addMembership(t, sqlDB, otherHome, stranger.UUID, account.RoleOwner)

	for _, tc := range []struct {
		name   string
		userID uuid.UUID
		want   account.Role
	}{
		{"an owner", owner.UUID, account.RoleOwner},
		{"a member", member.UUID, account.RoleMember},
	} {
		t.Run(tc.name, func(t *testing.T) {
			role, err := repo.FindRole(context.Background(), homeID, tc.userID)
			if err != nil {
				t.Fatalf("FindRole: %v", err)
			}
			if role != tc.want {
				t.Errorf("FindRole returned %q, want %q", role, tc.want)
			}
		})
	}

	// An owner of another home, so the refusal is about this home rather than
	// about the user being unknown.
	t.Run("a non-member", func(t *testing.T) {
		_, err := repo.FindRole(context.Background(), homeID, stranger.UUID)
		if !errors.Is(err, account.ErrForbidden) {
			t.Errorf("FindRole for a non-member returned %v, want %v", err, account.ErrForbidden)
		}
	})
}

// TestMembershipListMembers proves the roster is the home's and only the
// home's. A listing that forgot its home_id would still return everybody the
// test put in it, so the second home's member is what makes this assertion
// worth running.
func TestMembershipListMembers(t *testing.T) {
	sqlDB := openTestDB(t)
	repo := newAccountRepo(sqlDB)

	owner := membershipUser(t, sqlDB, "roster-owner")
	member := membershipUser(t, sqlDB, "roster-member")
	outsider := membershipUser(t, sqlDB, "roster-outsider")
	homeID := membershipHome(t, sqlDB, "roster")
	otherHome := membershipHome(t, sqlDB, "roster-other")
	addMembership(t, sqlDB, homeID, owner.UUID, account.RoleOwner)
	addMembership(t, sqlDB, homeID, member.UUID, account.RoleMember)
	addMembership(t, sqlDB, otherHome, outsider.UUID, account.RoleMember)

	members, err := repo.ListMembers(context.Background(), homeID)
	if err != nil {
		t.Fatalf("ListMembers: %v", err)
	}

	roles := make(map[uuid.UUID]account.Role, len(members))
	for _, m := range members {
		roles[m.User.UUID] = m.Role
	}

	if len(members) != 2 {
		t.Errorf("ListMembers returned %d members, want 2", len(members))
	}
	if got := roles[owner.UUID]; got != account.RoleOwner {
		t.Errorf("the owner is listed as %q, want %q", got, account.RoleOwner)
	}
	if got := roles[member.UUID]; got != account.RoleMember {
		t.Errorf("the member is listed as %q, want %q", got, account.RoleMember)
	}
	if _, listed := roles[outsider.UUID]; listed {
		t.Errorf("ListMembers returned a member of another home")
	}

	// The subject comes off the joined user row; an empty one means the listing
	// is reporting memberships rather than people.
	for _, m := range members {
		if m.User.Subject == "" {
			t.Errorf("member %s is listed with no subject", m.User.UUID)
		}
	}
}
