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
home provisioned without them is called "My Book". They arrive on every request, so a
changed email or name is written back on the next one and housemates see it in the member
list; a header that stops arriving leaves the stored value alone rather than blanking it.
`FOUNDER_SUBJECT` names the one subject that joins the home holding the collection that
predates all this, rather than an empty one.

A caller in more than one home picks between them with an `X-Home` header. That one comes
from the client rather than the edge, so it is a request and not a fact: the middleware
returns the named home only to a member of it, and answers a non-member with a 403 and the
code `home_forbidden`. That is deliberately not the 401 an unauthenticated caller gets,
because the client refreshes its token and replays on a 401 — a user removed from a home
their client still names would burn a refresh on a session that is perfectly good. The 403
tells them to drop the home instead. Absent, a request acts on the home its caller most
recently joined — which accepting an invitation makes the new one.

Locally there is no auth in front of the binary; it talks to a local Postgres.

## Homes, members and invitations

`internal/application/api/account_handler.go` carries the five routes that move people
between homes: `GET /api/me`, `POST /api/homes/{id}/invitations`,
`POST /api/invitations/accept`, `GET /api/homes/{id}/members` and
`DELETE /api/homes/{id}/members/{userID}`. Inviting and removing are an owner's to do; a
home's last owner cannot be removed, since nobody would be left who could invite or remove
anybody. There is no UI for any of it — this is an API a person drives with curl.

An invitation is 256 bits from `crypto/rand`, handed back once in the response that
creates it. The row stores only its SHA-256 hash, so reading the `invitations` table joins
nobody to anything. That table sits outside row-level security by necessity: a token is
looked up before either party's home is known. Redemption is a single conditional `UPDATE`
that spends the invitation in the statement that finds it, so a token admits one person
once however many requests carry it at the same moment.

## Tenancy

Every recipe, pantry and shopping-list table carries a `home_id` whose default is
`NULLIF(current_setting('app.home_id', true), '')::uuid`. The repositories run each
operation inside `InHomeTx`
(`internal/infrastructure/storage/repository/home_tx.go`), which publishes the request's
home as that transaction-local setting. An `INSERT` that never names a home still lands in
the caller's, and one that runs with no home set fails the `NOT NULL` check rather than
writing a row nobody owns — so no query takes a home parameter or carries a home predicate.
`units` and `labels` stay global: shared vocabulary rather than anybody's data. Shared and
mutable, though — `CreateUnit` upserts an abbreviation, so an ordinary save in one home
rewrites the abbreviation every home sees. Nothing guards that.

PostgreSQL enforces this, not the query layer. Nine tenant tables — `recipes`, `steps`,
`recipe_ingredient`, `recipe_label`, `photos`, `meal_plan_recipes`, `ingredients`,
`pantry_items` and `shopping_list_items` — carry `ENABLE` and `FORCE ROW LEVEL SECURITY`
with one `home_isolation` policy each, keyed on that same `app.home_id` setting
(`migrations/00014_rls.sql`). No query carries a home predicate or a home parameter; the
policy is the predicate. The identity tables — `users`, `homes`, `home_members`,
`invitations` — stay outside it, because they're read to decide which home a request acts
on in the first place.

FORCE does not bind a superuser or a role holding BYPASSRLS — and `DB_USER` is the postgres
superuser in the deployed chart. So the server connects instead as `bluer_book_app`, a role
that owns no table and holds neither SUPERUSER nor BYPASSRLS. There is deliberately no
fallback from `APP_DB_USER` to `DB_USER`, and the server checks the connected role's
privileges at startup, and the tables' `FORCE` flags and policies, refusing to serve on
anything that wouldn't bind. Ingredient lookup by name is scoped per home by the same
policy. `labels` is not, being global, so `ListLabels` keeps its listing inside the home by
dropping any label this home has never applied.

Uniqueness and foreign keys are checked with row security switched off, so a policy cannot
stop one home writing a row that *references* another home's. Keys carry `home_id` for that
reason — the pantry on `(home_id, ingredient_id)`, the meal plan on `(home_id, recipe_id)` —
so such a row lands in the writer's own home and cannot occupy the other's slot.

The MCP server has no caller to resolve — its route carries no auth and its tools take no
caller argument — so every tool call acts on the home named by `MCP_HOME_ID`, which defaults
to the founder home. The chat agent reaches the same home through it, which is why
`POST /api/chat` refuses any caller whose resolved home is not `MCP_HOME_ID`, with a 403 and
the code `chat_unavailable_for_home`. That gate is a stopgap, not the fix: the assistant
stays unavailable to every other home until MCP can carry the caller and the pin comes out.

`cmd/tag` and `cmd/fetchimages` still connect as `DB_USER`, not `bluer_book_app`, because
they sweep every home at once; so they name `home_id` explicitly, taking it from the recipe
each row belongs to. That sweep works only because `DB_USER` is a superuser: `FORCE` binds a
plain owner like anyone else, so a `DB_USER` stripped of SUPERUSER would read nothing and
both init containers would complete as silent no-ops.

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
Migrations run via the `migrate` subcommand (goose) — see `cmd/migrate` — which also sets
`bluer_book_app`'s password from `APP_DB_PASS` on every run, so that secret never lands in
a file that ships in the image.

[mark3labs/mcp-go]: https://github.com/mark3labs/mcp-go
