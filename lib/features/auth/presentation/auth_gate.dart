import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/strings/app_strings.dart';
import 'providers/session_provider.dart';
import 'screens/login_screen.dart';

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
      error: (error, stackTrace) => Scaffold(
        body: Center(child: Text('${AppStrings.authGateErrorPrefix}$error')),
      ),
    );
  }
}
