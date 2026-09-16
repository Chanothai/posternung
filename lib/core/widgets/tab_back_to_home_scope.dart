import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../router/app_routes.dart';

/// Wraps a bottom-nav tab screen so Android's system back (and any other
/// pop request) goes to `/home` instead of leaving the app.
///
/// `ADR-0037` Amendment 4 A4-D2 #6 — back on a non-home tab goes to home,
/// it doesn't leave the app. `canPop: false` means the pop is always
/// intercepted (`didPop` is always `false`), so there is only one branch.
///
/// Used by `OrdersPlaceholderScreen`/`ProfileScreen` — the Home tab itself
/// doesn't need this (`/home` is already where a pop would land).
class TabBackToHomeScope extends StatelessWidget {
  const TabBackToHomeScope({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (didPop) return;
        context.go(AppRoutes.homePath);
      },
      child: child,
    );
  }
}
