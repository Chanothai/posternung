// INF-40 step 1 — `docs/status/gates/INF-40-gate1.md` (workspace repo).
//
// This file proves six things about `StartupTrace`:
//   1. disabled → zero output (a negative assertion, not just "no crash")
//   2. enabled → every line matches the `t=<ms> event=<name> k=v ...`
//      contract, and `ms=` is a non-negative integer
//   3. every line's `t=` comes from one anchor — never goes backward
//   4. the closed-world of each wire enum is exactly what the gate plan
//      names, no more, no fewer (`GateDecisionVia` is five values as of
//      round 2 — see below)
//   5. the public API is *structurally* closed to `Object`/`dynamic`/`Map`/
//      free `String` — the GATE 1 security requirement ("the type system
//      rejects it, not caller discipline") — via a source scan in the same
//      style as `test/core/error_message_safety_test.dart`.
//   6. (round 2) `gateDecision`'s `data(null)` → `session_expiry` upgrade —
//      the correlation that has to live in `StartupTrace`, not the gate —
//      actually happens, and only on the branch it's supposed to.
//
// `debugEnabledOverride`/`debugSink` are the test-only seam `StartupTrace`
// exposes for exactly this file — see its class doc comment for why one is
// unavoidable (`kDebugMode` is `true` for the whole life of a `flutter test`
// process, so the real compile-time flag can never be driven `false` from a
// test). `debugReset()` (round 2) is the one call that clears all of the
// test-mutable static state this file owns, including the round-2 flag —
// added because two separate `= null` assignments in `tearDown` would have
// been easy to extend to two and forget the third.
//
// 🔴 Round 2 (coordinator correction, 2026-09-10): `via=session_expiry` was
// wired to the wrong branch in round 1 (see `GateDecisionVia`'s doc comment
// in `startup_trace.dart`) and `restore_end` dropped its always-`null`
// `status=` field entirely. Every test below reflects the corrected shape.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:posternung/core/diagnostics/startup_trace.dart';

/// True when [content] mentions any of `StartupTrace`'s three test-only
/// static seams — shared by the real `lib/` scan and its own
/// positive/negative control (test-quality §3.1: the previous scans in this
/// file each hand-rolled this exact "shared predicate" pattern already, for
/// the same reason — relaxing the real scan without also breaking its
/// control is the failure mode this guards against).
bool _referencesDebugSeam(String content) =>
    content.contains('debugEnabledOverride') ||
    content.contains('debugSink') ||
    content.contains('debugReset');

