import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design_system/app_spacing.dart';
import '../../../core/strings/app_strings.dart';
import 'auth_error_display.dart';
import 'providers/session_provider.dart';
import 'screens/login_screen.dart';
import 'widgets/auth_error_banner.dart';

/// Gates [builder] behind auth state: shows [LoginScreen] when signed out,
/// otherwise builds the authenticated destination. Watches `sessionProvider`,
/// which reports authenticated if EITHER the Firebase session (email/password
/// + Apple) or the backend JWT session (Google) has a user.
class AuthGate extends ConsumerWidget {
  const AuthGate({super.key, required this.builder});

  final WidgetBuilder builder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider);

    return session.when(
      data: (user) => user == null ? const LoginScreen() : builder(context),
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      // `error` here is whatever `sessionProvider`'s stream threw. Found
      // during ADR-0017 (not in its own count of ~20 call sites — this used
      // to interpolate `$error` straight onto the screen, the exact class
      // of leak AC-1 forbids): route it through the same
      // `authErrorDisplayFor` every other auth screen uses, not a
      // hand-rolled fallback.
      //
      // `sessionProvider` (`session_provider.dart`) forwards
      // `backendSessionProvider`'s error whenever the Firebase session is
      // unauthenticated, and `BackendAuthDataSource._guard` guarantees that
      // one is always an `AuthException` — so the common case (e.g. a
      // `network_error` on startup) gets the real, specific Thai line, not
      // a generic one. `authErrorDisplayFor` still handles the fallback
      // itself (fixed `unhandled_error` code, real type to the debug log —
      // ADR-0017 OD-1) for the rarer case where it genuinely isn't one.
      error: (error, stackTrace) {
        final display = authErrorDisplayFor(error);
        return Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: AuthErrorBanner(
                message: display?.message ?? AppStrings.authErrorGeneric,
                code: display?.code,
              ),
            ),
          ),
        );
      },
    );
  }
}
