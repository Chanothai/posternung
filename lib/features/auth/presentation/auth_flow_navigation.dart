import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';

/// Call after any sign-in succeeds, from every auth entry point.
///
/// Deciding *what* to show is still not this function's job — `AuthGate`
/// watches `sessionProvider` and swaps `LoginScreen` for the authenticated
/// destination by itself, and ADR-0018 D4 deliberately keeps it that way
/// rather than moving auth into a route-level `redirect` this round. What
/// this function does is make sure nothing is left standing on top of the
/// gate's route: `OtpVerificationScreen` and `RegisterScreen` are pushed
/// above it and would otherwise still be covering the screen the user just
/// earned.
///
/// [AppRoutes.homePath] via `go`, not a series of pops: `go` replaces the
/// whole stack in one step, so it is correct from every entry point without
/// any of them having to know how deep it currently is. That matters here —
/// the call sites are genuinely different shapes. `LoginScreen` is the
/// gate's own child with nothing above it, `OtpVerificationScreen` sits one
/// route up, and the social buttons can fire from either. The `popUntil`
/// this replaced only worked because `LoginScreen` was not a route at all;
/// it was a no-op in the one case and a pop in the others, which is exactly
/// the kind of "depends where you are" that a route table exists to delete.
///
/// [FocusScope.unfocus] dismisses the keyboard for the paths that had one
/// open (email/password, phone OTP) and is harmless for the social ones.
void completeAuthFlow(BuildContext context) {
  FocusScope.of(context).unfocus();
  context.go(AppRoutes.homePath);
}
