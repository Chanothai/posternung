import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:posternung/core/error/auth_exception.dart';
import 'package:posternung/core/strings/app_strings.dart';
import 'package:posternung/features/auth/data/datasources/phone_sign_in_data_source.dart';
import 'package:posternung/features/auth/presentation/providers/auth_providers.dart';
import 'package:posternung/features/auth/presentation/screens/login_screen.dart';
import 'package:posternung/features/auth/presentation/screens/otp_verification_screen.dart';
import 'package:posternung/features/auth/presentation/screens/register_screen.dart';
import 'package:posternung/features/auth/presentation/widgets/auth_email_field.dart';

class FakeAuthViewModel extends AuthViewModel {
  FakeAuthViewModel({this.errorToThrow});

  final Object? errorToThrow;

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
}

void main() {
  Widget wrap({Object? errorToThrow}) {
    return ProviderScope(
      overrides: [
        authViewModelProvider.overrideWith(
          () => FakeAuthViewModel(errorToThrow: errorToThrow),
        ),
      ],
      child: const MaterialApp(home: LoginScreen()),
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

  testWidgets('tapping the mode toggle navigates to the register screen', (
    tester,
  ) async {
    await tester.pumpWidget(wrap());

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
  });

  testWidgets(
    'error banner shows a friendly Thai message + the raw error code',
    (tester) async {
      await tester.pumpWidget(
        wrap(
          errorToThrow: const AuthException(
            code: 'wrong-password',
            message: 'The password is invalid.',
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
      'showing the phone number',
      (tester) async {
        await tester.pumpWidget(wrap());
        await tester.tap(find.text(AppStrings.authMethodPhoneTab));
        await tester.pump();

        await tester.enterText(find.byType(TextFormField), '812345678');
        final submit = find.text(AppStrings.authSubmitPhoneOtp);
        await tester.ensureVisible(submit);
        await tester.tap(submit);
        await tester.pumpAndSettle();

        expect(find.byType(OtpVerificationScreen), findsOneWidget);
        expect(find.text('+66812345678'), findsOneWidget);
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
  });
}
