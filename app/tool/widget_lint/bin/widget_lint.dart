// Structural lint for the Flutter app.
//
// Enforces two of the "keep widgets small" rules from docs/frontend.md that are
// mechanically checkable:
//
//   one-widget-per-file    A .dart file under lib/ holds at most one widget
//                          class (anything whose superclass name ends in
//                          "Widget" — StatelessWidget, StatefulWidget,
//                          ConsumerWidget, HookConsumerWidget, custom *Widget
//                          bases…). State/CustomPainter/ChangeNotifier
//                          companions don't count. A second widget class in the
//                          same file — public sibling or private `_SubWidget` —
//                          is a violation: extract it to its own file.
//
//   widget-returning-method  No helper method/function returns a `Widget`
//                          (other than the framework `build` override). Extract
//                          it into a widget class instead. Non-widget helpers
//                          (returning InputDecoration, TextStyle, a String…)
//                          are fine.
//
// The tool is intentionally self-contained: it depends only on `package:analyzer`
// so it runs under a plain Dart SDK, no Flutter toolchain required.
//
// Existing violations are grandfathered through baseline.txt so the check can be
// switched on in CI without first refactoring the whole app. New violations
// fail; the backlog can be burned down over time (and the baseline shrunk).
//
// Usage:
//   dart run widget_lint                 # check lib/, honouring the baseline
//   dart run widget_lint --update-baseline
//   dart run widget_lint --no-baseline   # report every violation (ignore baseline)
//   dart run widget_lint --lib <dir> --baseline <file>

import 'dart:io';

import 'package:analyzer/dart/analysis/features.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';

const ruleOneWidgetPerFile = 'one-widget-per-file';
const ruleWidgetReturningMethod = 'widget-returning-method';

void main(List<String> args) {
  final opts = _Options.parse(args);

  final libDir = Directory(opts.libPath);
  if (!libDir.existsSync()) {
    stderr.writeln('widget_lint: lib directory not found: ${opts.libPath}');
    exit(2);
  }

  final findings = <Finding>[];
  for (final file in _dartSources(libDir)) {
    findings.addAll(_analyze(file, opts.appPath));
  }
  findings.sort();

  if (opts.updateBaseline) {
    _writeBaseline(opts.baselinePath, findings);
    stdout.writeln(
      'widget_lint: wrote ${findings.length} entries to '
      '${_relative(opts.baselinePath, Directory.current.path)}',
    );
    return;
  }

  final baseline = opts.useBaseline
      ? _readBaseline(opts.baselinePath)
      : <String>{};
  final seen = <String>{};
  final fresh = <Finding>[];
  for (final f in findings) {
    seen.add(f.signature);
    if (!baseline.contains(f.signature)) fresh.add(f);
  }

  if (fresh.isNotEmpty) {
    stderr.writeln(
      'widget_lint: ${fresh.length} new widget-structure '
      'violation${fresh.length == 1 ? '' : 's'} '
      '(see docs/frontend.md "Keeping widgets small"):\n',
    );
    for (final f in fresh) {
      stderr.writeln('  ${f.describe()}');
    }
    stderr.writeln(
      '\nFix by extracting each extra widget class into its own file '
      '(a screen + its sub-widgets = a folder of files), or convert '
      'Widget-returning helpers into widget classes.\n'
      'If a violation is intentional and must stay, add its signature to\n'
      '  ${_relative(opts.baselinePath, Directory.current.path)}\n'
      'or rerun with --update-baseline (and please justify it in review).',
    );
    exit(1);
  }

  // Surface baseline drift: entries that no longer correspond to a real
  // violation. Not fatal, but they should be pruned so the backlog shrinks.
  final stale = baseline.difference(seen);
  if (opts.useBaseline && stale.isNotEmpty) {
    stdout.writeln(
      'widget_lint: ${stale.length} stale baseline '
      'entr${stale.length == 1 ? 'y' : 'ies'} (violation fixed — '
      'remove from baseline / rerun --update-baseline):',
    );
    for (final s in (stale.toList()..sort())) {
      stdout.writeln('  $s');
    }
  }

  final grandfathered = baseline.intersection(seen).length;
  stdout.writeln(
    'widget_lint: ok — no new violations'
    '${grandfathered > 0 ? ' ($grandfathered grandfathered in baseline)' : ''}.',
  );
}

/// One detected violation.
class Finding implements Comparable<Finding> {
  Finding({
    required this.relPath,
    required this.rule,
    required this.name,
    required this.line,
    required this.detail,
  });

  final String relPath; // path relative to the app dir, e.g. lib/.../foo.dart
  final String rule;
  final String name; // class or method name — the stable part of the signature
  final int line;
  final String detail; // human-readable explanation

