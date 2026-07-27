import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:posternung/core/error/auth_exception.dart';
import 'package:posternung/core/strings/app_strings.dart';
import 'package:posternung/features/auth/presentation/providers/auth_providers.dart';
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
}

void main() {
  Widget wrap({Object? errorToThrow}) {
    return ProviderScope(
      overrides: [
        authViewModelProvider.overrideWith(
          () => FakeAuthViewModel(errorToThrow: errorToThrow),
        ),
      ],
      child: const MaterialApp(home: RegisterScreen()),
    );
  }

  Widget wrapPushed({Object? errorToThrow}) {
    return ProviderScope(
      overrides: [
        authViewModelProvider.overrideWith(
          () => FakeAuthViewModel(errorToThrow: errorToThrow),
        ),
      ],
      child: MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const RegisterScreen()),
                ),
                child: const Text('root'),
              ),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('renders register copy, fields, and no Google button', (
    tester,
  ) async {
    await tester.pumpWidget(wrap());

    expect(find.text('PosterNung'), findsOneWidget);
    expect(find.text(AppStrings.authHeadingRegister), findsOneWidget);
    expect(find.text(AppStrings.authSubtitleRegister), findsOneWidget);
    expect(find.text(AppStrings.authMethodEmailTab), findsOneWidget);
    expect(find.text(AppStrings.authPasswordLabel), findsOneWidget);
    expect(find.text(AppStrings.authSubmitRegister), findsOneWidget);
    expect(find.text(AppStrings.authForgotPassword), findsNothing);
    expect(find.text(AppStrings.authGoogleSignIn), findsNothing);
    expect(find.text(AppStrings.authOrDivider), findsNothing);
    expect(
      find.text('มีบัญชีอยู่แล้ว? เข้าสู่ระบบ', findRichText: true),
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

  testWidgets(
    'error banner shows a friendly Thai message + the raw error code',
    (tester) async {
      await tester.pumpWidget(
        wrap(
          errorToThrow: const AuthException(
            code: 'email-already-in-use',
            message: 'The email address is already in use.',
          ),
        ),
      );
      await tester.pump();

      expect(find.text(AppStrings.authErrorEmailAlreadyInUse), findsOneWidget);
      expect(
        find.text('${AppStrings.authErrorCodeLabel}email-already-in-use'),
        findsOneWidget,
      );
    },
  );

  testWidgets('tapping the nav link pops back to the previous screen', (
    tester,
  ) async {
    await tester.pumpWidget(wrapPushed());

    await tester.tap(find.text('root'));
    await tester.pumpAndSettle();
    expect(find.byType(RegisterScreen), findsOneWidget);

    final navLink = find.text(
      'มีบัญชีอยู่แล้ว? เข้าสู่ระบบ',
      findRichText: true,
    );
    await tester.ensureVisible(navLink);
    await tester.tap(navLink);
    await tester.pumpAndSettle();

    expect(find.byType(RegisterScreen), findsNothing);
    expect(find.text('root'), findsOneWidget);
  });

  testWidgets('a successful register pops back to the previous screen', (
    tester,
  ) async {
    await tester.pumpWidget(wrapPushed());

    await tester.tap(find.text('root'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).first, 'you@example.com');
    await tester.enterText(find.byType(TextFormField).last, 'password123');

    final submit = find.text(AppStrings.authSubmitRegister);
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.pumpAndSettle();

    expect(find.byType(RegisterScreen), findsNothing);
    expect(find.text('root'), findsOneWidget);
  });
}
