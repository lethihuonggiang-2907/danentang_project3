import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Utility to crop an image file to a designated pixel sub-rectangle.
class ImageCropper {
  ImageCropper._();

  /// Crops the image at [sourcePath] to [cropRect] (in image pixel coordinates).
  /// Returns the path to the cropped image file, or [sourcePath] on fallback.
  static Future<String> cropImageFile({
    required String sourcePath,
    required Rect cropRect,
  }) async {
    final File sourceFile = File(sourcePath);
    if (!await sourceFile.exists()) {
      return sourcePath;
    }

    try {
      final Uint8List bytes = await sourceFile.readAsBytes();
      final Codec codec = await instantiateImageCodec(bytes);
      final FrameInfo frame = await codec.getNextFrame();
      final Image fullImage = frame.image;

      final double imgW = fullImage.width.toDouble();
      final double imgH = fullImage.height.toDouble();

      // Validate cropRect within image dimensions
      final double safeLeft = cropRect.left.clamp(0.0, imgW - 1);
      final double safeTop = cropRect.top.clamp(0.0, imgH - 1);
      final double safeRight = cropRect.right.clamp(safeLeft + 1, imgW);
      final double safeBottom = cropRect.bottom.clamp(safeTop + 1, imgH);

      final Rect safeCrop = Rect.fromLTRB(safeLeft, safeTop, safeRight, safeBottom);
      final int targetWidth = safeCrop.width.round();
      final int targetHeight = safeCrop.height.round();

      if (targetWidth <= 0 || targetHeight <= 0) {
        return sourcePath;
      }

      // Render the sub-rectangle to a new canvas
      final PictureRecorder recorder = PictureRecorder();
      final Canvas canvas = Canvas(recorder);

      final Rect src = safeCrop;
      final Rect dst = Rect.fromLTWH(0, 0, targetWidth.toDouble(), targetHeight.toDouble());

      canvas.drawImageRect(fullImage, src, dst, Paint()..isAntiAlias = true);

      final Picture picture = recorder.endRecording();
      final Image croppedUiImage = await picture.toImage(targetWidth, targetHeight);

      final ByteData? byteData = await croppedUiImage.toByteData(
        format: ImageByteFormat.png,
      );

      if (byteData == null) {
        return sourcePath;
      }

      final Directory tempDir = await getTemporaryDirectory();
      final String outPath = p.join(
        tempDir.path,
        'cropped_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );

      final File outFile = File(outPath);
      await outFile.writeAsBytes(byteData.buffer.asUint8List());

      return outPath;
    } catch (_) {
      // Graceful fallback to original image if cropping encounters an error
      return sourcePath;
    }
  }
}
