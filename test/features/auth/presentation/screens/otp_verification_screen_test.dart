import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:posternung/core/error/auth_exception.dart';
import 'package:posternung/core/strings/app_strings.dart';
import 'package:posternung/features/auth/data/datasources/phone_sign_in_data_source.dart';
import 'package:posternung/features/auth/presentation/providers/auth_providers.dart';
import 'package:posternung/features/auth/presentation/screens/otp_verification_screen.dart';

class FakeAuthViewModel extends AuthViewModel {
  FakeAuthViewModel({
    this.errorToThrow,
    this.confirmPhoneCodeErrorToThrow,
    this.onConfirmPhoneCode,
    this.onSendPhoneCode,
    this.resendResult,
  });

  final Object? errorToThrow;
  final Object? confirmPhoneCodeErrorToThrow;
  final void Function(String verificationId, String smsCode)?
  onConfirmPhoneCode;
  final void Function(String phoneNumber, int? resendToken)? onSendPhoneCode;
  final PhoneVerificationResult? resendResult;

  @override
  FutureOr<void> build() {
    final error = errorToThrow;
    if (error != null) throw error;
    return null;
  }

  @override
  Future<void> signIn({
    required String email,
    required String password,
  }) async {}

  @override
  Future<void> signUp({
    required String email,
    required String password,
  }) async {}

  @override
  Future<void> signInWithGoogle() async {}

  @override
  Future<void> signInWithApple() async {}

  @override
  Future<PhoneVerificationResult?> sendPhoneCode(
    String phoneNumber, {
    int? resendToken,
  }) async {
    onSendPhoneCode?.call(phoneNumber, resendToken);
    return resendResult;
  }

  @override
  Future<void> confirmPhoneCode({
    required String verificationId,
    required String smsCode,
  }) async {
    onConfirmPhoneCode?.call(verificationId, smsCode);
    final error = confirmPhoneCodeErrorToThrow;
    // Mirror what the real method does via `AsyncValue.guard` — set `state`
    // rather than throw, so `authState.error` actually reflects the failure
    // (the widget under test reacts to `state`, not to this call throwing).
    state = error != null
        ? AsyncError(error, StackTrace.current)
        : const AsyncData(null);
  }
}

