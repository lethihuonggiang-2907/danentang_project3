import 'package:flutter/material.dart';

/// Overlay widget providing a darkened mask with a translucent cutout and corner brackets
/// to guide receipt framing.
class CameraCropOverlay extends StatelessWidget {
  final Rect cropRect;

  const CameraCropOverlay({
    super.key,
    required this.cropRect,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.infinite,
      painter: _CropOverlayPainter(cropRect: cropRect),
    );
  }
}

class _CropOverlayPainter extends CustomPainter {
  final Rect cropRect;

  _CropOverlayPainter({required this.cropRect});

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Draw darkened overlay outside the crop rect
    final Path screenPath = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    final Path cropPath = Path()
      ..addRRect(RRect.fromRectAndRadius(cropRect, const Radius.circular(16)));

    final Path maskPath = Path.combine(
      PathOperation.difference,
      screenPath,
      cropPath,
    );

    final Paint maskPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.55)
      ..style = PaintingStyle.fill;

    canvas.drawPath(maskPath, maskPaint);

    // 2. Draw border
    final Paint borderPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    canvas.drawRRect(
      RRect.fromRectAndRadius(cropRect, const Radius.circular(16)),
      borderPaint,
    );

    // 3. Draw 4 bright corner brackets
    final Paint cornerPaint = Paint()
      ..color = const Color(0xFF00E676) // Bright emerald accent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0
      ..strokeCap = StrokeCap.round;

    const double cornerLength = 26.0;

    // Top-Left
    canvas.drawLine(
      Offset(cropRect.left, cropRect.top + cornerLength),
      Offset(cropRect.left, cropRect.top),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(cropRect.left, cropRect.top),
      Offset(cropRect.left + cornerLength, cropRect.top),
      cornerPaint,
    );

    // Top-Right
    canvas.drawLine(
      Offset(cropRect.right - cornerLength, cropRect.top),
      Offset(cropRect.right, cropRect.top),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(cropRect.right, cropRect.top),
      Offset(cropRect.right, cropRect.top + cornerLength),
      cornerPaint,
    );

    // Bottom-Left
    canvas.drawLine(
      Offset(cropRect.left, cropRect.bottom - cornerLength),
      Offset(cropRect.left, cropRect.bottom),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(cropRect.left, cropRect.bottom),
      Offset(cropRect.left + cornerLength, cropRect.bottom),
      cornerPaint,
    );

    // Bottom-Right
    canvas.drawLine(
      Offset(cropRect.right - cornerLength, cropRect.bottom),
      Offset(cropRect.right, cropRect.bottom),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(cropRect.right, cropRect.bottom - cornerLength),
      Offset(cropRect.right, cropRect.bottom),
      cornerPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _CropOverlayPainter oldDelegate) {
    return oldDelegate.cropRect != cropRect;
  }
}
