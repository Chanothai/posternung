import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// Draws a dashed circular stroke behind [child], sized to fill the
/// available space. Used for the onboarding badge's dashed ring — Flutter
/// has no built-in dashed border, so this is a small local painter rather
/// than pulling in a package for a single shape.
class DashedCircleBorder extends StatelessWidget {
  const DashedCircleBorder({
    super.key,
    required this.child,
    this.color = AppColors.borderMuted,
    this.strokeWidth = 2,
    this.dashWidth = 6,
    this.gapWidth = 4,
  });

  final Widget child;
  final Color color;
  final double strokeWidth;
  final double dashWidth;
  final double gapWidth;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DashedCirclePainter(
        color: color,
        strokeWidth: strokeWidth,
        dashWidth: dashWidth,
        gapWidth: gapWidth,
      ),
      child: child,
    );
  }
}

class _DashedCirclePainter extends CustomPainter {
  _DashedCirclePainter({
    required this.color,
    required this.strokeWidth,
    required this.dashWidth,
    required this.gapWidth,
  });

  final Color color;
  final double strokeWidth;
  final double dashWidth;
  final double gapWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    final radius = (size.shortestSide - strokeWidth) / 2;
    final path = Path()
      ..addOval(
        Rect.fromCircle(center: size.center(Offset.zero), radius: radius),
      );

    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final next = distance + dashWidth;
        canvas.drawPath(
          metric.extractPath(distance, next.clamp(0, metric.length)),
          paint,
        );
        distance = next + gapWidth;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedCirclePainter oldDelegate) {
    return color != oldDelegate.color ||
        strokeWidth != oldDelegate.strokeWidth ||
        dashWidth != oldDelegate.dashWidth ||
        gapWidth != oldDelegate.gapWidth;
  }
}
