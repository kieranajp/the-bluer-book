# AGENTS.md

Guidance for AI agents working in this repo. This file is deliberately short and
covers the **non-obvious** rules; the deep dives live in `docs/`. Read code for
the obvious stuff.

- Backend (Go): `internal/`, layered DDD — see `docs/backend.md`
- Frontend (Flutter): `app/lib/`, same `domain`/`application`/`infrastructure` split — see `docs/frontend.md`
- How the pieces fit (REST + MCP + chat + auth): `docs/architecture.md`

## Generated code — regenerate, never hand-edit

- **sqlc**: `internal/infrastructure/storage/db/` is generated and **git-ignored** — it
  won't exist in a fresh clone. After editing `migrations/*.sql` or
  `internal/infrastructure/storage/queries/*.sql`, run `sqlc generate`. Nothing
  compiles until you do.
- **freezed/json_serializable**: after editing any `app/lib/domain/*.dart`, run
  `dart run build_runner build --delete-conflicting-outputs`. The `*.freezed.dart` /
  `*.g.dart` files are committed but are outputs, not sources.

## Layering rules (enforced, not just suggested)

- The **service layer is the only door into the domain**. REST handlers
  (`application/api`), MCP tools (`application/mcp`), and the chat agent all call
  `RecipeService` — never the repository or `db` directly from a handler.
- The domain **owns its observability**: `recipe.Probe` is a domain interface;
  `infrastructure/metrics` implements it (Prometheus + zerolog) with a `Noop*` for
  tests. Fire probe calls from the **service**, not handlers.
- Everything is **interface + unexported struct + `NewX` constructor + constructor
  injection**. Match that shape when adding a type.

## Things that will bite you

- **The chat agent is an MCP client.** `application/chat` loops back to the in-process
  MCP server over localhost HTTP/SSE. MCP tools are the single source of truth for LLM
  capabilities — add a tool in `application/mcp` and chat gets it for free; there is no
  separate "chat tools" layer.
- **Vocabulary is "meal plan" everywhere.** There is no "favourite" concept (it was
  vestigial and removed). Don't reintroduce it.
- **FE↔BE field names differ by design.** The Flutter domain bridges names with
  `@JsonKey` (e.g. `preparationTime`↔`prepTime`, `cookingTime`↔`cookTime`). If you
  change a Go JSON struct tag, update the matching `@JsonKey` in `app/lib/domain`.
- **REST error shape** is always `{"error":{"code","message"}}`. Map domain sentinel
  errors (`recipe.ErrRecipeNotFound`, …) with `errors.Is`, not string matching.
- **REST path params**: use `r.PathValue("id")` (via the `recipeIDFromPath` helper),
  never manual `strings.TrimPrefix`/`Split`. Routes declare `{id}` in the mux pattern.
- **Flutter styling**: never hardcode colours or sizes. Use `context.colours`
  (the `Colours` ThemeExtension) plus `Spacing` / `TextStyles` / `Shapes`. The
  `ColorScheme` is hand-built — do not switch to `ColorScheme.fromSeed`.
- **Flutter widget size**: **one widget class per file** (a screen + its sub-widgets =
  a folder of files, public classes prefixed for ownership). Extract widget *classes*,
  never `Widget _buildX()` helper methods. Screens orchestrate; logic lives in notifiers;
  dialogs are widgets. See `docs/frontend.md`. **Enforced in CI** by
  `app/tool/widget_lint` (one widget class per file + no `Widget`-returning helpers);
  the backlog is cleared so its `baseline.txt` is empty — keep it that way.

## Build & test

```bash
go build ./... && go test ./...          # backend (run sqlc generate first in a fresh clone)
cd app && flutter test                   # frontend
```

Develop on the branch you were given; commit with clear messages; never push to `main`.
