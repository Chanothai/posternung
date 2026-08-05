import 'package:flutter/material.dart';

import '../../../../core/catalog/restoration_status.dart';
import '../../../../core/design_system/app_spacing.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

/// ADR-0011 §D2 — a fact-only badge shown beside/near the condition grade
/// (OD-1: as a separate line under the price/grade row) for
/// [RestorationStatus.restored] / [RestorationStatus.linenBacked]. Both
/// values mean the visible condition is an *apparent* grade — the buyer
/// needs to see this without expanding the details accordion, which is why
/// it does not live there like [RestorationStatus] siblings do.
///
/// 🔴 This widget never computes, adjusts, or re-labels the condition grade
/// itself — that is owned entirely by ADR-0003 / `ConditionGradeIndicator`.
/// It only renders next to it.
///
/// [RestorationStatus.none] and `null` render nothing — declaring a sheet
/// "not restored" is a positive claim about it that Phase 1 has no
/// mechanism to back up (ADR-0011 §D2).
///
/// [RestorationStatus.unknown] **also** renders nothing — ADR-0011
/// §Amendment (2) / D2′, decided by the user at GATE 3. Round 1 of this
/// feature (H1, code-critic) had this render like `RESTORED`/`LINEN_BACKED`
/// on the theory that §D7's `NULL`≠`UNKNOWN` rule applied here too; the
/// user overturned that at GATE 3 and made `restoration_status` an
/// explicit exception to §D7 (revised AC-10: "RESTORED หรือ LINEN_BACKED
/// **เท่านั้น** ต้องเห็นได้"). §D7 still applies in full to every other
/// field (`release_region`/`poster_type`/`size_format`) — this exception is
/// scoped to this one badge, not a reversal of §D7 itself. Reasoning: this
/// badge's only job is to warn that the grade next to it is an *apparent*
/// grade (ADR-0009 §D5); "checked, couldn't tell" isn't a warning and would
/// just borrow the attention reserved for one. `UNKNOWN` isn't erased from
/// the system — it simply has no place on screen yet.
class PosterRestorationBadge extends StatelessWidget {
  const PosterRestorationBadge({super.key, required this.status});

  final RestorationStatus? status;

  /// Single source of truth for "does this status get a badge at all" —
  /// both this widget's own [build] and `PosterDetailScreen` (which needs
  /// to know whether to add the spacing line above this widget) call
  /// through here, so the rule lives in exactly one place rather than being
  /// duplicated and risking drift between the two (workspace `CLAUDE.md`:
  /// "กฎหนึ่งข้อมีที่อยู่ที่เดียว"). `NONE`/[RestorationStatus.unknown]/`null`
  /// all return `false` — see the class doc for why `UNKNOWN` is grouped
  /// with the other two here despite §D7 elsewhere.
  static bool showsFor(RestorationStatus? status) =>
      status == RestorationStatus.restored ||
      status == RestorationStatus.linenBacked;

  @override
  Widget build(BuildContext context) {
    if (!showsFor(status)) return const SizedBox.shrink();

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(
          Icons.history_edu_outlined,
          size: 14,
          color: AppColors.textSecondary,
        ),
        const SizedBox(width: AppSpacing.xs),
        Text(
          status!.label,
          style: AppTextStyles.homePosterSubtitle.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}
