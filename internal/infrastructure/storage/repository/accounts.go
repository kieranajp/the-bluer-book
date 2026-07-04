package repository

import (
	"context"
	"database/sql"
	"errors"

	"github.com/google/uuid"

	"github.com/kieranajp/the-bluer-book/internal/domain/account"
	"github.com/kieranajp/the-bluer-book/internal/infrastructure/storage/db"
)

// accountRepository persists users, homes, memberships and invitations.
// It implements account.Repository — see that interface for the contract.
// These tables are deliberately outside the per-home RLS policy: they
// resolve who you are *before* a home context exists for the request,
// so this repo uses the connection pool directly rather than InHomeTx.
type accountRepository struct {
	q *db.Queries
}

func NewAccountRepository(q *db.Queries) account.Repository {
	return &accountRepository{q: q}
}

func (r *accountRepository) GetUserBySubject(ctx context.Context, subject string) (*account.User, error) {
	row, err := r.q.GetUserBySubject(ctx, subject)
	if err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			return nil, account.ErrUserNotFound
		}
		return nil, err
	}
	return userFromRow(row), nil
}

func (r *accountRepository) GetUserByUUID(ctx context.Context, id uuid.UUID) (*account.User, error) {
	row, err := r.q.GetUserByUUID(ctx, id)
	if err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			return nil, account.ErrUserNotFound
		}
		return nil, err
	}
	return userFromRow(row), nil
}

func (r *accountRepository) CreateUser(ctx context.Context, subject, email, displayName string) (*account.User, error) {
	row, err := r.q.CreateUser(ctx, db.CreateUserParams{
		Subject:     subject,
		Email:       nullString(email),
		DisplayName: nullString(displayName),
	})
	if err != nil {
		return nil, err
	}
	return userFromRow(row), nil
}

func (r *accountRepository) CreateHome(ctx context.Context, name string) (*account.Home, error) {
	row, err := r.q.CreateHome(ctx, name)
	if err != nil {
		return nil, err
	}
	return homeFromRow(row), nil
}

func (r *accountRepository) GetHomeByID(ctx context.Context, id uuid.UUID) (*account.Home, error) {
	row, err := r.q.GetHomeByID(ctx, id)
	if err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			return nil, account.ErrHomeNotFound
		}
		return nil, err
	}
	return homeFromRow(row), nil
}

func (r *accountRepository) GetHomeForUserByID(ctx context.Context, userID, homeID uuid.UUID) (*account.Home, error) {
	row, err := r.q.GetHomeForUserByID(ctx, db.GetHomeForUserByIDParams{
		UserID: userID,
		Uuid:   homeID,
	})
	if err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			return nil, account.ErrHomeNotFound
		}
		return nil, err
	}
	return homeFromRow(row), nil
}

func (r *accountRepository) GetMostRecentHomeForUser(ctx context.Context, userID uuid.UUID) (*account.Home, error) {
	row, err := r.q.GetMostRecentHomeForUser(ctx, userID)
	if err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			return nil, account.ErrHomeNotFound
		}
		return nil, err
	}
	return homeFromRow(row), nil
}

func (r *accountRepository) ListHomesForUser(ctx context.Context, userID uuid.UUID) ([]account.Membership, error) {
	rows, err := r.q.ListHomesForUser(ctx, userID)
	if err != nil {
		return nil, err
	}
	out := make([]account.Membership, len(rows))
	for i, row := range rows {
		out[i] = account.Membership{
			Home: account.Home{
				UUID:      row.Uuid,
				Name:      row.Name,
				CreatedAt: row.CreatedAt,
				UpdatedAt: row.UpdatedAt,
			},
			Role: account.Role(row.Role),
		}
	}
	return out, nil
}

func (r *accountRepository) AddMember(ctx context.Context, homeID, userID uuid.UUID, role account.Role) error {
	_, err := r.q.AddHomeMember(ctx, db.AddHomeMemberParams{
		HomeID: homeID,
		UserID: userID,
		Role:   db.HomeRole(role),
	})
	return err
}

func (r *accountRepository) RemoveMember(ctx context.Context, homeID, userID uuid.UUID) error {
	return r.q.RemoveHomeMember(ctx, db.RemoveHomeMemberParams{
		HomeID: homeID,
		UserID: userID,
	})
}

