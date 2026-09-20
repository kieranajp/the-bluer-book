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

// accountRepository reads and writes the identity tables, which resolve a
// request before any home is known.
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

func (r *accountRepository) FindUserByID(ctx context.Context, userID uuid.UUID) (account.User, error) {
	row, err := r.db.GetUserByUUID(ctx, userID)
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
		home, err = joinHome(ctx, q, user.Uuid, target, account.RoleOwner)
	}
	if err != nil {
		return account.User{}, account.Home{}, err
	}

	if err := tx.Commit(); err != nil {
		return account.User{}, account.Home{}, err
	}
	return toUser(user), toHome(home), nil
}

// joinHome puts the user in the home the target names, creating that home first
// unless the target already identifies one.
func joinHome(ctx context.Context, q *db.Queries, userID uuid.UUID, target account.HomeTarget, role account.Role) (db.Home, error) {
	var home db.Home
	var err error

	if target.ID == uuid.Nil {
		home, err = q.CreateHome(ctx, target.Name)
	} else {
		home, err = q.GetHomeByID(ctx, target.ID)
		if errors.Is(err, sql.ErrNoRows) {
			// Landing them in a substitute home would quietly cut them off from
			// everything the named one holds.
			return db.Home{}, account.ErrHomeNotFound
		}
	}
	if err != nil {
		return db.Home{}, err
	}

	err = q.AddHomeMember(ctx, db.AddHomeMemberParams{
		HomeID: home.Uuid,
		UserID: userID,
		Role:   db.HomeRole(role),
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

func (r *accountRepository) FindHomeForUser(ctx context.Context, userID, homeID uuid.UUID) (account.Home, error) {
	row, err := r.db.GetHomeForUserByID(ctx, db.GetHomeForUserByIDParams{UserID: userID, HomeID: homeID})
	if errors.Is(err, sql.ErrNoRows) {
		return account.Home{}, account.ErrHomeNotFound
	}
	if err != nil {
		return account.Home{}, err
	}
	return toHome(row), nil
}

func (r *accountRepository) ListHomesForUser(ctx context.Context, userID uuid.UUID) ([]account.Membership, error) {
	rows, err := r.db.ListHomesForUser(ctx, userID)
	if err != nil {
		return nil, err
	}

	homes := make([]account.Membership, 0, len(rows))
	for _, row := range rows {
		homes = append(homes, account.Membership{Home: toHome(row.Home), Role: account.Role(row.Role)})
	}
	return homes, nil
}

func (r *accountRepository) FindRole(ctx context.Context, homeID, userID uuid.UUID) (account.Role, error) {
	role, err := r.db.GetMembershipRole(ctx, db.GetMembershipRoleParams{HomeID: homeID, UserID: userID})
	if errors.Is(err, sql.ErrNoRows) {
		return "", account.ErrForbidden
	}
	if err != nil {
		return "", err
	}
	return account.Role(role), nil
}

func (r *accountRepository) ListMembers(ctx context.Context, homeID uuid.UUID) ([]account.Member, error) {
	rows, err := r.db.ListMembersForHome(ctx, homeID)
	if err != nil {
		return nil, err
	}

	members := make([]account.Member, 0, len(rows))
	for _, row := range rows {
		members = append(members, account.Member{
			User: account.User{
				UUID:        row.Uuid,
				Subject:     row.Subject,
				Email:       row.Email,
				DisplayName: row.DisplayName,
				CreatedAt:   row.CreatedAt,
				UpdatedAt:   row.UpdatedAt,
			},
			Role: account.Role(row.Role),
		})
	}
	return members, nil
}

func (r *accountRepository) CreateInvitation(ctx context.Context, inv account.Invitation, tokenHash string) (account.Invitation, error) {
	row, err := r.db.CreateInvitation(ctx, db.CreateInvitationParams{
		HomeID:    inv.HomeID,
		Email:     inv.Email,
		TokenHash: tokenHash,
		Role:      db.HomeRole(inv.Role),
		InvitedBy: uuid.NullUUID{UUID: inv.InvitedBy, Valid: inv.InvitedBy != uuid.Nil},
		ExpiresAt: inv.ExpiresAt,
	})
	if err != nil {
		return account.Invitation{}, err
	}
	return toInvitation(row), nil
}

// RedeemInvitation spends a token and joins its home in one transaction, so
// neither half can happen without the other. The redeeming statement is a
// conditional UPDATE: it matches only an invitation that is unaccepted and
// unexpired, and marks it accepted as it matches. Two requests carrying the
// same token therefore cannot both be admitted, however closely they arrive,
// and a failure to add the member puts the token back by rolling the mark back.
func (r *accountRepository) RedeemInvitation(ctx context.Context, tokenHash string, userID uuid.UUID) (account.Home, account.Role, error) {
	tx, err := r.sqlDB.BeginTx(ctx, nil)
	if err != nil {
		return account.Home{}, "", err
	}
	defer tx.Rollback()

	q := db.New(tx)

	inv, err := q.RedeemInvitation(ctx, tokenHash)
	if errors.Is(err, sql.ErrNoRows) {
		return account.Home{}, "", refusalReason(ctx, q, tokenHash)
	}
	if err != nil {
		return account.Home{}, "", err
	}

	// A user already in this home keeps the standing they have: an invitation
	// admits people, it does not demote them.
	err = q.AddHomeMember(ctx, db.AddHomeMemberParams{
		HomeID: inv.HomeID,
		UserID: userID,
		Role:   inv.Role,
	})
	if err != nil {
		return account.Home{}, "", err
	}

	role, err := q.GetMembershipRole(ctx, db.GetMembershipRoleParams{HomeID: inv.HomeID, UserID: userID})
	if err != nil {
		return account.Home{}, "", err
	}

	home, err := q.GetHomeByID(ctx, inv.HomeID)
	if err != nil {
		return account.Home{}, "", err
	}

	if err := tx.Commit(); err != nil {
		return account.Home{}, "", err
	}

	r.logger.Info().Str("home_id", home.Uuid.String()).Str("user_id", userID.String()).Msg("Invitation accepted")
	return toHome(home), account.Role(role), nil
}

// refusalReason says why a token redeemed nothing. It runs only after the
// redeeming statement has already declined to match, so it decides no
// admission — it only turns one silence into an answer the caller can act on.
func refusalReason(ctx context.Context, q *db.Queries, tokenHash string) error {
	inv, err := q.GetInvitationByTokenHash(ctx, tokenHash)
	if errors.Is(err, sql.ErrNoRows) {
		return account.ErrInvitationNotFound
	}
	if err != nil {
		return err
	}
	if inv.AcceptedAt.Valid {
		return account.ErrInvitationUsed
	}
	return account.ErrInvitationExpired
}

// RemoveMember takes a user out of a home under a lock on that home, because
// the last-owner rule is a statement about the whole membership. Counting
// owners and then deleting one without the lock lets two removals each see the
// other's owner and each proceed, leaving a home nobody can administer.
func (r *accountRepository) RemoveMember(ctx context.Context, homeID, userID uuid.UUID) error {
	tx, err := r.sqlDB.BeginTx(ctx, nil)
	if err != nil {
		return err
	}
	defer tx.Rollback()

	q := db.New(tx)

	if _, err := q.LockHome(ctx, homeID); errors.Is(err, sql.ErrNoRows) {
		return account.ErrHomeNotFound
	} else if err != nil {
		return err
	}

	role, err := q.GetMembershipRole(ctx, db.GetMembershipRoleParams{HomeID: homeID, UserID: userID})
	if errors.Is(err, sql.ErrNoRows) {
		return account.ErrMemberNotFound
	}
	if err != nil {
		return err
	}

	if account.Role(role) == account.RoleOwner {
		owners, err := q.CountHomeOwners(ctx, homeID)
		if err != nil {
			return err
		}
		if owners <= 1 {
			return account.ErrLastOwner
		}
	}

	removed, err := q.RemoveHomeMember(ctx, db.RemoveHomeMemberParams{HomeID: homeID, UserID: userID})
	if err != nil {
		return err
	}
	if removed == 0 {
		return account.ErrMemberNotFound
	}

	return tx.Commit()
}

func toInvitation(row db.Invitation) account.Invitation {
	return account.Invitation{
		UUID:      row.Uuid,
		HomeID:    row.HomeID,
		Email:     row.Email,
		Role:      account.Role(row.Role),
		InvitedBy: row.InvitedBy.UUID,
		ExpiresAt: row.ExpiresAt,
		CreatedAt: row.CreatedAt,
	}
}
