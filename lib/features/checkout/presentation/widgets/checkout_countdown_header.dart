import 'package:flutter/material.dart';

import '../../../../core/design_system/app_spacing.dart';
import '../../../../core/strings/app_strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

/// The pinned "time remaining" banner (SCR-07 AC-8 — "ต้องเห็นตลอดหน้า").
/// A [SliverPersistentHeader] so it stays visible while the form below it
/// scrolls, per `docs/status/gates/SCR-07-sliceB-gate1.md` §3 step 4.
class CheckoutCountdownHeader extends StatelessWidget {
  const CheckoutCountdownHeader({required this.remaining, super.key});

  final Duration remaining;

  static const double _height = 56;

  @override
  Widget build(BuildContext context) {
    return SliverPersistentHeader(
      pinned: true,
      delegate: _CountdownHeaderDelegate(remaining: remaining),
    );
  }
}

/// mm:ss, hand-formatted — no `intl` in this project. Clamped at 99:59 so a
/// stale/negative span (should never happen — `ReservationCountdownNotifier`
/// already floors at [Duration.zero]) can never render a negative sign.
String formatCountdownMmSs(Duration remaining) {
  final Duration safe = remaining.isNegative ? Duration.zero : remaining;
  final int totalSeconds = safe.inSeconds.clamp(0, 99 * 60 + 59);
  final int minutes = totalSeconds ~/ 60;
  final int seconds = totalSeconds % 60;
  return '${minutes.toString().padLeft(2, '0')}:'
      '${seconds.toString().padLeft(2, '0')}';
}

class _CountdownHeaderDelegate extends SliverPersistentHeaderDelegate {
  const _CountdownHeaderDelegate({required this.remaining});

  final Duration remaining;

  @override
  double get minExtent => CheckoutCountdownHeader._height;

  @override
  double get maxExtent => CheckoutCountdownHeader._height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(
      height: CheckoutCountdownHeader._height,
      color: AppColors.surfaceDark,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      alignment: Alignment.centerLeft,
      child: Row(
        children: [
          Expanded(
            child: Text(
              AppStrings.checkoutCountdownLabel,
              style: AppTextStyles.cardSubtitle,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Text(
            formatCountdownMmSs(remaining),
            style: AppTextStyles.authCardHeading,
          ),
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _CountdownHeaderDelegate oldDelegate) =>
      oldDelegate.remaining != remaining;
}
