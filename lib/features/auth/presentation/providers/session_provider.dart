import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/auth_user.dart';
import 'backend_session_provider.dart';

/// The app's single source of truth for "is someone logged in" (ADR-0021
/// D1): the backend JWT session, and *only* the backend JWT session.
/// `AuthGate` watches this — not `backendSessionProvider` directly — so
/// callers don't need to know that name.
///
/// 🔴 Deliberately does **not** also read `authStateChangesProvider` any
/// more. Every sign-in method (email/password, register, Google, phone)
/// establishes a Firebase session as an intermediate step on the way to
/// exchanging a Firebase ID token at `/auth/firebase`
/// (`BackendSessionNotifier`) — but a Firebase session with no backend JWT
/// yet means the app cannot call any of its own APIs, since every
/// authenticated endpoint requires the backend's own token. The old code
/// merged the two sessions with `firebase.asData?.value ?? backend.asData
/// ?.value`, which let `AuthGate` advance behind a session that could not
/// do anything — the exact defect ADR-0021 §Context documents. Since every
/// route with real content already sits behind `AuthGate` (ADR-0018 D4),
/// "logged in" is defined as "can call the backend", not "Firebase
/// recognizes this device".
final sessionProvider = Provider<AsyncValue<AuthUser?>>((ref) {
  return ref.watch(backendSessionProvider);
});
