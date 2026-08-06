import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:posternung/core/error/auth_exception.dart';
import 'package:posternung/core/router/app_router.dart';
import 'package:posternung/core/router/app_routes.dart';
import 'package:posternung/core/strings/app_strings.dart';
import 'package:posternung/features/auth/domain/entities/auth_user.dart';
import 'package:posternung/features/auth/presentation/providers/auth_providers.dart';
import 'package:posternung/features/auth/presentation/providers/session_provider.dart';
import 'package:posternung/features/auth/presentation/screens/register_screen.dart';
import 'package:posternung/features/auth/presentation/widgets/auth_email_field.dart';

import '../../../../support/router_harness.dart';

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
      // Reached by its real path (ADR-0018 D9) rather than by naming the
      // widget: that is the only way a test can fail when the route that
      // gets a user here is wrong or missing.
      child: routedApp(location: AppRoutes.registerPath, routes: appRoutes),
    );
  }

  Widget wrapPushed({
    Object? errorToThrow,
    void Function(GoRouter router)? onRouter,
  }) {
    return ProviderScope(
      overrides: [
        authViewModelProvider.overrideWith(
          () => FakeAuthViewModel(errorToThrow: errorToThrow),
        ),
        // A successful register ends the auth flow at `AppRoutes.homePath`,
        // and the gate there reads the session.
        sessionProvider.overrideWithValue(const AsyncData<AuthUser?>(null)),
      ],
      child: routedApp(
        onRouter: onRouter,
        routes: routesHosting(
          Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => context.push(AppRoutes.registerPath),
                  child: const Text('root'),
                ),
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
            debugDetail: 'The email address is already in use.',
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

  testWidgets('a successful register leaves no auth screen on the stack — '
      'it lands on the post-auth destination rather than popping one route '
      'back to whatever pushed it (AC-6)', (tester) async {
    late GoRouter router;
    await tester.pumpWidget(wrapPushed(onRouter: (r) => router = r));

    await tester.tap(find.text('root'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).first, 'you@example.com');
    await tester.enterText(find.byType(TextFormField).last, 'password123');

    final submit = find.text(AppStrings.authSubmitRegister);
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.pumpAndSettle();

    expect(find.byType(RegisterScreen), findsNothing);
    expect(find.text('root'), findsNothing);
    expect(router.state.uri.toString(), AppRoutes.homePath);
  });
}
