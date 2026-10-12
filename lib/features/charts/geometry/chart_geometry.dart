import 'dart:math';
import 'dart:ui';

/// Pure geometric data structure representing a slice in a pie or donut chart.
class PieSliceGeometry {
  final int index;
  final String label;
  final int value;
  final double percentage; // 0.0 to 1.0
  final double startAngle; // radians
  final double sweepAngle; // radians

  const PieSliceGeometry({
    required this.index,
    required this.label,
    required this.value,
    required this.percentage,
    required this.startAngle,
    required this.sweepAngle,
  });

  @override
  String toString() {
    return 'PieSliceGeometry(label: $label, value: $value, pct: ${(percentage * 100).toStringAsFixed(1)}%, start: $startAngle, sweep: $sweepAngle)';
  }
}

/// Pure geometric data structure representing a column in a bar chart.
class BarGeometry {
  final int index;
  final DateTime date;
  final String dayLabel;
  final int value;
  final double normalizedHeight; // 0.0 to 1.0
  final Rect rect;

  const BarGeometry({
    required this.index,
    required this.date,
    required this.dayLabel,
    required this.value,
    required this.normalizedHeight,
    required this.rect,
  });

  @override
  String toString() {
    return 'BarGeometry(day: $dayLabel, value: $value, rect: $rect)';
  }
}

/// Pure math computational geometry engine for chart projection and hit-testing.
class ChartGeometry {
  ChartGeometry._();

  /// Computes start and sweep angles for a set of category values.
  /// Guarantees that the sum of sweep angles equals 2 * pi for non-empty positive data.
  static List<PieSliceGeometry> computePieSlices({
    required Map<String, int> categoryTotals,
    double startAngleOffset = -pi / 2, // Start at 12 o'clock by default
  }) {
    // Filter out zero or negative values
    final List<MapEntry<String, int>> positiveEntries = categoryTotals.entries
        .where((MapEntry<String, int> e) => e.value > 0)
        .toList();

    if (positiveEntries.isEmpty) {
      return <PieSliceGeometry>[];
    }

    final int totalSum = positiveEntries.fold<int>(
      0,
      (int sum, MapEntry<String, int> e) => sum + e.value,
    );

    if (totalSum <= 0) {
      return <PieSliceGeometry>[];
    }

    // Special case: Single category consumes entire 2*pi circle
    if (positiveEntries.length == 1) {
      final MapEntry<String, int> single = positiveEntries.first;
      return <PieSliceGeometry>[
        PieSliceGeometry(
          index: 0,
          label: single.key,
          value: single.value,
          percentage: 1.0,
          startAngle: startAngleOffset,
          sweepAngle: 2 * pi,
        ),
      ];
    }

    final List<PieSliceGeometry> slices = <PieSliceGeometry>[];
    double currentAngle = startAngleOffset;
    double accumulatedSweep = 0.0;

    for (int i = 0; i < positiveEntries.length; i++) {
      final MapEntry<String, int> entry = positiveEntries[i];
      final double fraction = entry.value / totalSum;

      // For the last slice, ensure the total sum of sweeps equals exactly 2*pi
      final double sweep;
      if (i == positiveEntries.length - 1) {
        sweep = (2 * pi) - accumulatedSweep;
      } else {
        sweep = fraction * 2 * pi;
        accumulatedSweep += sweep;
      }

      slices.add(
        PieSliceGeometry(
          index: i,
          label: entry.key,
          value: entry.value,
          percentage: fraction,
          startAngle: currentAngle,
          sweepAngle: sweep,
        ),
      );

      currentAngle += sweep;
    }

    return slices;
  }

  /// Determines which pie slice was tapped given a touch point in the local coordinate space.
  /// Returns the slice index, or null if tapped outside the pie/donut ring.
  static int? hitTestPieSlice({
    required Offset touchPoint,
    required Offset center,
    required double outerRadius,
    double innerRadius = 0.0,
    required List<PieSliceGeometry> slices,
  }) {
    if (slices.isEmpty) return null;

    final double dx = touchPoint.dx - center.dx;
    final double dy = touchPoint.dy - center.dy;
    final double distance = sqrt(dx * dx + dy * dy);

    // Verify distance is within the ring boundary
    if (distance < innerRadius || distance > outerRadius) {
      return null;
    }

    // Compute angle in radians [-pi, pi]
    double touchAngle = atan2(dy, dx);

    // Normalize touchAngle and slice startAngles to [0, 2*pi)
    for (final PieSliceGeometry slice in slices) {
      // Normalize angle relative to slice.startAngle
      double diff = (touchAngle - slice.startAngle) % (2 * pi);
      if (diff < 0) diff += 2 * pi;

      if (diff >= 0 && diff <= slice.sweepAngle) {
        return slice.index;
      }
    }

    return null;
  }

  /// Computes bar coordinates and normalized heights for daily spending.
  static List<BarGeometry> computeBars({
    required Map<DateTime, int> dailyTotals,
    required Size canvasSize,
    double topPadding = 30.0,
    double bottomPadding = 40.0,
    double sidePadding = 16.0,
  }) {
    if (dailyTotals.isEmpty) return <BarGeometry>[];

    final List<MapEntry<DateTime, int>> entries = dailyTotals.entries.toList();
    final int maxValue = entries.fold<int>(
      0,
      (int maxVal, MapEntry<DateTime, int> e) => e.value > maxVal ? e.value : maxVal,
    );

    final double availableWidth = canvasSize.width - (sidePadding * 2);
    final double availableHeight = canvasSize.height - topPadding - bottomPadding;
    final int count = entries.length;

    final double slotWidth = availableWidth / count;
    final double barWidth = slotWidth * 0.55;

    final List<BarGeometry> bars = <BarGeometry>[];

    for (int i = 0; i < count; i++) {
      final MapEntry<DateTime, int> entry = entries[i];
      final double normalized = maxValue > 0 ? (entry.value / maxValue) : 0.0;
      final double barHeight = availableHeight * normalized;

      final double left = sidePadding + (i * slotWidth) + ((slotWidth - barWidth) / 2);
      final double top = canvasSize.height - bottomPadding - barHeight;

      final Rect rect = Rect.fromLTWH(left, top, barWidth, barHeight);

      final String dayLabel = _getDayName(entry.key.weekday);

      bars.add(
        BarGeometry(
          index: i,
          date: entry.key,
          dayLabel: dayLabel,
          value: entry.value,
          normalizedHeight: normalized,
          rect: rect,
        ),
      );
    }

    return bars;
  }

  /// Determines which bar was tapped.
  static int? hitTestBar({
    required Offset touchPoint,
    required List<BarGeometry> bars,
    double hitSlopX = 12.0,
  }) {
    for (final BarGeometry bar in bars) {
      // Allow slightly wider horizontal tap area for friendly touch target
      final Rect expandedRect = Rect.fromLTRB(
        bar.rect.left - hitSlopX,
        0,
        bar.rect.right + hitSlopX,
        bar.rect.bottom + 20,
      );

      if (expandedRect.contains(touchPoint)) {
        return bar.index;
      }
    }
    return null;
  }

  static String _getDayName(int weekday) {
    switch (weekday) {
      case DateTime.monday:
        return 'T2';
      case DateTime.tuesday:
        return 'T3';
      case DateTime.wednesday:
        return 'T4';
      case DateTime.thursday:
        return 'T5';
      case DateTime.friday:
        return 'T6';
      case DateTime.saturday:
        return 'T7';
      case DateTime.sunday:
        return 'CN';
      default:
        return '';
    }
  }
}
