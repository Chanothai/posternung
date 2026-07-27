import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/auth_user.dart';
import 'auth_providers.dart';
import 'backend_session_provider.dart';

/// The app's single source of truth for "is someone logged in", merging the
/// two coexisting sessions: Firebase (email/password + Apple) and the backend
/// JWT session (Google). Authenticated if EITHER has a non-null user.
/// `AuthGate` watches this instead of either source directly.
final sessionProvider = Provider<AsyncValue<AuthUser?>>((ref) {
  final firebase = ref.watch(authStateChangesProvider);
  final backend = ref.watch(backendSessionProvider);

  final user = firebase.asData?.value ?? backend.asData?.value;
  if (user != null) return AsyncData(user);

  // Neither is authenticated. Stay in loading until both have resolved, so
  // the login screen doesn't flash before a stored session is restored.
  if (firebase.isLoading || backend.isLoading) return const AsyncLoading();

  if (firebase.hasError) {
    return AsyncError(firebase.error!, firebase.stackTrace!);
  }
  if (backend.hasError) {
    return AsyncError(backend.error!, backend.stackTrace!);
  }

  return const AsyncData(null);
});
