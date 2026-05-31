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
├── application/              # adapters / entry points
│   ├── api/                  #   REST (net/http) + middleware
│   ├── mcp/                  #   MCP tools (mark3labs)
│   └── chat/                 #   LLM agent (ADK/Gemini, SSE)
└── infrastructure/           # the outside world
    ├── storage/{db,queries,repository,mapper}
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
  maps sqlc rows ↔ domain types (helpers in `storage/mapper`) and owns transactions
  with the `defer` commit/rollback idiom:

  ```go
  tx, err := r.sqlDB.BeginTx(ctx, nil)
  q := db.New(tx)
  defer func() { if err != nil { tx.Rollback() } else { tx.Commit() } }()
  ```

  (The named `err` return is what makes that defer work — keep assigning to it.)

## CLI & config

`main.go` builds a `urfave/cli/v2` app with `server`, `migrate`, and `tag` subcommands.
Config comes from CLI flags backed by env vars (`config.New(c)`), e.g. `LISTEN_ADDR`,
`MCP_ADDR`, `DB_*`, `GOOGLE_API_KEY`, `GEMINI_MODEL`.

## Adding a new recipe operation (checklist)

1. Add the SQL to `queries/*.sql`; run `sqlc generate`.
2. Add the method to `RecipeRepository` (interface + impl) with row↔domain mapping.
3. Add it to `RecipeService`; fire the relevant `Probe` calls; add a `Probe` method +
   noop + Prometheus impl if it's a new kind of event.
4. Expose it: REST handler + route, and/or an MCP tool in `mcp/handler.go`. The chat
   agent picks up new MCP tools automatically.
5. Tests: services/handlers use `NoopRecipeProbe`.
