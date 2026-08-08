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

  test('every `debugDetail:` constructor argument in lib/ is wrapped in '
      '`logDebugDetail(` (ADR-0017 D7 — the kDebugMode guard lives inside that '
      'helper, so an unwrapped assignment silently turns the one sanctioned '
      'diagnostic channel back into store-and-discard)', () {
    // 🔴 พบด้วย mutation 2026-08-06: ถอด wrapper ออกจาก
    // `google_sign_in_data_source.dart:56` แล้ว `flutter test` **ยังเขียว
    // 370/370** — ไม่มีเทสตัวไหนคุมการห่อนี้เลยสักตัว · เคสนี้คือตัวที่ปิดช่องนั้น
    //
    // ทำไมสำคัญกว่าที่ดู: ADR-0017 §ผลที่ตามมา ข้อ 4 บันทึกไว้ว่ารอบนั้น
    // **ลด "ข้อมูลที่ผู้ใช้เห็น" โดยไม่ได้เพิ่ม "ข้อมูลที่ทีมเห็น"** (ยังไม่มี crash
    // reporting — NFR-08) · `logDebugDetail()` จึงเป็นช่องทาง diagnostic
    // *ช่องเดียว* ที่มีอยู่จริงวันนี้ การถอดมันออกเงียบ ๆ ทำให้ debug ตาบอดสนิท
    final offenders = <String>[];
    for (final file in dartFiles) {
      final path = relPath(file);
      for (final line in file.readAsStringSync().split('\n')) {
        final index = line.indexOf('debugDetail:');
        if (index < 0) continue;
        final after = line.substring(index + 'debugDetail:'.length).trim();
        // ค่าอาจขึ้นบรรทัดใหม่ (`debugDetail: logDebugDetail(` แล้ว argument
        // อยู่บรรทัดถัดไป) — ที่ต้องอยู่ติดกันคือ *ชื่อฟังก์ชัน* ไม่ใช่ทั้ง expression
        if (!after.startsWith('logDebugDetail(')) {
          offenders.add('$path: ${line.trim()}');
        }
      }
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'พบ `debugDetail:` ที่ไม่ได้ห่อด้วย logDebugDetail() — ADR-0017 D7 '
          'บังคับให้ค่านี้ออกจากแอปได้ทางเดียวคือ log line ที่ guard ด้วย '
          'kDebugMode ซึ่ง guard นั้นอยู่ *ในตัวฟังก์ชัน* จึงลืมไม่ได้ '
          'ถ้าไม่เรียกผ่านมัน\n'
          'จุดที่พบ:\n  ${offenders.join('\n  ')}',
    );
  });

  test('`logDebugDetail` is referenced only from its own file and from data '
      'layers (ADR-0017 D7 — the D10 scan above bans the token `debugDetail` '
      'under presentation/, but `logDebugDetail` has a capital D and slips '
      'straight past that check)', () {
    // ⚠️ ช่องนี้บันทึกไว้เองใน known_gaps ของ INF-02: ชื่อ `logDebugDetail`
    // ไม่ match `contains('debugDetail')` ของเคสข้างบน จึงเรียกจากที่ไหนก็ได้ ·
    // วันนี้ถูกเพราะถูกเรียกจาก data layer ล้วน — แต่ "วันนี้ถูก" ไม่ใช่กฎ
    const definition = 'lib/core/error/debug_log.dart';
    final offenders = <String>[];
    for (final file in dartFiles) {
      final path = relPath(file);
      if (path == definition) continue;
      if (!file.readAsStringSync().contains('logDebugDetail')) continue;
      if (!path.contains('/data/')) offenders.add(path);
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'พบการเรียก logDebugDetail() นอกชั้น data — ค่านี้เป็น diagnostic '
          'ของชั้นที่เห็น exception ต้นทางเท่านั้น การเรียกจากชั้นอื่น '
          '(โดยเฉพาะ presentation/) คือการดึง debugDetail เข้าใกล้ชั้น render '
          'ซึ่ง D7 ห้าม\n'
          'จุดที่พบ:\n  ${offenders.join('\n  ')}',
    );
    // closed-world — ถ้าไฟล์นิยามหายไปหรือเปลี่ยนชื่อ เคสข้างบนจะผ่านฟรีทันที
    expect(File(definition).existsSync(), isTrue, reason: '$definition หายไป');
  });

  test('the first argument of every `resolveErrorDisplay(` call in lib/ is a '
      '`.displayMessage` — ADR-0017 D4 step 2 may only ever receive the '
      'backend-envelope field, and that slot is positional so the D2 scan '
      'above cannot see what goes into it', () {
    // 🔴 ช่องที่ *ดีไซน์รอบนี้สร้างขึ้นเอง* ไม่ใช่ข้อจำกัดทั่วไปของการสแกน:
    // พารามิเตอร์ถูกทำเป็น positional โดยเจตนา (เหตุผลอยู่ใน doc comment ของ
    // `error_display.dart`) เพื่อไม่ให้ไฟล์ที่แค่ *ส่งต่อ* ค่าต้องเข้า allowlist ของ D2
    // ผลข้างเคียงคือ mapper ส่งค่าอะไรเข้าไปก็ได้โดยเทสเขียว
    //
    // ยืนยันด้วย mutation 2026-08-06: เปลี่ยน `e.displayMessage` → `e.toString()`
    // ใน `catalog_error_display.dart` แล้วเทสสแกนยังเขียวครบ
    const definition = 'lib/core/error/error_display.dart';
    final offenders = <String>[];
    for (final file in dartFiles) {
      final path = relPath(file);
      if (path == definition) continue;
      final lines = file.readAsStringSync().split('\n');
      for (var i = 0; i < lines.length; i++) {
        if (!lines[i].contains('resolveErrorDisplay(')) continue;
        // argument ตัวแรกอยู่ท้ายบรรทัดเดียวกัน หรือบรรทัดถัดไป (dart format
        // ขึ้นบรรทัดใหม่เมื่อ argument list ยาว) — ยอมรับทั้งสองรูป
        final tail = lines[i].split('resolveErrorDisplay(').last.trim();
        final first = tail.isEmpty ? lines[i + 1].trim() : tail;
        if (!RegExp(r'^\w+\.displayMessage,?$').hasMatch(first)) {
          offenders.add('$path:${i + 1}: $first');
        }
      }
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'argument ตัวแรกของ resolveErrorDisplay() ต้องเป็น '
          '`<exception>.displayMessage` เท่านั้น — ADR-0017 D2 กำหนดว่าช่องนั้น '
          'เติมได้จาก envelope {error_code, message} ของ backend เท่านั้น '
          'การส่ง e.toString() หรือข้อความจาก SDK เข้าไปคือการพาข้อความดิบ '
          'ขึ้นจอผ่านขั้นที่ 2 ของ D4\n'
          'จุดที่พบ:\n  ${offenders.join('\n  ')}',
    );
    // closed-world — เคสข้างบนวนเฉพาะไฟล์ที่ *มี* การเรียก ถ้าวันหนึ่งไม่มีใคร
    // เรียกเลย มันจะผ่านฟรีทั้งที่ mapper ถูกรื้อทิ้ง
    final callers = dartFiles
        .where((f) => relPath(f) != definition)
        .where((f) => f.readAsStringSync().contains('resolveErrorDisplay('))
        .map(relPath)
        .toList();
    expect(
      callers,
      hasLength(2),
      reason:
          'ADR-0017 D9 — ต้องมี mapper ต่อฟีเจอร์ 2 ตัว (auth · catalog) '
          'ที่เรียกอัลกอริทึมกลาง · เจอ: $callers',
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
