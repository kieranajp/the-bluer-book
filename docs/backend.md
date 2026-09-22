# Backend patterns (Go)

Layered domain-driven design under `internal/`. The dependency rule points inward:
`infrastructure` and `application` depend on `domain`; `domain` depends on nothing in
this repo.

```
internal/
├── domain/recipe/            # pure domain — no framework imports
│   ├── recipe.go             #   aggregate root + value objects
│   ├── errors.go             #   typed errors + sentinels
│   ├── probe.go              #   observability interface (domain-owned)
│   └── service/              #   RecipeService — orchestration
├── domain/account/           # users, homes and who belongs to which
│   ├── repository.go         #   the persistence port, owned by the domain
│   └── service/              #   provision on first login, resolve the active home
├── application/              # adapters / entry points
│   ├── api/                  #   REST (net/http) + middleware
│   ├── mcp/                  #   MCP tools (mark3labs)
│   ├── chat/                 #   LLM agent (ADK/Gemini, SSE)
│   └── identity/             #   binds the auth middleware to the account service
└── infrastructure/           # the outside world
    ├── storage/{db,queries,repository,mapper}
    ├── auth/                 #   X-User middleware; user and home on the context
    ├── metrics/              #   Prometheus impls of the Probe interfaces
    ├── logger/ config/
```

## The canonical type shape

Every collaborator is an **interface + unexported implementation + `NewX`
constructor**, wired by constructor injection in `cmd/server/server.go`.

```go
type RecipeService interface { /* ... */ }

type recipeService struct {
    repo  repository.RecipeRepository
    probe recipe.Probe
}

func NewRecipeService(repo repository.RecipeRepository, probe recipe.Probe) RecipeService {
    return &recipeService{repo: repo, probe: probe}
}
```

Handlers are the exception: they're concrete structs (`*RecipeHandler`,
`*RecipeMCPHandler`) since nothing depends on them abstractly.

## The service layer is the only door into the domain

REST handlers, MCP tools, and the chat agent **all call `RecipeService`** — never the
repository or `db` package. The MCP `CreateRecipe` and the HTTP `CreateRecipe` build the
same `recipe.Recipe` and call the same `s.CreateRecipe(ctx, rec)`. Put domain rules in
the service so every entry point gets them.

## Observability via the Probe pattern

The domain declares what's worth observing; infrastructure decides how.

- `recipe.Probe` (in `domain/recipe/probe.go`) is a domain interface:
  `RecipeCreated`, `MealPlanChanged`, `RecipeError`, …
- `metrics.RecipeProbe` implements it with Prometheus counters + zerolog.
- `metrics.NoopRecipeProbe` is the test implementation.

Fire probe calls **from the service**, around the repository call, not from handlers:

```go
result, err := s.repo.SaveRecipe(ctx, r)
if err != nil {
    s.probe.RecipeError("create", err)
    return nil, err
}
s.probe.RecipeCreated(result.Name)
```

This keeps Prometheus out of the domain and gives tests a silent probe.

## Errors

Domain errors are **typed struct + sentinel + `Is`** so callers match on identity while
the message carries context:

```go
var ErrRecipeNotFound = errors.New("recipe not found")

type RecipeNotFoundError struct{ ID uuid.UUID }
func (e RecipeNotFoundError) Error() string { return fmt.Sprintf("recipe with ID %s not found", e.ID) }
func (e RecipeNotFoundError) Is(target error) bool { return target == ErrRecipeNotFound }
```

Handlers translate them to HTTP with `errors.Is` and the **standard error envelope**:

```go
if errors.Is(err, recipe.ErrRecipeNotFound) {
    h.writeErrorResponse(w, http.StatusNotFound, "recipe_not_found", "Recipe not found")
    return
}
// → {"error":{"code":"recipe_not_found","message":"Recipe not found"}}
```

## REST conventions

- **Routing** uses std-lib method+pattern routes (`GET /api/recipes/{id}`) in
  `api/router.go`. Read path params with **`r.PathValue("id")`**, via the shared
  `recipeIDFromPath(w, r)` helper which validates the UUID and writes the error
  response — callers just `if !ok { return }`. Do not hand-parse the URL.
- **Validation** for create/update lives in `api/middleware/validation.go`: it decodes
  and validates the body, then stashes the validated `recipe.Recipe` in the request
  `context` under a typed key (`ValidatedRecipeKey`). The handler pulls it out — so a
  handler reaching that code can assume a valid body.
- **List endpoints** return `{"recipes":[...],"total":N,"limit":L,"offset":O}`.
- Cross-cutting middleware (`metrics.HTTPMetrics`, `middleware.AccessLog`) wraps the
  whole mux in `NewRouter`.

