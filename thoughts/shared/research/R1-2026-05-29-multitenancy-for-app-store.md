---
date: 2026-05-29T22:35:56+0000
researcher: Kieran Patel
git_commit: cf11d5d978a68e97e6c883c24a0be439aea1f655
branch: fix/gemini-key-1password-config
repository: the-bluer-book
topic: "What's needed to make The Bluer Book multitenant for the app store"
tags: [research, codebase, multitenancy, auth, data-model, deployment, app-store]
last_updated: 2026-05-29
---

# Research: Multitenancy for the App Store

**Date**: 2026-05-29T22:35:56+0000
**Researcher**: Kieran Patel
**Git Commit**: cf11d5d978a68e97e6c883c24a0be439aea1f655
**Branch**: fix/gemini-key-1password-config
**Repository**: the-bluer-book

## Research Question
"I want to make this multitenant so I can add it to the app store. Analyse what's needed."

## Summary

The Bluer Book is, today, a **fully single-tenant, single-user, unauthenticated** application. There is no `users` table, no `tenant_id`/`workspace_id` on any table, no auth middleware on either the HTTP API or the MCP server, and the chat handler hardcodes `userID := "default_user"`. All recipes, the meal plan, ingredients, units, and labels live in one global namespace. Migrations stop at `00008_consolidate_units.sql`; nothing identity-related exists in the schema.

This document maps the current state, then (as explicitly requested) analyses the gap to a true multi-tenant product on Google Play. The gap is large: identity + auth from scratch, real per-tenant data isolation on every read, self-service signup, object storage for photos, per-tenant LLM cost/abuse controls, Play compliance (account deletion, data safety, privacy/export), and production-grade infra.

## Detailed Findings

### Current State: Identity & Auth — none exists

- **No authentication anywhere.** HTTP routes are wrapped only by `metrics.HTTPMetrics(middleware.AccessLog(...))` (`internal/application/api/router.go:60`). No auth middleware.
- **MCP server is wide open.** Served via `http.Serve(mcpListener, httpMCPServer)` with no wrapper (`cmd/server/server.go:121-138`). Any caller can invoke any recipe tool.
- **Chat hardcodes a user.** `userID := "default_user"` (`internal/application/chat/handler.go:118`). Chat sessions are in-memory (`session.InMemoryService()`) — lost on restart, not shared across replicas.
- **`r.Context()` is plumbed end-to-end** (handler → service → repository) but nothing is ever read from it for identity. This is the natural injection point for a `UserID`/`WorkspaceID`.
- **The Flutter app authenticates as the *app*, not a user.** It uses Hydra OAuth2 `client_credentials` (`app/lib/infrastructure/network/auth_interceptor.dart`), client `the-bluer-book`, scope `recipes:api`, shipping a client secret in the APK (`app/lib/infrastructure/config/oauth_config.dart`, `app/env/release.env`). No login screen — `main.dart` boots straight into `AppShell`.
- **Edge auth is split** (`charts/bluer-book/templates/ingressroute.yaml`): `/mcp` has *no* middleware, `/api` uses `jwt-auth` (Oathkeeper forward-auth), everything else uses `ory-auth` (Kratos session cookies). So there is a perimeter OAuth/OIDC story via the Ory homelab stack (Hydra + Kratos + Oathkeeper, documented in `.claude/skills/oauth-api-auth.md`), but the app code consumes none of it.

### Current State: Data Model — one global namespace

No table has `user_id`, `tenant_id`, `owner`, or `workspace_id`. Tables (`migrations/00002`–`00008`):

- `recipes` (root; soft-delete via `archived_at`), `steps`, `recipe_ingredient`, `recipe_label`, `photos`.
- Shared lookup/reference data: `ingredients` (UNIQUE name, lowercased), `units` (UNIQUE name), `labels` (typed taxonomy: course/cuisine/diet/method, UNIQUE(type,name)).
- `meal_plan_recipes` keyed on **`recipe_id` alone** — a single global meal plan.

Every sqlc query (`internal/infrastructure/storage/queries/*.sql`) filters by `archived_at IS NULL` and recipe/name/label predicates only — **never by an owner**. Ingredients/units/labels are deduplicated globally by unique name, i.e. they are deliberately *shared canonical reference data*, not user data. This is the single biggest data-model decision a multi-tenant migration must confront (see gap analysis).

### Current State: Photos — URLs only, no storage

`photos` stores a `url` string with a polymorphic `(entity_type, entity_id)`. The backend **never uploads or serves image bytes** — URLs are assumed to be provided by the client and hosted elsewhere (`internal/infrastructure/storage/repository/recipes.go`). There is no S3/GCS/bucket integration anywhere.

### Current State: Config & Deployment — single everything

