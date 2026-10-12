import 'dart:math';
import 'dart:ui';
import 'package:expense_tracker/features/charts/geometry/chart_geometry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ChartGeometry Mathematical Tests', () {
    test('Sum of sweep angles equals exactly 2 * pi for multi-category data', () {
      final Map<String, int> data = <String, int>{
        'Thực phẩm': 300000,
        'Học tập': 150000,
        'Di chuyển': 50000,
        'Giải trí': 100000,
      };

      final List<PieSliceGeometry> slices = ChartGeometry.computePieSlices(
        categoryTotals: data,
      );

      expect(slices.length, 4);

      final double totalSweep = slices.fold<double>(
        0.0,
        (double sum, PieSliceGeometry s) => sum + s.sweepAngle,
      );

      // Verify exact sum to 2*pi
      expect(totalSweep, closeTo(2 * pi, 1e-9));

      // Verify proportions: total = 600,000
      expect(slices[0].percentage, closeTo(300000 / 600000, 1e-6)); // 50%
      expect(slices[1].percentage, closeTo(150000 / 600000, 1e-6)); // 25%
      expect(slices[2].percentage, closeTo(50000 / 600000, 1e-6)); // 8.33%
      expect(slices[3].percentage, closeTo(100000 / 600000, 1e-6)); // 16.67%
    });

    test('Single category consumes entire circle (sweepAngle = 2 * pi)', () {
      final Map<String, int> data = <String, int>{
        'Thực phẩm': 500000,
      };

      final List<PieSliceGeometry> slices = ChartGeometry.computePieSlices(
        categoryTotals: data,
      );

      expect(slices.length, 1);
      expect(slices.first.percentage, 1.0);
      expect(slices.first.sweepAngle, closeTo(2 * pi, 1e-9));
    });

    test('Empty data returns empty list without error', () {
      final List<PieSliceGeometry> slices = ChartGeometry.computePieSlices(
        categoryTotals: <String, int>{},
      );
      expect(slices, isEmpty);
    });

    test('Zero values are filtered out without crashing or zero-division', () {
      final Map<String, int> data = <String, int>{
        'Thực phẩm': 200000,
        'Du lịch': 0,
        'Giải trí': 0,
      };

      final List<PieSliceGeometry> slices = ChartGeometry.computePieSlices(
        categoryTotals: data,
      );

      expect(slices.length, 1);
      expect(slices.first.label, 'Thực phẩm');
      expect(slices.first.sweepAngle, closeTo(2 * pi, 1e-9));
    });

    test('All zero values return empty list safely', () {
      final Map<String, int> data = <String, int>{
        'Thực phẩm': 0,
        'Du lịch': 0,
      };

      final List<PieSliceGeometry> slices = ChartGeometry.computePieSlices(
        categoryTotals: data,
      );
      expect(slices, isEmpty);
    });

    test('Hit testing detects tapped slice correctly', () {
      final Map<String, int> data = <String, int>{
        'Thực phẩm': 50000, // 50%
        'Học tập': 50000, // 50%
      };

      final List<PieSliceGeometry> slices = ChartGeometry.computePieSlices(
        categoryTotals: data,
        startAngleOffset: 0, // Starts at 3 o'clock (0 rad)
      );

      const Offset center = Offset(100, 100);
      const double radius = 80;

      // Tap on right half (Slice 0: angle 0 to pi, e.g., Offset(150, 120))
      final int? hit0 = ChartGeometry.hitTestPieSlice(
        touchPoint: const Offset(150, 120),
        center: center,
        outerRadius: radius,
        slices: slices,
      );
      expect(hit0, 0);

      // Tap outside circle should return null
      final int? hitOutside = ChartGeometry.hitTestPieSlice(
        touchPoint: const Offset(200, 200),
        center: center,
        outerRadius: radius,
        slices: slices,
      );
      expect(hitOutside, isNull);
    });

    test('Bar geometry computes 7 daily bars with proportional heights', () {
      final DateTime monday = DateTime(2026, 10, 12);
      final Map<DateTime, int> daily = <DateTime, int>{
        monday: 100000,
        monday.add(const Duration(days: 1)): 200000, // max
        monday.add(const Duration(days: 2)): 50000,
        monday.add(const Duration(days: 3)): 0,
        monday.add(const Duration(days: 4)): 150000,
        monday.add(const Duration(days: 5)): 80000,
        monday.add(const Duration(days: 6)): 20000,
      };

      final List<BarGeometry> bars = ChartGeometry.computeBars(
        dailyTotals: daily,
        canvasSize: const Size(350, 200),
      );

      expect(bars.length, 7);
      expect(bars[1].normalizedHeight, 1.0); // max value (200,000)
      expect(bars[0].normalizedHeight, 0.5); // 100,000 / 200,000
      expect(bars[3].normalizedHeight, 0.0); // 0
      expect(bars[0].dayLabel, 'T2');
      expect(bars[6].dayLabel, 'CN');
    });
  });
}
