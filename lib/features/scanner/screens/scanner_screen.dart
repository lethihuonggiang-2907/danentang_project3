import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../extraction/receipt_parser.dart';
import '../services/ocr_service.dart';
import '../services/thumbnail_service.dart';
import 'receipt_confirm_screen.dart';

/// Screen for picking receipt image from camera or gallery and running on-device OCR.
class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  final ImagePicker _picker = ImagePicker();
  final OcrService _ocrService = OcrService();
  bool _isProcessing = false;
  String _statusMessage = '';

  @override
  void dispose() {
    _ocrService.dispose();
    super.dispose();
  }

  Future<void> _pickAndProcessImage(ImageSource source) async {
    try {
      // Pick image with downscaling applied to optimize OCR processing latency
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        maxWidth: 1200,
        maxHeight: 1600,
        imageQuality: 85,
      );

      if (pickedFile == null) {
        // User cancelled image selection
        return;
      }

      setState(() {
        _isProcessing = true;
        _statusMessage = 'Đang nhận diện chữ viết (On-Device OCR)...';
      });

      // 1. Run offline text recognition via ML Kit and measure duration
      final OcrScanResult ocrResult =
          await _ocrService.recognizeText(pickedFile.path);

      setState(() {
        _statusMessage = 'Đang lưu ảnh thumbnail và phân tích nội dung...';
      });

      // 2. Generate and store lightweight thumbnail
      String? thumbnailPath;
      try {
        thumbnailPath =
            await ThumbnailService.createThumbnail(pickedFile.path);
      } catch (e) {
        // If thumbnail generation fails, we still continue with OCR result
        thumbnailPath = null;
      }

      // 3. Parse receipt fields via pure heuristic regex parser
      final ParsedReceiptResult parsedResult =
          ReceiptParser.parse(ocrResult.text);

      setState(() {
        _isProcessing = false;
      });

      if (!mounted) return;

      // If OCR returned zero text, alert user
      if (ocrResult.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Không tìm thấy chữ trên ảnh. Bạn có thể chụp lại rõ hơn.',
            ),
          ),
        );
      }

      // 4. Navigate to confirm & edit screen
      await Navigator.of(context).push(
        MaterialPageRoute<bool>(
          builder: (BuildContext context) => ReceiptConfirmScreen(
            parsedResult: parsedResult,
            thumbnailPath: thumbnailPath,
            ocrDurationMs: ocrResult.durationMs,
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Không thể quét hóa đơn: $e'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Quét hóa đơn OCR'),
      ),
      body: Stack(
        children: <Widget>[
          SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 500),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                // Header Illustration / Icon
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.document_scanner_rounded,
                    size: 64,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 24),

                Text(
                  'Quét hóa đơn tự động',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),

                Text(
                  'Ứng dụng sử dụng trí tuệ nhân tạo On-Device (Google ML Kit) để tự động trích xuất số tiền, ngày và tên cửa hàng hoàn toàn offline mà không cần kết nối mạng.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 40),

                // Button: Camera
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _isProcessing
                        ? null
                        : () => _pickAndProcessImage(ImageSource.camera),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    icon: const Icon(Icons.camera_alt_rounded),
                    label: const Text(
                      'Chụp ảnh hóa đơn (Camera)',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Button: Gallery
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _isProcessing
                        ? null
                        : () => _pickAndProcessImage(ImageSource.gallery),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    icon: const Icon(Icons.photo_library_rounded),
                    label: const Text(
                      'Chọn ảnh từ thư viện',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),

          // Loading overlay
          if (_isProcessing)
            Container(
              color: Colors.black.withValues(alpha: 0.5),
              child: Center(
                child: Card(
                  elevation: 8,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(28),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        const CircularProgressIndicator(),
                        const SizedBox(height: 20),
                        Text(
                          _statusMessage,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
