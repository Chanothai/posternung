import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'app_routes.dart';

/// Leaving-a-screen helpers that cannot strand the user.
extension AppNavigation on BuildContext {
  /// Goes back one screen, or lands on home when there is nothing to go back
  /// to.
  ///
  /// Why not a bare `pop()`: `go_router` throws `GoError('There is nothing to
  /// pop')` when the current route is the only one on the stack, where the
  /// `Navigator.pop`/`Navigator.maybePop` calls this replaced either handled
  /// it or did nothing. A screen can genuinely be the first one — the `/otp`
  /// route redirects an argument-less arrival home, and a restored process
  /// can come back on any location — so "back" has to mean somewhere real
  /// rather than an exception thrown at whoever tapped it.
  void popOrGoHome() {
    if (canPop()) {
      pop();
    } else {
      go(AppRoutes.homePath);
    }
  }
}
