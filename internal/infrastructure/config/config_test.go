package config

import (
	"net/url"
	"testing"
)

func TestDBDSNSurvivesAPasswordWithURLDelimiters(t *testing.T) {
	cfg := Config{DBUser: "bluer_book", DBPass: "p@ss/w:rd#1?", DBHost: "db", DBPort: "5432", DBName: "bluer_book"}

	u, err := url.Parse(cfg.DBDSN())
	if err != nil {
		t.Fatalf("DSN does not parse: %v", err)
	}
	if pass, _ := u.User.Password(); pass != cfg.DBPass || u.User.Username() != cfg.DBUser {
		t.Errorf("DSN carries %q/%q, want %q/%q", u.User.Username(), pass, cfg.DBUser, cfg.DBPass)
	}
	if u.Host != "db:5432" || u.Path != "/bluer_book" {
		t.Errorf("DSN points at %s%s, want db:5432/bluer_book", u.Host, u.Path)
	}
}
