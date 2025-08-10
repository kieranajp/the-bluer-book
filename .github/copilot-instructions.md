## AI Coding Agent Instructions for The Blue(r) Book

Concise, project-specific guidance to be productive quickly. Prefer concrete existing patterns over generic advice.

### 1. Architecture Overview
- Layers (clean-ish):
	1. HTTP API (`internal/application/api`) – thin handlers + validation middleware; no business logic.
	2. MCP tools (`internal/application/mcp`) – mirror core recipe operations for LLM/tooling access; share the same service.
	3. Domain (`internal/domain/recipe`) – aggregate structs, domain errors, service interface/implementation (`service/`). Keep business rules here.
	4. Infrastructure:
		 - Persistence (`internal/infrastructure/storage`):
			 - `queries/` raw SQL for sqlc.
			 - Generated code in `storage/db/` (DO NOT EDIT) from `sqlc generate`.
			 - Repository (`storage/repository/recipes.go`) orchestrates multi-table transactions & row → domain assembly.
		 - Logging (`infrastructure/logger`) zerolog wrapper.
		 - LLM & external integrations (e.g. `infrastructure/llm`, `infrastructure/trello`).
	5. CLI entry (`main.go` + `cmd/server`) wires config, DB, services, HTTP + MCP servers.

### 2. Data & Persistence Patterns
- Schema migrations: `migrations/01_schema.sql`, soft-delete additions in `02_soft_delete.sql` (adds `archived_at` with partial indices for active vs archived queries).
- sqlc config in `sqlc.yaml`; source queries live in `internal/infrastructure/storage/queries/` (add SQL there, then regenerate).
- Generated package name: `db`. Never hand-edit generated files; instead adjust SQL.
- Repositories manage:
	- Explicit transactions for create (multi-entity insert + logging).
	- Row-to-aggregate reconstruction via helper `buildRecipeFromRows` (ensure new related tables get added there when expanding Recipe aggregate).
	- Soft delete = set `archived_at`; restoration clears it (see `ArchiveRecipe`, `RestoreRecipe`).

### 3. Service & Domain Conventions
- Service interface (`recipe_service.go`) exposes CRUD + archive/restore & listing; returns domain objects or typed not-found errors (`internal/domain/recipe/errors.go`).
- UUID generation performed in service for create if absent; repository double-checks for safety.
- Partial updates currently simplistic (UpdateRecipe overwrites provided scalar fields; TODO: photos, steps, ingredients re-sync logic not yet implemented—avoid speculative changes unless implementing fully).

### 4. HTTP API Conventions
- Router uses Go 1.22+ pattern verbs (`mux.HandleFunc("GET /api/recipes", ...)`). Keep to this pattern when adding routes.
- Validation lives in middleware (`internal/application/api/middleware`) which injects a validated `recipe.Recipe` into context under `middleware.ValidatedRecipeKey` before handler executes. Follow same pattern for new create/update style endpoints.
- Error responses: JSON envelope `{ "error": { "code": string, "message": string } }` with appropriate HTTP status (see `RecipeHandler.writeErrorResponse`). Reuse that helper.
- Pagination: `limit` (default 20, capped 100) and `offset` query params. Include `total`, `limit`, `offset` in list responses.

### 5. MCP Tooling Layer
- Tools registered in `internal/application/mcp/handler.go` mirror API capabilities; each tool file (`create_recipe.go`, `search_recipes.go`, etc.) parses loosely-typed `mcp.CallToolRequest` arguments then calls the same service.
- When adding a new recipe-facing capability, update both HTTP router and MCP registration for parity (name tools in snake_case, concise description, explicit schema for each argument).
- Responses to MCP calls are serialized JSON strings via `mcp.NewToolResultText` for LLM friendliness.

### 6. Logging
- Use injected `logger.Logger` (zerolog wrapper). Chain fields then `Msg(...)`. Keep contextual fields short (`recipe_id`, not `id`). Avoid printing large structs; log counts or IDs.

### 7. Front-End (Static SPA)
- Served from `./static` with a fallback to `index.html` for client routing (see router root handler).
- JS store (`static/js/store.js`) is framework-agnostic state; interaction modules under `static/js/` (e.g. `api.js`, `pagination.js`). Keep new modules small & single-purpose; export pure functions.
- Avoid coupling UI directly to fetch; centralize API calls in `api.js` (follow existing conventions when extending).

### 8. Build & Dev Workflow
- Primary dev path is a Dev Container / Docker Compose stack (see `docker-compose.yml`). Postgres + app run there.
- Generate database layer after changing SQL: run VS Code default task (Ctrl+Shift+B) or `sqlc generate` (defined in `.vscode` tasks) producing code in `internal/infrastructure/storage/db/`.
- Start server via CLI: `go run . server --db-dsn "$DSN"` (or environment `DB_DSN`). Starts both HTTP (default :8080) and MCP (:8082) servers.
- Reset DB: `docker compose down -v && docker compose up -d` (replays migrations; destructive).