  /// Stable, location-independent key used for baselining. Deliberately excludes
  /// the line number so that unrelated edits above don't churn the baseline.
  String get signature => '$relPath|$rule|$name';

  String describe() => '$relPath:$line  [$rule]  $detail';

  @override
  int compareTo(Finding other) {
    final byPath = relPath.compareTo(other.relPath);
    if (byPath != 0) return byPath;
    final byRule = rule.compareTo(other.rule);
    if (byRule != 0) return byRule;
    return name.compareTo(other.name);
  }
}

Iterable<File> _dartSources(Directory libDir) sync* {
  final entries = libDir.listSync(recursive: true).whereType<File>().toList()
    ..sort((a, b) => a.path.compareTo(b.path));
  for (final f in entries) {
    final path = f.path;
    if (!path.endsWith('.dart')) continue;
    if (path.endsWith('.g.dart') || path.endsWith('.freezed.dart')) continue;
    yield f;
  }
}

List<Finding> _analyze(File file, String appDir) {
  final relPath = _relative(file.path, appDir);
  final parsed = parseFile(
    path: file.absolute.path,
    featureSet: FeatureSet.latestLanguageVersion(),
    throwIfDiagnostics: false,
  );
  final unit = parsed.unit;
  final lineInfo = unit.lineInfo;
  final findings = <Finding>[];

  final visitor = _WidgetVisitor();
  unit.accept(visitor);

  // Rule: one widget class per file. The first widget class (preferring the one
  // whose name matches the filename) is the legitimate owner; flag the rest.
  if (visitor.widgetClasses.length > 1) {
    final expected = _expectedClassName(relPath);
    final ordered = [...visitor.widgetClasses];
    final primaryIdx = ordered.indexWhere((c) => c.name == expected);
    final primary = primaryIdx >= 0 ? ordered[primaryIdx] : ordered.first;
    for (final c in ordered) {
      if (identical(c, primary)) continue;
      findings.add(
        Finding(
          relPath: relPath,
          rule: ruleOneWidgetPerFile,
          name: c.name,
          line: lineInfo.getLocation(c.offset).lineNumber,
          detail:
              'extra widget class `${c.name}` (extends ${c.superName}); '
              'one widget class per file — move it to its own file',
        ),
      );
    }
  }

  // Rule: no Widget-returning helper methods/functions (except `build`).
  for (final m in visitor.widgetReturningMembers) {
    findings.add(
      Finding(
        relPath: relPath,
        rule: ruleWidgetReturningMethod,
        name: m.name,
        line: lineInfo.getLocation(m.offset).lineNumber,
        detail:
            '`${m.name}` returns ${m.returnType}; extract it into a widget '
            'class instead of a Widget-returning helper',
      ),
    );
  }

  return findings;
}

class _WidgetClass {
  _WidgetClass(this.name, this.superName, this.offset);
  final String name;
  final String superName;
  final int offset;
}

class _Member {
  _Member(this.name, this.returnType, this.offset);
  final String name;
  final String returnType;
  final int offset;
}

class _WidgetVisitor extends RecursiveAstVisitor<void> {
  final widgetClasses = <_WidgetClass>[];
  final widgetReturningMembers = <_Member>[];

  @override
  void visitClassDeclaration(ClassDeclaration node) {
    final superType = node.extendsClause?.superclass;
    if (superType != null) {
      final superName = _simpleTypeName(superType.toSource());
      if (superName.endsWith('Widget')) {
        widgetClasses.add(
          _WidgetClass(node.name.lexeme, superName, node.offset),
        );
      }
    }
    super.visitClassDeclaration(node);
  }

  @override
  void visitMethodDeclaration(MethodDeclaration node) {
    _checkReturnsWidget(node.name.lexeme, node.returnType, node.offset);
    super.visitMethodDeclaration(node);
  }

  @override
  void visitFunctionDeclaration(FunctionDeclaration node) {
    _checkReturnsWidget(node.name.lexeme, node.returnType, node.offset);
    super.visitFunctionDeclaration(node);
  }

  void _checkReturnsWidget(
    String name,
    TypeAnnotation? returnType,
    int offset,
  ) {
    if (returnType == null) return;
    if (name == 'build') return; // the framework override is the point
    final src = returnType.toSource();
    // Match `Widget` / `Widget?` exactly — the helper smell from frontend.md.
    // Deliberately does not match `PreferredSizeWidget`, `List<Widget>`, etc.,
    // to avoid false positives on legitimate factory/builder helpers.
    if (src == 'Widget' || src == 'Widget?') {
      widgetReturningMembers.add(_Member(name, src, offset));
    }
  }
}

/// "State<Foo>" -> "State", "a.b.ConsumerWidget" -> "ConsumerWidget".
String _simpleTypeName(String source) {
  var s = source.trim();
  final lt = s.indexOf('<');
  if (lt >= 0) s = s.substring(0, lt);
  final dot = s.lastIndexOf('.');
  if (dot >= 0) s = s.substring(dot + 1);
  return s.trim();
}

