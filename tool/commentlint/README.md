# commentlint

The mechanical part of the `comment-discipline` skill: three comment shapes that
are wrong every time, so a linter can hold them. Everything else about comments —
above all *whether one earns its place* — stays the reviewer's call.

| Rule | Fails on | Exempt |
|------|----------|--------|
| `max-comment-run` | a run of standalone comment lines taller than 2 | a trailing comment beside code never joins a run |
| `no-narration` | journey phrases — "turns out", "we used to", "the bug was", "originally", "in hindsight", … | — |
| `no-path-pointer` | a source path (`internal/domain/recipe/recipe.go`) or line pointer (`recipe.go:42`) | URLs; a bare filename with no directory |

One tool covers **both languages**: the rules are lexical and Go and Dart share
`//`. Go comments come from `go/parser`, Dart's from a small scanner that knows
Dart's string forms — so neither a `"https://…"` literal nor a `'''…'''` block is
mistaken for prose. It depends only on the standard library, so it runs without
the sqlc stubs or a Dart SDK.

Directives are machine-readable, not prose, and are skipped: `//go:build`,
`//go:generate`, `//nolint`, `// ignore:`, `// ignore_for_file:`, `// dart format
off`, generator banners. Generated output (`*.g.dart`, `*.freezed.dart`, the
sqlc `db` package) is not scanned at all.

## Running

```bash
go run ./tool/commentlint            # main.go, cmd/, internal/, migrations/, tool/, app/lib/
go run ./tool/commentlint app/lib    # narrow it to one path
go run ./tool/commentlint -max=3     # loosen the run cap (don't)
```

A clean run prints `commentlint: ok — no violations.` A failure lists each
offender as `path:line  [rule]  detail` and exits non-zero. It runs on every PR
as the **"Comments: Lint"** job.

## No baseline, on purpose

`widget_lint` carries a baseline because its backlog was 32 structural refactors.
This one has none: every violation is a comment, and a comment is deleted or
rewritten in the time it takes to grandfather it. Fix them as you pass through.
