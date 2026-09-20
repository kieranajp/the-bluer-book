# Architecture

The Bluer Book is a personal recipe book. A single Go binary serves a REST API and
an MCP server; a Flutter app and an in-process LLM chat agent are both clients of
that backend. Data lives in PostgreSQL.

```
                 ┌────────────────────────────────────────────────┐
                 │                  Go binary                       │
   Flutter app ──┤  :8080  REST API  ──┐                            │
   (app/)        │                     ├──► RecipeService ──► repo ─┼──► PostgreSQL
                 │  :8082  MCP server ─┘         ▲                  │
   Claude / LLM ─┤         (mark3labs)           │                  │
   over MCP      │                               │                  │
                 │  :8080  /api/chat  ──► chat agent (ADK/Gemini)   │
                 │            └─ MCP *client* ──► :8082 (loopback) ──┘
                 └────────────────────────────────────────────────┘
```

## Components

- **REST API** (`internal/application/api`) — JSON over `net/http` `ServeMux`, consumed
  by the Flutter app.
- **MCP server** (`internal/application/mcp`) — [mark3labs/mcp-go]. Exposes recipe
  operations as MCP tools so Claude (or any MCP client) can search/create/update/archive
  recipes and manage the meal plan.
- **Chat agent** (`internal/application/chat`) — a Google ADK + Gemini agent reached at
  `POST /api/chat` over Server-Sent Events. Crucially, **the agent is itself an MCP
  client**: it connects back to the binary's own MCP server over `http://localhost:8082`.
  So every MCP tool is automatically available to the chat agent — there is no separate
  tool registry for chat.
- **Flutter app** (`app/`) — Riverpod + Dio client. Talks only to the REST API.
- **PostgreSQL** — accessed through sqlc-generated queries behind a repository.

## Request lifecycle (all entry points converge)

```
HTTP handler ─┐
MCP tool      ├─► RecipeService ─► RecipeRepository ─► db (sqlc) ─► PostgreSQL
chat→MCP tool ┘        │
                       └─► recipe.Probe (metrics + structured logs)
```

The service layer is the single choke point for domain logic and observability. No
entry point reaches the repository or `db` package directly. See `docs/backend.md`.

## Authentication

In production the backend sits behind Traefik, whose `auth-token` middleware
(traefik-jwt-plugin) validates the bearer token's RS256 signature against the-bluer-book's
Authentik JWKS and injects an `X-User` header (the JWT `sub`). A person signs in through
Authentik in the Flutter app with the `authorization_code` grant and PKCE
(`app/lib/infrastructure/auth/`), against a public client — no secret ships in the binary.
Their tokens live in the device keychain and `AuthInterceptor`
(`app/lib/infrastructure/network/auth_interceptor.dart`) refreshes them as they age out.
This replaced the Ory stack (Hydra issued the tokens; Oathkeeper validated them). The
`oauth-api-auth` skill (`.claude/skills/oauth-api-auth.md`) covers the endpoints and the
edge, but still describes the app's old `client_credentials` grant.

Middleware on every `/api/` route (`internal/infrastructure/auth`) turns `X-User` into a
user and a home on the request context, provisioning both the first time a subject
appears. A request without the header is 401; `/health` and `/metrics` sit outside it.
The edge also forwards the `email` and `name` claims as `X-User-Email` and `X-User-Name`,
and a new home is named after the email's local part — both headers are optional, and a
home provisioned without them is called "My Book". `FOUNDER_SUBJECT` names the one subject
that joins the home holding the collection that predates all this, rather than an empty
one.

Locally there is no auth in front of the binary; it talks to a local Postgres.

## Tenancy

Every recipe, pantry and shopping-list table carries a `home_id` whose default is
`NULLIF(current_setting('app.home_id', true), '')::uuid`. The repositories run each
operation inside `InHomeTx`
(`internal/infrastructure/storage/repository/home_tx.go`), which publishes the request's
home as that transaction-local setting. An `INSERT` that never names a home still lands in
the caller's, and one that runs with no home set fails the `NOT NULL` check rather than
writing a row nobody owns — so no query takes a home parameter or carries a home predicate.
`units` and `labels` stay global: shared vocabulary rather than anybody's data.

Nothing stops a caller reading another home's rows yet. That is row-level security's job,
and it is not here. Until it lands, ingredient lookup by name in particular reads across
homes.

The MCP server has no caller to resolve — its route carries no auth and its tools take no
caller argument — so every tool call acts on the home named by `MCP_HOME_ID`, which defaults
to the founder home. The chat agent reaches the same home through it.

`cmd/tag` and `cmd/fetchimages` sweep every home at once under the owning database role, so
they name `home_id` explicitly, taking it from the recipe each row belongs to.

## Observability

- **Metrics**: Prometheus at `/metrics`. HTTP middleware records request
  duration/count (with `{id}` path normalisation); the `recipe.Probe` / `pantry.Probe` /
  `chat.Probe` implementations emit domain counters (`bluerbook_recipe_operations_total`,
  `bluerbook_meal_plan_changes_total`, `bluerbook_pantry_changes_total`, …). The storage
  layer is timed by an instrumented `db.DBTX` wrapper (`bluerbook_db_query_duration_seconds`,
  labelled by sqlc query name) plus `go_sql_*` connection-pool stats — see "Storage" in
  `backend.md`.
- **Dashboard**: a Grafana dashboard lives at
  `charts/bluer-book/dashboards/dashboard.json` (overview, HTTP, recipes, pantry,
  chat, database, Go runtime). It is auto-provisioned — the Helm chart ships it as
  a ConfigMap labelled `grafana_dashboard: "1"`, which Grafana's sidecar discovers
  across all namespaces. Its datasource variable resolves to the cluster's default
  Prometheus datasource, so no manual import or datasource selection is needed.
- **Logs**: structured zerolog throughout, including an access-log middleware.

## Deployment

Containerised (`Dockerfile`), deployed via Helm charts under `charts/` to a Kubernetes
homelab. `docker-compose.yml` brings up the binary + Postgres for local work.
Migrations run via the `migrate` subcommand (goose) — see `cmd/migrate`.

[mark3labs/mcp-go]: https://github.com/mark3labs/mcp-go