- **Config** (`internal/infrastructure/config/config.go`): `LISTEN_ADDR` (:8080), `MCP_ADDR` (:8082), `DB_*` (single Postgres DSN, `sslmode=disable`), `GOOGLE_API_KEY`, `GEMINI_MODEL` (default `gemini-3.5-flash`). Secrets now sourced from 1Password (`charts/bluer-book/templates/secrets.yaml`, vault `Homelab`, item `bluer-book-secrets`).
- **One Postgres** per deployment (`db.New(sqlDB)`, single `sql.DB`). Helm ships a 1-replica `postgres:17.5-alpine` StatefulSet on a **1Gi `local-path` PVC** (`charts/bluer-book/templates/postgresql-statefulset.yaml`) — homelab-grade, no HA, no backups visible.
- **One app replica** (`app.replicaCount: 1`), image `ghcr.io/kieranajp/the-bluer-book`, behind a single Traefik IngressRoute on `recipes.kieranajp.uk`.
- **One shared Gemini key** for both the chat handler and the `tag-recipes` batch job.
- **`tag-recipes` runs as a deploy-time initContainer** over *all* recipes (`charts/bluer-book/templates/app-deployment.yaml`, `--continue-on-error`). This is a global batch — incompatible with per-tenant data at scale.
- CI/CD: `build.yml` (tests + GHCR push), `deploy.yml` (helm upgrade via Tailscale), `release.yml` (Flutter APK with OAuth secrets injected).

## "What's Needed" — Gap Analysis (explicitly requested)

Everything below is net-new relative to the current code, ordered roughly foundation-first.

### 1. Auth foundation
- Identity on every request: read the authenticated subject at the edge → `UserID` in `r.Context()`; auth middleware on `/api/*` AND `/mcp/*` (the latter currently has none); a `users` table; retire the Flutter `client_credentials` flow in favour of a user-bound login.
- **Self-serve signup** is the app-store-specific part: registration + onboarding for strangers, not the current fixed single user. The auth design has to be public-signup-capable.

### 2. Tenant model & provisioning
- A real `workspaces` table with `workspace_id` as a FK on every domain table.
- **Auto-provision a workspace on signup** (each new account gets its own book), plus a `workspace_members` join for household sharing/invites and roles.
- A `current_workspace` resolution path on every request.

### 3. Data isolation on **reads**, not just writes — the big one
- *Every* query in `recipes.sql`, `meal_plan.sql`, `label_filtering.sql` needs a `workspace_id = $n` predicate, plus composite indexes `(workspace_id, archived_at)` etc.
- Strongly consider **Postgres Row-Level Security** as a backstop so a missed `WHERE` can't leak across tenants. sqlc + RLS via a per-request `SET app.workspace_id` is a known pattern. This is the difference between "attribution" and "isolation".
- **Shared reference data decision (unavoidable):** `ingredients`, `units`, `labels` are globally unique/deduped today. Per-tenant tables would break that uniqueness model and the `tag-recipes` taxonomy; global-shared keeps dedup but leaks "which ingredients exist" across tenants and lets one tenant's typo pollute everyone. This choice ripples through the repository layer (`recipes.go` upserts ingredients/units/labels by name).
- `meal_plan_recipes` must gain `workspace_id` and re-key.

### 4. Photo / image storage
- UGC at app-store scale can't be "client provides a URL". You need real object storage (S3/GCS/R2), upload endpoints, signed URLs, size/type validation, per-tenant prefixes/quotas, and likely content moderation. None exists today.

### 5. LLM cost, quota & abuse
- One shared `GOOGLE_API_KEY` bills all tenants' chat + tagging to you. Multi-tenant needs per-tenant rate limits, usage metering/quotas, and abuse protection (the chat endpoint is an open Gemini proxy once auth'd).
- **`tag-recipes` as a deploy-time batch over all recipes does not scale per-tenant** — auto-tagging must become per-recipe/async (on create/update) or an opt-in per-tenant job.
- Chat sessions are in-memory + single-replica — needs a shared/durable session store once you scale replicas.

