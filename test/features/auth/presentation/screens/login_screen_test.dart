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
import 'package:posternung/features/auth/presentation/providers/session_provider.dart';
import 'package:posternung/features/auth/presentation/screens/login_screen.dart';
import 'package:posternung/features/auth/presentation/screens/otp_verification_screen.dart';
import 'package:posternung/features/auth/presentation/screens/register_screen.dart';
import 'package:posternung/features/auth/presentation/widgets/auth_email_field.dart';

import '../../../../support/router_harness.dart';

class FakeAuthViewModel extends AuthViewModel {
  FakeAuthViewModel({this.errorToThrow, this.confirmPhoneCodeErrorToThrow});

  final Object? errorToThrow;

  /// Set to make [confirmPhoneCode] fail, for exercising the OTP screen's
  /// error banner (which shares this same provider with [LoginScreen]).
  final Object? confirmPhoneCodeErrorToThrow;

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
  }) async => SmsCodeSent('test-verification-id');

  @override
  Future<void> confirmPhoneCode({
    required String verificationId,
    required String smsCode,
  }) async {
    // Mirror what the real method does via `AsyncValue.guard` — set `state`
    // rather than throw, so `state.error` actually reflects the failure.
    final error = confirmPhoneCodeErrorToThrow;
    state = error != null
        ? AsyncError(error, StackTrace.current)
        : const AsyncData(null);
  }
}

