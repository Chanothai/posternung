import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'providers/auth_providers.dart';
import 'screens/login_screen.dart';

/// Gates [builder] behind auth state: shows [LoginScreen] when signed out,
/// otherwise builds the authenticated destination.
class AuthGate extends ConsumerWidget {
  const AuthGate({super.key, required this.builder});

  final WidgetBuilder builder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateChangesProvider);

    return authState.when(
      data: (user) => user == null ? const LoginScreen() : builder(context),
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, stackTrace) =>
          Scaffold(body: Center(child: Text('Something went wrong: $error'))),
    );
  }
}
