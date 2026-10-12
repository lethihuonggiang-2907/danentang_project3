import 'dart:math';
import 'package:flutter/material.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../transactions/utils/category_helper.dart';
import '../geometry/chart_geometry.dart';

/// CustomPainter that renders a Donut Chart with a center hole displaying total expenditure.
class DonutChartPainter extends CustomPainter {
  final List<PieSliceGeometry> slices;
  final int? selectedIndex;
  final double animationProgress;
  final int totalAmount;
  final Color textColor;

  DonutChartPainter({
    required this.slices,
    this.selectedIndex,
    required this.animationProgress,
    required this.totalAmount,
    required this.textColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (slices.isEmpty) return;

    final Offset center = Offset(size.width / 2, size.height / 2);
    final double outerRadius = min(size.width, size.height) / 2 * 0.85;
    final double innerRadius = outerRadius * 0.58;

    // Draw donut ring slices
    for (final PieSliceGeometry slice in slices) {
      final bool isSelected = slice.index == selectedIndex;
      final double sliceOuterRadius = isSelected ? outerRadius + 8 : outerRadius;

      final Color color = CategoryHelper.getColor(slice.label);

      final Paint strokePaint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = (sliceOuterRadius - innerRadius)
        ..isAntiAlias = true;

      final double midRadius = (sliceOuterRadius + innerRadius) / 2;
      final Rect ringRect = Rect.fromCircle(center: center, radius: midRadius);

      final double sweep = slice.sweepAngle * animationProgress;

      canvas.drawArc(ringRect, slice.startAngle, sweep, false, strokePaint);
    }

    // Draw center text: Total amount
    final String labelText = selectedIndex != null && selectedIndex! < slices.length
        ? slices[selectedIndex!].label
        : 'Tổng chi tiêu';

    final String amountText = selectedIndex != null && selectedIndex! < slices.length
        ? CurrencyFormatter.formatVND(slices[selectedIndex!].value)
        : CurrencyFormatter.formatVND(totalAmount);

    final TextPainter titlePainter = TextPainter(
      text: TextSpan(
        text: labelText,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: textColor.withValues(alpha: 0.7),
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout(maxWidth: innerRadius * 1.8);

    final TextPainter amountPainter = TextPainter(
      text: TextSpan(
        text: amountText,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: textColor,
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout(maxWidth: innerRadius * 1.8);

    final double totalTextHeight = titlePainter.height + amountPainter.height + 4;
    final double startY = center.dy - (totalTextHeight / 2);

    titlePainter.paint(
      canvas,
      Offset(center.dx - (titlePainter.width / 2), startY),
    );
    amountPainter.paint(
      canvas,
      Offset(center.dx - (amountPainter.width / 2), startY + titlePainter.height + 4),
    );
  }

  @override
  bool shouldRepaint(covariant DonutChartPainter oldDelegate) {
    return oldDelegate.slices != slices ||
        oldDelegate.selectedIndex != selectedIndex ||
        oldDelegate.animationProgress != animationProgress ||
        oldDelegate.totalAmount != totalAmount ||
        oldDelegate.textColor != textColor;
  }
}
