import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:posternung/core/error/auth_exception.dart';
import 'package:posternung/core/router/app_router.dart';
import 'package:posternung/core/router/app_routes.dart';
import 'package:posternung/core/strings/app_strings.dart';
import 'package:posternung/features/auth/data/datasources/phone_sign_in_data_source.dart';
import 'package:posternung/features/auth/domain/entities/auth_user.dart';
import 'package:posternung/features/auth/presentation/providers/auth_providers.dart';
import 'package:posternung/features/auth/presentation/providers/otp_flow_provider.dart';
import 'package:posternung/features/auth/presentation/providers/session_provider.dart';
import 'package:posternung/features/auth/presentation/screens/otp_verification_screen.dart';

import '../../../../support/otp_flow_harness.dart';
import '../../../../support/router_harness.dart';

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
        otpFlowProvider.overrideWith(
          () => SeededOtpFlow(
            OtpFlowState(
              phoneNumber: testPhoneNumber,
              verificationId: testVerificationId,
              resendToken: resendToken,
            ),
          ),
        ),
      ],
      // Reached by its real path with a real open flow, not by handing the
      // constructor three values (ADR-0018 D9). The flow is seeded through
      // `otpFlowProvider` because the route carries no arguments at all any
      // more (Amendment 2 A2-D2).
      child: routedApp(location: AppRoutes.otpPath, routes: appRoutes),
    );
  }

  Widget wrapPushed({
    Object? confirmPhoneCodeErrorToThrow,
    void Function(String verificationId, String smsCode)? onConfirmPhoneCode,
    void Function(GoRouter router)? onRouter,
    PhoneVerificationResult? resendResult,
  }) {
    return ProviderScope(
      overrides: [
        authViewModelProvider.overrideWith(
          () => FakeAuthViewModel(
            confirmPhoneCodeErrorToThrow: confirmPhoneCodeErrorToThrow,
            onConfirmPhoneCode: onConfirmPhoneCode,
            resendResult: resendResult,
          ),
        ),
        // A success here ends the auth flow, which lands on
        // `AppRoutes.homePath` — and the gate there reads the session.
        sessionProvider.overrideWithValue(const AsyncData<AuthUser?>(null)),
        otpFlowProvider.overrideWith(
          () => SeededOtpFlow(
            const OtpFlowState(
              phoneNumber: testPhoneNumber,
              verificationId: testVerificationId,
            ),
          ),
        ),
      ],
      child: routedApp(
        onRouter: onRouter,
        routes: routesHosting(
          Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => context.push(AppRoutes.otpPath),
                  child: const Text('root'),
                ),
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
    'exactly once, with the verification ID and code, then leaves no auth '
    'screen on the stack (AC-6)',
    (tester) async {
      final capturedCodes = <String>[];
      String? capturedVerificationId;
      late GoRouter router;
      await tester.pumpWidget(
        wrapPushed(
          onRouter: (r) => router = r,
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
      // `completeAuthFlow` replaces the stack rather than popping one route
      // (ADR-0018 D4): the OTP screen is gone, the screen that pushed it is
      // gone with it, and the location is the post-auth destination.
      expect(find.byType(OtpVerificationScreen), findsNothing);
      expect(find.text('root'), findsNothing);
      expect(router.state.uri.toString(), AppRoutes.homePath);
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

  group('ADR-0021 D3 — the error banner\'s retry button (code-critic GATE 3 '
      'round 1: this screen was the one D3 missed the first time round)', () {
    testWidgets(
      'appears for OAUTH_LOGIN_CONFLICT, keeps the entered code (unlike '
      'every other error) since it was not wrong, and re-runs confirmPhoneCode '
      'with that same code on tap',
      (tester) async {
        final capturedCodes = <String>[];
        await tester.pumpWidget(
          wrapPushed(
            confirmPhoneCodeErrorToThrow: const AuthException(
              code: 'OAUTH_LOGIN_CONFLICT',
            ),
            onConfirmPhoneCode: (_, code) => capturedCodes.add(code),
          ),
        );

        await tester.tap(find.text('root'));
        await tester.pumpAndSettle();

        await tester.enterText(find.byType(TextField), '472019');
        await tester.pumpAndSettle();

        expect(capturedCodes, ['472019']);
        expect(
          find.text('${AppStrings.authErrorCodeLabel}OAUTH_LOGIN_CONFLICT'),
          findsOneWidget,
        );
        // The digits are still in the (invisible) capture field — not
        // cleared like a wrong code would be. Proven behaviorally below:
        // if it had been cleared, retry would resubmit an empty smsCode.
        final retry = find.text(AppStrings.authRetryButton);
        expect(retry, findsOneWidget);
        await tester.tap(retry);
        await tester.pumpAndSettle();

        expect(
          capturedCodes,
          ['472019', '472019'],
          reason:
              'retry must resubmit the same (correct) code, not an '
              'empty one',
        );
      },
    );

    testWidgets(
      'does NOT appear for an ordinary wrong-code failure, which still '
      'clears the field as before',
      (tester) async {
        await tester.pumpWidget(
          wrapPushed(
            confirmPhoneCodeErrorToThrow: const AuthException(
              code: 'invalid-verification-code',
            ),
          ),
        );

        await tester.tap(find.text('root'));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField), '472019');
        await tester.pumpAndSettle();

        expect(find.text(AppStrings.authRetryButton), findsNothing);
      },
    );
  });

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

  testWidgets('resend forwards the resendToken the open flow holds, '
      'without which Firebase silently sends no SMS', (tester) async {
    int? capturedResendToken;
    await tester.pumpWidget(
      wrap(
        resendToken: 42,
        onSendPhoneCode: (_, resendToken) => capturedResendToken = resendToken,
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
  });

  testWidgets(
    'INF-18 AC-2 — a code resent mid-flow is verified against the SMS that '
    'was actually sent last, even after a GoRouter.refresh() rebuilds the '
    'screen underneath the user',
    (tester) async {
      const String resentId = 'verification-id-from-the-second-sms';
      String? capturedVerificationId;
      late GoRouter router;

      await tester.pumpWidget(
        wrapPushed(
          onRouter: (GoRouter r) => router = r,
          onConfirmPhoneCode: (String verificationId, String _) =>
              capturedVerificationId = verificationId,
          resendResult: SmsCodeSent(resentId),
        ),
      );
      await tester.tap(find.text('root'));
      await tester.pumpAndSettle();

      // Resend: from here on, only `resentId` can verify a code.
      await tester.pump(const Duration(seconds: 30));
      final Finder resendLink = find.text(
        '${AppStrings.authOtpResendPrompt}${AppStrings.authOtpResendAction}',
        findRichText: true,
      );
      await tester.ensureVisible(resendLink);
      await tester.tap(resendLink);
      await tester.pumpAndSettle();

      router.refresh();
      await tester.pumpAndSettle();
      expect(find.byType(OtpVerificationScreen), findsOneWidget);

      await tester.enterText(find.byType(TextField), '472019');
      await tester.pumpAndSettle();

      expect(capturedVerificationId, resentId);
      // Said the other way round, because this is the failure that would not
      // announce itself: verifying against the *first* SMS's id returns a
      // plain "wrong code" for a code the user copied correctly.
      expect(capturedVerificationId, isNot(testVerificationId));
    },
  );
}
