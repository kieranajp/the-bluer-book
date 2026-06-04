# PLAN 002: Multitenancy for The Bluer Book

## Overview

Turn The Bluer Book from a single-tenant, single-user, unauthenticated app into a real multi-tenant product: households (homes) with multiple members and invites, per-tenant data isolation enforced both in application queries and by Postgres Row-Level Security, Google-only login via the existing Ory edge stack, self-service signup that auto-provisions a home, and the Google Play compliance gates (account deletion + GDPR export). Existing production data is preserved by backfilling it into a founder home.

This is the implementation of research `thoughts/shared/research/R1-2026-05-29-multitenancy-for-app-store.md`, whose decisions section settled all the product-level questions. This plan is the engineering follow-through, with the implementation-level decisions resolved (see "Resolved Decisions" below).

## Current State Analysis

Verified against the codebase at this branch (findings below carry file:line references):

- **No auth anywhere in Go.** `internal/infrastructure/auth/` does not exist. No middleware reads an `Authorization` header or any identity. The sole HTTP middleware chain is `metrics.HTTPMetrics(middleware.AccessLog(logger, mux))` (`internal/application/api/router.go:60`). The MCP server is served by bare `http.Serve(mcpListener, httpMCPServer)` with **no** middleware (`cmd/server/server.go:120-138`).
- **The only "identity" is `userID := "default_user"`** (`internal/application/chat/handler.go:118`), used purely as an ADK session key; it never reaches the service, repo, or DB.
- **`context.Context` is threaded end-to-end** (handler → service → repo → sqlc `*Context`) but nothing is read from it for identity. This is the injection seam.
- **No tenant column on any table.** Tenant-relevant tables (`migrations/00002_schema.sql` onward): `recipes`, `steps`, `recipe_ingredient`, `recipe_label`, `photos`, `meal_plan_recipes`. Global reference data: `ingredients` (`UNIQUE(name)`, `00002:4`), `units` (`UNIQUE(name)`, `00008:42`), `labels` (`UNIQUE(type,name)`, `00007:204`).
- **`meal_plan_recipes` is a single global plan**, PK `(recipe_id)` (`00004:4-8`).
- **Every sqlc query filters by `archived_at IS NULL` and id/name/label predicates only — never by an owner.** The upsert-by-name flow in the repo is a `GetXByName` → `CreateX`-on-`ErrNoRows` pattern (`internal/infrastructure/storage/repository/recipes.go:138-232`), with `ON CONFLICT` on the global uniques as a secondary guard.
- **`database/sql` with `lib/pq`, one process-wide pool** (`cmd/server/server.go:95-108`, `db.New(sqlDB)`). The generated `db.DBTX` interface is satisfied by both `*sql.DB` and `*sql.Tx` (`internal/infrastructure/storage/db/db.go:12-31`). Transactions are ad-hoc, only inside `SaveRecipe`/`UpdateRecipe` (`r.sqlDB.BeginTx(ctx, nil)` + `db.New(tx)`). No connection-scoped or per-request session hook exists. DSN is `sslmode=disable`, single role (`internal/infrastructure/config/config.go:43-48`).
- **Migrations: goose v3**, embedded (`migrations/embed.go`), naming `NNNNN_name.sql`, current head `00008`. Run via `./bluer-book migrate` (`cmd/migrate/migrate.go`).
- **Edge auth (homelab Traefik + Ory).** `charts/bluer-book/templates/ingressroute.yaml`: `/mcp` → no middleware; `/api` → `jwt-auth` (Oathkeeper forward-auth, forwards `X-User` + `Authorization`); everything else → `ory-auth` (forwards `X-User` only). On success Oathkeeper sets **`X-User`** = token subject (client id for `client_credentials`, identity id for Kratos sessions) per `.claude/skills/oauth-api-auth.md`.
- **No DCR, no authorization-code/PKCE today.** The skill confirms clients are statically provisioned in homelab Terraform; the only grant configured is `client_credentials`. Kratos has no Google IdP wired for app users yet (the app has no login).
- **Flutter authenticates as the *app*, not a user.** `client_credentials` flow with a committed secret (`app/lib/infrastructure/network/auth_interceptor.dart`, `app/lib/infrastructure/config/oauth_config.dart`, `app/env/release.env`). `main.dart:27` boots straight into `AppShell` — no login gate. Riverpod + Dio; API base under `/api`.
- **Deployment is single-everything.** App `replicaCount: 1`; Postgres `17.5-alpine` StatefulSet, 1 replica, 1Gi `local-path` PVC; secrets from 1Password (`vaults/Homelab/items/bluer-book-secrets`). `tag-recipes` runs as a deploy-time initContainer over all recipes (`charts/bluer-book/templates/app-deployment.yaml:44-57`).
- **There is a Sept-2025 prod dump** in the working tree (`dump-postgres-202509131613.sql`) — existing data to preserve.

## Desired End State

