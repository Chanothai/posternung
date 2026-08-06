import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:posternung/core/error/auth_exception.dart';
import 'package:posternung/core/strings/app_strings.dart';
import 'package:posternung/features/auth/domain/entities/auth_user.dart';
import 'package:posternung/features/auth/presentation/auth_gate.dart';
import 'package:posternung/features/auth/presentation/providers/auth_providers.dart';
import 'package:posternung/features/auth/presentation/providers/session_provider.dart';
import 'package:posternung/features/auth/presentation/screens/login_screen.dart';

/// A no-op stand-in for the real `AuthViewModel` — `LoginScreen` (rendered by
/// `AuthGate`'s `data: null` branch) reads `authViewModelProvider`, and the
/// real one would try to touch Firebase/the backend at build time. Mirrors
/// the same pattern `login_screen_test.dart` uses.
class _NoopAuthViewModel extends AuthViewModel {
  @override
  FutureOr<void> build() {}
}

void main() {
  Widget wrap({
    required AsyncValue<AuthUser?> session,
    WidgetBuilder? builder,
  }) {
    return ProviderScope(
      overrides: [
        sessionProvider.overrideWithValue(session),
        authViewModelProvider.overrideWith(_NoopAuthViewModel.new),
      ],
      child: MaterialApp(
        home: AuthGate(
          builder: builder ?? (_) => const Text('AUTHENTICATED-DESTINATION'),
        ),
      ),
    );
  }

  testWidgets('loading — shows a spinner, not the login screen or the '
      'destination', (tester) async {
    await tester.pumpWidget(wrap(session: const AsyncLoading()));

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byType(LoginScreen), findsNothing);
    expect(find.text('AUTHENTICATED-DESTINATION'), findsNothing);
  });

  testWidgets('data(null) — signed out shows LoginScreen', (tester) async {
    await tester.pumpWidget(wrap(session: const AsyncData(null)));

    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.text('AUTHENTICATED-DESTINATION'), findsNothing);
  });

  testWidgets('data(user) — signed in builds the caller\'s destination, not '
      'LoginScreen', (tester) async {
    await tester.pumpWidget(
      wrap(
        session: const AsyncData(
          AuthUser(uid: 'u1', email: 'user@example.com'),
        ),
      ),
    );

    expect(find.text('AUTHENTICATED-DESTINATION'), findsOneWidget);
    expect(find.byType(LoginScreen), findsNothing);
  });

  testWidgets(
    'error — an AuthException routes through authErrorDisplayFor like every '
    'other auth screen, so the common case (e.g. network_error on startup) '
    'shows a specific Thai line + code, not a bare generic one',
    (tester) async {
      await tester.pumpWidget(
        wrap(
          session: AsyncError(
            const AuthException(code: 'network_error'),
            StackTrace.current,
          ),
        ),
      );

      expect(find.text(AppStrings.authErrorNetwork), findsOneWidget);
      expect(
        find.text('${AppStrings.authErrorCodeLabel}network_error'),
        findsOneWidget,
      );
      // Not the bare generic line with no code — that's the exact AC-4
      // violation ("a generic line with no code") this screen used to have.
      expect(find.text(AppStrings.authErrorGeneric), findsNothing);
    },
  );

  testWidgets(
    'error — a non-AuthException still shows *some* code (AC-4 — never a '
    'generic line with nothing to diagnose from), via the same fixed '
    'unhandled_error path every other auth screen falls back to',
    (tester) async {
      await tester.pumpWidget(
        wrap(session: AsyncError(StateError('boom'), StackTrace.current)),
      );

      expect(find.text(AppStrings.authErrorGeneric), findsOneWidget);
      expect(
        find.text('${AppStrings.authErrorCodeLabel}unhandled_error'),
        findsOneWidget,
      );
    },
  );
}
