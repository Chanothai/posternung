import 'dart:ui';

import 'package:flutter/material.dart';

import '../design_system/app_dimens.dart';
import '../theme/app_colors.dart';

/// The 40px translucent glass button (ADR-0012 §D1 7:981) both the back
/// button and the zoom action of SCR-05 render as — `rgba(0,0,0,0.4)` fill,
/// blurred backdrop, and a faint `rgba(255,255,255,0.1)` ring, floating
/// directly on the image rather than sitting in an opaque bar. Wraps a real
/// `IconButton` rather than a bare `GestureDetector` so the
/// tooltip/semantics/ripple behaviour every call site already relied on
/// keeps working unchanged.
///
/// Lifted out of `poster_detail_screen.dart` (where it was the private
/// `_GlassCircleButton`) in SCR-07 B9 so `/checkout` can render the same
/// header back button SCR-05 has — the code is the original, moved, not
/// rewritten.
///
/// 🔴 code-critic round 1 (Medium) measured the first version of this
/// widget's actual tap target at 38×38 — the *whole* button (glass circle
/// **and** its `IconButton`) was sized to the 40px visual diameter, short of
/// both Material's 48dp and Apple's 44pt minimums, on a control that AC-1
/// gates inspecting condition before a non-refundable purchase (ADR-0002).
/// The visual stays exactly 40px (ADR-0012 §D1 is about the glass circle's
/// look, not the tap target); only `IconButton.constraints` grows to
/// [hitArea] now, via the `icon:` slot rather than the outer size — the
/// glass circle becomes the *content* `IconButton` centers inside its own
/// larger, invisible hit box, instead of being the box.
class GlassCircleButton extends StatelessWidget {
  const GlassCircleButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    super.key,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  static const _diameter = 40.0;

  /// Material's 48dp / Apple HIG's 44pt minimum touch target — see the
  /// class doc.
  static const hitArea = 48.0;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints.tightFor(
        width: hitArea,
        height: hitArea,
      ),
      onPressed: onPressed,
      tooltip: tooltip,
      icon: ClipOval(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Container(
            width: _diameter,
            height: _diameter,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.black.withValues(alpha: 0.4),
              border: Border.all(color: AppColors.white.withValues(alpha: 0.1)),
            ),
            child: Icon(
              icon,
              size: AppDimens.iconMd,
              color: AppColors.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}