A user opening the Flutter app is taken to a Google login (Kratos), lands in their own household's book, can invite others, and sees only their home's recipes/meal-plan/ingredients. Every API and chat-driven DB access is scoped to the caller's home by application-level `WHERE` **and** by Postgres RLS as a backstop — a missing `WHERE` physically cannot cross tenants because the app connects as a non-owner role under `FORCE ROW LEVEL SECURITY`. New accounts auto-provision a home on first login. Users can delete their account+data (in-app and via a public web URL) and export their data as JSON. Existing production data lives intact in a founder home owned by Kieran's Google identity.

### Verification of end state
- A request bearing home A's identity that asks for a recipe UUID owned by home B returns 404, not the recipe (app-level), and even a deliberately un-scoped query run on the app role returns zero rows (RLS).
- A fresh Google login with a never-seen identity results in a new `homes` row, a `home_members` row (owner role), and an empty book — no manual provisioning.
- `DELETE /api/account` (and the public web URL) removes the identity and, where the user is the sole owner, purges the home's recipes, tenant ingredients, photos, meal plan, members, and invitations.
- All existing recipes appear under the founder home and nowhere else.

### Key Discoveries
- Identity seam is `r.Context()`, already plumbed through every layer (`router.go` → service → `recipes.go` → sqlc).
- RLS-vs-pool problem: `database/sql` hands each query an arbitrary pooled connection, so a session-level `SET app.home_id` would leak across requests. The repo only opens a tx for two operations today (`recipes.go:52-56, 472`).
- The generated `db.DBTX` abstraction (`db/db.go:12-31`) already lets a `*Queries` run on either a pool or a tx — the lever for a per-request home tx.
- The global uniques the upsert flow depends on: `ingredients.name`, `units.name`, `labels(type,name)`. Only `ingredients` moves to per-tenant; `units`/`labels` stay global.
- `X-User` (not `X-User-Id`) is the subject header; `/api` already forwards it, `/mcp` is unauthenticated by design.

## What We're NOT Doing

Explicitly out of scope for this plan (deferred to follow-ups, per decisions on 2026-05-29/30):