void main() {
  const testPhoneNumber = '+66812345678';
  const testVerificationId = 'test-verification-id';

  Widget wrap({
    Object? errorToThrow,
    Object? confirmPhoneCodeErrorToThrow,
    void Function(String verificationId, String smsCode)? onConfirmPhoneCode,
    void Function(String phoneNumber, int? resendToken)? onSendPhoneCode,
    PhoneVerificationResult? resendResult,
    int? resendToken,
  }) {
    return ProviderScope(
      overrides: [
        authViewModelProvider.overrideWith(
          () => FakeAuthViewModel(
            errorToThrow: errorToThrow,
            confirmPhoneCodeErrorToThrow: confirmPhoneCodeErrorToThrow,
            onConfirmPhoneCode: onConfirmPhoneCode,
            onSendPhoneCode: onSendPhoneCode,
            resendResult: resendResult,
          ),
        ),
      ],
      child: MaterialApp(
        home: OtpVerificationScreen(
          phoneNumber: testPhoneNumber,
          verificationId: testVerificationId,
          resendToken: resendToken,
        ),
      ),
    );
  }

  Widget wrapPushed({
    Object? confirmPhoneCodeErrorToThrow,
    void Function(String verificationId, String smsCode)? onConfirmPhoneCode,
  }) {
    return ProviderScope(
      overrides: [
        authViewModelProvider.overrideWith(
          () => FakeAuthViewModel(
            confirmPhoneCodeErrorToThrow: confirmPhoneCodeErrorToThrow,
            onConfirmPhoneCode: onConfirmPhoneCode,
          ),
        ),
      ],
      child: MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const OtpVerificationScreen(
                      phoneNumber: testPhoneNumber,
                      verificationId: testVerificationId,
                    ),
                  ),
                ),
                child: const Text('root'),
              ),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('renders the heading and the target phone number', (
    tester,
  ) async {
    await tester.pumpWidget(wrap());

    expect(find.text(AppStrings.authOtpHeading), findsOneWidget);
    expect(find.text(AppStrings.authOtpSubtitlePrefix), findsOneWidget);
    expect(find.text(testPhoneNumber), findsOneWidget);
  });

  testWidgets('there is no submit button — verification is automatic', (
    tester,
  ) async {
    await tester.pumpWidget(wrap());

    // The only ElevatedButton on this screen was the removed submit button;
    // resend is a GestureDetector/RichText and back is an IconButton.
    expect(find.byType(ElevatedButton), findsNothing);
  });

  testWidgets('entering fewer than 6 digits does not call confirmPhoneCode', (
    tester,
  ) async {
    String? capturedCode;
    await tester.pumpWidget(
      wrap(onConfirmPhoneCode: (_, code) => capturedCode = code),
    );

    await tester.enterText(find.byType(TextField), '12345');
    await tester.pump();

    expect(capturedCode, isNull);
  });

  testWidgets(
    'entering a complete 6-digit code calls confirmPhoneCode automatically '
    'exactly once, with the verification ID and code, then pops to root on '
    'success',
    (tester) async {
      final capturedCodes = <String>[];
      String? capturedVerificationId;
      await tester.pumpWidget(
        wrapPushed(
          onConfirmPhoneCode: (verificationId, code) {
            capturedVerificationId = verificationId;
            capturedCodes.add(code);
          },
        ),
      );

      await tester.tap(find.text('root'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), '472019');
      await tester.pumpAndSettle();

      expect(capturedVerificationId, testVerificationId);
      expect(capturedCodes, ['472019']);
      expect(find.byType(OtpVerificationScreen), findsNothing);
      expect(find.text('root'), findsOneWidget);
    },
  );

  testWidgets(
    'a confirmPhoneCode failure shows the error banner, stays on screen, and '
    'clears the code so the user can retype without deleting it manually',
    (tester) async {
      final capturedCodes = <String>[];
      await tester.pumpWidget(
        wrapPushed(
          confirmPhoneCodeErrorToThrow: const AuthException(
            code: 'invalid-verification-code',
            debugDetail: 'The SMS code has expired.',
          ),
          onConfirmPhoneCode: (_, code) => capturedCodes.add(code),
        ),
      );

      await tester.tap(find.text('root'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), '472019');
      await tester.pumpAndSettle();

      expect(find.byType(OtpVerificationScreen), findsOneWidget);
      expect(
        find.text('${AppStrings.authErrorCodeLabel}invalid-verification-code'),
        findsOneWidget,
      );
      expect(capturedCodes, ['472019']);

      // Field was cleared on failure (not left full), so retyping a fresh
      // 6-digit code auto-submits again instead of being a no-op.
      await tester.enterText(find.byType(TextField), '111111');
      await tester.pumpAndSettle();
      expect(capturedCodes, ['472019', '111111']);
    },
  );

  testWidgets('tapping resend after the countdown calls sendPhoneCode again', (
    tester,
  ) async {
    String? capturedPhoneNumber;
    await tester.pumpWidget(
      wrap(
        onSendPhoneCode: (phoneNumber, _) => capturedPhoneNumber = phoneNumber,
        resendResult: SmsCodeSent('new-verification-id'),
      ),
    );

    // Fast-forward past the 30s resend countdown.
    await tester.pump(const Duration(seconds: 30));

    final resendLink = find.text(
      '${AppStrings.authOtpResendPrompt}${AppStrings.authOtpResendAction}',
      findRichText: true,
    );
    await tester.ensureVisible(resendLink);
    await tester.tap(resendLink);
    await tester.pump();

    expect(capturedPhoneNumber, testPhoneNumber);
  });

  testWidgets(
    'resend forwards the resendToken the screen was constructed with, '
    'without which Firebase silently sends no SMS',
    (tester) async {
      int? capturedResendToken;
      await tester.pumpWidget(
        wrap(
          resendToken: 42,
          onSendPhoneCode: (_, resendToken) =>
              capturedResendToken = resendToken,
          resendResult: SmsCodeSent('new-verification-id'),
        ),
      );

      await tester.pump(const Duration(seconds: 30));

      final resendLink = find.text(
        '${AppStrings.authOtpResendPrompt}${AppStrings.authOtpResendAction}',
        findRichText: true,
      );
      await tester.ensureVisible(resendLink);
      await tester.tap(resendLink);
      await tester.pump();

      expect(capturedResendToken, 42);
    },
  );
}
