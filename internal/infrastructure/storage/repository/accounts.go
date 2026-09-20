package repository

import (
	"context"
	"database/sql"
	"errors"

	"github.com/google/uuid"

	"github.com/kieranajp/the-bluer-book/internal/domain/account"
	"github.com/kieranajp/the-bluer-book/internal/infrastructure/logger"
	"github.com/kieranajp/the-bluer-book/internal/infrastructure/storage/db"
)

// accountRepository reads and writes the identity tables. They sit outside
// per-home row-level security and resolve the request before a home is known,
// so this is the one repository that works on the plain pool rather than inside
// a home-scoped transaction.
type accountRepository struct {
	db     *db.Queries
	sqlDB  *sql.DB
	logger logger.Logger
}

func NewAccountRepository(queries *db.Queries, sqlDB *sql.DB, logger logger.Logger) account.Repository {
	return &accountRepository{db: queries, sqlDB: sqlDB, logger: logger}
}

func (r *accountRepository) FindUserBySubject(ctx context.Context, subject string) (account.User, error) {
	row, err := r.db.GetUserBySubject(ctx, subject)
	if errors.Is(err, sql.ErrNoRows) {
		return account.User{}, account.ErrUserNotFound
	}
	if err != nil {
		return account.User{}, err
	}
	return toUser(row), nil
}

func (r *accountRepository) FindMostRecentHome(ctx context.Context, userID uuid.UUID) (account.Home, error) {
	row, err := r.db.GetMostRecentHomeForUser(ctx, userID)
	if errors.Is(err, sql.ErrNoRows) {
		return account.Home{}, account.ErrHomeNotFound
	}
	if err != nil {
		return account.Home{}, err
	}
	return toHome(row), nil
}

func (r *accountRepository) ProvisionUser(ctx context.Context, id account.Identity, target account.HomeTarget) (account.User, account.Home, error) {
	tx, err := r.sqlDB.BeginTx(ctx, nil)
	if err != nil {
		return account.User{}, account.Home{}, err
	}
	defer tx.Rollback()

	q := db.New(tx)

	// The lock and the re-checks below are what make this idempotent: a subject
	// provisioned twice at once settles on one user and one home rather than
	// racing to create two.
	if err := q.LockSubject(ctx, id.Subject); err != nil {
		return account.User{}, account.Home{}, err
	}

	user, err := q.GetUserBySubject(ctx, id.Subject)
	if errors.Is(err, sql.ErrNoRows) {
		r.logger.Info().Str("subject", id.Subject).Msg("Provisioning a new user")
		user, err = q.CreateUser(ctx, db.CreateUserParams{
			Subject:     id.Subject,
			Email:       id.Email,
			DisplayName: id.DisplayName,
		})
	}
	if err != nil {
		return account.User{}, account.Home{}, err
	}

	home, err := q.GetMostRecentHomeForUser(ctx, user.Uuid)
	if errors.Is(err, sql.ErrNoRows) {
		home, err = joinHome(ctx, q, user.Uuid, target)
	}
	if err != nil {
		return account.User{}, account.Home{}, err
	}

	if err := tx.Commit(); err != nil {
		return account.User{}, account.Home{}, err
	}
	return toUser(user), toHome(home), nil
}

// joinHome makes the user an owner of the home the target names, creating that
// home first unless the target already identifies one.
func joinHome(ctx context.Context, q *db.Queries, userID uuid.UUID, target account.HomeTarget) (db.Home, error) {
	var home db.Home
	var err error

	if target.ID == uuid.Nil {
		home, err = q.CreateHome(ctx, target.Name)
	} else {
		home, err = q.GetHomeByID(ctx, target.ID)
		if errors.Is(err, sql.ErrNoRows) {
			// Only the founder home is ever named directly, and migration 00011
			// creates it. Landing the user somewhere else would quietly cut them
			// off from every recipe that home holds.
			return db.Home{}, account.ErrHomeNotFound
		}
	}
	if err != nil {
		return db.Home{}, err
	}

	err = q.AddHomeMember(ctx, db.AddHomeMemberParams{
		HomeID: home.Uuid,
		UserID: userID,
		Role:   db.HomeRoleOwner,
	})
	if err != nil {
		return db.Home{}, err
	}
	return home, nil
}

func toUser(row db.User) account.User {
	return account.User{
		UUID:        row.Uuid,
		Subject:     row.Subject,
		Email:       row.Email,
		DisplayName: row.DisplayName,
		CreatedAt:   row.CreatedAt,
		UpdatedAt:   row.UpdatedAt,
	}
}

func toHome(row db.Home) account.Home {
	return account.Home{
		UUID:      row.Uuid,
		Name:      row.Name,
		CreatedAt: row.CreatedAt,
		UpdatedAt: row.UpdatedAt,
	}
}
