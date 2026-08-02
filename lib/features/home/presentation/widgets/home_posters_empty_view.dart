import 'package:flutter/material.dart';

import '../../../../core/design_system/app_spacing.dart';
import '../../../../core/strings/app_strings.dart';
import '../../../../core/widgets/app_status_view.dart';

/// SCR-03's `empty` required state — `total == 0`, i.e. the catalog itself
/// has nothing, which is a legitimate answer and not a failure. Hence
/// [AppStatusTone.neutral] and no action: retrying an empty catalog just
/// returns the same empty catalog.
class HomePostersEmptyView extends StatelessWidget {
  const HomePostersEmptyView({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
      child: AppStatusView(
        icon: Icons.inbox_outlined,
        title: AppStrings.homePostersEmptyTitle,
        body: AppStrings.homePostersEmptyBody,
      ),
    );
  }
}