void main() {
  Widget wrap({
    Object? errorToThrow,
    Object? confirmPhoneCodeErrorToThrow,
    void Function(GoRouter router)? onRouter,
  }) {
    return ProviderScope(
      overrides: [
        authViewModelProvider.overrideWith(
          () => FakeAuthViewModel(
            errorToThrow: errorToThrow,
            confirmPhoneCodeErrorToThrow: confirmPhoneCodeErrorToThrow,
          ),
        ),
        // Signed out — which is the only state in which the gate at
        // `/home` renders the screen this file is about.
        sessionProvider.overrideWithValue(const AsyncData<AuthUser?>(null)),
      ],
      // `/home`, not `MaterialApp(home: LoginScreen())`: `LoginScreen` is
      // not a route of its own — it is what `AuthGate` renders at
      // `AppRoutes.homePath` while signed out (ADR-0018 D4). Starting from
      // the path proves that is still true, and gives the screen a real
      // router to push `/register` and `/otp` onto.
      child: routedApp(
        location: AppRoutes.homePath,
        routes: appRoutes,
        onRouter: onRouter,
      ),
    );
  }

  testWidgets('renders login-mode copy by default', (tester) async {
    await tester.pumpWidget(wrap());

    expect(find.text('PosterNung'), findsOneWidget);
    expect(find.text('ยินดีต้อนรับกลับ'), findsOneWidget);
    expect(find.text('เข้าสู่ระบบ'), findsOneWidget);
    expect(
      find.text('ยังไม่มีบัญชี? สร้างบัญชีใหม่', findRichText: true),
      findsOneWidget,
    );
  });

  testWidgets('autofocuses the email field on entry', (tester) async {
    await tester.pumpWidget(wrap());
    // Let the post-frame autofocus request settle.
    await tester.pump();

    final editable = tester.widget<EditableText>(
      find.descendant(
        of: find.byType(AuthEmailField),
        matching: find.byType(EditableText),
      ),
    );
    expect(editable.focusNode.hasFocus, isTrue);
  });

  testWidgets('tapping the mode toggle pushes the register screen — pushes, '
      'so back comes straight back here rather than stranding someone who '
      'only wanted to look', (tester) async {
    late GoRouter router;
    await tester.pumpWidget(wrap(onRouter: (r) => router = r));

    // The toggle link reads "สร้างบัญชีใหม่" (inside a Text.rich, hence
    // findRichText: true, matched against the full combined text). It sits
    // at the bottom of a scrollable card, so scroll it into view first.
    final toggleLink = find.text(
      'ยังไม่มีบัญชี? สร้างบัญชีใหม่',
      findRichText: true,
    );
    await tester.ensureVisible(toggleLink);
    await tester.tap(toggleLink);
    await tester.pumpAndSettle();

    expect(find.byType(RegisterScreen), findsOneWidget);
    // `go` would show the same screen and leave nothing to go back to, so
    // asserting only on what is rendered cannot tell the two apart.
    expect(
      router.canPop(),
      isTrue,
      reason: 'register must sit on top of the gate, not replace it',
    );

    router.pop();
    await tester.pumpAndSettle();
    expect(find.byType(RegisterScreen), findsNothing);
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(router.state.uri.toString(), AppRoutes.homePath);
  });

  testWidgets(
    'error banner shows a friendly Thai message + the raw error code',
    (tester) async {
      await tester.pumpWidget(
        wrap(
          errorToThrow: const AuthException(
            code: 'wrong-password',
            // Firebase's own English text — real data sources put this in
            // debugDetail (ADR-0017 D2/D7); asserted below that it never
            // reaches the widget tree no matter what a guard puts here.
            debugDetail: 'The password is invalid.',
          ),
        ),
      );
      await tester.pump();

      // Firebase's English message is mapped to Thai; the raw code shows on a
      // second line for diagnosis.
      expect(find.text(AppStrings.authErrorWrongPassword), findsOneWidget);
      expect(
        find.text('${AppStrings.authErrorCodeLabel}wrong-password'),
        findsOneWidget,
      );
      expect(find.text('The password is invalid.'), findsNothing);
    },
  );

  group('phone method', () {
    testWidgets(
      'tapping the phone tab hides the password field and mode toggle, '
      'shows the phone field',
      (tester) async {
        await tester.pumpWidget(wrap());

        await tester.tap(find.text(AppStrings.authMethodPhoneTab));
        await tester.pump();

        expect(find.text(AppStrings.authPhoneHeading), findsOneWidget);
        expect(find.text(AppStrings.authPhoneLabel), findsOneWidget);
        expect(find.text(AppStrings.authPasswordLabel), findsNothing);
        expect(find.text(AppStrings.authForgotPassword), findsNothing);
        expect(
          find.text('ยังไม่มีบัญชี? สร้างบัญชีใหม่', findRichText: true),
          findsNothing,
        );
        expect(find.text(AppStrings.authSubmitPhoneOtp), findsOneWidget);
      },
    );

    testWidgets(
      'submitting an incomplete phone number shows the validation error',
      (tester) async {
        await tester.pumpWidget(wrap());
        await tester.tap(find.text(AppStrings.authMethodPhoneTab));
        await tester.pump();

        await tester.enterText(find.byType(TextFormField), '812345');
        final submit = find.text(AppStrings.authSubmitPhoneOtp);
        await tester.ensureVisible(submit);
        await tester.tap(submit);
        await tester.pump();

        expect(find.text(AppStrings.authPhoneValidationError), findsOneWidget);
      },
    );

    testWidgets(
      'submitting a valid 9-digit phone number navigates to the OTP screen '
      'showing the phone number — and the URL that navigation produced '
      'carries none of the phone number, verification id or resend token '
      '(AC-5 / ADR-0018 D6)',
      (tester) async {
        late GoRouter router;
        await tester.pumpWidget(wrap(onRouter: (r) => router = r));
        await tester.tap(find.text(AppStrings.authMethodPhoneTab));
        await tester.pump();

        await tester.enterText(find.byType(TextFormField), '812345678');
        final submit = find.text(AppStrings.authSubmitPhoneOtp);
        await tester.ensureVisible(submit);
        await tester.tap(submit);
        await tester.pumpAndSettle();

        expect(find.byType(OtpVerificationScreen), findsOneWidget);
        expect(find.text('+66812345678'), findsOneWidget);

        // 🔴 This is the assertion that has to be made *here* rather than in
        // `app_router_test.dart`. That file starts a router at
        // `AppRoutes.otpPath` and then checks the location is
        // `AppRoutes.otpPath` — a URL the test fed in itself, which stays
        // true no matter what the production call site does. What matters is
        // the URL `LoginScreen._submit` produced, so it is read after the
        // real tap and nowhere else.
        final uri = router.state.uri;
        expect(uri.path, AppRoutes.otpPath);
        expect(uri.queryParameters, isEmpty);
        expect(uri.fragment, isEmpty);

        final location = uri.toString();
        expect(location, AppRoutes.otpPath);
        expect(location, isNot(contains('+66812345678')));
        // Also without the '+': percent-encoded or stripped is still a leak.
        expect(location, isNot(contains('66812345678')));
        // The id the fake view model handed back at this exact call site —
        // not a literal retyped here, so it cannot drift out of the check.
        expect(location, isNot(contains('test-verification-id')));
      },
    );

    testWidgets(
      'submitting the habitual leading-zero form normalizes it to E.164 '
      'instead of dialing an invalid number',
      (tester) async {
        await tester.pumpWidget(wrap());
        await tester.tap(find.text(AppStrings.authMethodPhoneTab));
        await tester.pump();

        await tester.enterText(find.byType(TextFormField), '0812345678');
        final submit = find.text(AppStrings.authSubmitPhoneOtp);
        await tester.ensureVisible(submit);
        await tester.tap(submit);
        await tester.pumpAndSettle();

        expect(find.byType(OtpVerificationScreen), findsOneWidget);
        expect(find.text('+66812345678'), findsOneWidget);
      },
    );

    testWidgets(
      'backing out of a failed OTP attempt clears its error banner — it and '
      'the login screen share authViewModelProvider, so a wrong-code error '
      'must not still be showing once the user is back here',
      (tester) async {
        await tester.pumpWidget(
          wrap(
            confirmPhoneCodeErrorToThrow: const AuthException(
              code: 'invalid-verification-code',
              debugDetail: 'The SMS code has expired.',
            ),
          ),
        );

        await tester.tap(find.text(AppStrings.authMethodPhoneTab));
        await tester.pump();
        await tester.enterText(find.byType(TextFormField), '812345678');
        final submit = find.text(AppStrings.authSubmitPhoneOtp);
        await tester.ensureVisible(submit);
        await tester.tap(submit);
        await tester.pumpAndSettle();
        expect(find.byType(OtpVerificationScreen), findsOneWidget);

        // Entering a full code on the real OTP screen auto-submits and,
        // with the fake configured to fail, leaves its error banner up.
        await tester.enterText(find.byType(TextField), '472019');
        await tester.pumpAndSettle();
        expect(
          find.text(
            '${AppStrings.authErrorCodeLabel}invalid-verification-code',
          ),
          findsOneWidget,
        );

        await tester.pageBack();
        await tester.pumpAndSettle();

        expect(find.byType(OtpVerificationScreen), findsNothing);
        expect(
          find.text(
            '${AppStrings.authErrorCodeLabel}invalid-verification-code',
          ),
          findsNothing,
        );
      },
    );
  });
}
