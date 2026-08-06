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

  test('GoRouterState.extra is cast in exactly one place (ADR-0018 D6) — a '
      'second cast site is the known way this stops being type-safe', () {
    final List<String> castSites = hits(lib, RegExp(r'\.extra!? as '));
    expect(castSites, hasLength(1), reason: 'extra cast sites: $castSites');
    expect(castSites.single, contains('core/router/app_router.dart'));
  });
}
