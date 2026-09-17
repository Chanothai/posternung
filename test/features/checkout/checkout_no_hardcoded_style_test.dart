import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// SCR-07 B9 (AC-B9-1 / AC-B9-2): `lib/features/checkout/` carries no
/// style of its own — colours, fonts and Material palette values come from
/// `core/theme/` (`AppColors`, `AppTextStyles`, `AppTheme`) and nothing
/// else. B8-UI happened because the checkout screens restated (and chose
/// wrongly) what the theme should have provided; this pins the fix so the
/// next edit cannot quietly bring a `TextStyle(` or a `Colors.white` back.
///
/// Source text, not an AST — the same guardrail-not-boundary caveat as
/// `test/core/router/no_imperative_navigation_test.dart`, whose comment
/// stripper this reuses in shape. Generated files (`*.g.dart`,
/// `*.freezed.dart`) are skipped: they are not hand-written and contain no
/// widgets.
void main() {
  /// Everything outside a `//` comment on [line], quote-aware so a `//`
  /// inside a string does not hide what follows it.
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

  final Directory checkout = Directory('lib/features/checkout');

  List<File> sources() => checkout
      .listSync(recursive: true)
      .whereType<File>()
      .where((File f) => f.path.endsWith('.dart'))
      .where((File f) => !f.path.endsWith('.g.dart'))
      .where((File f) => !f.path.endsWith('.freezed.dart'))
      .toList();

  /// `file:line: <code>` for every line of hand-written checkout source
  /// matching [pattern] — the offending line itself is printed so a red run
  /// says *what* came back, not just that something did.
  List<String> offenders(Pattern pattern) {
    final List<String> found = <String>[];
    for (final File file in sources()) {
      final List<String> lines = file.readAsLinesSync();
      for (int i = 0; i < lines.length; i++) {
        final String code = stripComment(lines[i]);
        if (code.contains(pattern)) {
          found.add('${file.path}:${i + 1}: ${code.trim()}');
        }
      }
    }
    return found;
  }

  // The four things a feature file must not do; each entry names the
  // `core/theme/` home for the value instead.
  final Map<String, Pattern> banned = <String, Pattern>{
    'TextStyle( — use an AppTextStyles entry (or .copyWith on one)':
        'TextStyle(',
    'Color(0x — hex lives in AppColors only': 'Color(0x',
    'fontFamily: — the family is GoogleFonts.kanit via AppTextStyles':
        'fontFamily:',
    'Material Colors.* — use AppColors (Colors.transparent included)': RegExp(
      r'(^|[^A-Za-z])Colors\.',
    ),
  };

  test('the scanner reads real files — an empty scope would pass every '
      'assertion below while checking nothing', () {
    final List<File> files = sources();
    expect(files.length, greaterThan(10), reason: 'scanned ${files.length}');
    expect(
      files.any((File f) => f.path.endsWith('checkout_screen.dart')),
      isTrue,
    );
    expect(files.any((File f) => f.path.endsWith('.g.dart')), isFalse);
  });

  test('every matcher recognises the thing it bans (positive control)', () {
    expect(
      '  style: TextStyle(color: x),'.contains(banned.values.first),
      isTrue,
    );
    expect(
      stripComment('  c: Color(0xFF000000),').contains('Color(0x'),
      isTrue,
    );
    expect('  fontFamily: "Lora",'.contains('fontFamily:'), isTrue);
    final Pattern colors = banned.values.last;
    expect('  color: Colors.white,'.contains(colors), isTrue);
    expect('Colors.transparent'.contains(colors), isTrue);
    // ...and does not trip on the token-holder it points people at.
    expect('  color: AppColors.white,'.contains(colors), isFalse);
    // The stripper keeps a `//` inside a string from hiding a real hit.
    expect(
      stripComment("const u = 'https://a.b'; c: Colors.red;"),
      contains('Colors.red'),
    );
    expect(
      stripComment('  // Colors.red is banned'),
      isNot(contains('Colors')),
    );
  });

  for (final MapEntry<String, Pattern> entry in banned.entries) {
    test('AC-B9-1 — no ${entry.key}', () {
      expect(
        offenders(entry.value),
        isEmpty,
        reason:
            'a style crept back into lib/features/checkout/ — move the value '
            'to core/theme/ (AppColors / AppTextStyles / AppTheme):',
      );
    });
  }

  test('AC-B9-2 — main.dart installs AppTheme.dark() and the deepPurple seed '
      'is gone', () {
    final String main = File(
      'lib/main.dart',
    ).readAsLinesSync().map(stripComment).join('\n');
    expect(main, contains('theme: AppTheme.dark()'));
    expect(main, isNot(contains('deepPurple')));
    expect(main, isNot(contains('ColorScheme.fromSeed')));
    // `AppTheme` is the only `ThemeData` factory in the app — a second one
    // would be the start of the drift this round removed.
    final List<String> themeDataSites = <String>[];
    for (final FileSystemEntity e in Directory(
      'lib',
    ).listSync(recursive: true)) {
      if (e is! File || !e.path.endsWith('.dart')) continue;
      final List<String> lines = e.readAsLinesSync();
      for (int i = 0; i < lines.length; i++) {
        if (stripComment(lines[i]).contains('ThemeData(')) {
          themeDataSites.add(e.path);
        }
      }
    }
    expect(themeDataSites.toSet(), <String>{'lib/core/theme/app_theme.dart'});
  });
}
