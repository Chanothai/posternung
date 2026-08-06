import 'package:flutter/material.dart';

import '../design_system/app_dimens.dart';
import '../design_system/app_radius.dart';
import '../design_system/app_spacing.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

/// Which accent a status view carries. Only the icon tint and its halo
/// differ — the copy, card and action are identical, so a failure and an
/// empty catalog read as the same kind of message rather than two
/// unrelated screens.
enum AppStatusTone {
  /// Something went wrong and may succeed on a retry.
  error,

  /// A legitimate answer that just has nothing in it (empty catalog,
  /// nothing found). Not a failure — never tinted red.
  neutral,
}

/// The one screen-level "nothing to show here" block: error, empty, and
/// not-found states across features all render through this.
///
/// It exists because those states were previously hand-rolled per feature
/// and drifted apart from the app's own theme: they reused `authCardHeading`
/// (an auth *page* title) for a section-level heading, and their retry
/// buttons carried **no** [AppTextStyles] at all — a bare `OutlinedButton`
/// falls back to the `ThemeData` default, which in this app is an unstyled
/// `ColorScheme.fromSeed(deepPurple)`, so the label rendered in Roboto and
/// seed-purple on a warm dark background, next to Kanit everywhere else.
/// Every visual decision here is a token from `theme/`/`design_system/`.
class AppStatusView extends StatelessWidget {
  const AppStatusView({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
    this.tone = AppStatusTone.neutral,
    this.actionLabel,
    this.actionIcon,
    this.onAction,
  }) : assert(
         (actionLabel == null) == (onAction == null),
         'An action needs both a label and a callback, or neither.',
       );

  final IconData icon;
  final String title;

  /// The explanation under [title]. Call sites resolve this through the
  /// ADR-0017 D4/D9 mapper (`catalogErrorDisplayMessage`/`authErrorDisplay`
  /// — never a raw `CatalogException`/`AuthException` field directly) so the
  /// user sees what actually failed instead of one generic line for every
  /// cause, without a hand-rolled `is CatalogException` check at each site.
  final String body;

  final AppStatusTone tone;

  /// Optional call to action. Omitted for states where acting is pointless
  /// — an empty catalog returns the same empty catalog on retry, and a
  /// 404 id cannot start existing.
  final String? actionLabel;
  final IconData? actionIcon;
  final VoidCallback? onAction;

  Color get _iconColor => switch (tone) {
    AppStatusTone.error => AppColors.accentRed,
    AppStatusTone.neutral => AppColors.textSecondary,
  };

  Color get _haloColor => switch (tone) {
    AppStatusTone.error => AppColors.accentRedSoft,
    AppStatusTone.neutral => AppColors.accentSoft,
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xl,
        vertical: AppSpacing.xxl,
      ),
      decoration: BoxDecoration(
        // Same glass treatment as the auth cards, so a state block reads as
        // part of the app rather than raw text dropped on the background.
        color: AppColors.glassCardFill,
        border: Border.all(color: AppColors.glassCardBorder),
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: _haloSize,
            height: _haloSize,
            decoration: BoxDecoration(
              color: _haloColor,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: AppDimens.iconLg, color: _iconColor),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            title,
            style: AppTextStyles.statusTitle,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            body,
            style: AppTextStyles.statusBody,
            textAlign: TextAlign.center,
          ),
          if (actionLabel != null) ...[
            const SizedBox(height: AppSpacing.xl),
            _StatusAction(
              label: actionLabel!,
              icon: actionIcon,
              onPressed: onAction!,
            ),
          ],
        ],
      ),
    );
  }

  /// Icon + breathing room around it. Not a token: it's derived from
  /// [AppDimens.iconLg], and exists only inside this widget.
  static const double _haloSize = AppDimens.iconLg * 2;
}

/// The pill CTA. Shaped like the rest of the app's pill buttons
/// (`AppRadius.full`, the same border/label treatment as Home's
/// "โหลดเพิ่มเติม" pager — `home_load_more_footer.dart`), tinted with
/// [AppColors.accent] rather than the Material default so the one
/// actionable element on a failed screen is visible on the dark background.
class _StatusAction extends StatelessWidget {
  const _StatusAction({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final IconData? icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final style = OutlinedButton.styleFrom(
      foregroundColor: AppColors.textPrimary,
      side: const BorderSide(color: AppColors.accent),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xl,
        vertical: AppSpacing.md,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
    );
    final text = Text(label, style: AppTextStyles.statusActionLabel);

    if (icon == null) {
      return OutlinedButton(onPressed: onPressed, style: style, child: text);
    }
    return OutlinedButton.icon(
      onPressed: onPressed,
      style: style,
      icon: Icon(icon, size: AppDimens.iconSm, color: AppColors.accent),
      label: text,
    );
  }
}
