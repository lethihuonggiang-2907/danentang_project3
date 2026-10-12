import 'package:flutter/material.dart';
import '../../../core/utils/currency_formatter.dart';
import '../geometry/chart_geometry.dart';

/// CustomPainter that renders a 7-day Weekly Bar Chart with animated bars and value tooltips.
class BarChartPainter extends CustomPainter {
  final List<BarGeometry> bars;
  final int? selectedIndex;
  final double animationProgress;
  final Color primaryColor;
  final Color highlightColor;
  final Color textColor;

  BarChartPainter({
    required this.bars,
    this.selectedIndex,
    required this.animationProgress,
    required this.primaryColor,
    required this.highlightColor,
    required this.textColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (bars.isEmpty) return;

    final double baselineY = size.height - 35.0;

    // 1. Draw dashed/subtle baseline
    final Paint linePaint = Paint()
      ..color = textColor.withValues(alpha: 0.15)
      ..strokeWidth = 1.0;

    canvas.drawLine(Offset(10, baselineY), Offset(size.width - 10, baselineY), linePaint);

    // 2. Draw bars
    for (final BarGeometry bar in bars) {
      final bool isSelected = bar.index == selectedIndex;

      // Animated height from baseline upwards
      final double fullHeight = bar.rect.height;
      final double animatedHeight = fullHeight * animationProgress;
      final double currentTop = baselineY - animatedHeight;

      final Rect animatedRect = Rect.fromLTRB(
        bar.rect.left,
        currentTop,
        bar.rect.right,
        baselineY,
      );

      final RRect roundedBar = RRect.fromRectAndCorners(
        animatedRect,
        topLeft: const Radius.circular(8),
        topRight: const Radius.circular(8),
      );

      // Bar fill color
      final Paint barPaint = Paint()
        ..color = isSelected
            ? highlightColor
            : (bar.value > 0 ? primaryColor : textColor.withValues(alpha: 0.1))
        ..style = PaintingStyle.fill;

      canvas.drawRRect(roundedBar, barPaint);

      // Selected bar border
      if (isSelected) {
        final Paint borderPaint = Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0;
        canvas.drawRRect(roundedBar, borderPaint);
      }

      // 3. Day label below bar (T2, T3, ...)
      final TextPainter dayPainter = TextPainter(
        text: TextSpan(
          text: bar.dayLabel,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? highlightColor : textColor.withValues(alpha: 0.7),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      dayPainter.paint(
        canvas,
        Offset(
          bar.rect.center.dx - (dayPainter.width / 2),
          baselineY + 8,
        ),
      );

      // 4. Value label above bar if selected or non-zero
      if (isSelected && bar.value > 0) {
        final String formatted = CurrencyFormatter.formatVND(bar.value);
        final TextPainter valuePainter = TextPainter(
          text: TextSpan(
            text: formatted,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();

        final double badgeW = valuePainter.width + 10;
        final double badgeH = valuePainter.height + 6;
        final double badgeX = bar.rect.center.dx - (badgeW / 2);
        final double badgeY = currentTop - badgeH - 6;

        final RRect badgeRect = RRect.fromRectAndRadius(
          Rect.fromLTWH(badgeX, badgeY, badgeW, badgeH),
          const Radius.circular(6),
        );

        final Paint badgePaint = Paint()
          ..color = highlightColor
          ..style = PaintingStyle.fill;

        canvas.drawRRect(badgeRect, badgePaint);
        valuePainter.paint(
          canvas,
          Offset(badgeX + 5, badgeY + 3),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant BarChartPainter oldDelegate) {
    return oldDelegate.bars != bars ||
        oldDelegate.selectedIndex != selectedIndex ||
        oldDelegate.animationProgress != animationProgress ||
        oldDelegate.primaryColor != primaryColor ||
        oldDelegate.highlightColor != highlightColor ||
        oldDelegate.textColor != textColor;
  }
}
