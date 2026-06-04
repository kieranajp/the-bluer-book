# The widget_lint CI check

`app/tool/widget_lint` is a self-contained Dart tool (depends only on
`package:analyzer`) that enforces the two structural rules below. It runs on every
PR as the **"Widget structure lint"** step inside the **"Flutter: Test"** job
(`.github/workflows/build.yml`). **If it finds a violation, the job fails** — your
PR goes red before a human reviews it.

## What it catches

| Rule | Fails on | Allowed |
|------|----------|---------|
| `one-widget-per-file` | a 2nd widget class in a file — public sibling **or** private `_SubWidget` | `State<T>` / `ConsumerState<T>` companions, `CustomPainter`, non-widget classes |
| `widget-returning-method` | a method/function returning `Widget` (other than `build`) | helpers returning `InputDecoration`, `TextStyle`, `String`, `List<Widget>`, … |

A "widget class" is detected syntactically: any class whose superclass name ends
in `Widget` (`StatelessWidget`, `ConsumerWidget`, `HookConsumerWidget`, a custom
`FooWidget` base…).

## Run it locally (do this before pushing)

```bash
cd app/tool/widget_lint
dart pub get
dart run widget_lint            # honours baseline.txt — what CI runs
dart run widget_lint --no-baseline   # report everything, ignore the baseline
```

A clean run prints `widget_lint: ok — no new violations.` A failure lists each
offender as `path:line  [rule]  detail` and exits non-zero.

## The baseline

`baseline.txt` is **empty** — the original 32-violation backlog was cleared, so the
check is effectively strict. Keep it empty: fix violations, don't grandfather them.

It remains as a ratchet *escape hatch*. If you ever have a genuinely justified
exception, add its stable signature (`<relpath>|<rule>|<name>`, no line number) to
`baseline.txt` — or regenerate with `dart run widget_lint --update-baseline` — and
explain it in review. A passing run also reports **stale** baseline entries (a
listed violation that's since been fixed) so they can be pruned.

## Why a standalone tool (not custom_lint)

It parses source syntactically — no Flutter SDK, no resolution, no pub-version
juggling — so it runs anywhere a plain Dart SDK exists, and it supports the
baseline ratchet that `flutter analyze` can't. The app excludes `tool/**` from
`flutter analyze` so the tool's own deps don't leak into app analysis.
See `app/tool/widget_lint/README.md`.
