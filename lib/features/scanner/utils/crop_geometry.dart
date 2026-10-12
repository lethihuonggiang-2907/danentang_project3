import 'dart:ui';

/// Pure math computational utility to map screen viewport crop frame
/// onto raw captured camera image pixel coordinates.
class CropGeometry {
  CropGeometry._();

  /// Maps a crop overlay rectangle defined in screen coordinate space [screenRect]
  /// with preview dimension [screenSize] to the actual pixel coordinates on [imageSize].
  ///
  /// Assumes [BoxFit.cover] mapping as used in standard full-screen camera previews.
  static Rect mapScreenCropToImagePixels({
    required Rect screenRect,
    required Size screenSize,
    required Size imageSize,
  }) {
    if (screenSize.width <= 0 ||
        screenSize.height <= 0 ||
        imageSize.width <= 0 ||
        imageSize.height <= 0) {
      return Rect.zero;
    }

    // Camera preview uses BoxFit.cover:
    // Scale is determined by max(imageWidth / screenWidth, imageHeight / screenHeight)
    final double scaleX = imageSize.width / screenSize.width;
    final double scaleY = imageSize.height / screenSize.height;
    final double scale = scaleX > scaleY ? scaleX : scaleY;

    // Viewport center in image coordinates
    final double scaledScreenWidth = screenSize.width * scale;
    final double scaledScreenHeight = screenSize.height * scale;

    final double offsetX = (scaledScreenWidth - imageSize.width) / 2.0;
    final double offsetY = (scaledScreenHeight - imageSize.height) / 2.0;

    // Project screen rect coordinates to image pixels
    double pixelLeft = (screenRect.left * scale) - offsetX;
    double pixelTop = (screenRect.top * scale) - offsetY;
    double pixelRight = (screenRect.right * scale) - offsetX;
    double pixelBottom = (screenRect.bottom * scale) - offsetY;

    // Clamp within image bounds
    pixelLeft = pixelLeft.clamp(0.0, imageSize.width);
    pixelTop = pixelTop.clamp(0.0, imageSize.height);
    pixelRight = pixelRight.clamp(0.0, imageSize.width);
    pixelBottom = pixelBottom.clamp(0.0, imageSize.height);

    final double width = (pixelRight - pixelLeft).clamp(0.0, imageSize.width);
    final double height = (pixelBottom - pixelTop).clamp(0.0, imageSize.height);

    return Rect.fromLTWH(pixelLeft, pixelTop, width, height);
  }

  /// Calculates normalized [0.0, 1.0] coordinates for camera focus & exposure points
  /// given a local tap offset on screen preview.
  static Offset mapTapToCameraFocusPoint({
    required Offset tapOffset,
    required Size previewSize,
  }) {
    if (previewSize.width <= 0 || previewSize.height <= 0) {
      return const Offset(0.5, 0.5);
    }
    final double dx = (tapOffset.dx / previewSize.width).clamp(0.0, 1.0);
    final double dy = (tapOffset.dy / previewSize.height).clamp(0.0, 1.0);
    return Offset(dx, dy);
  }
}
