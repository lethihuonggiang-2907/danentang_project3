import 'dart:math';
import 'package:flutter/material.dart';
import '../../transactions/utils/category_helper.dart';
import '../geometry/chart_geometry.dart';

/// CustomPainter that renders a Pie Chart using geometry computed by ChartGeometry.
class PieChartPainter extends CustomPainter {
  final List<PieSliceGeometry> slices;
  final int? selectedIndex;
  final double animationProgress;

  PieChartPainter({
    required this.slices,
    this.selectedIndex,
    required this.animationProgress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (slices.isEmpty) return;

    final Offset center = Offset(size.width / 2, size.height / 2);
    final double baseRadius = min(size.width, size.height) / 2 * 0.85;

    for (final PieSliceGeometry slice in slices) {
      final bool isSelected = slice.index == selectedIndex;
      final double sliceRadius = isSelected ? baseRadius + 8 : baseRadius;

      // Color from CategoryHelper
      final Color color = CategoryHelper.getColor(slice.label);

      final Paint fillPaint = Paint()
        ..color = color
        ..style = PaintingStyle.fill
        ..isAntiAlias = true;

      final Paint borderPaint = Paint()
        ..color = isSelected ? Colors.white : Colors.white.withValues(alpha: 0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = isSelected ? 3.0 : 1.5
        ..isAntiAlias = true;

      // Scaled sweep angle according to entry animation
      final double sweep = slice.sweepAngle * animationProgress;

      final Rect rect = Rect.fromCircle(center: center, radius: sliceRadius);

      // Draw slice
      canvas.drawArc(rect, slice.startAngle, sweep, true, fillPaint);
      canvas.drawArc(rect, slice.startAngle, sweep, true, borderPaint);
    }
  }

  @override
  bool shouldRepaint(covariant PieChartPainter oldDelegate) {
    return oldDelegate.slices != slices ||
        oldDelegate.selectedIndex != selectedIndex ||
        oldDelegate.animationProgress != animationProgress;
  }
}
