// Package link issues and revokes the tokens another app reads one home with.
package link

import (
	"context"
	"database/sql"
	"errors"
	"fmt"
	"io"

	"github.com/google/uuid"
	_ "github.com/lib/pq"
	"github.com/urfave/cli/v2"

	"github.com/kieranajp/the-bluer-book/internal/domain/account"
	accountservice "github.com/kieranajp/the-bluer-book/internal/domain/account/service"
	"github.com/kieranajp/the-bluer-book/internal/infrastructure/config"
	"github.com/kieranajp/the-bluer-book/internal/infrastructure/logger"
	"github.com/kieranajp/the-bluer-book/internal/infrastructure/metrics"
	"github.com/kieranajp/the-bluer-book/internal/infrastructure/storage/db"
	"github.com/kieranajp/the-bluer-book/internal/infrastructure/storage/repository"
)

// IssueCommand writes the token alone to stdout, so it pipes straight into the
// app that stores it.
var IssueCommand = &cli.Command{
	Name:  "issue-link",
	Usage: "Issue a read-only link token for one home",
	Flags: append(config.DBFlags(),
		&cli.StringFlag{Name: "home", Usage: "Home the token reads"},
	),
	Action: func(c *cli.Context) error {
		return withLinks(c, func(links linker) error {
			return issue(c.Context, links, c.String("home"), c.App.Writer, c.App.ErrWriter)
		})
	},
}

var RevokeCommand = &cli.Command{
	Name:  "revoke-link",
	Usage: "Revoke a link token, so it reads nothing from then on",
	Flags: append(config.DBFlags(),
		&cli.StringFlag{Name: "id", Usage: "Link to revoke, as issue-link printed it"},
	),
	Action: func(c *cli.Context) error {
		return withLinks(c, func(links linker) error {
			return revoke(c.Context, links, c.String("id"), c.App.ErrWriter)
		})
	},
}

type linker interface {
	IssueLink(ctx context.Context, homeID uuid.UUID) (account.Link, string, error)
	RevokeLink(ctx context.Context, linkID uuid.UUID) error
}

// withLinks connects as the owning role: the server's role may only read
// link tokens.
func withLinks(c *cli.Context, fn func(linker) error) error {
	cfg := config.New(c)
	log := logger.NewTo(c.App.ErrWriter, logger.LogLevel(cfg.LogLevel))

	sqlDB, err := sql.Open("postgres", cfg.DBDSN())
	if err != nil {
		return fmt.Errorf("open db: %w", err)
	}
	defer sqlDB.Close()
	if err := sqlDB.PingContext(c.Context); err != nil {
		return fmt.Errorf("ping db: %w", err)
	}

	repo := repository.NewAccountRepository(db.New(sqlDB), sqlDB, log)
	return fn(accountservice.NewAccountService(repo, "", metrics.NewAccountProbe(log)))
}

func issue(ctx context.Context, links linker, home string, stdout, stderr io.Writer) error {
	homeID, err := uuid.Parse(home)
	if err != nil {
		return fmt.Errorf("--home %q is not a home id: %w", home, err)
	}

	link, token, err := links.IssueLink(ctx, homeID)
	if errors.Is(err, account.ErrHomeNotFound) {
		return fmt.Errorf("no home %s", homeID)
	}
	if err != nil {
		return fmt.Errorf("issue link: %w", err)
	}

	fmt.Fprintf(stderr, "Issued link %s for %q (%s)\n", link.UUID, link.HomeName, link.HomeID)
	fmt.Fprintln(stdout, token)
	return nil
}

func revoke(ctx context.Context, links linker, id string, stderr io.Writer) error {
	linkID, err := uuid.Parse(id)
	if err != nil {
		return fmt.Errorf("--id %q is not a link id: %w", id, err)
	}

	err = links.RevokeLink(ctx, linkID)
	if errors.Is(err, account.ErrLinkNotFound) {
		return fmt.Errorf("no live link %s", linkID)
	}
	if err != nil {
		return fmt.Errorf("revoke link: %w", err)
	}

	fmt.Fprintf(stderr, "Revoked link %s\n", linkID)
	return nil
}
