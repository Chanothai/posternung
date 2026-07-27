import 'package:flutter/material.dart';

/// Call after any sign-in succeeds, from every auth entry point.
///
/// Navigation to the destination is already reactive — `AuthGate` watches
/// `sessionProvider` and swaps `LoginScreen` for the authenticated
/// destination on its own. What differs between screens is only whether
/// anything is stacked *on top* of that gate:
///
/// - `LoginScreen` is `AuthGate`'s child on the first route, so the
///   `popUntil` below is a no-op — the gate has already swapped underneath.
/// - `OtpVerificationScreen` / `RegisterScreen` are pushed above the gate's
///   route, so they must pop back to root to reveal what it switched to.
///
/// Routing both cases through this one call keeps every path identical at
/// the call site instead of each screen remembering which shape it is.
/// [FocusScope.unfocus] dismisses the keyboard for the paths that had one
/// open (email/password, phone OTP) and is harmless for the social ones.
void completeAuthFlow(BuildContext context) {
  FocusScope.of(context).unfocus();
  Navigator.of(context).popUntil((route) => route.isFirst);
}
