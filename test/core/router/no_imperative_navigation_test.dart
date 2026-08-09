import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Locks ADR-0018 D8 in CI: nothing under `lib/` may open or close a screen
/// through `Navigator` any more — destinations are named, and the route
/// table decides what they mean.
///
/// A test rather than a `grep` in a checklist, for the same reason ADR-0017
/// D10 gives: a command a human is supposed to remember to run is not
/// enforcement. And it scans **source text, not an AST** — which makes it a
/// guardrail against forgetting, not a security boundary. Anyone who wants
/// to route around it can (`final nav = Navigator; nav.of(...)`), and this
/// will not see it.
///
/// The allowlist is **empty**, and that is a result rather than an
/// aspiration. ADR-0018 D2 kept `condition_grade_guide_sheet.dart` on
/// `Navigator` because nobody had checked whether `context.pop()` inside a
/// `showModalBottomSheet` closes the sheet or the page beneath it. It closes
/// the sheet: the sheet is pushed on the very Navigator `go_router` builds
/// (`showModalBottomSheet` defaults to `useRootNavigator: false`, i.e. the
/// nearest one), `InheritedGoRouter` wraps that Navigator rather than
/// sitting under it (`router.dart:303-305`), and `GoRouterDelegate.pop`
/// pops that Navigator's topmost route (`delegate.dart:96-103`). Verified
/// on go_router 17.4.0, and exercised for real by
/// `condition_grade_guide_sheet_test.dart`'s dismissal test.
void main() {
  /// Everything outside a `//` comment on [line].
  ///
  /// Quote-aware, so a `//` inside a string literal (a URL, say) does not
  /// blank the rest of the line and hide a real call sitting after it.
  /// Block comments and multi-line strings are not modelled — the failure
  /// mode there is a false alarm, which someone will notice, rather than a
  /// silent pass.
  String stripComment(String line) {
    String? quote;
    for (int i = 0; i < line.length; i++) {
      final String ch = line[i];
      if (quote != null) {
        if (ch == r'\') {
          i++;
        } else if (ch == quote) {
          quote = null;
        }
        continue;
      }
      if (ch == "'" || ch == '"') {
        quote = ch;
        continue;
      }
      if (ch == '/' && i + 1 < line.length && line[i + 1] == '/') {
        return line.substring(0, i);
      }
    }
    return line;
  }

  /// `file:line` for every line of code under [root] matching [pattern].
  List<String> hits(Directory root, Pattern pattern) {
    final List<String> found = <String>[];
    for (final FileSystemEntity entity in root.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final List<String> lines = entity.readAsLinesSync();
      for (int i = 0; i < lines.length; i++) {
        if (stripComment(lines[i]).contains(pattern)) {
          found.add('${entity.path}:${i + 1}');
        }
      }
    }
    return found;
  }

  final Directory lib = Directory('lib');

  test('the scanner actually reads the source tree — a run that found no '
      'files would pass every assertion below without checking anything', () {
    expect(lib.existsSync(), isTrue);
    final int dartFiles = lib
        .listSync(recursive: true)
        .whereType<File>()
        .where((File f) => f.path.endsWith('.dart'))
        .length;
    expect(dartFiles, greaterThan(50), reason: 'scanned $dartFiles files');
    // Something the scanner must be able to find, so a broken matcher shows
    // up here rather than as a quiet all-clear.
    expect(hits(lib, 'GoRoute('), isNotEmpty);
  });

  test('the comment stripper does not blind the scan', () {
    expect(stripComment('  x(); // Navigator.of(context).pop()'), '  x(); ');
    expect(stripComment('/// Navigator.push does the thing'), '');
    // A `//` inside a string must not swallow what follows it.
    expect(
      stripComment("const u = 'https://a.b'; Navigator.of(c).pop();"),
      contains('Navigator.of'),
    );
    expect(stripComment('final a = 1;'), 'final a = 1;');
  });

  test('no MaterialPageRoute anywhere in lib/', () {
    expect(hits(lib, 'MaterialPageRoute'), isEmpty);
  });

  test('no Navigator anywhere in lib/ — the allowlist is empty, including '
      'the condition-guide sheet (ADR-0018 D2 resolved during INF-01)', () {
    expect(hits(lib, 'Navigator.'), isEmpty);
    expect(hits(lib, 'Navigator.of('), isEmpty);
    expect(hits(lib, 'Navigator.push'), isEmpty);
    expect(hits(lib, 'Navigator.maybePop'), isEmpty);
  });

  test('main.dart drives MaterialApp.router from the provider and has no '
      'home: left (AC-2) — the entry screen is the / route now, not a widget '
      'named in main', () {
    // Comments stripped: the file explains *why* there is no `home:` any
    // more, and a raw search reads that sentence as the thing it denies.
    final String main = File(
      'lib/main.dart',
    ).readAsLinesSync().map(stripComment).join('\n');
    expect(main, contains('MaterialApp.router'));
    expect(main, contains('routerConfig: ref.watch(routerProvider)'));
    expect(main, isNot(contains('home:')));
    // The environment override that resolves the native flavor has to
    // survive the switch to a router — nothing else picks SIT/UAT/prod.
    expect(
      main,
      contains('environmentProvider.overrideWithValue(environment)'),
    );
  });

  test('no deep-link plumbing was added — ADR-0018 D5 defers all of it to '
      'INF-15, and the native side of it is out of scope entirely (AC-7)', () {
    expect(hits(lib, 'uni_links'), isEmpty);
    expect(hits(lib, 'FlutterDeepLinkingEnabled'), isEmpty);
    expect(hits(lib, 'intent-filter'), isEmpty);
  });

  test('no route codegen crept in — ADR-0018 D1/D6 keep build_runner scoped '
      'to data/models DTOs', () {
    // Comments stripped first: `pubspec.yaml` explains in prose why
    // `riverpod_generator` is *not* used, and a raw text search reads that
    // sentence as the dependency it warns against.
    final String pubspec = File('pubspec.yaml')
        .readAsLinesSync()
        .map((String line) {
          final int hash = line.indexOf('#');
          return hash == -1 ? line : line.substring(0, hash);
        })
        .join('\n');
    expect(pubspec, isNot(contains('go_router_builder')));
    expect(pubspec, isNot(contains('riverpod_generator')));
    expect(pubspec, isNot(contains('auto_route')));
    expect(pubspec, contains('go_router:'));
  });

  /// Every `lib/` file that imports go_router — the only files in which a
  /// `.extra` could possibly be `GoRouterState.extra`.
  ///
  /// Scoping by import rather than by a list of filenames is what lets this
  /// assert **zero** without knowing anything about Dio: `RequestOptions.extra`
  /// lives in files that do not import go_router, so they are not in scope
  /// and no allowlist has to name them (INF-18 AC-4). An allowlist of
  /// filenames, or worse of line numbers, would rot the moment either file
  /// moved — and would rot silently, in the direction of passing.
  ///
  /// 🔴 The import must be matched with **both quote styles**. `analysis_options.yaml`
  /// leaves `prefer_single_quotes` commented out, so `import "package:go_router/…"`
  /// is legal here — and a scope that only recognised `'` would drop such a
  /// file out of range entirely, taking every `.extra` in it along. That is
  /// not hypothetical: it was the state of this test when `code-critic`
  /// reviewed INF-18, and a file added with double quotes read
  /// `GoRouterState.of(context).extra` with the suite green.
  List<File> goRouterFiles(Directory root) {
    return root
        .listSync(recursive: true)
        .whereType<File>()
        .where((File f) => f.path.endsWith('.dart'))
        .where(
          (File f) => f.readAsLinesSync().any(
            (String l) =>
                l.contains(RegExp('''import ['"]package:go_router''')),
          ),
        )
        .toList();
  }

  test('no file that uses go_router touches `.extra` at all (ADR-0018 D6 + '
      'Amendment 2 A2-D2) — a route argument is how the phone-verification '
      'flow used to be silently dropped on every refresh', () {
    // The old shape of this test allowed exactly one reader and required the
    // matcher to find it. Amendment 2 moved that state into a provider, so
    // "there is a reader" became false by construction and the assertion had
    // to become the stronger one: there are none. It also drops the
    // `(?:state|State)\.extra` matcher, whose recorded blind spot was a read
    // through a differently-named variable (`screens.yaml` INF-01
    // `standing_rules`) — `\.extra\b` has no such gap.
    //
    // 🔴 What that blind spot became, rather than what it stopped being: the
    // matcher no longer misses a read, but the *scope* can still miss a whole
    // file. `goRouterFiles` decides membership from an import line, so
    // anything that reaches `GoRouterState` without one — a re-export, a
    // `part of`, an alias — is invisible here no matter how the read is
    // spelled. Still text, still not an AST, still a guardrail rather than a
    // boundary (ADR-0018 D8).
    final List<File> scoped = goRouterFiles(lib);

    // Positive control 1: the scope is real. A run that resolved to no files
    // would pass the assertion below while checking nothing.
    expect(
      scoped,
      isNotEmpty,
      reason: 'no lib/ file imports go_router — the scope is broken',
    );

    // Positive control 2: the matcher can match. A regex that matches nothing
    // at all would also pass the assertion below.
    expect(
      stripComment(
        "final Object? e = state.extra;",
      ).contains(RegExp(r'\.extra\b')),
      isTrue,
      reason: 'the matcher no longer recognises a real read',
    );

    final List<String> offenders = <String>[];
    for (final File file in scoped) {
      final List<String> lines = file.readAsLinesSync();
      for (int i = 0; i < lines.length; i++) {
        if (stripComment(lines[i]).contains(RegExp(r'\.extra\b'))) {
          offenders.add('${file.path}:${i + 1}');
        }
      }
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'a route argument came back. State a route cannot render without '
          'belongs in a provider reached through `requireRouteState` — '
          '`extra` is JSON-encoded by go_router and becomes null on refresh: '
          '$offenders',
    );

    // The casts that turned the dropped value into a crash on screen. Kept
    // as their own assertion: `extra` reappearing *with* a safe read would
    // still be the pattern this forbids, and these would not catch it.
    expect(hits(lib, RegExp(r'\.extra!')), isEmpty);
    expect(hits(lib, RegExp(r'\.extra as ')), isEmpty);
  });
}