/// snake_case filename -> expected PascalCase widget class name.
/// `recipe_header.dart` -> `RecipeHeader`.
String _expectedClassName(String relPath) {
  final base = relPath.split('/').last.replaceAll('.dart', '');
  return base
      .split('_')
      .where((p) => p.isNotEmpty)
      .map((p) => p[0].toUpperCase() + p.substring(1))
      .join();
}

Set<String> _readBaseline(String path) {
  final file = File(path);
  if (!file.existsSync()) return <String>{};
  return file
      .readAsLinesSync()
      .map((l) => l.trim())
      .where((l) => l.isNotEmpty && !l.startsWith('#'))
      .toSet();
}

void _writeBaseline(String path, List<Finding> findings) {
  final file = File(path);
  file.parent.createSync(recursive: true);
  final buf = StringBuffer()
    ..writeln('# widget_lint baseline — grandfathered structural violations.')
    ..writeln('#')
    ..writeln(
      '# Each line is `<relpath>|<rule>|<name>`. Entries here are KNOWN',
    )
    ..writeln(
      '# pre-existing violations that do NOT fail CI. New violations do.',
    )
    ..writeln('# Burn this list down over time; do not add to it casually.')
    ..writeln('# Regenerate with: dart run widget_lint --update-baseline')
    ..writeln('#');
  for (final f in findings) {
    buf.writeln(f.signature);
  }
  file.writeAsStringSync(buf.toString());
}

/// Walks up from the current directory, returning the first ancestor (inclusive)
/// for which [test] holds, or null if none match before the filesystem root.
String? _findUp(bool Function(Directory) test) {
  var dir = Directory.current.absolute;
  while (true) {
    if (test(dir)) return dir.path;
    final parent = dir.parent;
    if (parent.path == dir.path) return null; // reached the root
    dir = parent;
  }
}

String _relative(String path, String from) {
  final p = File(path).absolute.path;
  final base = Directory(from).absolute.path;
  final prefix = base.endsWith('/') ? base : '$base/';
  return p.startsWith(prefix) ? p.substring(prefix.length) : p;
}

class _Options {
  _Options({
    required this.appPath,
    required this.libPath,
    required this.baselinePath,
    required this.updateBaseline,
    required this.useBaseline,
  });

  final String appPath; // app dir containing lib/ — relpaths are relative to it
  final String libPath;
  final String baselinePath;
  final bool updateBaseline;
  final bool useBaseline;

  static _Options parse(List<String> args) {
    String? libArg;
    String? appArg;
    String? baselineArg;
    var update = false;
    var useBaseline = true;

    for (var i = 0; i < args.length; i++) {
      final a = args[i];
      switch (a) {
        case '--update-baseline':
          update = true;
        case '--no-baseline':
          useBaseline = false;
        case '--lib':
          libArg = args[++i];
        case '--app':
          appArg = args[++i];
        case '--baseline':
          baselineArg = args[++i];
        case '-h':
        case '--help':
          stdout.writeln(
            'widget_lint — structural lint for the Flutter app.\n\n'
            'Options:\n'
            '  --update-baseline   rewrite the baseline from current violations\n'
            '  --no-baseline       report every violation (ignore the baseline)\n'
            '  --lib <dir>         directory to scan (default: <app>/lib)\n'
            '  --app <dir>         app dir containing lib/ (default: ../../ )\n'
            '  --baseline <file>   baseline path (default: <pkg>/baseline.txt)',
          );
          exit(0);
        default:
          stderr.writeln('widget_lint: unknown argument: $a');
          exit(2);
      }
    }

    // Defaults are resolved by walking up from the current directory, so the
    // tool works whether invoked from its own package dir (the usual case,
    // `dart run widget_lint`) or from the app dir.
    final packageRoot =
        _findUp(
          (d) =>
              File('${d.path}/bin/widget_lint.dart').existsSync() &&
              File('${d.path}/pubspec.yaml').existsSync(),
        ) ??
        Directory.current.path;
    final resolvedApp =
        appArg ??
        _findUp(
          (d) =>
              Directory('${d.path}/lib').existsSync() &&
              File('${d.path}/pubspec.yaml').existsSync() &&
              d.path != packageRoot,
        ) ??
        Directory.current.path;
    final libPath = libArg ?? '$resolvedApp/lib';
    final baselinePath = baselineArg ?? '$packageRoot/baseline.txt';

    return _Options(
      appPath: Directory(resolvedApp).absolute.path,
      libPath: Directory(libPath).absolute.path,
      baselinePath: File(baselinePath).absolute.path,
      updateBaseline: update,
      useBaseline: useBaseline,
    );
  }
}
