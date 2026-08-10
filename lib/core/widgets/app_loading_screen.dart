import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// The full-screen "nothing is known yet" placeholder.
///
/// A widget rather than a `Scaffold` + spinner spelled out per call site,
/// because what it is for is *visual*: it paints on `AppColors.surfaceDark`,
/// the same ground the dark screens on either side of it use, so a moment of
/// waiting is not a white frame between two dark ones.
///
/// Call sites today: `requireRouteState` (`core/router/route_state_guard.dart`)
/// while a route that arrived without the state it needs leaves again, and
/// `OnboardingEntryGate` (`features/onboarding/`) while the stored session is
/// being restored at cold start (ADR-0023 D4).
class AppLoadingScreen extends StatelessWidget {
  const AppLoadingScreen({super.key});

  @override
  Widget build(BuildContext context) => const Scaffold(
    backgroundColor: AppColors.surfaceDark,
    body: Center(child: CircularProgressIndicator(color: AppColors.accent)),
  );
}
