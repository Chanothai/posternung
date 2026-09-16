// SCR-07 AC-2 / NFR-02 — checkout/profile PII must never touch local
// persistence of any kind, encrypted or not: "ต้องไม่มี local persistence
// เลย" is stricter than "must be encrypted if stored", so this test bans the
// storage mechanisms outright rather than checking how they're used.
//
// Shaped after `test/features/poster/verification_fields_not_wired_test.dart`
// — a plain text scan over source files, not an AST check, run from CI on
// every build rather than relying on a reviewer noticing.
//
// Two independent guarantees live here:
//   1. No file under `lib/features/checkout/` or `lib/features/profile/`
//      imports a local-persistence package/API at all.
//   2. `CheckoutState`/`CheckoutFlowState` never grow a `ShippingAddress`
//      field — the form's values must live only in the screen's own
//      `TextEditingController`s (per those files' own doc comments).

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Tokens that would appear literally in an `import` line for any of the
/// local-persistence mechanisms this app could reach for. `token_storage.dart`
/// is this app's own secure-storage wrapper (`core/network/token_storage.dart`,
/// `flutter_secure_storage` underneath) — banned by name here because
/// `flutter_secure_storage` alone wouldn't catch a checkout/profile file that
/// imported the wrapper instead of the package directly.
const List<String> _forbiddenImportTokens = <String>[
  'package:shared_preferences',
  'package:flutter_secure_storage',
  'package:hive',
  'package:sqflite',
  'package:path_provider',
  'dart:io',
  'token_storage.dart',
];

bool _importsForbiddenStorage(String source) =>
    _forbiddenImportTokens.any(source.contains);

/// Deliberately narrow — a type name immediately followed by an identifier
/// and then either `=` (an initializer) or `;` (no initializer) — so it
/// matches a genuine field declaration (`final ShippingAddress? draft;` or
/// `final ShippingAddress? draft = null;`) without matching the doc-comment
/// prose both target files already contain, at length, *about* not holding
/// a shipping address.
///
/// F8 — widened from `;`-only: the original pattern required the `;` to sit
/// directly after the identifier, so a field declared *with* an initializer
/// (`= null`, `= someDefault`) sat between the name and the `;` and slipped
/// past undetected. `(=|;)` catches a field declaration either way.
final RegExp _shippingAddressFieldPattern = RegExp(
  r'ShippingAddress\??\s+\w+\s*(=|;)',
);

const List<String> _scannedDirs = <String>[
  'lib/features/checkout',
  'lib/features/profile',
];

const List<String> _flowStateFiles = <String>[
  'lib/features/checkout/presentation/state/checkout_state.dart',
  'lib/features/checkout/presentation/providers/checkout_flow_provider.dart',
];

List<File> _dartFilesUnder(String dirPath) {
  final dir = Directory(dirPath);
  if (!dir.existsSync()) return const [];
  return dir
      .listSync(recursive: true)
      .whereType<File>()
      .where((entity) => entity.path.endsWith('.dart'))
      .toList();
}