### 6. Google Play compliance — hard gates
**Target is Google Play, not Apple** (decided 2026-05-29 — no iOS, so Sign in with Apple is *not* required).
- **Account deletion is mandatory.** Google Play's data-deletion policy requires any app with account creation to offer account+data deletion via **both** an in-app path **and** a publicly reachable web URL. Implies a real tenant-purge that removes recipes, tenant-scoped ingredients, photos, meal plans, cooking events, and the identity.
- **Data safety form** (Play's declaration of what data is collected/shared).
- **Privacy policy + data export/portability** (GDPR) — EU-resident dev, likely EU users; DSAR export + deletion flows needed.
- If later monetised: **Google Play Billing** + entitlement checks (the connected Superwall MCP hints at future paywall intent). Out of scope at launch (free).

### 7. Production infra
- 1-replica app + 1Gi `local-path` single Postgres on a homelab cluster is not an app-store backend. Needs: managed/HA Postgres with backups + PITR, horizontal app scaling (stateless — fix in-memory chat sessions first), TLS to the DB (currently `sslmode=disable`), observability per-tenant, and a public-grade ingress/domain story (vs `kieranajp.uk`).

### 8. MCP per-tenant scoping
- Once `/mcp` is auth'd, each tenant's Claude connection must resolve to that tenant's `workspace_id` and see only their recipes. The chat handler's localhost MCP client call must propagate the real user/workspace, not a fixed service user.

## Code References
- `internal/application/api/router.go:60` — sole middleware chain; auth slots in here.
- `cmd/server/server.go:121-138` — MCP server served with no middleware.
- `internal/application/chat/handler.go:118` — `userID := "default_user"` hardcode.
- `internal/infrastructure/storage/queries/recipes.sql` / `meal_plan.sql` / `label_filtering.sql` — every query; none owner-scoped.
- `migrations/00002_schema.sql` — core tables, no identity columns.
- `migrations/00004_meal_planning.sql:4-8` — `meal_plan_recipes` keyed on `recipe_id` only (global plan).
- `internal/infrastructure/storage/repository/recipes.go` — ingredient/unit/label upsert-by-global-name logic; photos as URLs.
- `internal/infrastructure/config/config.go:13-48` — config fields + single DSN.
- `charts/bluer-book/templates/ingressroute.yaml` — edge auth split (`/mcp` none, `/api` jwt-auth, rest ory-auth).
- `charts/bluer-book/templates/postgresql-statefulset.yaml` — 1Gi local-path single Postgres.
- `charts/bluer-book/templates/app-deployment.yaml` — `tag-recipes` deploy-time initContainer over all recipes.
- `app/lib/infrastructure/network/auth_interceptor.dart` — Flutter `client_credentials` flow.
- `app/lib/main.dart` — boots straight into `AppShell`, no login gate.

## Architecture Documentation
- Hexagonal layout: `domain/recipe` (model + service), `application/{api,mcp,chat}` (adapters in), `infrastructure/{storage,config,logger,metrics,auth}` (adapters out). `r.Context()` threaded throughout — the designed seam for identity.
- sqlc-generated DB layer (`internal/infrastructure/storage/db`) from `queries/*.sql`; mapper translates DB ↔ domain.
- Two HTTP listeners in one process (API :8080, MCP :8082); chat handler is itself an MCP *client* over localhost to reach recipe tools.
- Perimeter auth via Ory (Traefik → Oathkeeper → Hydra/Kratos), currently unconsumed by app code.

## Historical Context (from thoughts/)
- `thoughts/api-jwt-auth.md` — pre-existing JWT plumbing notes; flags the missing Oathkeeper `/mcp` rule.
- `thoughts/mobile-app-migration-plan.md`, `thoughts/shared/plans/P001-...chat-and-bottom-nav.md` — adjacent history.
- `.claude/skills/oauth-api-auth.md` — the Ory homelab auth pattern (`X-User` header injection).

## Related Research
- None yet (this is R1).

## Decisions (2026-05-29)
Resolved with Kieran:
1. **Tenant scope = Household with invites.** Workspace has multiple members; build the `workspace_members` join + roles from day one. Shared-book model, extended to many households. → tenant ≠ user; need invite flow + membership.
2. **Reference data = Hybrid.** Global curated, read-only base taxonomy for `labels` + `units` (preserves `tag-recipes`); `ingredients` become **tenant-scoped**. → the global `UNIQUE(name)` on `ingredients` and the upsert-by-name logic in `recipes.go` must move to `(workspace_id, name)`; `labels`/`units` upserts stay global.
3. **IdP = self-hosted Ory (Hydra + Kratos), Google-login only.** Rationale: Auth0 ruled out (past bad experience); Clerk buys nothing over Ory at this scale; Ory is already deployed + edge-wired and Hydra already supports the OAuth DCR that the Claude remote-MCP "Connect" flow needs — the alternatives mostly lack it. **Google-only login is the key simplifier**: Kratos does no passwords, so no email verification / reset / recovery and minimal bot-signup exposure — the main self-hosting burden evaporates. Auth design = Hydra DCR + Oathkeeper subject header + Flutter PKCE, made public-signup-capable.
   - Residual, non-blocking: GCP OAuth consent-screen publish (light branding review for `email`/`profile` scopes); Google-only locks out the Google-less (fine on Play); transactional email (deletion confirm, GDPR-export ping) is a later additive SES/Postmark job, off the launch critical path.
4. **Target = Google Play (not Apple); free at launch.** No iOS → no Sign in with Apple. No IAP/entitlement gating now. → still required for Play: account deletion (in-app **and** web URL), data safety form, privacy policy, GDPR export.
5. **Isolation = RLS backstop.** Single shared Postgres; app-level `WHERE workspace_id` *plus* Postgres Row-Level Security as a leak backstop (per-request `SET app.workspace_id`, wired through the `database/sql` connection). A missed `WHERE` physically can't cross tenants. Not schema-per-tenant.
6. **Sequencing = tenant-real from day one.** One coherent plan, phased schema → Go identity → Ory → Flutter → UI. The first migration creates real `workspaces` + `workspace_members` + signup-time provisioning — no hardcoded-constant interim, no later rework.

All major decisions are now settled — ready to turn into an implementation plan.
