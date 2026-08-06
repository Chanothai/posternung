// ADR-0017 OD-2 — locks the two token-log closures shut. Same source-scan
// style as `test/core/error_message_safety_test.dart` (ADR-0017 D10) and
// `test/features/poster/verification_fields_not_wired_test.dart` (ADR-0014
// D5.1) — a text scan, not an AST check, so it proves the specific
// regression it names doesn't come back, not that no token can ever reach a
// log line by some other route. See `project-gotchas` §3.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _apiClientPath = 'lib/core/network/api_client.dart';
const _backendSessionProviderPath =
    'lib/features/auth/presentation/providers/backend_session_provider.dart';

void main() {
  test("api_client.dart's debug-only PrettyDioLogger has every header/body "
      'flag off — not just requestHeader. Tokens on this client travel in '
      'request/response *bodies* too (POST /auth/firebase, /auth/refresh, '
      '/auth/logout), so requestBody/responseBody must be off as well, '
      'kDebugMode guard or not (security-baseline §2)', () {
    final file = File(_apiClientPath);
    expect(
      file.existsSync(),
      isTrue,
      reason: '$_apiClientPath หายไป — แก้ path ในเทสนี้',
    );
    final source = file.readAsStringSync();

    for (final flag in [
      'requestHeader',
      'requestBody',
      'responseHeader',
      'responseBody',
    ]) {
      expect(
        source,
        contains('$flag: false'),
        reason:
            '$_apiClientPath ไม่มี "$flag: false" — PrettyDioLogger ต้องปิด '
            'ครบทั้ง 4 ช่องนี้ (ADR-0017 OD-2)',
      );
      expect(
        source,
        isNot(contains('$flag: true')),
        reason:
            '$_apiClientPath มี "$flag: true" — ช่องนี้ต้องปิดเสมอ ไม่ว่าจะอยู่ใน '
            'kDebugMode guard หรือไม่ก็ตาม (ADR-0017 OD-2 / security-baseline §2)',
      );
    }
  });

  test('backend_session_provider.dart never logs a raw token — the exact '
      'regression this locks: `developer.log(idToken, ...)` used to print the '
      'whole Firebase ID token to the debug console on every sign-in', () {
    final file = File(_backendSessionProviderPath);
    expect(
      file.existsSync(),
      isTrue,
      reason: '$_backendSessionProviderPath หายไป — แก้ path ในเทสนี้',
    );
    final source = file.readAsStringSync();

    final tokenLogPattern = RegExp(
      r'developer\.log\(\s*(idToken|accessToken|refreshToken)\b',
    );
    expect(
      tokenLogPattern.hasMatch(source),
      isFalse,
      reason:
          'พบ developer.log(...) ที่รับตัวแปร token เป็น argument แรกตรง ๆ ใน '
          '$_backendSessionProviderPath — ต้องไม่ log token แม้ใน debug build '
          '(ADR-0017 OD-2 / security-baseline §2)',
    );
  });
}