void main() {
  tearDown(StartupTrace.debugReset);

  group('disabled — no output at all (negative assertion)', () {
    test('every public method produces zero lines when disabled', () {
      StartupTrace.debugEnabledOverride = false;
      final lines = <String>[];
      StartupTrace.debugSink = lines.add;

      StartupTrace.gateInit();
      StartupTrace.gateDecision(
        dest: GateDecisionDestination.home,
        via: GateDecisionVia.dataUser,
      );
      StartupTrace.gateGoHome(mounted: true);
      StartupTrace.deadlineFired(mounted: false);
      final start = StartupTrace.restoreStart();
      StartupTrace.authMeSent(attempt: AuthMeAttempt.first);
      StartupTrace.restoreEnd(
        outcome: RestoreOutcome.user,
        elapsed: const Duration(milliseconds: 5),
      );
      StartupTrace.sessionExpiryFired();

      expect(
        lines,
        isEmpty,
        reason: 'disabled must not produce any line at all',
      );
      expect(
        start,
        0,
        reason: 'restoreStart() must not create/start the anchor when disabled',
      );
      expect(StartupTrace.elapsedMs(), 0);
    });
  });

  group('enabled — line shape matches the contract', () {
    late List<String> lines;

    setUp(() {
      StartupTrace.debugEnabledOverride = true;
      lines = <String>[];
      StartupTrace.debugSink = lines.add;
    });

    /// `t=<int>` at the start, `event=<name>` next, both mandatory; anything
    /// after is `k=v` pairs separated by single spaces.
    final lineShape = RegExp(r'^t=(\d+) event=([a-z_]+)( [a-z_]+=[^ ]+)*$');

    test('gate_init — no fields', () {
      StartupTrace.gateInit();
      expect(lines, hasLength(1));
      expect(lineShape.hasMatch(lines.single), isTrue, reason: lines.single);
      expect(lines.single, matches(RegExp(r'^t=\d+ event=gate_init$')));
    });

    test('gate_decision — dest and via in order', () {
      StartupTrace.gateDecision(
        dest: GateDecisionDestination.home,
        via: GateDecisionVia.dataUser,
      );
      expect(lineShape.hasMatch(lines.single), isTrue, reason: lines.single);
      expect(
        lines.single,
        matches(RegExp(r'^t=\d+ event=gate_decision dest=home via=data_user$')),
      );
    });

    test('gate_go_home — mounted=true and mounted=false', () {
      StartupTrace.gateGoHome(mounted: true);
      StartupTrace.gateGoHome(mounted: false);
      expect(
        lines[0],
        matches(RegExp(r'^t=\d+ event=gate_go_home mounted=true$')),
      );
      expect(
        lines[1],
        matches(RegExp(r'^t=\d+ event=gate_go_home mounted=false$')),
      );
    });

    test('deadline_fired — mounted=true and mounted=false', () {
      StartupTrace.deadlineFired(mounted: true);
      StartupTrace.deadlineFired(mounted: false);
      expect(
        lines[0],
        matches(RegExp(r'^t=\d+ event=deadline_fired mounted=true$')),
      );
      expect(
        lines[1],
        matches(RegExp(r'^t=\d+ event=deadline_fired mounted=false$')),
      );
    });

    test('restore_start — no fields, and returns the same t it logs', () {
      final start = StartupTrace.restoreStart();
      expect(lines.single, matches(RegExp(r'^t=(\d+) event=restore_start$')));
      final logged = int.parse(
        RegExp(r'^t=(\d+)').firstMatch(lines.single)!.group(1)!,
      );
      expect(start, logged);
    });

    test('auth_me_sent — attempt=first and attempt=retry', () {
      StartupTrace.authMeSent(attempt: AuthMeAttempt.first);
      StartupTrace.authMeSent(attempt: AuthMeAttempt.retry);
      expect(
        lines[0],
        matches(RegExp(r'^t=\d+ event=auth_me_sent attempt=first$')),
      );
      expect(
        lines[1],
        matches(RegExp(r'^t=\d+ event=auth_me_sent attempt=retry$')),
      );
    });

    test('restore_end — outcome and ms, in order, and (round 2) no '
        'status= field at all', () {
      StartupTrace.restoreEnd(
        outcome: RestoreOutcome.user,
        elapsed: const Duration(milliseconds: 42),
      );
      StartupTrace.restoreEnd(
        outcome: RestoreOutcome.nullNoToken,
        elapsed: Duration.zero,
      );
      expect(
        lines[0],
        matches(RegExp(r'^t=\d+ event=restore_end outcome=user ms=42$')),
      );
      expect(
        lines[1],
        matches(
          RegExp(r'^t=\d+ event=restore_end outcome=null_no_token ms=0$'),
        ),
      );
      expect(
        lines.any((l) => l.contains('status')),
        isFalse,
        reason:
            'round 2 dropped status= entirely — a field that could only '
            'ever read null was worse than no field',
      );
    });

    test(
      'restore_end — ms is never negative, even for a zero-length window',
      () {
        StartupTrace.restoreEnd(
          outcome: RestoreOutcome.user,
          elapsed: Duration.zero,
        );
        final ms = int.parse(
          RegExp(r'ms=(\d+)$').firstMatch(lines.single)!.group(1)!,
        );
        expect(ms, greaterThanOrEqualTo(0));
        expect(lines.single.contains('ms=-'), isFalse);
      },
    );

    test('session_expiry_fired — no fields', () {
      StartupTrace.sessionExpiryFired();
      expect(
        lines.single,
        matches(RegExp(r'^t=\d+ event=session_expiry_fired$')),
      );
    });
  });

  group('single anchor — t= never goes backward across events', () {
    test('a mixed sequence of calls produces non-decreasing t= values', () {
      StartupTrace.debugEnabledOverride = true;
      final lines = <String>[];
      StartupTrace.debugSink = lines.add;

      StartupTrace.gateInit();
      final start = StartupTrace.restoreStart();
      StartupTrace.authMeSent(attempt: AuthMeAttempt.first);
      StartupTrace.restoreEnd(
        outcome: RestoreOutcome.user,
        elapsed: Duration(milliseconds: StartupTrace.elapsedMs() - start),
      );
      StartupTrace.gateDecision(
        dest: GateDecisionDestination.home,
        via: GateDecisionVia.dataUser,
      );
      StartupTrace.gateGoHome(mounted: true);

      final ts = lines
          .map((l) => int.parse(RegExp(r'^t=(\d+)').firstMatch(l)!.group(1)!))
          .toList();
      expect(ts, hasLength(6));
      for (var i = 1; i < ts.length; i++) {
        expect(
          ts[i],
          greaterThanOrEqualTo(ts[i - 1]),
          reason: 't= at index $i (${ts[i]}) went backward from ${ts[i - 1]}',
        );
      }
    });
  });

  group(
    'closed-world — each wire enum is exactly the set the gate plan names',
    () {
      setUp(() {
        StartupTrace.debugEnabledOverride = true;
      });

      test('GateDecisionVia — exactly {data_user, data_null, '
          'session_expiry, deadline, session_error}, five values, no '
          'sixth (round 2 — was four, wrongly, in round 1)', () {
        expect(GateDecisionVia.values, hasLength(5));
        final wire = <String>{};
        for (final via in GateDecisionVia.values) {
          final lines = <String>[];
          StartupTrace.debugSink = lines.add;
          StartupTrace.gateDecision(
            dest: GateDecisionDestination.home,
            via: via,
          );
          wire.add(RegExp(r'via=(\w+)$').firstMatch(lines.single)!.group(1)!);
        }
        expect(wire, {
          'data_user',
          'data_null',
          'session_expiry',
          'deadline',
          'session_error',
        });
      });

      test('RestoreOutcome — exactly {user, null_no_token, null_infra, '
          'null_cleared}, four values, no fifth', () {
        expect(RestoreOutcome.values, hasLength(4));
        final wire = <String>{};
        for (final outcome in RestoreOutcome.values) {
          final lines = <String>[];
          StartupTrace.debugSink = lines.add;
          StartupTrace.restoreEnd(outcome: outcome, elapsed: Duration.zero);
          wire.add(
            RegExp(r'outcome=(\w+) ms').firstMatch(lines.single)!.group(1)!,
          );
        }
        expect(wire, {'user', 'null_no_token', 'null_infra', 'null_cleared'});
      });

      test('GateDecisionDestination — exactly {home, onboarding}', () {
        expect(GateDecisionDestination.values, hasLength(2));
        final wire = <String>{};
        for (final dest in GateDecisionDestination.values) {
          final lines = <String>[];
          StartupTrace.debugSink = lines.add;
          StartupTrace.gateDecision(dest: dest, via: GateDecisionVia.dataUser);
          wire.add(
            RegExp(r'dest=(\w+) via').firstMatch(lines.single)!.group(1)!,
          );
        }
        expect(wire, {'home', 'onboarding'});
      });

      test('AuthMeAttempt — exactly {first, retry}', () {
        expect(AuthMeAttempt.values, hasLength(2));
        final wire = <String>{};
        for (final attempt in AuthMeAttempt.values) {
          final lines = <String>[];
          StartupTrace.debugSink = lines.add;
          StartupTrace.authMeSent(attempt: attempt);
          wire.add(
            RegExp(r'attempt=(\w+)$').firstMatch(lines.single)!.group(1)!,
          );
        }
        expect(wire, {'first', 'retry'});
      });
    },
  );

  group('round 2 — gateDecision correlates data(null) with a prior '
      'session_expiry_fired, and the gate itself never has to know', () {
    late List<String> lines;

    setUp(() {
      StartupTrace.debugEnabledOverride = true;
      lines = <String>[];
      StartupTrace.debugSink = lines.add;
    });

    test('no session_expiry_fired yet → dataNull stays via=data_null', () {
      StartupTrace.gateDecision(
        dest: GateDecisionDestination.onboarding,
        via: GateDecisionVia.dataNull,
      );
      expect(
        lines.single,
        matches(RegExp(r'event=gate_decision dest=onboarding via=data_null$')),
      );
    });

    test('session_expiry_fired happened first → the *same* call site '
        'passing via: dataNull comes out as via=session_expiry — the '
        'upgrade the gate itself cannot do', () {
      StartupTrace.sessionExpiryFired();
      lines.clear(); // only inspecting the gate_decision line below
      StartupTrace.gateDecision(
        dest: GateDecisionDestination.onboarding,
        via: GateDecisionVia.dataNull,
      );
      expect(
        lines.single,
        matches(
          RegExp(r'event=gate_decision dest=onboarding via=session_expiry$'),
        ),
      );
    });

    test('the error: branch reports via=session_error and is never '
        'upgraded by a prior session_expiry_fired — the two are unrelated '
        'branches even though round 1 conflated them', () {
      StartupTrace.sessionExpiryFired();
      lines.clear();
      StartupTrace.gateDecision(
        dest: GateDecisionDestination.onboarding,
        via: GateDecisionVia.sessionError,
      );
      expect(
        lines.single,
        matches(
          RegExp(r'event=gate_decision dest=onboarding via=session_error$'),
        ),
      );
    });

    test('via=data_user is never upgraded by session_expiry_fired — the '
        'correlation only ever touches dataNull', () {
      StartupTrace.sessionExpiryFired();
      lines.clear();
      StartupTrace.gateDecision(
        dest: GateDecisionDestination.home,
        via: GateDecisionVia.dataUser,
      );
      expect(
        lines.single,
        matches(RegExp(r'event=gate_decision dest=home via=data_user$')),
      );
    });

    test('debugReset() clears the correlation flag along with the sink/'
        'override — a leftover session_expiry_fired from a previous test '
        'must not bleed into this one', () {
      StartupTrace.sessionExpiryFired();
      StartupTrace.debugReset();
      StartupTrace.debugEnabledOverride = true;
      final freshLines = <String>[];
      StartupTrace.debugSink = freshLines.add;

      StartupTrace.gateDecision(
        dest: GateDecisionDestination.onboarding,
        via: GateDecisionVia.dataNull,
      );

      expect(
        freshLines.single,
        matches(RegExp(r'via=data_null$')),
        reason:
            'debugReset() must clear the flag — if it leaked, this would '
            'read via=session_expiry instead',
      );
    });
  });

  group('GATE 1 security requirement — the public API cannot accept a '
      'session/user/raw-string payload by construction, not by convention', () {
    late String source;

    setUpAll(() {
      final file = File('lib/core/diagnostics/startup_trace.dart');
      expect(
        file.existsSync(),
        isTrue,
        reason: 'ต้องรันเทสจาก root ของ package (ที่เดียวกับ pubspec.yaml)',
      );
      source = file.readAsStringSync();
    });

    /// Every `required <Type> name` parameter declared anywhere in the file
    /// — deliberately not scoped to one method, so a new event method added
    /// later is covered automatically. Every meaningful parameter on every
    /// public event method uses `required`, so this single scan covers the
    /// whole public surface without needing to hand-parse each method's
    /// parameter list separately.
    final requiredParamPattern = RegExp(
      r'required\s+([A-Za-z_][A-Za-z0-9_]*(?:<[^()]*>)?\??)\s+\w+',
    );

    const allowedTypes = {
      'GateDecisionDestination',
      'GateDecisionVia',
      'bool',
      'AuthMeAttempt',
      'RestoreOutcome',
      'Duration',
    };

    test('every `required` parameter type in the file is one of the '
        'allowed closed set (enum / bool / Duration) — no `Object`, '
        '`dynamic`, `Map`, `String`, `int`, or a domain type like '
        '`AuthUser` (round 2 dropped `int?` along with `status=`)', () {
      final types = requiredParamPattern
          .allMatches(source)
          .map((m) => m.group(1)!)
          .toList();

      // Vacuous-pass guard (test-quality §4) — if this ever hits zero, the
      // scan below would pass for free without checking anything.
      expect(
        types,
        isNotEmpty,
        reason: 'สแกนไม่เจอ required parameter เลย — เคสข้างล่างจะผ่านฟรี',
      );
      expect(
        types,
        hasLength(7),
        reason:
            'คาดว่ามี required parameter รวม 7 ตัวข้าม 5 event method '
            '(gateDecision×2, gateGoHome×1, deadlineFired×1, authMeSent×1, '
            'restoreEnd×2 — ลดจาก 3 เหลือ 2 ตอนถอด status=) — จำนวนไม่ตรงแปลว่ามี '
            'event ใหม่โผล่มาโดยไม่ถูกสแกนคลุม หรือสแกนเก่าไม่ครอบ ต้องอัปเดตเทสนี้'
            'อย่างตั้งใจ ไม่ใช่ปล่อยผ่าน\n$types',
      );

      final offenders = types.where((t) => !allowedTypes.contains(t)).toList();
      expect(
        offenders,
        isEmpty,
        reason:
            'พบ required parameter ที่ type ไม่อยู่ใน allowlist: $offenders — '
            'ทุก parameter ที่ trace formatter รับต้องเป็น enum ปิดของไฟล์นี้เอง / '
            'bool / Duration เท่านั้น ไม่รับ Object/dynamic/Map/String เสรี/'
            'session object ใด ๆ',
      );
    });

    test('positive/negative control for the `required` scan above — it '
        'must flag a fabricated `Object`/`dynamic`/`Map` parameter and must '
        'not false-positive on this file\'s own prose mentioning those '
        'words (e.g. "no `Object`/`dynamic` parameter")', () {
      const objectMutant = 'static void x({required Object payload}) {}';
      const dynamicMutant = 'static void x({required dynamic payload}) {}';
      const mapMutant = 'static void x({required Map<String, Object?> f}) {}';
      const proseThatMentionsBothWords =
          '/// no `Object`/`dynamic` parameter, and no `Map` on the path';

      String? typeOf(String snippet) =>
          requiredParamPattern.firstMatch(snippet)?.group(1);

      expect(
        typeOf(objectMutant),
        'Object',
        reason: 'ต้องจับ required Object ได้',
      );
      expect(
        typeOf(dynamicMutant),
        'dynamic',
        reason: 'ต้องจับ required dynamic ได้',
      );
      expect(
        typeOf(mapMutant),
        'Map<String, Object?>',
        reason:
            'ต้องจับ required Map<...> ได้ทั้ง generic ไม่ใช่แค่คำว่า Map เฉย ๆ',
      );
      expect(
        typeOf(proseThatMentionsBothWords),
        isNull,
        reason:
            'ต้องไม่ false-positive กับ comment ที่แค่พูดถึงคำว่า Object/dynamic '
            'โดยไม่ได้ประกาศ parameter จริง (ไฟล์จริงมีประโยคแบบนี้ในตัวเอง)',
      );
    });

    // ‹แก้ 2026-09-10› เดิมคาด 2 import (dart:developer + foundation) ·
    // `dart:developer` ถูกถอดออกหลังพิสูจน์บนเครื่องว่า log() ไปไม่ถึงทั้ง
    // logcat และ flutter run console — ตอนนี้เหลือ foundation ตัวเดียว
    // (debugPrint) · จำนวนที่คาดต้องตามของจริง ไม่ใช่ค้างไว้ที่เลขเดิม
    test('no import of a session/user/network type — the file only imports '
        'package:flutter/foundation.dart', () {
      final importLines = source
          .split('\n')
          .where((l) => l.trim().startsWith('import '))
          .toList();
      expect(importLines, hasLength(1), reason: importLines.join('\n'));
      expect(
        importLines.any(
          (l) =>
              l.contains('auth_user') ||
              l.contains('backend_user') ||
              l.contains('session_provider') ||
              l.contains('flutter_riverpod') ||
              l.contains('dio') ||
              l.contains('firebase'),
        ),
        isFalse,
        reason: 'พบ import ที่พาข้อมูล session/user/network เข้ามาในไฟล์ trace',
      );
    });

    test('no literal reference to AuthUser/BackendUser/Map< anywhere in the '
        'file, not just in parameter position — closes the gap the '
        '`required`-only scan above cannot see on its own (a private '
        'helper or a non-`required` parameter would slip past it)', () {
      expect(source.contains('AuthUser'), isFalse);
      expect(source.contains('BackendUser'), isFalse);
      expect(source.contains('Map<'), isFalse);
      expect(source.contains('Map ('), isFalse);
    });
  });

  group('round 2 — debugEnabledOverride/debugSink are structurally '
      'confined to this one file (closed-world over lib/)', () {
    late List<File> libDartFiles;

    setUpAll(() {
      final libDir = Directory('lib');
      expect(
        libDir.existsSync(),
        isTrue,
        reason: 'ต้องรันเทสจาก root ของ package (ที่เดียวกับ pubspec.yaml)',
      );
      libDartFiles = libDir
          .listSync(recursive: true)
          .whereType<File>()
          .where(
            (f) =>
                f.path.endsWith('.dart') &&
                !f.path.endsWith('.freezed.dart') &&
                !f.path.endsWith('.g.dart'),
          )
          .toList();
      expect(libDartFiles, isNotEmpty);
    });

    String relPath(File f) =>
        f.path.replaceAll('\\', '/').replaceFirst(RegExp(r'^\./'), '');

    const ownerFile = 'lib/core/diagnostics/startup_trace.dart';

    test('no file under lib/ other than startup_trace.dart itself '
        'references debugEnabledOverride, debugSink, or debugReset — '
        'these are test-only seams and must not become a way for '
        'production code to silence or spoof the trace', () {
      final offenders = <String>[];
      for (final file in libDartFiles) {
        final path = relPath(file);
        if (path == ownerFile) continue;
        if (_referencesDebugSeam(file.readAsStringSync())) {
          offenders.add(path);
        }
      }
      expect(
        offenders,
        isEmpty,
        reason:
            'พบการอ้าง debugEnabledOverride/debugSink/debugReset นอก '
            '$ownerFile — ช่องทางนี้มีไว้ให้เทสเท่านั้น โค้ด production ต้องไม่แตะ\n'
            'จุดที่พบ:\n  ${offenders.join('\n  ')}',
      );
    });

    test('positive/negative control for _referencesDebugSeam above — must '
        'catch each of the three seam names individually, and must not '
        'false-positive on ordinary code that mentions neither', () {
      expect(
        _referencesDebugSeam('StartupTrace.debugEnabledOverride = false;'),
        isTrue,
        reason: 'ต้องจับ debugEnabledOverride ได้',
      );
      expect(
        _referencesDebugSeam('StartupTrace.debugSink = print;'),
        isTrue,
        reason: 'ต้องจับ debugSink ได้',
      );
      expect(
        _referencesDebugSeam('StartupTrace.debugReset();'),
        isTrue,
        reason: 'ต้องจับ debugReset ได้',
      );
      expect(
        _referencesDebugSeam('StartupTrace.gateInit();'),
        isFalse,
        reason:
            'ต้องไม่ false-positive กับการเรียก event ปกติที่ไม่แตะ seam เลย',
      );
    });

    test('startup_trace.dart itself is the one file allowed to reference '
        'these — a scan that finds zero references anywhere would mean '
        'the scan above is vacuous (nothing to exempt)', () {
      final ownerSource = libDartFiles
          .firstWhere((f) => relPath(f) == ownerFile)
          .readAsStringSync();
      expect(ownerSource.contains('debugEnabledOverride'), isTrue);
      expect(ownerSource.contains('debugSink'), isTrue);
      expect(ownerSource.contains('debugReset'), isTrue);
    });
  });
}
