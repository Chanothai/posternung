import 'package:flutter_test/flutter_test.dart';
import 'package:posternung/core/error/auth_exception.dart';
import 'package:posternung/core/strings/app_strings.dart';
import 'package:posternung/features/auth/presentation/auth_error_display.dart';

void main() {
  group('authErrorDisplay', () {
    test(
      'maps a known Firebase code to a Thai message and echoes the code',
      () {
        final display = authErrorDisplay(
          const AuthException(code: 'wrong-password'),
        );

        expect(display.message, AppStrings.authErrorWrongPassword);
        expect(display.code, 'wrong-password');
      },
    );

    test("the feature's code table wins even when displayMessage is also set "
        '— ADR-0017 D4\'s step order is fixed, not "whichever is present"', () {
      final display = authErrorDisplay(
        const AuthException(
          code: 'wrong-password',
          displayMessage: 'ข้อความจาก backend ที่ไม่ควรถูกใช้ตรงนี้',
        ),
      );

      expect(display.message, AppStrings.authErrorWrongPassword);
    });

    test('passes the backend envelope displayMessage through when the code '
        "isn't in the feature's table", () {
      // Backend AppError → `{error_code, message}` (message already Thai).
      final display = authErrorDisplay(
        const AuthException(
          code: 'INVALID_CREDENTIALS',
          displayMessage: 'อีเมลหรือรหัสผ่านไม่ถูกต้อง',
        ),
      );

      expect(display.message, 'อีเมลหรือรหัสผ่านไม่ถูกต้อง');
      expect(display.code, 'INVALID_CREDENTIALS');
    });

    test('falls back to the generic Thai message when displayMessage is '
        'null (ADR-0017 D1 — no more English-sentinel workaround, there is '
        'simply nothing to show)', () {
      final display = authErrorDisplay(
        const AuthException(code: 'missing_id_token'),
      );

      expect(display.message, AppStrings.authErrorGeneric);
      expect(display.code, 'missing_id_token');
    });

    test('falls back to the generic Thai message for an empty/blank '
        'displayMessage', () {
      final display = authErrorDisplay(
        const AuthException(code: 'weird', displayMessage: '   '),
      );

      expect(display.message, AppStrings.authErrorGeneric);
      expect(display.code, 'weird');
    });

    test('maps the transport-level network_error/server_error codes thrown '
        'by BackendAuthDataSource/AuthRepositoryImpl to Thai, not just '
        'Firebase codes', () {
      expect(
        authErrorDisplay(const AuthException(code: 'network_error')).message,
        AppStrings.authErrorNetwork,
      );
      expect(
        authErrorDisplay(const AuthException(code: 'server_error')).message,
        AppStrings.authErrorServer,
      );
    });

    test('maps phone-auth Firebase codes to Thai instead of falling through '
        "to a generic line", () {
      final invalidCode = authErrorDisplay(
        const AuthException(code: 'invalid-verification-code'),
      );
      expect(invalidCode.message, AppStrings.authErrorInvalidVerificationCode);

      final invalidNumber = authErrorDisplay(
        const AuthException(code: 'invalid-phone-number'),
      );
      expect(invalidNumber.message, AppStrings.authErrorInvalidPhoneNumber);

      final quota = authErrorDisplay(
        const AuthException(code: 'quota-exceeded'),
      );
      expect(quota.message, AppStrings.authErrorQuotaExceeded);
    });

    test('maps account-exists-with-different-credential (social sign-in) to '
        'Thai instead of the raw English code', () {
      final display = authErrorDisplay(
        const AuthException(code: 'account-exists-with-different-credential'),
      );

      expect(
        display.message,
        AppStrings.authErrorAccountExistsWithDifferentCredential,
      );
      expect(display.code, 'account-exists-with-different-credential');
    });

    test('never surfaces debugDetail — it is not a parameter this function can '
        'read at all (ADR-0017 D7)', () {
      final display = authErrorDisplay(
        const AuthException(
          code: 'weird',
          debugDetail: 'raw SDK text that must never reach the screen',
        ),
      );

      expect(display.message, isNot(contains('raw SDK text')));
      expect(display.message, AppStrings.authErrorGeneric);
    });
  });

  group('authErrorDisplayFor', () {
    test('returns null when there is nothing to show', () {
      expect(authErrorDisplayFor(null), isNull);
    });

    test('delegates to authErrorDisplay for an AuthException', () {
      final display = authErrorDisplayFor(
        const AuthException(code: 'wrong-password'),
      );

      expect(display, isNotNull);
      expect(display!.message, AppStrings.authErrorWrongPassword);
      expect(display.code, 'wrong-password');
    });

    test('shows the fixed code `unhandled_error` — not the runtime type — for '
        'anything that is not an AuthException (ADR-0017 OD-1). Every '
        'data-source guard is supposed to wrap failures into an AuthException '
        "before they reach state, so this case is itself a bug; it must "
        'still show *something* diagnosable rather than a code-less generic '
        'line that looks identical to "everything is fine" — but the '
        'diagnostic detail (the real type) goes to the debug log, not the '
        'screen. This reverses the app\'s original decision on this exact '
        'line (which rendered `error.runtimeType` directly) — D6 forbids a '
        'runtime-composed string reaching the screen, full stop, and that '
        "includes this fallback path.", () {
      final display = authErrorDisplayFor(StateError('boom'));

      expect(display, isNotNull);
      expect(display!.message, AppStrings.authErrorGeneric);
      expect(display.code, 'unhandled_error');
      expect(display.code, isNot(contains('StateError')));
    });
  });
}
