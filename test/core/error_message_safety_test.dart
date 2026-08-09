// ADR-0017 D10 — source scan enforcing the three-field split (D1) that
// keeps raw exception/SDK text off screen. Same style as the existing
// precedent, `test/features/poster/verification_fields_not_wired_test.dart`
// (ADR-0014 D5.1): a plain text scan over `lib/`, not an AST check — see
// `project-gotchas` §3 and ADR-0017 §ผลที่ตามมา ข้อ 5 for what that does and
// doesn't prove. Scope is `lib/` only, on purpose: `test/` fixtures need to
// construct a `BackendErrorEnvelope` (via `test/support/backend_envelope_
// fixture.dart`, itself round-tripping a real `DioException` through the
// real parser — see ADR-0017 Amendment 1, OD-A) and an arbitrary
// `debugDetail` to exercise the mapper, and that is not a D2/D7 violation —
// only production code populating those fields wrongly is.
//
// 🔴 Amendment 1 (2026-08-09) replaced the file-path allowlist this file
// used to check for `displayMessage:` with a stronger mechanism: the field
// is no longer a parameter of either exception class's public constructor
// at all (`AuthException.fromEnvelope`/`CatalogException.fromEnvelope` are
// the only way in, gated by `BackendErrorEnvelope`'s private constructor —
// see `lib/core/error/backend_envelope.dart`). The scan below now bans both
// write forms (`displayMessage:` and `displayMessage =`) anywhere in `lib/`
// outside `lib/core/error/`, rather than naming specific files — there is no
// allowlist left to widen when a third datasource is added. It still does
// not (and must not) ban the plain `.displayMessage` getter read — the two
// feature mappers relay the field to `resolveErrorDisplay()` and are meant
// to keep doing that from `presentation/`.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Matches a `Response(` or `Response<...>(` construction, but not a
/// substring occurrence like `TokenResponse(` (ADR-0017 Amendment 1 A1-D5).
/// The negative lookbehind is the word boundary; the optional `<...>` group
/// accepts a type argument (including nested generics like
/// `Map<String, dynamic>`) between `Response` and the opening paren.
final _responseConstructionPattern = RegExp(
  r'(?<![A-Za-z0-9_])Response(<[^()]*>)?\(',
);