void main() {
  test('sanity: checkout/ and profile/ actually have .dart files to scan — a '
      'closed-world check over an empty tree would prove nothing', () {
    for (final dirPath in _scannedDirs) {
      expect(
        Directory(dirPath).existsSync(),
        isTrue,
        reason: 'ต้องรันเทสจาก root ของ package (ที่เดียวกับ pubspec.yaml)',
      );
      expect(
        _dartFilesUnder(dirPath),
        isNotEmpty,
        reason: '$dirPath ไม่มีไฟล์ .dart เลย — เทสนี้จะไม่พิสูจน์อะไร',
      );
    }
  });

  group(
    '_importsForbiddenStorage — positive/negative control (test-quality §3.1 '
    "— prove the predicate can actually fail before trusting it on real files)",
    () {
      test('flags a genuine secure-storage import', () {
        expect(
          _importsForbiddenStorage(
            "import 'package:flutter_secure_storage/flutter_secure_storage.dart';",
          ),
          isTrue,
        );
      });

      test('flags this app\'s own token-storage wrapper by filename', () {
        expect(
          _importsForbiddenStorage(
            "import '../../../../core/network/token_storage.dart';",
          ),
          isTrue,
        );
      });

      test('does not flag ordinary, unrelated imports', () {
        expect(
          _importsForbiddenStorage(
            "import 'package:flutter/material.dart';\n"
            "import '../../../../core/strings/app_strings.dart';\n"
            "import 'dart:async';",
          ),
          isFalse,
        );
      });
    },
  );

  test(
    'no file under lib/features/checkout/ or lib/features/profile/ imports '
    'local persistence of any kind (SCR-07 AC-2, NFR-02 — OWASP Mobile M2)',
    () {
      final offenders = <String>[];
      for (final dirPath in _scannedDirs) {
        for (final file in _dartFilesUnder(dirPath)) {
          if (_importsForbiddenStorage(file.readAsStringSync())) {
            offenders.add(file.path);
          }
        }
      }
      expect(
        offenders,
        isEmpty,
        reason:
            'พบการ import local persistence ใต้ checkout/ หรือ profile/ — '
            'SCR-07 AC-2 ห้ามเก็บที่อยู่/ข้อมูลส่วนตัวแบบ local ทุกชนิด '
            '(เข้ารหัสหรือไม่ก็ตาม — ข้อบังคับคือ "ห้ามมี" ไม่ใช่ "ต้องเข้ารหัสถ้ามี")\n'
            'จุดที่พบ:\n  ${offenders.join('\n  ')}',
      );
    },
  );

  group('ShippingAddress field-declaration pattern — positive/negative control '
      '(test-quality §3.1)', () {
    test('matches a genuine field declaration', () {
      expect(
        _shippingAddressFieldPattern.hasMatch('final ShippingAddress? draft;'),
        isTrue,
      );
      expect(
        _shippingAddressFieldPattern.hasMatch(
          'final ShippingAddress recipientAddress;',
        ),
        isTrue,
      );
      // F8 — the case the widened `(=|;)` alternation exists for: a field
      // declared with an initializer, where the old `;`-only pattern found
      // nothing because `= null` sits between the identifier and the `;`.
      // Mutation-verified: reverting to the old `ShippingAddress\??\s+\w+\s*;`
      // pattern turns this specific expectation red while every other test
      // in this file stays green — that is what proves this case, not the
      // others, is what the widening was for.
      expect(
        _shippingAddressFieldPattern.hasMatch(
          'final ShippingAddress? draft = null;',
        ),
        isTrue,
      );
    });

    test('does not match doc-comment prose that merely discusses '
        'shipping addresses', () {
      expect(
        _shippingAddressFieldPattern.hasMatch(
          '/// 🔴 Deliberately carries **no shipping address field** '
          '(SCR-07 AC-2) — the form\'s values live only in the screen\'s '
          'own `TextEditingController`s.',
        ),
        isFalse,
      );
    });
  });

  test('checkout_state.dart and checkout_flow_provider.dart declare no '
      'ShippingAddress field (SCR-07 AC-2 — the address form only ever lives '
      "in the screen's own TextEditingControllers, never in state that "
      'survives leaving and returning to /checkout)', () {
    final offenders = <String>[];
    for (final path in _flowStateFiles) {
      final file = File(path);
      expect(
        file.existsSync(),
        isTrue,
        reason: '$path หายไป — เทสนี้ผูกกับไฟล์จริง ไม่ใช่สแกนทั้งโฟลเดอร์',
      );
      if (_shippingAddressFieldPattern.hasMatch(file.readAsStringSync())) {
        offenders.add(path);
      }
    }
    expect(
      offenders,
      isEmpty,
      reason:
          'พบฟิลด์ชนิด ShippingAddress ใน state/flow ของ checkout — SCR-07 AC-2 '
          'ห้ามเก็บที่อยู่ไว้ในสถานะที่มีชีวิตยาวกว่าฟอร์มบนจอ\n'
          'จุดที่พบ:\n  ${offenders.join('\n  ')}',
    );
  });
}
