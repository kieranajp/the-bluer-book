package link

import (
	"bytes"
	"context"
	"strings"
	"testing"

	"github.com/google/uuid"

	"github.com/kieranajp/the-bluer-book/internal/domain/account"
)

type stubLinker struct {
	link      account.Link
	token     string
	issueErr  error
	revokeErr error

	issued  []uuid.UUID
	revoked []uuid.UUID
}

func (s *stubLinker) IssueLink(_ context.Context, homeID uuid.UUID) (account.Link, string, error) {
	s.issued = append(s.issued, homeID)
	return s.link, s.token, s.issueErr
}

func (s *stubLinker) RevokeLink(_ context.Context, linkID uuid.UUID) error {
	s.revoked = append(s.revoked, linkID)
	return s.revokeErr
}

func TestIssueWritesOnlyTheTokenToStdout(t *testing.T) {
	home := uuid.New()
	links := &stubLinker{
		link:  account.Link{UUID: uuid.New(), HomeID: home, HomeName: "Home A"},
		token: "the-token",
	}
	var stdout, stderr bytes.Buffer

	if err := issue(context.Background(), links, home.String(), &stdout, &stderr); err != nil {
		t.Fatalf("issue: %v", err)
	}
	if got := stdout.String(); got != "the-token\n" {
		t.Errorf("stdout is %q, want the token alone", got)
	}
	for _, want := range []string{links.link.UUID.String(), "Home A"} {
		if !strings.Contains(stderr.String(), want) {
			t.Errorf("stderr %q does not name %s", stderr.String(), want)
		}
	}
	if len(links.issued) != 1 || links.issued[0] != home {
		t.Errorf("issued for %v, want only %s", links.issued, home)
	}
}

func TestIssueRefusesAHomeThatIsNotAnID(t *testing.T) {
	links := &stubLinker{}
	var stdout, stderr bytes.Buffer

	if err := issue(context.Background(), links, "home-a", &stdout, &stderr); err == nil {
		t.Fatal("issue accepted a home that is not a uuid")
	}
	if len(links.issued) != 0 || stdout.Len() != 0 {
		t.Errorf("issued %v and wrote %q for a bad home id", links.issued, stdout.String())
	}
}

func TestIssueWritesNothingToStdoutOnFailure(t *testing.T) {
	links := &stubLinker{token: "never-issued", issueErr: account.ErrHomeNotFound}
	var stdout, stderr bytes.Buffer

	if err := issue(context.Background(), links, uuid.New().String(), &stdout, &stderr); err == nil {
		t.Fatal("issue reported success for a missing home")
	}
	if stdout.Len() != 0 {
		t.Errorf("stdout is %q, want nothing", stdout.String())
	}
}

func TestRevokeReportsAnUnknownLink(t *testing.T) {
	links := &stubLinker{revokeErr: account.ErrLinkNotFound}
	id := uuid.New()

	err := revoke(context.Background(), links, id.String(), &bytes.Buffer{})
	if err == nil || !strings.Contains(err.Error(), id.String()) {
		t.Errorf("got %v, want an error naming %s", err, id)
	}
	if len(links.revoked) != 1 || links.revoked[0] != id {
		t.Errorf("revoked %v, want %s", links.revoked, id)
	}
}
