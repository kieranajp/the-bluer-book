package account

import "context"

// NoopIdentityDeleter satisfies IdentityDeleter without contacting any
// IdP. It's the default wired in dev / pre-Phase-0 — local account
// deletion still scrubs the database; the upstream Kratos identity
// stays until Phase 0's admin URL is configured and a real deleter is
// wired in its place.
type NoopIdentityDeleter struct{}

func (NoopIdentityDeleter) Delete(_ context.Context, _ string) error { return nil }
