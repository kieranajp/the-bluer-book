# widget_lint

A small, self-contained structural lint for the Flutter app. It enforces the two
mechanically-checkable rules from [`docs/frontend.md`](../../../docs/frontend.md)
("Keeping widgets small"):

| Rule | What it catches |
|------|-----------------|
| `one-widget-per-file` | A `lib/**.dart` file with more than one widget class — a second public sibling **or** a private `_SubWidget`. (`State` / `CustomPainter` / `ChangeNotifier` companions don't count.) Extract the extra class into its own file; a screen + its sub-widgets is a folder of files. |
| `widget-returning-method` | A helper method or function that returns a `Widget` (anything other than the framework `build` override). Make it a widget class. Non-widget helpers — returning `InputDecoration`, `TextStyle`, a `String`, `List<Widget>`, … — are fine. |

It depends only on `package:analyzer`, so it runs under a plain Dart SDK without
the Flutter toolchain (it parses source syntactically — no `flutter pub get`,
no resolution). The app excludes `tool/**` from `flutter analyze`.

## Running

```bash
cd app/tool/widget_lint
dart pub get
dart run widget_lint            # check lib/, honouring the baseline (CI does this)
```

## The baseline

When this lint was introduced the app had 32 pre-existing violations. They have
since all been refactored away, so [`baseline.txt`](baseline.txt) is now **empty**
and the check is effectively strict — any violation fails CI.

The baseline remains as a ratchet for grandfathering, if ever needed again: add a
`path|rule|name` signature to keep a deliberate exception out of CI, but don't
grow it casually. Each entry is a stable signature with no line number, so
unrelated edits don't churn it.

```bash
dart run widget_lint --no-baseline      # report every violation, ignore baseline
dart run widget_lint --update-baseline  # rewrite baseline from current violations
```

A passing run also reports **stale** baseline entries (a violation that's since
been fixed) so they can be pruned.

## Notes / limits

- Detection is syntactic: a "widget class" is one whose superclass name ends in
  `Widget` (`StatelessWidget`, `ConsumerWidget`, `HookConsumerWidget`, a custom
  `FooWidget` base, …). This matches every Flutter widget base and excludes
  `State<T>`, `CustomPainter`, notifiers, etc.
- The SOLID/DRY ideas in `AGENTS.md` aren't all mechanical; this tool only covers
  the file/widget-structure rules. It's the place to add further structural
  checks as they become well-defined.
