import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:posternung/core/error/auth_exception.dart';
import 'package:posternung/features/auth/presentation/providers/auth_providers.dart';
import 'package:posternung/features/auth/presentation/screens/login_screen.dart';

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

  testWidgets('tapping the mode toggle switches to register copy', (
    tester,
  ) async {
    await tester.pumpWidget(wrap());

    // In login mode, the toggle link reads "สร้างบัญชีใหม่" (inside a
    // Text.rich, hence findRichText: true, matched against the full
    // combined text). It sits at the bottom of a scrollable card, so scroll
    // it into view before tapping.
    final toggleLink = find.text(
      'ยังไม่มีบัญชี? สร้างบัญชีใหม่',
      findRichText: true,
    );
    await tester.ensureVisible(toggleLink);
    await tester.tap(toggleLink);
    await tester.pump();

    // Register mode: "สร้างบัญชีใหม่" now only labels the heading (plain
    // Text), the submit button reads "สร้างบัญชี", and the toggle link
    // flips to "เข้าสู่ระบบ" (now inside the Text.rich, moved off the
    // submit button which showed it in login mode).
    expect(find.text('สร้างบัญชีใหม่'), findsOneWidget);
    expect(find.text('สร้างบัญชี'), findsOneWidget);
    expect(
      find.text('มีบัญชีอยู่แล้ว? เข้าสู่ระบบ', findRichText: true),
      findsOneWidget,
    );
  });

  testWidgets('renders the error banner when the view model has an error', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        errorToThrow: const AuthException(
          code: 'wrong-password',
          message: 'The password is invalid.',
        ),
      ),
    );
    await tester.pump();

    expect(find.text('The password is invalid.'), findsOneWidget);
  });
}
