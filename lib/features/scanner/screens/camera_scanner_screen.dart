import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../../extraction/receipt_parser.dart';
import '../services/ocr_service.dart';
import '../services/thumbnail_service.dart';
import '../utils/crop_geometry.dart';
import '../utils/image_cropper.dart';
import '../widgets/camera_crop_overlay.dart';
import '../widgets/focus_ring_widget.dart';
import 'receipt_confirm_screen.dart';

/// Live Camera Scanner Screen featuring camera preview, crop overlay,
/// flash toggle, tap-to-focus/exposure, and on-device receipt processing.
class CameraScannerScreen extends StatefulWidget {
  const CameraScannerScreen({super.key});

  @override
  State<CameraScannerScreen> createState() => _CameraScannerScreenState();
}

class _CameraScannerScreenState extends State<CameraScannerScreen>
    with WidgetsBindingObserver {
  CameraController? _controller;
  List<CameraDescription> _cameras = <CameraDescription>[];
  bool _isCameraInitialized = false;
  bool _isProcessing = false;
  String _statusMessage = '';

  FlashMode _currentFlashMode = FlashMode.off;
  bool _hasFlash = true;

  Offset? _focusPosition;
  final ImagePicker _picker = ImagePicker();
  final OcrService _ocrService = OcrService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    _ocrService.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final CameraController? cameraController = _controller;

    // App state changed before camera could be initialized
    if (cameraController == null || !cameraController.value.isInitialized) {
      return;
    }

    if (state == AppLifecycleState.inactive) {
      cameraController.dispose();
      _isCameraInitialized = false;
    } else if (state == AppLifecycleState.resumed) {
      _initCamera();
    }
  }

  Future<void> _initCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        if (mounted) {
          setState(() {
            _isCameraInitialized = false;
          });
        }
        return;
      }

      // Pick rear camera by default
      final CameraDescription rearCamera = _cameras.firstWhere(
        (CameraDescription c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => _cameras.first,
      );

      final CameraController controller = CameraController(
        rearCamera,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: Platform.isAndroid
            ? ImageFormatGroup.jpeg
            : ImageFormatGroup.bgra8888,
      );

      _controller = controller;
      await controller.initialize();

      // Check if flash is supported
      try {
        await controller.setFlashMode(FlashMode.off);
      } catch (_) {
        _hasFlash = false;
      }

      if (mounted) {
        setState(() {
          _isCameraInitialized = true;
          _currentFlashMode = FlashMode.off;
        });
      }
    } on CameraException catch (e) {
      _handleCameraException(e);
    } catch (_) {
      if (mounted) {
        setState(() {
          _isCameraInitialized = false;
        });
      }
    }
  }

  void _handleCameraException(CameraException e) {
    if (mounted) {
      setState(() {
        _isCameraInitialized = false;
      });
      showDialog<void>(
        context: context,
        builder: (BuildContext dCtx) => AlertDialog(
          title: const Text('Lỗi máy ảnh'),
          content: Text(
            e.code == 'CameraAccessDenied' || e.code == 'CameraAccessDeniedWithoutPrompt'
                ? 'Quyền truy cập máy ảnh bị từ chối. Vui lòng cấp quyền trong Cài đặt thiết bị để sử dụng tính năng quét.'
                : 'Không thể khởi động máy ảnh: ${e.description ?? e.code}',
          ),
          actions: <Widget>[
            FilledButton(
              onPressed: () => Navigator.of(dCtx).pop(),
              child: const Text('Đã hiểu'),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _toggleFlash() async {
    if (_controller == null || !_controller!.value.isInitialized || !_hasFlash) {
      return;
    }

    final FlashMode nextMode;
    switch (_currentFlashMode) {
      case FlashMode.off:
        nextMode = FlashMode.auto;
        break;
      case FlashMode.auto:
        nextMode = FlashMode.torch;
        break;
      case FlashMode.torch:
      default:
        nextMode = FlashMode.off;
        break;
    }

    try {
      await _controller!.setFlashMode(nextMode);
      setState(() {
        _currentFlashMode = nextMode;
      });
    } catch (_) {
      // Flash not supported on this device
    }
  }

  Future<void> _onTapToFocus(TapUpDetails details, Size previewSize) async {
    if (_controller == null || !_controller!.value.isInitialized) return;

    final Offset tapOffset = details.localPosition;
    setState(() {
      _focusPosition = tapOffset;
    });

    final Offset normalizedPoint = CropGeometry.mapTapToCameraFocusPoint(
      tapOffset: tapOffset,
      previewSize: previewSize,
    );

    try {
      await _controller!.setFocusPoint(normalizedPoint);
      await _controller!.setExposurePoint(normalizedPoint);
    } catch (_) {
      // Focus point not supported on this hardware
    }
  }

  Future<void> _captureAndProcessReceipt(Rect cropRectOnScreen, Size previewSize) async {
    if (_controller == null ||
        !_controller!.value.isInitialized ||
        _isProcessing) {
      return;
    }

    try {
      setState(() {
        _isProcessing = true;
        _statusMessage = 'Đang chụp và cắt vùng hóa đơn...';
      });

      // 1. Capture full picture
      final XFile photo = await _controller!.takePicture();

      // Read image size to map coordinates
      final Uint8List imageBytes = await File(photo.path).readAsBytes();
      final Size imagePixelSize = await _getImageDimensions(imageBytes);

      // 2. Map screen crop rect to pixel coords and crop
      final Rect cropPixelRect = CropGeometry.mapScreenCropToImagePixels(
        screenRect: cropRectOnScreen,
        screenSize: previewSize,
        imageSize: imagePixelSize,
      );

      final String processedPath = await ImageCropper.cropImageFile(
        sourcePath: photo.path,
        cropRect: cropPixelRect,
      );

      setState(() {
        _statusMessage = 'Đang nhận diện chữ viết (On-Device OCR)...';
      });

      // 3. Run ML Kit text recognition
      final OcrScanResult ocrResult =
          await _ocrService.recognizeText(processedPath);

      setState(() {
        _statusMessage = 'Đang phân tích cấu trúc hóa đơn...';
      });

      // 4. Save thumbnail
      String? thumbnailPath;
      try {
        thumbnailPath = await ThumbnailService.createThumbnail(processedPath);
      } catch (_) {
        thumbnailPath = null;
      }

      // 5. Parse receipt with pure heuristic parser
      final ParsedReceiptResult parsedResult =
          ReceiptParser.parse(ocrResult.text);

      setState(() {
        _isProcessing = false;
      });

      if (!mounted) return;

      // Navigate to Confirm Screen
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
            content: Text('Không thể xử lý hóa đơn: $e'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    }
  }

  Future<Size> _getImageDimensions(Uint8List bytes) async {
    try {
      final decoded = await decodeImageFromList(bytes);
      return Size(decoded.width.toDouble(), decoded.height.toDouble());
    } catch (_) {
      return const Size(1080, 1920);
    }
  }

  Future<void> _pickFromGallery() async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1200,
        maxHeight: 1600,
        imageQuality: 85,
      );

      if (pickedFile == null) return;

      setState(() {
        _isProcessing = true;
        _statusMessage = 'Đang nhận diện chữ viết...';
      });

      final OcrScanResult ocrResult =
          await _ocrService.recognizeText(pickedFile.path);

      String? thumbPath;
      try {
        thumbPath = await ThumbnailService.createThumbnail(pickedFile.path);
      } catch (_) {}

      final ParsedReceiptResult parsedResult =
          ReceiptParser.parse(ocrResult.text);

      setState(() {
        _isProcessing = false;
      });

      if (!mounted) return;

      await Navigator.of(context).push(
        MaterialPageRoute<bool>(
          builder: (BuildContext context) => ReceiptConfirmScreen(
            parsedResult: parsedResult,
            thumbnailPath: thumbPath,
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
          SnackBar(content: Text('Lỗi khi mở thư viện: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    if (!_isCameraInitialized || _controller == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Máy quét hóa đơn')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                const Icon(Icons.camera_alt_outlined, size: 64, color: Colors.grey),
                const SizedBox(height: 16),
                const Text(
                  'Không thể khởi động camera trực tiếp.',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Vui lòng kiểm tra quyền camera hoặc chọn ảnh từ thư viện.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: _pickFromGallery,
                  icon: const Icon(Icons.photo_library_rounded),
                  label: const Text('Chọn ảnh từ thư viện'),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: _initCamera,
                  child: const Text('Thử lại camera'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final Size previewSize = Size(constraints.maxWidth, constraints.maxHeight);

          // Calculate centered receipt crop rect (approx 72% width, 60% height)
          final double cropWidth = previewSize.width * 0.82;
          final double cropHeight = previewSize.height * 0.58;
          final Rect cropRect = Rect.fromCenter(
            center: Offset(previewSize.width / 2, previewSize.height / 2 - 30),
            width: cropWidth,
            height: cropHeight,
          );

          return Stack(
            fit: StackFit.expand,
            children: <Widget>[
              // 1. Camera Preview with Tap-to-Focus
              GestureDetector(
                onTapUp: (TapUpDetails details) =>
                    _onTapToFocus(details, previewSize),
                child: Center(
                  child: CameraPreview(_controller!),
                ),
              ),

              // 2. Crop Overlay Frame (Darkened mask + Corner brackets)
              CameraCropOverlay(cropRect: cropRect),

              // 3. Focus Ring Animation
              if (_focusPosition != null)
                FocusRingWidget(
                  position: _focusPosition!,
                  onDismissed: () {
                    setState(() {
                      _focusPosition = null;
                    });
                  },
                ),

              // 4. Top Action Bar: Flash Toggle & Title
              SafeArea(
                child: Align(
                  alignment: Alignment.topCenter,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: <Widget>[
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.4),
                            shape: BoxShape.circle,
                          ),
                          child: IconButton(
                            icon: const Icon(Icons.arrow_back, color: Colors.white),
                            onPressed: () => Navigator.of(context).maybePop(),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            'Đặt hóa đơn vào khung',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        if (_hasFlash)
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.4),
                              shape: BoxShape.circle,
                            ),
                            child: IconButton(
                              icon: Icon(
                                _currentFlashMode == FlashMode.torch
                                    ? Icons.flash_on_rounded
                                    : _currentFlashMode == FlashMode.auto
                                        ? Icons.flash_auto_rounded
                                        : Icons.flash_off_rounded,
                                color: _currentFlashMode != FlashMode.off
                                    ? Colors.amberAccent
                                    : Colors.white,
                              ),
                              onPressed: _toggleFlash,
                            ),
                          )
                        else
                          const SizedBox(width: 48),
                      ],
                    ),
                  ),
                ),
              ),

              // 5. Bottom Capture Controls
              Align(
                alignment: Alignment.bottomCenter,
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 24, left: 24, right: 24),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: <Widget>[
                        // Gallery Button
                        IconButton(
                          tooltip: 'Chọn ảnh từ thư viện',
                          icon: const Icon(Icons.photo_library_rounded, color: Colors.white, size: 30),
                          onPressed: _isProcessing ? null : _pickFromGallery,
                        ),

                        // Shutter Capture Button
                        GestureDetector(
                          onTap: _isProcessing
                              ? null
                              : () => _captureAndProcessReceipt(cropRect, previewSize),
                          child: Container(
                            width: 76,
                            height: 76,
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 4),
                            ),
                            child: Container(
                              decoration: const BoxDecoration(
                                color: Color(0xFF00E676),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.camera_alt_rounded,
                                color: Colors.black,
                                size: 36,
                              ),
                            ),
                          ),
                        ),

                        // Spacer placeholder for alignment
                        const SizedBox(width: 48),
                      ],
                    ),
                  ),
                ),
              ),

              // 6. Processing Overlay
              if (_isProcessing)
                Container(
                  color: Colors.black.withValues(alpha: 0.7),
                  child: Center(
                    child: Card(
                      color: theme.colorScheme.surface,
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
          );
        },
      ),
    );
  }
}
