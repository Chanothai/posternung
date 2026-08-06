// ADR-0017 D10 — source scan enforcing the three-field split (D1) that
// keeps raw exception/SDK text off screen. Same style as the existing
// precedent, `test/features/poster/verification_fields_not_wired_test.dart`
// (ADR-0014 D5.1): a plain text scan over `lib/`, not an AST check — see
// `project-gotchas` §3 and ADR-0017 §ผลที่ตามมา ข้อ 5 for what that does and
// doesn't prove. Scope is `lib/` only, on purpose: `test/` fixtures need to
// construct `AuthException`/`CatalogException` with arbitrary `debugDetail`/
// `displayMessage` values to exercise the mapper, and that is not a D2/D7
// violation — only production code populating those fields wrongly is.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The only two places allowed to populate `displayMessage` when
/// constructing `AuthException`/`CatalogException` (ADR-0017 D2) — the two
/// datasources that actually see a backend `{error_code, message}` envelope.
/// Written as full paths from the package root, same convention as
/// `verification_fields_not_wired_test.dart`'s `_selfPath`.
const _displayMessageAllowlist = <String>[
  'lib/features/auth/data/datasources/backend_auth_data_source.dart',
  'lib/features/poster/data/datasources/poster_remote_data_source.dart',
];

void main() {
  late Directory libDir;
  late List<File> dartFiles;

  setUpAll(() {
    libDir = Directory('lib');
    expect(
      libDir.existsSync(),
      isTrue,
      reason: 'ต้องรันเทสจาก root ของ package (ที่เดียวกับ pubspec.yaml)',
    );
    dartFiles = libDir
        .listSync(recursive: true)
        .whereType<File>()
        .where(
          (f) =>
              f.path.endsWith('.dart') &&
              !f.path.endsWith('.freezed.dart') &&
              !f.path.endsWith('.g.dart'),
        )
        .toList();
    // Sanity check that the scan is actually looking at a non-trivial tree —
    // an empty list here would make every check below vacuously pass.
    expect(dartFiles, isNotEmpty);
  });

  /// Normalizes a `File.path` to the `lib/...` form used throughout this
  /// file's allowlists/directory checks, regardless of whether `Directory`
  /// yielded it with a leading `./` or backslashes (Windows CI runners).
  String relPath(File f) =>
      f.path.replaceAll('\\', '/').replaceFirst(RegExp(r'^\./'), '');

  bool underPresentationOrCoreWidgets(String path) =>
      path.contains('/presentation/') || path.contains('/core/widgets/');

  test('no `debugDetail` reference anywhere under lib/**/presentation/ or '
      'lib/core/widgets/ (ADR-0017 D7 — it may exist on the exception object, '
      'but nothing in the render path may read it)', () {
    final offenders = <String>[];
    for (final file in dartFiles) {
      final path = relPath(file);
      if (!underPresentationOrCoreWidgets(path)) continue;
      if (file.readAsStringSync().contains('debugDetail')) {
        offenders.add(path);
      }
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'พบการอ้าง debugDetail ใต้ presentation/ หรือ core/widgets/ — '
          'ADR-0017 D7 ห้ามให้ค่านี้ไปถึงชั้น render ไม่ว่าทางไหน '
          '(รวมถึง log line — ย้ายไปไว้ที่ data layer หรือ core/error/ แทน)\n'
          'จุดที่พบ:\n  ${offenders.join('\n  ')}',
    );
  });

  test('no `runtimeType` reference anywhere under lib/**/presentation/ '
      '(ADR-0017 D6/OD-1 — including debug-only log lines; the ban is on the '
      'token appearing in this subtree at all, not just on it reaching the '
      'screen, so a future debug log line cannot quietly reintroduce a '
      'runtime-composed string one refactor away from being rendered)', () {
    final offenders = <String>[];
    for (final file in dartFiles) {
      final path = relPath(file);
      if (!path.contains('/presentation/')) continue;
      if (file.readAsStringSync().contains('runtimeType')) {
        offenders.add(path);
      }
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'พบการอ้าง runtimeType ใต้ presentation/ — ADR-0017 D6/OD-1 '
          'ห้ามให้ code หรือข้อความที่ประกอบจาก runtimeType โผล่ในชั้นนี้เลย '
          'แม้จะเป็นแค่ debug log ก็ตาม — ใช้ error.toString() หรือค่าคงที่แทน\n'
          'จุดที่พบ:\n  ${offenders.join('\n  ')}',
    );
  });

  test("`displayMessage:` as a constructor argument appears only in the two "
      'backend-envelope datasources allowlisted by ADR-0017 D2 — anywhere '
      'else is a new, unreviewed way to put possibly-unsafe text on screen', () {
    final offenders = <String>[];
    for (final file in dartFiles) {
      final path = relPath(file);
      if (_displayMessageAllowlist.contains(path)) continue;
      if (file.readAsStringSync().contains('displayMessage:')) {
        offenders.add(path);
      }
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'พบ `displayMessage:` นอก allowlist ของ ADR-0017 D2 — '
          'ช่องนี้เติมได้จาก envelope {error_code, message} ของ backend เท่านั้น '
          '(สองไฟล์ที่ได้รับอนุญาต: ${_displayMessageAllowlist.join(", ")})\n'
          'ถ้าเป็น datasource ตัวใหม่ที่คุยกับ backend จริง ๆ ให้เพิ่มเข้า '
          '_displayMessageAllowlist ในไฟล์เทสนี้พร้อมอ้าง ADR-0017 ไม่ใช่ปิดเงียบ\n'
          'จุดที่พบ:\n  ${offenders.join('\n  ')}',
    );
  });

  test('sanity: the allowlisted datasources still exist and still construct an '
      'exception with displayMessage — guards against the allowlist silently '
      'protecting nothing after a rename/delete', () {
    for (final path in _displayMessageAllowlist) {
      final file = File(path);
      expect(file.existsSync(), isTrue, reason: '$path หายไป — แก้ allowlist');
      expect(
        file.readAsStringSync(),
        contains('displayMessage:'),
        reason:
            '$path ไม่มี displayMessage: อีกต่อไป — allowlist นี้ไม่จำเป็นแล้ว?',
      );
    }
  });
}