### 9. Adding New Persistence Fields (Example Flow)
1. Edit migration (new migration file preferred vs editing existing applied one) to add column.
2. Add/update SQL queries in `queries/`. Keep naming consistent (verb_entity.sqlc). Include updated columns in SELECT lists; repository relies on them.
3. Run `sqlc generate`.
4. Extend `recipe.Recipe` struct if domain needs field exposure (avoid leaking nullable DB semantics; map Null* types to zero values or pointers intentionally).
5. Update repository `buildRecipeFromRows` to populate new field; extend create/update logic transactionally.
6. Adjust handlers + MCP tools if surfaced externally.

### 10. Error Handling Patterns
- Domain not found errors implement custom types (e.g. `RecipeNotFoundError`) — repository returns them; handlers map to 404 by code comparison (see error usage in handlers). Maintain this: introduce new typed errors inside domain package and surface them unchanged outward.

### 11. Soft Delete Semantics
- Active recipe queries exclude archived records via partial indices. Do not physically delete recipes; use `ArchiveRecipe` + `RestoreRecipe`. When adding list endpoints, provide separate archived listing if needed.

### 12. Code Style & Misc
- Readability first: write code you can skim at 80 chars wide; avoid clever compression.
- Functions always multiline – no `func Foo() { return x }` or one-line anonymous functions; open brace on same line, body on its own lines, blank line between logical blocks.
- Avoid terse guard clauses like `if err != nil { return err }` stacked densely; one guard per block with an empty line after improves scanability. Still fine to use guard clauses—just format them clearly, never `if cond { return }` on one line.
- No single-line early returns: expand to multiline so future additions (logging, metrics) are trivial.
- Prefer explicit context propagation (`ctx context.Context`) across all repository/service methods.
- Transactions: start at repository layer only when multiple tables mutated; keep service layer free of DB transaction details.
- Keep files small & cohesive: when a file nears ~300 lines or mixes responsibilities (e.g. parsing + service orchestration + response shaping) split it (`*_parse.go`, `*_handler.go`, etc.).
- Factor long functions (> ~60 lines) by extracting pure helpers placed near their only caller; promote to package-level only when reused.
- Keep repository methods focused: assembly helpers (like `buildRecipeFromRows`) should remain isolated; add new assembly logic there instead of in handlers/services.
- Front-end: keep each module single purpose (state in `store.js`, fetch logic in `api.js`, pagination in `pagination.js`); avoid framework dependencies – stay vanilla modular JS.

#### 12a. Front-End JS Specifics (same readability rules as Go)
- Same multiline rule: no `const f = () => doThing()` inline bodies once non-trivial; always expand:
	```js
	export function fetchRecipes(params) {
		// ...logic...
		return result;
	}
	```
- Avoid `if (cond) return` one-liners; expand for clarity & future logging.
- Keep side-effects out of pure helpers; mutation confined to store-manipulation functions.
- Derivations belong in small pure helpers (see `derive` in `store.js`).
- Naming: verbs for actions (`loadRecipes`), nouns for data (`recipeCache`).
- Prefer explicit object returns over positional arrays.
- Keep modules < ~120 lines; split (`recipes_fetch.js`, `recipes_render.js`) when mixing concerns.
- Centralize fetch calls in `api.js`; UI modules call those abstractions, not `fetch` directly.
- Debounce/throttle user-driven network calls in a tiny utility module if added (do not inline ad-hoc timers everywhere).
- Error propagation: return `{ ok:false, error }` objects from API helpers; UI layer decides notification.

### 13. Safe Changes Checklist (before PR / completion)
- Added SQL? Regenerated with `sqlc generate` and no diff outside `storage/db/` expected except new generated files.
- New fields: repository build helper updated; API & MCP parity ensured.
- Tests (if adding) should mock repository via interface `RecipeService` or use a temp DB container (follow future test patterns once introduced).

### 14. Examples
- Creating a recipe (HTTP): POST `/api/recipes` with validated JSON (middleware enforces structure) → service.CreateRecipe → repository.SaveRecipe(transaction inserts steps, ingredients, labels, photos) → returns aggregate.
- MCP create: tool `create_recipe` with `ingredients` array of objects → same service path, JSON response in tool result.

### 15. When Unsure
- Prefer reading analogous existing file (e.g. see `update_recipe` tool or `ArchiveRecipe` handler) and replicate style.
- Avoid speculative refactors; keep atomic, purpose-driven changes.

---
Feedback welcome: identify unclear sections or missing patterns you need documented.