func (r *accountRepository) GetMembership(ctx context.Context, homeID, userID uuid.UUID) (account.Role, error) {
	row, err := r.q.GetMembership(ctx, db.GetMembershipParams{
		HomeID: homeID,
		UserID: userID,
	})
	if err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			return "", account.ErrForbidden
		}
		return "", err
	}
	return account.Role(row), nil
}

func (r *accountRepository) ListMembers(ctx context.Context, homeID uuid.UUID) ([]account.MemberWithUser, error) {
	rows, err := r.q.ListMembersForHome(ctx, homeID)
	if err != nil {
		return nil, err
	}
	out := make([]account.MemberWithUser, len(rows))
	for i, row := range rows {
		out[i] = account.MemberWithUser{
			User: account.User{
				UUID:        row.Uuid,
				Subject:     row.Subject,
				Email:       row.Email.String,
				DisplayName: row.DisplayName.String,
				CreatedAt:   row.CreatedAt,
				UpdatedAt:   row.UpdatedAt,
			},
			Role: account.Role(row.Role),
		}
	}
	return out, nil
}

func (r *accountRepository) CountOwners(ctx context.Context, homeID uuid.UUID) (int, error) {
	count, err := r.q.CountOwnersOfHome(ctx, homeID)
	return int(count), err
}

func (r *accountRepository) CreateInvitation(ctx context.Context, inv account.Invitation) (*account.Invitation, error) {
	var invitedBy uuid.NullUUID
	if inv.InvitedBy != nil {
		invitedBy = uuid.NullUUID{UUID: *inv.InvitedBy, Valid: true}
	}
	row, err := r.q.CreateInvitation(ctx, db.CreateInvitationParams{
		HomeID:    inv.HomeID,
		Email:     inv.Email,
		Token:     inv.Token,
		Role:      db.HomeRole(inv.Role),
		InvitedBy: invitedBy,
		ExpiresAt: inv.ExpiresAt,
	})
	if err != nil {
		return nil, err
	}
	return invitationFromRow(row), nil
}

func (r *accountRepository) GetInvitationByToken(ctx context.Context, token string) (*account.Invitation, error) {
	row, err := r.q.GetInvitationByToken(ctx, token)
	if err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			return nil, account.ErrInvitationNotFound
		}
		return nil, err
	}
	return invitationFromRow(row), nil
}

func (r *accountRepository) MarkInvitationAccepted(ctx context.Context, invitationID uuid.UUID) error {
	return r.q.MarkInvitationAccepted(ctx, invitationID)
}

func (r *accountRepository) ListInvitations(ctx context.Context, homeID uuid.UUID) ([]account.Invitation, error) {
	rows, err := r.q.ListInvitationsForHome(ctx, homeID)
	if err != nil {
		return nil, err
	}
	out := make([]account.Invitation, len(rows))
	for i, row := range rows {
		out[i] = *invitationFromRow(row)
	}
	return out, nil
}

// Helpers — translation between db and domain.

func userFromRow(row db.User) *account.User {
	return &account.User{
		UUID:        row.Uuid,
		Subject:     row.Subject,
		Email:       row.Email.String,
		DisplayName: row.DisplayName.String,
		CreatedAt:   row.CreatedAt,
		UpdatedAt:   row.UpdatedAt,
	}
}

func homeFromRow(row db.Home) *account.Home {
	return &account.Home{
		UUID:      row.Uuid,
		Name:      row.Name,
		CreatedAt: row.CreatedAt,
		UpdatedAt: row.UpdatedAt,
	}
}

func invitationFromRow(row db.Invitation) *account.Invitation {
	inv := &account.Invitation{
		UUID:      row.Uuid,
		HomeID:    row.HomeID,
		Email:     row.Email,
		Token:     row.Token,
		Role:      account.Role(row.Role),
		ExpiresAt: row.ExpiresAt,
		CreatedAt: row.CreatedAt,
	}
	if row.InvitedBy.Valid {
		id := row.InvitedBy.UUID
		inv.InvitedBy = &id
	}
	if row.AcceptedAt.Valid {
		t := row.AcceptedAt.Time
		inv.AcceptedAt = &t
	}
	return inv
}

func nullString(s string) sql.NullString {
	return sql.NullString{String: s, Valid: s != ""}
}
