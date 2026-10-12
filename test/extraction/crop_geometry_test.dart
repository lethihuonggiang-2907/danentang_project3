import 'dart:ui';
import 'package:expense_tracker/features/scanner/utils/crop_geometry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CropGeometry Mathematical Unit Tests', () {
    test('Maps centered screen rect to centered pixel rect when aspect ratios match', () {
      const Size screenSize = Size(400, 800);
      const Size imageSize = Size(800, 1600); // exactly 2x scale
      const Rect screenCrop = Rect.fromLTWH(50, 100, 300, 600);

      final Rect pixelCrop = CropGeometry.mapScreenCropToImagePixels(
        screenRect: screenCrop,
        screenSize: screenSize,
        imageSize: imageSize,
      );

      expect(pixelCrop.left, 100.0);
      expect(pixelCrop.top, 200.0);
      expect(pixelCrop.width, 600.0);
      expect(pixelCrop.height, 1200.0);
    });

    test('Clamps pixel coordinates within image boundary', () {
      const Size screenSize = Size(400, 800);
      const Size imageSize = Size(1000, 1000);
      const Rect screenCrop = Rect.fromLTWH(-50, -50, 500, 900);

      final Rect pixelCrop = CropGeometry.mapScreenCropToImagePixels(
        screenRect: screenCrop,
        screenSize: screenSize,
        imageSize: imageSize,
      );

      expect(pixelCrop.left, greaterThanOrEqualTo(0.0));
      expect(pixelCrop.top, greaterThanOrEqualTo(0.0));
      expect(pixelCrop.right, lessThanOrEqualTo(1000.0));
      expect(pixelCrop.bottom, lessThanOrEqualTo(1000.0));
    });

    test('Zero size inputs return Rect.zero without divide-by-zero crash', () {
      final Rect res = CropGeometry.mapScreenCropToImagePixels(
        screenRect: const Rect.fromLTWH(0, 0, 100, 100),
        screenSize: Size.zero,
        imageSize: const Size(100, 100),
      );
      expect(res, Rect.zero);
    });

    test('mapTapToCameraFocusPoint normalizes tap coordinates to [0.0, 1.0]', () {
      const Size preview = Size(400, 800);

      final Offset centerFocus = CropGeometry.mapTapToCameraFocusPoint(
        tapOffset: const Offset(200, 400),
        previewSize: preview,
      );
      expect(centerFocus.dx, 0.5);
      expect(centerFocus.dy, 0.5);

      final Offset outOfBoundsFocus = CropGeometry.mapTapToCameraFocusPoint(
        tapOffset: const Offset(500, -100),
        previewSize: preview,
      );
      expect(outOfBoundsFocus.dx, 1.0);
      expect(outOfBoundsFocus.dy, 0.0);
    });
  });
}
