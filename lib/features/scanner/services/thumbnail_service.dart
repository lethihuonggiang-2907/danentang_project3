import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Service responsible for resizing and storing lightweight receipt thumbnails.
class ThumbnailService {
  ThumbnailService._();

  /// Creates a thumbnail (max 300px wide) from [sourcePath] and saves it
  /// into the app documents directory under the `receipts/` subdirectory.
  /// Returns the absolute path of the created thumbnail file.
  static Future<String> createThumbnail(String sourcePath) async {
    final File sourceFile = File(sourcePath);
    if (!await sourceFile.exists()) {
      throw FileNotFoundException('Source receipt image not found: $sourcePath');
    }

    final Uint8List bytes = await sourceFile.readAsBytes();

    // Decode and downscale to max 300px width using Flutter's native engine codec
    final ui.Codec codec = await ui.instantiateImageCodec(
      bytes,
      targetWidth: 300,
    );
    final ui.FrameInfo frameInfo = await codec.getNextFrame();
    final ByteData? byteData = await frameInfo.image.toByteData(
      format: ui.ImageByteFormat.png,
    );

    if (byteData == null) {
      throw Exception('Failed to encode downscaled thumbnail');
    }

    // Prepare destination receipts directory in App Documents
    final Directory appDocsDir = await getApplicationDocumentsDirectory();
    final Directory receiptsDir = Directory(p.join(appDocsDir.path, 'receipts'));
    if (!await receiptsDir.exists()) {
      await receiptsDir.create(recursive: true);
    }

    final String fileName = 'thumb_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final String targetPath = p.join(receiptsDir.path, fileName);

    final File targetFile = File(targetPath);
    await targetFile.writeAsBytes(byteData.buffer.asUint8List());

    return targetPath;
  }
}

class FileNotFoundException implements Exception {
  final String message;
  FileNotFoundException(this.message);

  @override
  String toString() => 'FileNotFoundException: $message';
}
