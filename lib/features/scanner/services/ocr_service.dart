import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

/// Result object holding recognized text and measured on-device OCR latency.
class OcrScanResult {
  final String text;
  final int durationMs;

  const OcrScanResult({
    required this.text,
    required this.durationMs,
  });
}

/// Service managing on-device optical character recognition (OCR) using Google ML Kit.
class OcrService {
  TextRecognizer? _textRecognizer;

  TextRecognizer get _recognizer {
    _textRecognizer ??= TextRecognizer(script: TextRecognitionScript.latin);
    return _textRecognizer!;
  }

  /// Processes an image from the local file system and returns recognized text with duration.
  Future<OcrScanResult> recognizeText(String imagePath) async {
    final Stopwatch stopwatch = Stopwatch()..start();
    final InputImage inputImage = InputImage.fromFilePath(imagePath);

    try {
      final RecognizedText recognized = await _recognizer.processImage(inputImage);
      stopwatch.stop();

      return OcrScanResult(
        text: recognized.text,
        durationMs: stopwatch.elapsedMilliseconds,
      );
    } catch (e) {
      stopwatch.stop();
      rethrow;
    }
  }

  /// Disposes the underlying native text recognizer resources.
  Future<void> dispose() async {
    if (_textRecognizer != null) {
      await _textRecognizer!.close();
      _textRecognizer = null;
    }
  }
}