- **Object storage for photos.** Photos stay the client-provided-URL model, just home-scoped. No S3/GCS/R2, upload endpoints, signed URLs, or moderation.
- **LLM per-tenant quotas / abuse controls / usage metering.** One shared Gemini key remains. (The `tag-recipes` batch is *removed* — see below — so there's no remaining global LLM batch.)
- **HA / production infra.** Stays single-replica app + single 1Gi `local-path` Postgres. No managed/HA Postgres, backups/PITR, TLS-to-DB, or horizontal scaling. Chat sessions stay in-memory and single-replica.
- **External Claude.ai remote-MCP "Connect" flow.** No Hydra Dynamic Client Registration, no authorization-code on `/mcp`. `/mcp` internal scoping (for the in-process chat handler) IS done; external per-tenant Claude connections are a documented follow-up.
- **`tag-recipes`.** Being **removed** (it has done its one-off legacy cleanup). Not re-tooled per-tenant here.
- **Billing / IAP / entitlements.** Free at launch.
- **Transactional email** (deletion confirmations, export pings). Additive later; not on the critical path with Google-only login (no password reset/verification needed).

## Implementation Approach

Foundation-first and tenant-real from migration #1 — no hardcoded-constant interim. Schema and isolation land before the product surfaces (provisioning, invites, Flutter login) are built on top, so there's no rework. The hard backstop (RLS + non-owner role) goes in with the schema so that every subsequent phase is developed against a database that actively refuses cross-tenant access.

**Out-of-repo dependency.** Two in-scope items — the `X-User`-based middleware (Phase 2) and Flutter Google login (Phase 5) — depend on homelab Ory/Terraform configuration that does not exist yet (Kratos Google IdP, a public authorization-code+PKCE client, an Oathkeeper rule resolving `X-User` to the Kratos identity on `/api` and a new `/auth` path). That work lives in a different repository and is captured as Phase 0; this plan's Go/Flutter code is written to consume it but does not build it. Phase 0 must complete before Phases 2 and 5 can be verified end-to-end, but Phases 1, 3, 4 and most of 2's code can proceed in parallel with it.

---

## Phase 0: Ory homelab prerequisite (out-of-repo, dependency only)

### Overview
Configure the homelab Ory stack so the app can consume real per-user identity. **No files in this repo change in this phase** — it is documented here as a gating dependency and tracked separately in the homelab Terraform repo.

### Changes Required (in the homelab Terraform repo, not here):
- **Kratos**: enable the Google OIDC provider for app-user self-service login; no passwords (Google-only).
- **Hydra**: register a public client for the Flutter app supporting `authorization_code` + PKCE (no secret), with redirect URIs for the app's custom scheme/deep link. Keep the existing `client_credentials` client until Flutter migrates, then retire it.
- **Oathkeeper**: an access rule so a Kratos session (and the Flutter PKCE access token) resolves to the Kratos **identity id** in the `X-User` header on `/api/*` and a new `/auth/*` path used for the session/userinfo bootstrap. Keep `jwt-auth` forwarding `X-User` + `Authorization`.
- **GCP**: publish the OAuth consent screen for `email`/`profile` scopes (light branding review).

### Success Criteria:

#### Automated Verification:
- [ ] `curl -H "Authorization: Bearer <kratos-session-or-pkce-token>" https://recipes.kieranajp.uk/api/health` reaches the backend with an `X-User` header set to the Kratos identity id (verify by temporarily echoing the header).

#### Manual Verification:
- [ ] A Google login through Kratos issues a session whose identity id is stable across logins for the same Google account.
- [ ] The Flutter PKCE client can complete an authorization-code exchange against Hydra in a manual browser flow.

---

## Phase 1: Schema — identity tables, tenant columns, backfill, RLS

### Overview
Two migrations: `00009` creates the identity/tenancy tables; `00010` adds `home_id` to every tenant table, re-keys `ingredients` to per-tenant, backfills all existing data into a founder home, then enables RLS with `FORCE` and creates the non-owner application role. After this phase the database is structurally multi-tenant and actively isolating, even though no Go code reads identity yet (the founder home is the only tenant, so nothing breaks).

### Changes Required:

#### 1. Identity & tenancy tables
**File**: `migrations/00009_identity.sql` (new, goose-annotated)
**Changes**: Create the identity model.

```sql
-- +goose Up
CREATE TABLE users (
    uuid          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    subject       TEXT NOT NULL UNIQUE,         -- Kratos identity id (the X-User value)
    email         TEXT,
    display_name  TEXT,
    created_at    TIMESTAMP NOT NULL DEFAULT now(),
    updated_at    TIMESTAMP NOT NULL DEFAULT now()
);

CREATE TABLE homes (
    uuid        UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name        TEXT NOT NULL,
    created_at  TIMESTAMP NOT NULL DEFAULT now(),
    updated_at  TIMESTAMP NOT NULL DEFAULT now()
);

CREATE TYPE home_role AS ENUM ('owner', 'member');

CREATE TABLE home_members (
    home_id  UUID NOT NULL REFERENCES homes(uuid) ON DELETE CASCADE,
    user_id       UUID NOT NULL REFERENCES users(uuid) ON DELETE CASCADE,
    role          home_role NOT NULL DEFAULT 'member',
    created_at    TIMESTAMP NOT NULL DEFAULT now(),
    PRIMARY KEY (home_id, user_id)
);
CREATE INDEX idx_home_members_user ON home_members(user_id);

CREATE TABLE invitations (
    uuid          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    home_id  UUID NOT NULL REFERENCES homes(uuid) ON DELETE CASCADE,
    email         TEXT NOT NULL,
    token         TEXT NOT NULL UNIQUE,
    role          home_role NOT NULL DEFAULT 'member',
    invited_by    UUID REFERENCES users(uuid) ON DELETE SET NULL,
    accepted_at   TIMESTAMP NULL,
    expires_at    TIMESTAMP NOT NULL,
    created_at    TIMESTAMP NOT NULL DEFAULT now()
);
CREATE INDEX idx_invitations_home ON invitations(home_id);

-- +goose Down
DROP TABLE invitations;
DROP TABLE home_members;
DROP TYPE home_role;
DROP TABLE homes;
DROP TABLE users;
```

#### 2. Tenant columns, ingredient re-key, backfill, RLS
**File**: `migrations/00010_tenancy.sql` (new, goose-annotated)
**Changes**: Denormalise `home_id` onto every tenant table (chosen so RLS policies are trivial per-table predicates rather than parent-joins), move `ingredients` to per-tenant uniqueness, backfill the founder home, then enable and force RLS.

```sql
-- +goose Up
-- 1. Founder home + user (backfill target). Subject is set to a placeholder
--    and reconciled to Kieran's real Kratos identity id on first login (Phase 3
--    links an existing-by-email/known-subject user to this home).
INSERT INTO homes (uuid, name) VALUES ('00000000-0000-0000-0000-000000000001', 'Founder');
-- (founder user + membership are created in Phase 3 provisioning when Kieran first
--  logs in; the home exists now so data can be stamped.)

-- 2. Add nullable home_id to every tenant table, backfill to founder, then NOT NULL.
ALTER TABLE recipes            ADD COLUMN home_id UUID REFERENCES homes(uuid) ON DELETE CASCADE;
ALTER TABLE steps              ADD COLUMN home_id UUID REFERENCES homes(uuid) ON DELETE CASCADE;
ALTER TABLE recipe_ingredient  ADD COLUMN home_id UUID REFERENCES homes(uuid) ON DELETE CASCADE;
ALTER TABLE recipe_label       ADD COLUMN home_id UUID REFERENCES homes(uuid) ON DELETE CASCADE;
ALTER TABLE photos             ADD COLUMN home_id UUID REFERENCES homes(uuid) ON DELETE CASCADE;
ALTER TABLE meal_plan_recipes  ADD COLUMN home_id UUID REFERENCES homes(uuid) ON DELETE CASCADE;
ALTER TABLE ingredients        ADD COLUMN home_id UUID REFERENCES homes(uuid) ON DELETE CASCADE;

UPDATE recipes            SET home_id = '00000000-0000-0000-0000-000000000001';
UPDATE steps              SET home_id = '00000000-0000-0000-0000-000000000001';
UPDATE recipe_ingredient  SET home_id = '00000000-0000-0000-0000-000000000001';
UPDATE recipe_label       SET home_id = '00000000-0000-0000-0000-000000000001';
UPDATE photos             SET home_id = '00000000-0000-0000-0000-000000000001';
UPDATE meal_plan_recipes  SET home_id = '00000000-0000-0000-0000-000000000001';
UPDATE ingredients        SET home_id = '00000000-0000-0000-0000-000000000001';

ALTER TABLE recipes            ALTER COLUMN home_id SET NOT NULL;
ALTER TABLE steps              ALTER COLUMN home_id SET NOT NULL;
ALTER TABLE recipe_ingredient  ALTER COLUMN home_id SET NOT NULL;
ALTER TABLE recipe_label       ALTER COLUMN home_id SET NOT NULL;
ALTER TABLE photos             ALTER COLUMN home_id SET NOT NULL;
ALTER TABLE meal_plan_recipes  ALTER COLUMN home_id SET NOT NULL;
ALTER TABLE ingredients        ALTER COLUMN home_id SET NOT NULL;

-- 3. Re-key ingredients per-tenant (was global UNIQUE(name)).
ALTER TABLE ingredients DROP CONSTRAINT ingredients_name_key;     -- the 00002 UNIQUE(name)
ALTER TABLE ingredients ADD CONSTRAINT ingredients_home_name_unique UNIQUE (home_id, name);

-- 4. Re-key the meal plan per-tenant (was PK(recipe_id) — already 1 row/recipe,
--    recipe_id stays globally unique so PK is unchanged, but add the scope index).
CREATE INDEX idx_meal_plan_home ON meal_plan_recipes(home_id, added_at DESC);

-- 5. Composite indexes for the scoped read paths.
CREATE INDEX idx_recipes_home_active ON recipes(home_id, created_at DESC) WHERE archived_at IS NULL;
CREATE INDEX idx_recipes_home_archived ON recipes(home_id, archived_at DESC) WHERE archived_at IS NOT NULL;

-- 6. Enable + FORCE RLS on every tenant table, policy keyed on a per-request GUC.
--    (units and labels are intentionally NOT touched — global reference data.)
DO $$
DECLARE t TEXT;
BEGIN
  FOREACH t IN ARRAY ARRAY['recipes','steps','recipe_ingredient','recipe_label','photos','meal_plan_recipes','ingredients']
  LOOP
    EXECUTE format('ALTER TABLE %I ENABLE ROW LEVEL SECURITY;', t);
    EXECUTE format('ALTER TABLE %I FORCE ROW LEVEL SECURITY;', t);
    EXECUTE format($f$
      CREATE POLICY home_isolation ON %I
        USING (home_id = current_setting('app.home_id', true)::uuid)
        WITH CHECK (home_id = current_setting('app.home_id', true)::uuid);
    $f$, t);
  END LOOP;
END $$;

-- 7. Non-owner application role, subject to RLS (the migration/owner role is not).
--    Password is injected by the deploy from 1Password; created here idempotently.
DO $$
BEGIN
  IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'bluer_book_app') THEN
    CREATE ROLE bluer_book_app LOGIN;
  END IF;
END $$;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO bluer_book_app;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO bluer_book_app;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO bluer_book_app;
-- bluer_book_app is NOT the table owner and has no BYPASSRLS, so FORCE RLS applies to it.

-- +goose Down
-- (reverse: drop policies, disable RLS, drop role grants, drop columns, restore UNIQUE(name))
```

**Notes:**
- `current_setting('app.home_id', true)` with the `true` (missing_ok) flag returns NULL when unset, so the policy denies all rows rather than erroring — a connection that forgot to set the GUC sees nothing. This is the desired fail-closed behaviour.
- `units` and `labels` keep their global uniques and get **no** RLS (shared reference data, readable by all tenants). They are owned by the migration role; `bluer_book_app` gets SELECT/INSERT/UPDATE on them but no RLS gate.
- The founder *user* + membership are deliberately created in Phase 3 (provisioning logic), keyed off Kieran's real Kratos subject on first login. The home row exists now purely as the backfill target.

#### 3. sqlc regeneration
**File**: `internal/infrastructure/storage/db/*` (regenerated)
**Changes**: After updating `queries/*.sql` (Phase 2), run `sqlc generate`. Models gain `HomeID uuid.UUID`.

### Success Criteria:

#### Automated Verification:
- [x] Migrations apply cleanly from the prod dump: restore `dump-postgres-202509131613.sql`, then `./bluer-book migrate` → exit 0.
- [x] Backfill is complete: `SELECT count(*) FROM recipes WHERE home_id IS NULL` returns 0 (and same for every tenant table).
- [x] RLS denies by default: connecting as `bluer_book_app` without setting the GUC, `SELECT count(*) FROM recipes` returns 0.
- [x] RLS scopes correctly: `SET app.home_id = '00000000-0000-0000-0000-000000000001'; SELECT count(*) FROM recipes` returns the full preserved count.
- [x] `go build ./...` succeeds after sqlc regen.

#### Manual Verification:
- [x] The founder home contains exactly the pre-migration recipe set (160 recipes, 716 ingredients backfilled into founder home).
- [x] `units` and `labels` are unchanged and have no RLS (`SELECT relrowsecurity FROM pg_class WHERE relname IN ('units','labels')` → false).

---

## Phase 2: Go isolation core — identity middleware, home tx, RLS wiring

### Overview
Make the backend read identity from `X-User`, resolve it to a home, put both in `r.Context()`, and run *every* DB operation inside a per-request transaction that first issues `SET LOCAL app.home_id = $1`. Switch the app's DB connection to the non-owner `bluer_book_app` role so RLS actually applies. Service and repository method signatures are unchanged — home travels via context.

### Changes Required:

#### 1. Identity middleware
**File**: `internal/infrastructure/auth/middleware.go` (new)
**Changes**: Read `X-User`, look up the user (provisioning is Phase 3; here it errors 401 if unknown), resolve the active home, stash `UserID` + `HomeID` in context.

```go
type ctxKey int
const (
    userIDKey ctxKey = iota
    homeIDKey
)

func Middleware(users UserResolver, log logger.Logger) func(http.Handler) http.Handler {
    return func(next http.Handler) http.Handler {
        return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
            subject := r.Header.Get("X-User")
            if subject == "" { http.Error(w, "unauthenticated", http.StatusUnauthorized); return }
            u, ws, err := users.Resolve(r.Context(), subject) // Phase 3 makes this provision-on-miss
            if err != nil { http.Error(w, "unauthenticated", http.StatusUnauthorized); return }
            ctx := context.WithValue(r.Context(), userIDKey, u.UUID)
            ctx = context.WithValue(ctx, homeIDKey, ws.UUID)
            next.ServeHTTP(w, r.WithContext(ctx))
        })
    }
}

func HomeID(ctx context.Context) (uuid.UUID, bool) { id, ok := ctx.Value(homeIDKey).(uuid.UUID); return id, ok }
func UserID(ctx context.Context) (uuid.UUID, bool)      { id, ok := ctx.Value(userIDKey).(uuid.UUID); return id, ok }
```

**File**: `internal/application/api/router.go`
**Changes**: Insert the auth middleware into the chain ahead of the handlers. The middleware applies to `/api/*` (which the edge already guards). Keep `/health` and `/metrics` unauthenticated.

```go
// was: return metrics.HTTPMetrics(middleware.AccessLog(logger, mux))
return metrics.HTTPMetrics(middleware.AccessLog(logger, auth.Middleware(userResolver, logger)(mux)))
// with /health and /metrics short-circuited before auth (separate mux or path check).
```

#### 2. Per-request home transaction + RLS GUC
**File**: `internal/infrastructure/storage/repository/home_tx.go` (new)
**Changes**: A helper that opens a tx, sets the GUC with `SET LOCAL`, runs the callback with a tx-bound `*db.Queries`, and commits. All repo methods route through it. `SET LOCAL` is scoped to the transaction, so pooled-connection reuse cannot leak the value.

```go
func (r *recipeRepository) inHomeTx(ctx context.Context, fn func(q *db.Queries) error) error {
    wsID, ok := auth.HomeID(ctx)
    if !ok { return ErrNoHome }
    tx, err := r.sqlDB.BeginTx(ctx, nil)
    if err != nil { return err }
    defer tx.Rollback() //nolint (no-op after commit)
    // set_config(..., true) = local to this tx; parameterised, no string interpolation.
    if _, err := tx.ExecContext(ctx, "SELECT set_config('app.home_id', $1, true)", wsID.String()); err != nil {
        return err
    }
    if err := fn(db.New(tx)); err != nil { return err }
    return tx.Commit()
}
```

**Changes (cont.)**: Refactor `recipes.go` so `SaveRecipe`, `UpdateRecipe` (already tx-based — fold the GUC in), and *all* the currently-pool-based methods (`GetRecipeByID`, `ListRecipes`, `ArchiveRecipe`, `RestoreRecipe`, `ListArchivedRecipes`, `AddToMealPlan`, `RemoveFromMealPlan`, `ListMealPlanRecipes`, `ListLabels`, `ListUnits`, `ListIngredients`) run inside `inHomeTx`. Reads-only ops can still use a tx (cheap; guarantees the GUC). `ListLabels`/`ListUnits` touch global tables — they still run in the tx but the GUC is harmless there.

#### 3. Home-scope the queries
**File**: `internal/infrastructure/storage/queries/{recipes,meal_plan,label_filtering}.sql`
**Changes**: Add `home_id = sqlc.arg('home_id')` (or `$n`) to the WHERE/INSERT of every tenant query, and set `home_id` on every INSERT. The ingredient upsert moves its `GetIngredientByName`/`CreateIngredient`/`ON CONFLICT` to `(home_id, name)`. `units`/`labels` upserts stay global. This is belt-and-braces alongside RLS — RLS is the backstop, the explicit predicate is the contract and keeps query plans using the new composite indexes. Regenerate with `sqlc generate`.

The repo passes `wsID` into each query call; since it's also in the GUC, RLS and the predicate agree.

#### 4. Non-owner DB role + config
**File**: `internal/infrastructure/config/config.go`, `cmd/server/server.go`, chart secret
**Changes**: The server connects as `bluer_book_app` (new credentials in the 1Password item), while `migrate` continues to connect as the owner role. Add `DB_USER`/`DB_PASS` distinction is already there — point the *server* DSN at the app role and the *migrate* command at the owner role. Keep `sslmode=disable` (TLS-to-DB deferred).

### Success Criteria:

#### Automated Verification:
- [x] `go build ./...` and `go test ./...` pass.
- [x] `sqlc generate` produces no diff after commit (CI's `sqlc generate` step stays green).
- [x] New isolation test: a repo-level test that sets home A in context, creates a recipe, then sets home B and confirms `GetRecipeByID`/`ListRecipes` cannot see it — passing via the explicit predicate (when run as the owner role) *and* via RLS (when run as `bluer_book_app`).
- [x] A request with no `X-User` header to `/api/recipes` returns 401 (covered by `TestMiddleware_RejectsMissingSubject`).

#### Manual Verification (needs Phase 0):
- [ ] Through the real edge, a request as identity A sees only A's recipes.
- [ ] Forcing a query without the GUC (e.g. a deliberately broken build) returns zero rows rather than cross-tenant data — confirms RLS is the live backstop, not just the predicate.

---

## Phase 3: Tenant model, provisioning, invites

### Overview
Build the users/homes/members domain and service, make the middleware's `Resolve` provision-on-first-login (auto-create home + owner membership, and link Kieran's first login to the founder home), and add invite + membership + home-switch endpoints.

### Changes Required:

#### 1. Domain + repository for identity
**File**: `internal/domain/account/` (new package: `User`, `Home`, `Member`, `Invitation`, roles), `internal/infrastructure/storage/repository/accounts.go` (new), `internal/infrastructure/storage/queries/accounts.sql` (new)
**Changes**: CRUD for users/homes/members/invitations. These tables are **not** under RLS (they're the resolution layer that runs before a home is known), so this repo uses the pool directly, not `inHomeTx`. Membership lookups scope by `user_id`.

#### 2. Provision-on-login
**File**: `internal/infrastructure/auth/resolver.go` (new) — implements `UserResolver.Resolve`
**Changes**:
- Look up user by `subject` (= `X-User`).
- If absent: create the user; if the email/subject matches Kieran's founder identity (configurable via env `FOUNDER_SUBJECT` or matched on first run), attach as owner of the founder home; otherwise create a fresh home named e.g. "{display_name}'s Book" and an owner membership.
- Resolve the active home: the user's default/most-recent membership, or a home passed via a header/path for switching (see endpoint below).

#### 3. Endpoints
**File**: `internal/application/api/account_handler.go` (new) + routes in `router.go`
**Changes**:
- `GET /api/me` — current user + homes + active home.
- `POST /api/homes/{id}/invitations` (owner only) — create invite (token, email, role, expiry).
- `POST /api/invitations/{token}/accept` — join home (adds membership).
- `GET /api/homes/{id}/members`, `DELETE .../members/{userID}` (owner only).
- Home switching: `X-Home` request header (validated against membership) overrides the default in `Resolve`; `/api/me` lists the options.

### Success Criteria:

#### Automated Verification:
- [x] `go test ./...` incl. new account service tests (provision-on-miss creates home+owner membership; second login for same subject reuses it; invite accept adds membership).
- [x] `go build ./...` passes.

#### Manual Verification (needs Phase 0):
- [ ] First Google login as Kieran lands in the founder home with all existing recipes.
- [ ] First Google login as a new account lands in a fresh empty home.
- [ ] Inviting a second Google account and accepting gives that account access to the same home; non-owners cannot invite.

---

## Phase 4: MCP internal home scoping

### Overview
The chat handler is an in-process MCP *client* over `http://localhost:8082/mcp`; the MCP server tools currently run anonymously. Propagate the authenticated home from the `/api/chat` request through the MCP transport into the MCP server's tool context, so chat-driven recipe operations are home-scoped exactly like the REST path. `/mcp` remains edge-unauthenticated (it's localhost-only in practice and not exposed for external Connect in this plan), but it gains an internal trust header.

### Changes Required:

#### 1. Propagate home on the MCP client call
**File**: `internal/application/chat/handler.go`
**Changes**: Replace the hardcoded `userID := "default_user"` with the real user id from `auth.UserID(r.Context())` (used as the ADK session key, so sessions are per-user). Set an internal header (e.g. `X-Home`) carrying `auth.HomeID(ctx)` on the MCP client transport. The transport is currently built once in `NewHandler` (`handler.go:58-69`); change it to inject the per-request home — either build the toolset per request, or use a transport whose `HTTPClient`/header hook reads a request-scoped value.

#### 2. Read the header on the MCP server
**File**: `cmd/server/server.go` (MCP listener) + `internal/application/mcp/` tool context
**Changes**: Wrap `http.Serve(mcpListener, httpMCPServer)` (`server.go:120-138`) with a small middleware that reads `X-Home` and injects it into the context the mark3labs server passes to tools, so each tool's `ctx` carries the home and the repo's `inHomeTx` finds it. Because `/mcp` has no edge auth, the header is only trusted from localhost; bind the MCP listener to `127.0.0.1` (it's currently all-interfaces `:8082`) to enforce that, and document the external-Connect follow-up.

### Success Criteria:

#### Automated Verification:
- [x] `go test ./...` passes incl. MCP-bridge tests asserting the X-Home header is set from chat ctx on outgoing client requests and read back into ctx on the server side (`auth.HomeHeaderRoundTripper`, `auth.InjectHomeFromHeader`).
- [x] `go build ./...` passes.

#### Manual Verification:
- [ ] Chatting "add X to my meal plan" as home A affects only A's meal plan.
- [ ] The MCP listener is not reachable cross-tenant: a call without `X-Home` (or from another home) cannot read A's recipes.

---

## Phase 5: Flutter — Google login, drop client_credentials

### Overview
Replace the app-as-client `client_credentials` flow with per-user Google login via authorization-code + PKCE against Hydra/Kratos (Phase 0), add a login gate before `AppShell`, store/refresh tokens securely, remove the committed secret, and add home + invite UI. Depends on Phase 0.

### Changes Required:

#### 1. PKCE auth + login gate
**File**: `app/lib/infrastructure/network/auth_interceptor.dart`, new `app/lib/infrastructure/auth/` (PKCE flow), `app/lib/main.dart`, `app/lib/application/screens/`
**Changes**:
- Add `flutter_appauth` (or `oauth2` + `flutter_web_auth_2`) for authorization-code + PKCE against Hydra; redirect via a registered custom scheme/deep link.
- Store tokens in `flutter_secure_storage`; refresh on expiry; attach `Authorization: Bearer` in the interceptor as now, but with the user token, not a client-credentials token.
- Gate: `main.dart:27` no longer goes straight to `AppShell`; an auth wrapper shows a login screen when there's no valid session, `AppShell` otherwise.
- Remove `OAuthConfig.clientSecret` and delete the secret from `app/env/release.env`; the public PKCE client has no secret. Update `release.yml` to stop injecting `OAUTH_CLIENT_SECRET`.

#### 2. Home + invite UI
**File**: `app/lib/application/screens/settings/` (+ providers)
**Changes**: Settings tab gains: current home, switch home (calls `/api/me`, sets `X-Home`), members list, invite-by-email, accept-invite (deep link), and **account deletion** entry point (Phase 6).

### Success Criteria:

#### Automated Verification:
- [ ] `flutter analyze` and `flutter test` pass (CI `flutter` job).
- [ ] No secret remains: `grep -r OAUTH_CLIENT_SECRET app/` returns nothing in source/env, and `release.yml` no longer references it.

#### Manual Verification (needs Phase 0):
- [ ] Cold start shows Google login; after login the app lands in the user's home.
- [ ] Token refresh works across an expiry; 401 triggers re-auth, not a crash.
- [ ] Switching home changes the visible recipes; inviting + accepting works end-to-end on a device.

---

## Phase 6: Google Play compliance — account deletion + GDPR export

### Overview
Add the mandatory account+data deletion (in-app **and** a public web URL) with a real tenant-purge, plus a GDPR JSON export. This is the in-scope compliance subset; data-safety form and privacy policy are content/console tasks tracked outside code.

### Changes Required:

#### 1. Deletion
**File**: `internal/application/api/account_handler.go`, `internal/domain/account/service.go`, new public web route
**Changes**:
- `DELETE /api/account` — authenticated. Removes the user's membership; if the user is the sole owner of a home, purge it: recipes, steps, recipe_ingredient, recipe_label, photos, meal_plan_recipes, tenant `ingredients`, invitations, members, then the home; finally delete the user. ON DELETE CASCADE from `homes`/`users` does most of the heavy lifting (every tenant table FKs `homes(uuid) ON DELETE CASCADE`), so the purge is largely `DELETE FROM homes WHERE uuid = $1` + `DELETE FROM users WHERE uuid = $1`, run as the owner role (outside RLS) in one tx. Also trigger Kratos identity deletion via its admin API.
- **Public web deletion URL**: a minimal server-rendered page/route (e.g. `GET/POST /account/delete` on the app, served on the non-`/api` path, behind `ory-auth` Google login) so a user without the app can delete — satisfies Play's "publicly reachable URL" requirement.

#### 2. Export
**File**: same handler/service
**Changes**: `GET /api/account/export` — returns the home's data (recipes with steps/ingredients/labels/photos, meal plan, tenant ingredients) as a JSON document for the active home. Owner-only for shared homes.

### Success Criteria:

#### Automated Verification:
- [x] `go test ./...` incl. a deletion test: create home + recipes + ingredients + members, sole-owner DeleteAccount purges all tenant rows; `TestPurgeHome_CascadesAcrossEveryTenantTable` exercises every tenant table and asserts zero post-purge.
- [x] Export test: covered by `TestExportData_*` (member-in-solo-home returns the data, non-owner in shared home gets ErrForbidden, owner in shared home succeeds, non-member refused).
- [x] `go build ./...` passes.

#### Manual Verification:
- [ ] In-app delete removes the account and signs the user out; re-login creates a fresh home (no resurrected data).
- [ ] The public web delete URL works from a browser with Google login and triggers the same purge.
- [ ] Export download opens as valid JSON with the expected recipes.

---

## Deployment changes (folded across phases)

**File**: `charts/bluer-book/templates/app-deployment.yaml`, `values.yaml`, 1Password item
- **Remove the `tag-recipes` initContainer** (`app-deployment.yaml:44-57`) — its one-off legacy cleanup is done. Also remove `cmd/tag/` and its references; drop the `gemini.model` plumbing that only fed it if unused elsewhere (chat still uses `GEMINI_MODEL`, so keep that).
- Keep the `migrate` initContainer; it runs as the **owner** DB role.
- Add the `bluer_book_app` role credentials to the 1Password item (`vaults/Homelab/items/bluer-book-secrets`); the app `Deployment` env uses the app role, `migrate` uses the owner role.
- App stays 1 replica; Postgres stays 1Gi `local-path` (HA deferred).

## Testing Strategy

### Unit Tests
- Account service: provision-on-miss, founder linkage, invite accept, role checks, sole-owner deletion purge.
- Auth middleware: 401 on missing `X-User`; context carries resolved user/home.
- `inHomeTx`: GUC is set, errors propagate as rollback, no home in ctx → `ErrNoHome`.

### Integration Tests (against a real Postgres — testcontainers or the homelab DB)
- **RLS isolation**: two homes, confirm reads/writes cannot cross, both with the predicate on and (deliberately) off to prove RLS is the backstop.
- **Backfill**: restore the prod dump, migrate, assert founder home owns everything.
- **Deletion cascade**: full purge leaves no orphans.

### Manual Testing Steps
1. Restore prod dump locally, run migrations, verify founder home.
2. (Post Phase 0) Google-login as Kieran → founder data; as a new account → empty home.
3. Invite + accept across two Google accounts; switch homes in the app.
4. Chat "add to meal plan" scoped correctly.
5. Delete account in-app and via web URL; export JSON.

## Performance Considerations
- Per-request transaction for every operation (incl. reads) adds a `BEGIN`/`set_config`/`COMMIT` round-trip. On a single small instance this is negligible; revisit if read latency matters (a read-only connection pre-set per pooled conn is a future optimisation, but the pool-leak risk makes the per-request tx the safe default now).
- New composite indexes `(home_id, …)` keep the scoped list/search paths index-backed.
- The `buildRecipeFromRows` N+1 (`recipes.go:370-463`) is pre-existing and unchanged; each sub-query now runs in the same tx so still one connection.

## Migration Notes
- `00009`/`00010` are forward migrations with Down sections; the backfill assumes a single existing tenant (true today). Run against a **copy** of prod first (the dump is in-tree).
- The non-owner role and RLS `FORCE` mean the app **cannot** function until Phase 2 wires the GUC — sequence Phase 1 and Phase 2 together in the same deploy, or the app (on the app role) sees zero rows. Until Phase 2 ships, the server keeps connecting as the owner role.
- Founder *user* row is created lazily on Kieran's first real login (Phase 3), linked to the pre-created founder home via `FOUNDER_SUBJECT`.

## References
- Research: `thoughts/shared/research/R1-2026-05-29-multitenancy-for-app-store.md` (decisions section, 2026-05-29/30)
- Auth pattern: `.claude/skills/oauth-api-auth.md` (X-User header, Oathkeeper, no-DCR reality)
- Prior plan: `thoughts/shared/plans/P001-2026-03-14-chat-and-bottom-nav.md`
- Key code: `internal/application/api/router.go:60`, `cmd/server/server.go:95-138`, `internal/application/chat/handler.go:118`, `internal/infrastructure/storage/repository/recipes.go:43-261`, `internal/infrastructure/storage/db/db.go:12-31`, `migrations/00002_schema.sql`, `charts/bluer-book/templates/{ingressroute,app-deployment}.yaml`, `app/lib/infrastructure/network/auth_interceptor.dart`, `app/lib/main.dart`