/// Matches an assignment (`=` or `??=`) into a `.data` member — e.g.
/// `e.response?.data = {...}` — but not a comparison (`.data ==`) or a read
/// into a local variable of the same name (`final data = e.response?.data;`,
/// which has no `.data` immediately followed by `=` — the `;` blocks it).
///
/// This closes the second forgery route `backendErrorEnvelopeOf` is exposed
/// to, found by code-critic (INF-20 round 1, M9): `Response.data` is a
/// plain mutable field (`T? data;`, not `final`), so a real, already-live
/// `DioException`'s response body can be overwritten in place and fed
/// straight back into the parser — no `Response(` construction, no
/// `displayMessage:`/`displayMessage =` token, and no record — needed at
/// all. `A1-D5`'s own reasoning ("the only way to forge an envelope is to
/// construct a fake `Response`") was **wrong**; this is the fix for that.
final _dataAssignmentPattern = RegExp(r'\.data\s*(?:=(?!=)|\?\?=)');

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

  /// The two write forms ADR-0017 Amendment 1 AC-3 names explicitly —
  /// `displayMessage:` (named constructor argument) and `displayMessage =`
  /// (plain assignment, e.g. a local variable someone names the same as the
  /// field to sneak a raw value past the colon-only pattern). Deliberately
  /// does **not** match the bare getter read `.displayMessage` — that form
  /// is what the two feature mappers legitimately do (D4 step 2 — relaying,
  /// not originating).
  bool hasDisplayMessageWriteForm(String content) =>
      content.contains('displayMessage:') ||
      content.contains('displayMessage =');

  test('the write-form `displayMessage:`/`displayMessage =` appears in lib/ '
      'only under lib/core/error/ (ADR-0017 Amendment 1, A1-D4 — supersedes '
      'the file-path allowlist this test used to check: since the public '
      'AuthException/CatalogException constructors no longer accept '
      'displayMessage as a named argument at all, there is no legitimate '
      "reason for either write-form to exist anywhere else in lib/). This "
      'bans only the *write* forms, not plain `.displayMessage` reads — the '
      'two feature mappers legitimately read it (they relay the field to '
      "resolveErrorDisplay(), they don't originate it — D4 step 2) and live "
      'under `presentation/`, not `core/error/`.', () {
    const scopeDir = 'lib/core/error/';
    final offenders = <String>[];
    final inScope = <String>[];
    for (final file in dartFiles) {
      final path = relPath(file);
      if (!hasDisplayMessageWriteForm(file.readAsStringSync())) continue;
      if (path.startsWith(scopeDir)) {
        inScope.add(path);
      } else {
        offenders.add(path);
      }
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'พบรูปเขียนค่า `displayMessage:`/`displayMessage =` นอก lib/core/error/ '
          '— ตั้งแต่ Amendment 1 ช่องนี้เติมได้ทางเดียวคือ AuthException.fromEnvelope / '
          'CatalogException.fromEnvelope ซึ่งนิยามอยู่ใน lib/core/error/ เท่านั้น '
          'การเห็นรูปเขียนค่านี้ที่อื่นแปลว่ามีคนพยายามตั้งค่ามันตรง ๆ อีกทางหนึ่ง\n'
          'จุดที่พบ:\n  ${offenders.join('\n  ')}',
    );

    // closed-world — ถ้า lib/core/error/ เองไม่มีรูปเขียนค่านี้เหลือเลย (เช่น
    // เปลี่ยนชื่อฟิลด์แล้วลืมแก้เทสนี้) เคสข้างบนจะผ่านฟรีทันทีโดยไม่ได้ตรวจ
    // อะไรจริง — ต้องยืนยันว่าขอบเขตที่อนุญาตยังมีของจริงอยู่ในนั้น
    expect(
      inScope,
      isNotEmpty,
      reason:
          'ไม่เจอรูปเขียนค่า displayMessage แม้แต่ใน lib/core/error/ เอง — '
          'เคสข้างบนน่าจะผ่านฟรี ไม่ได้ตรวจอะไรเลย',
    );
  });

  test('positive/negative control for the displayMessage write-form scan '
      'above — it must catch both a named-constructor-argument violation '
      'and a plain-assignment violation, and it must not falsely flag the '
      'legitimate `.displayMessage` getter read the two feature mappers '
      'make when relaying the field to resolveErrorDisplay() (a pattern '
      'that matched the getter form too would ban code D4 step 2 '
      'explicitly permits)', () {
    const namedArgumentViolation = 'displayMessage: rawSdkText,';
    const assignmentViolation = 'final displayMessage = e.message;';
    const legitimateGetterForm =
        'resolveErrorDisplay(e.displayMessage, code: e.code)';

    expect(
      hasDisplayMessageWriteForm(namedArgumentViolation),
      isTrue,
      reason: 'ต้องจับรูปที่เป็น named constructor argument ได้จริง',
    );
    expect(
      hasDisplayMessageWriteForm(assignmentViolation),
      isTrue,
      reason:
          'ต้องจับรูปที่เป็น plain assignment ได้ด้วย ไม่ใช่แค่รูป named argument',
    );
    expect(
      hasDisplayMessageWriteForm(legitimateGetterForm),
      isFalse,
      reason:
          'ต้องไม่ false-positive กับรูปอ่านค่าผ่าน getter (e.displayMessage) '
          'ซึ่งเป็นของถูกต้องใน mapper ทั้งสองไฟล์วันนี้',
    );
  });

  test('no construction of a `Response(` object anywhere in lib/ (ADR-0017 '
      'Amendment 1, A1-D2/A1-D5) — the only legal way into '
      '`backendErrorEnvelopeOf` is a real `DioException`; assembling a fake '
      '`Response` by hand and feeding it in would forge an envelope without '
      'ever talking to the backend', () {
    // Word boundary matters: lib/ has one legitimate occurrence of the
    // literal substring `Response(` today — `token_response.dart`'s
    // `const factory TokenResponse(` — which a naive
    // `contains('Response(')` would flag as an offender for no reason.
    // Must also match the generic form `Response<Map<String, dynamic>>(`,
    // not just the bare constructor call, or a mutant that adds a type
    // argument slips past.
    final offenders = <String>[];
    for (final file in dartFiles) {
      final path = relPath(file);
      if (_responseConstructionPattern.hasMatch(file.readAsStringSync())) {
        offenders.add(path);
      }
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'พบการประกอบ `Response(...)` ใน lib/ — ช่องทางเดียวที่ถูกต้องเข้า '
          'backendErrorEnvelopeOf คือ DioException จริงจาก Dio เท่านั้น\n'
          'จุดที่พบ:\n  ${offenders.join('\n  ')}',
    );
  });

  test('positive control for the Response( scan above — the word-boundary regex '
      'must still catch a real offending call (with and without a type '
      'argument), not just avoid false-flagging TokenResponse(, or it would be '
      'a regex that matches nothing and passes for free', () {
    expect(
      _responseConstructionPattern.hasMatch(
        'final r = Response(requestOptions: ro);',
      ),
      isTrue,
      reason: 'ต้องจับการประกอบ Response(...) แบบไม่มี type argument ได้',
    );
    expect(
      _responseConstructionPattern.hasMatch(
        'final r = Response<Map<String, dynamic>>(requestOptions: ro);',
      ),
      isTrue,
      reason: 'ต้องจับการประกอบ Response<...>(...) แบบมี type argument ได้ด้วย',
    );
    expect(
      _responseConstructionPattern.hasMatch(
        'const factory TokenResponse(String accessToken)',
      ),
      isFalse,
      reason:
          'ต้องไม่ false-positive กับ TokenResponse( ซึ่งเป็นของถูกต้องใน lib/ '
          'วันนี้ (token_response.dart:10)',
    );
  });

  test('no assignment into a `.data` member anywhere in lib/ (ADR-0017 '
      'Amendment 1 A1-D2, hardened after code-critic M9) — `Response.data` '
      'is a plain mutable field, so overwriting it on an already-live '
      '`DioException` and feeding that same exception back into '
      '`backendErrorEnvelopeOf` forges an envelope just as effectively as '
      'constructing a fake `Response`, without tripping the `Response(` scan '
      'above at all', () {
    final offenders = <String>[];
    for (final file in dartFiles) {
      final path = relPath(file);
      if (_dataAssignmentPattern.hasMatch(file.readAsStringSync())) {
        offenders.add(path);
      }
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'พบการเขียนทับ `.data` ใน lib/ — ช่องทางเดียวที่ถูกต้องเข้า '
          'backendErrorEnvelopeOf คือ response ของ DioException ตามที่ Dio '
          'ส่งมาจริง ไม่ใช่ response ที่ถูกแก้ค่าไปแล้ว\n'
          'จุดที่พบ:\n  ${offenders.join('\n  ')}',
    );
  });

  test('positive/negative control for the `.data` assignment scan above — '
      'must catch both `=` and `??=` forms of overwriting `.data`, and must '
      'not false-positive on a `.data ==` comparison or on reading `.data` '
      'into a local variable of the same name (both of which are ordinary, '
      'legitimate code)', () {
    expect(
      _dataAssignmentPattern.hasMatch(
        "e.response?.data = <String, dynamic>{'error_code': 'x'};",
      ),
      isTrue,
      reason: 'ต้องจับการเขียนทับด้วย = ได้',
    );
    expect(
      _dataAssignmentPattern.hasMatch("response.data ??= <String, dynamic>{};"),
      isTrue,
      reason: 'ต้องจับการเขียนทับด้วย ??= ได้ด้วย',
    );
    expect(
      _dataAssignmentPattern.hasMatch('if (response.data == expected) {'),
      isFalse,
      reason: 'ต้องไม่ false-positive กับการเทียบค่าด้วย ==',
    );
    expect(
      _dataAssignmentPattern.hasMatch('final data = e.response?.data;'),
      isFalse,
      reason:
          'ต้องไม่ false-positive กับการอ่านค่าเข้าตัวแปรชื่อ data ซึ่งเป็นโค้ด'
          'ปกติในไฟล์นี้เอง (backend_envelope.dart) และในหลายที่ของ lib/',
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

  test('BackendErrorEnvelope stays a class with a private constructor, not a '
      'record (ADR-0017 Amendment 1 A1-D3) — a record shape is structurally '
      'typed and can be forged by anyone with the right field names; a '
      'private (`._`) constructor is the one thing that is actually '
      "enforced by Dart's own language rules (library privacy), not by "
      'convention. code-critic proved the record form is forgeable at GATE 3 '
      '(INF-20 round 1, mutation M4) by switching the type and constructing '
      'one by hand — this test locks the *declaration shape itself* so that '
      'exact regression cannot land silently again.', () {
    const path = 'lib/core/error/backend_envelope.dart';
    final file = File(path);
    expect(file.existsSync(), isTrue, reason: '$path หายไป');
    final content = file.readAsStringSync();

    expect(
      content.contains('class BackendErrorEnvelope'),
      isTrue,
      reason:
          '$path ต้องประกาศ BackendErrorEnvelope เป็น class — เปลี่ยนเป็น '
          'typedef ของ record จะทำให้ประตูเดียวของ AC-2 กลายเป็นประตูที่ '
          'ล็อกไม่ได้ (A1-D3)',
    );
    expect(
      content.contains('BackendErrorEnvelope._('),
      isTrue,
      reason:
          '$path ต้องมี constructor ที่เป็น private (._) — เป็นกลไกเดียวที่ '
          'ทำให้ "ผลิตได้จาก backendErrorEnvelopeOf เท่านั้น" เป็นจริงจริง ๆ '
          'ไม่ใช่แค่คำอธิบายใน doc comment',
    );
  });

  test('positive control for the BackendErrorEnvelope shape scan above — '
      'proves the two literal checks actually discriminate the required '
      'class-with-private-constructor form from the record-typedef mutant '
      'that defeated the type gate at GATE 3, rather than being vacuously '
      'true for any file', () {
    const recordMutantSource = '''
import 'package:dio/dio.dart';

typedef BackendErrorEnvelope = (String, String?, String?);

BackendErrorEnvelope? backendErrorEnvelopeOf(DioException e) {
  final data = e.response?.data;
  if (data is Map && data['error_code'] is String) {
    return (data['error_code'] as String, data['message'] as String?, null);
  }
  return null;
}
''';

    expect(
      recordMutantSource.contains('class BackendErrorEnvelope'),
      isFalse,
      reason:
          'mutant ที่เปลี่ยนเป็น record ต้องไม่มี "class BackendErrorEnvelope" '
          'เหลืออยู่ — ถ้าเทสนี้ยังเห็นว่ามี แปลว่า string check ตัวนี้ไม่ได้ '
          'ตรวจอะไรจริง',
    );
    expect(
      recordMutantSource.contains('BackendErrorEnvelope._('),
      isFalse,
      reason:
          'mutant แบบเดียวกันต้องไม่มี BackendErrorEnvelope._( เหลืออยู่ด้วย',
    );
  });
}
