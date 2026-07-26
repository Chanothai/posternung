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
          const AuthException(
            code: 'wrong-password',
            message: 'The password is invalid.',
          ),
        );

        expect(display.message, AppStrings.authErrorWrongPassword);
        expect(display.code, 'wrong-password');
      },
    );

    test('passes the backend envelope Thai message through as-is', () {
      // Backend AppError → `{error_code, message}` (message already Thai).
      final display = authErrorDisplay(
        const AuthException(
          code: 'INVALID_CREDENTIALS',
          message: 'อีเมลหรือรหัสผ่านไม่ถูกต้อง',
        ),
      );

      expect(display.message, 'อีเมลหรือรหัสผ่านไม่ถูกต้อง');
      expect(display.code, 'INVALID_CREDENTIALS');
    });

    test('falls back to the generic Thai message for the English generic', () {
      final display = authErrorDisplay(
        const AuthException(
          code: 'missing_id_token',
          message: AppStrings.authGenericErrorMessage,
        ),
      );

      expect(display.message, AppStrings.authErrorGeneric);
      expect(display.code, 'missing_id_token');
    });

    test('falls back to the generic Thai message for an empty message', () {
      final display = authErrorDisplay(
        const AuthException(code: 'weird', message: ''),
      );

      expect(display.message, AppStrings.authErrorGeneric);
      expect(display.code, 'weird');
    });

    test('maps phone-auth Firebase codes to Thai instead of falling through '
        'to Firebase\'s raw English message', () {
      final invalidCode = authErrorDisplay(
        const AuthException(
          code: 'invalid-verification-code',
          message: 'The SMS verification code used has expired.',
        ),
      );
      expect(invalidCode.message, AppStrings.authErrorInvalidVerificationCode);

      final invalidNumber = authErrorDisplay(
        const AuthException(
          code: 'invalid-phone-number',
          message: 'The format of the phone number provided is incorrect.',
        ),
      );
      expect(invalidNumber.message, AppStrings.authErrorInvalidPhoneNumber);

      final quota = authErrorDisplay(
        const AuthException(
          code: 'quota-exceeded',
          message: 'The SMS quota for this project has been exceeded.',
        ),
      );
      expect(quota.message, AppStrings.authErrorQuotaExceeded);
    });
  });
}
