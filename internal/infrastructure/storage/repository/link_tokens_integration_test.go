package repository

import (
	"context"
	"errors"
	"testing"

	"github.com/google/uuid"

	"github.com/kieranajp/the-bluer-book/internal/domain/account"
	"github.com/kieranajp/the-bluer-book/internal/infrastructure/logger"
	"github.com/kieranajp/the-bluer-book/internal/infrastructure/storage/db"
)

func TestLinkTokens(t *testing.T) {
	sqlDB := openTestDB(t)
	skipUnlessUnrestricted(t, sqlDB)

	repo := NewAccountRepository(db.New(sqlDB), sqlDB, logger.New(logger.LogLevelError))
	ctx := context.Background()
	home := makeHome(t, sqlDB, "link tokens")

	_, hash, err := account.NewToken()
	if err != nil {
		t.Fatal(err)
	}

	issued, err := repo.CreateLink(ctx, home, hash)
	if err != nil {
		t.Fatalf("create link: %v", err)
	}
	if issued.HomeID != home || issued.HomeName != "link tokens" {
		t.Errorf("issued %+v, want a link for home %s named after it", issued, home)
	}

	found, err := repo.FindLiveLink(ctx, hash)
	if err != nil {
		t.Fatalf("find the live link: %v", err)
	}
	if found.UUID != issued.UUID || found.HomeID != home || found.HomeName != "link tokens" {
		t.Errorf("found %+v, want %+v", found, issued)
	}

	if _, err := repo.FindLiveLink(ctx, account.HashToken("never issued")); !errors.Is(err, account.ErrLinkNotFound) {
		t.Errorf("an unknown hash returned %v, want %v", err, account.ErrLinkNotFound)
	}

	if err := repo.RevokeLink(ctx, issued.UUID); err != nil {
		t.Fatalf("revoke: %v", err)
	}
	if _, err := repo.FindLiveLink(ctx, hash); !errors.Is(err, account.ErrLinkNotFound) {
		t.Errorf("a revoked link returned %v, want %v", err, account.ErrLinkNotFound)
	}
	if err := repo.RevokeLink(ctx, issued.UUID); !errors.Is(err, account.ErrLinkNotFound) {
		t.Errorf("revoking twice returned %v, want %v", err, account.ErrLinkNotFound)
	}

	if _, err := repo.CreateLink(ctx, uuid.New(), "hash for no home"); !errors.Is(err, account.ErrHomeNotFound) {
		t.Errorf("a link for a missing home returned %v, want %v", err, account.ErrHomeNotFound)
	}
}
