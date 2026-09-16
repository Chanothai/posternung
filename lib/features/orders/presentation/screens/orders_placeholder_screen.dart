import 'package:flutter/material.dart';

import '../../../../core/design_system/app_spacing.dart';
import '../../../../core/strings/app_strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_bottom_nav_bar.dart';
import '../../../../core/widgets/app_status_view.dart';
import '../../../../core/widgets/gradient_background.dart';
import '../../../../core/widgets/tab_back_to_home_scope.dart';

/// SCR-07 B7 — the orders tab. Placeholder only: no `GET /orders` call
/// exists yet, so there is nothing here beyond the "no orders" message and
/// the bottom nav. SCR-09 replaces this with the real list.
///
/// 🔴 `A4-D1` is explicit that `OrderCreatedView` (the screen shown right
/// after `POST /orders` succeeds) must never route here — a screen saying
/// "ยังไม่มีคำสั่งซื้อ" right after placing one would tell the user their
/// order both exists and doesn't, in the same flow.
///
/// No `data/`/`domain/` folder: this screen doesn't talk to a repository
/// (root `CLAUDE.md`'s "don't scaffold an empty layer" rule) — add both,
/// plus a `presentation/providers/` and `presentation/state/`, the moment
/// SCR-09 wires up the real endpoint.
class OrdersPlaceholderScreen extends StatelessWidget {
  const OrdersPlaceholderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return TabBackToHomeScope(
      child: Scaffold(
        backgroundColor: AppColors.surfaceDark,
        body: Stack(
          fit: StackFit.expand,
          children: [
            const AppGradientBackground(),
            const SafeArea(
              bottom: false,
              child: Center(
                child: Padding(
                  padding: EdgeInsets.all(AppSpacing.xl),
                  child: AppStatusView(
                    icon: Icons.receipt_long_outlined,
                    title: AppStrings.ordersPlaceholderTitle,
                    body: AppStrings.ordersPlaceholderBody,
                  ),
                ),
              ),
            ),
          ],
        ),
        bottomNavigationBar: const AppBottomNavBar(),
      ),
    );
  }
}