## Storage

- **sqlc** generates type-safe query code into `internal/infrastructure/storage/db/`
  from `migrations/*.sql` (schema) and `queries/*.sql` (queries). This directory is
  git-ignored — run `sqlc generate` after changing either. Config: `sqlc.yaml`.
- The **repository** (`repository/recipes.go`) is the only place that imports `db`. It
  maps sqlc rows ↔ domain types (helpers in `storage/mapper`) and reaches a tenant table
  only through `InHomeTx`, which opens the transaction, publishes the caller's home as
  `app.home_id` and commits or rolls back:

  ```go
  var out *recipe.Recipe
  err := InHomeTx(ctx, r.sqlDB, func(q *db.Queries) error {
      // …every query for this operation, in this one transaction…
      return nil
  })
  ```

  One transaction per repository method — never one per query, never nested. A context
  with no home gets `auth.ErrNoHome` and touches nothing. `fn`'s error comes back
  unwrapped, so translate `sql.ErrNoRows` into a domain error inside the closure. The
  identity tables in `repository/accounts.go` are the exception: they resolve a request
  before any home is known, so they use the plain pool.

  Postgres enforces this, not just the query layer: every tenant table carries a
  `home_isolation` policy keyed on the same `app.home_id` setting (`migrations/00014_rls.sql`),
  so a query inside `InHomeTx` needs no home predicate — the policy supplies it — and one
  written outside `InHomeTx` reads and writes nothing rather than crossing a boundary. That
  setting reverts to the empty string, not NULL, once its transaction ends, which is why the
  policy folds it through `NULLIF` before the cast: a bare cast would raise on a connection
  the pool hands back between transactions, whereas comparing against NULL evaluates to
  NULL, which excludes the row, so an idle connection reads zero rows rather than erroring. Ingredient name
  resolution is scoped per home by the same policy — two homes can each own an ingredient
  called "milk". `labels` is not: it is a global taxonomy carrying no policy, so only the
  `uses` count `ListLabels` reads out of `recipe_label` is scoped, and the query's
  `HAVING COUNT(rl.recipe_id) > 0` is what keeps a label another home invented out of the
  list.
- **Isolation** is proved against a real database, not asserted in code:
  `repository/isolation_integration_test.go` runs `TestIsolation` through the ordinary
  repositories and refuses outright — never skips — on a connection the policies wouldn't
  bind, since a superuser, a role holding BYPASSRLS, or the tables' owner would satisfy
  every assertion without a policy being consulted. Run it with `./scripts/rls-test.sh`,
  which builds both the owner and `bluer_book_app` roles and points the suite at each in
  turn — including a run as the owner that must fail, so the pass as `bluer_book_app`
  means something.
- **Query metrics** come for free: both the pool and each home-scoped transaction are
  wrapped in `metrics.NewInstrumentedDBTX`, so every sqlc query records
  `bluerbook_db_query_duration_seconds` / `_errors_total` (labelled by the sqlc query
  name parsed from its `-- name:` header) without the repository touching Prometheus —
  the same infra-owned, cross-cutting split as `metrics.HTTPMetrics`. `metrics.RegisterDBStats`
  adds `go_sql_*` connection-pool gauges.

## CLI & config

`main.go` builds a `urfave/cli/v2` app with `server`, `migrate`, and `tag` subcommands.
Config comes from CLI flags backed by env vars (`config.New(c)`), e.g. `LISTEN_ADDR`,
`MCP_ADDR`, `DB_*`, `APP_DB_USER`, `APP_DB_PASS`, `GOOGLE_API_KEY`, `GEMINI_MODEL`,
`FOUNDER_SUBJECT`, `MCP_HOME_ID`. `Config.AppDBDSN()` — not `DBDSN()` — is what the server
connects with; the split exists because the isolation policies described in
`docs/architecture.md` bind only the role `APP_DB_USER` names, never `DB_USER`.

## Adding a new recipe operation (checklist)

1. Add the SQL to `queries/*.sql`; run `sqlc generate`. A tenant table's `home_id` fills
   itself from the GUC, so do not name it or filter on it.
2. Add the method to `RecipeRepository` (interface + impl) with row↔domain mapping, its
   body inside a single `InHomeTx`.
3. Add it to `RecipeService`; fire the relevant `Probe` calls; add a `Probe` method +
   noop + Prometheus impl if it's a new kind of event.
4. Expose it: REST handler + route, and/or an MCP tool in `mcp/handler.go`. The chat
   agent picks up new MCP tools automatically.
5. Tests: services/handlers use `NoopRecipeProbe`.
