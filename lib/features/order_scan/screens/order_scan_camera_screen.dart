// lib/features/order_scan/screens/order_scan_camera_screen.dart
//
// Camera tuỳ biến để chụp PHIẾU ĐẶT HÀNG.
//
// Yêu cầu UX:
//   • Chỉ chế độ dọc (portrait).
//   • Preview camera hiển thị TOÀN BỘ khung nhìn (aspect-fit, letterbox
//     đen 2 bên nếu cần) — user thấy đúng thứ camera thấy, không bị zoom
//     hay cắt, canh phiếu vào khung được dễ dàng.
//   • Khung guideline dọc ở giữa preview area.
//   • Nút "Chụp" chỉ sáng khi đủ text được nhận diện trong khung.
//   • Có nút "Chụp dù sao" phòng phát hiện lệch.
//
// Kỹ thuật quan trọng:
//   • Dùng BoxFit.contain (aspect-fit) thay vì cover (aspect-fill).
//     Cover crop phần rìa camera → user không thấy được cả tờ A4.
//   • Toạ độ khung tính theo PREVIEW RECT (không phải screen), vì
//     preview có thể nhỏ hơn screen (letterbox top/bottom).
//   • Bbox từ ML Kit ở toạ độ ROTATED image (portrait) — map linear
//     bằng scale = imgW_rotated / previewW.

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

/// Trả về [File] ảnh đã chụp, hoặc `null` nếu user thoát.
class OrderScanCameraScreen extends StatefulWidget {
  const OrderScanCameraScreen({super.key});

  @override
  State<OrderScanCameraScreen> createState() => _OrderScanCameraScreenState();
}

class _OrderScanCameraScreenState extends State<OrderScanCameraScreen>
    with WidgetsBindingObserver {
  CameraController? _controller;
  late final Future<void> _initFuture;
  final _recognizer = TextRecognizer(script: TextRecognitionScript.latin);

  bool _busy = false;
  bool _analyzing = false;
  int _blocksInBox = 0;
  DateTime _lastAnalyze = DateTime.fromMillisecondsSinceEpoch(0);

  /// Kích thước preview area đo được sau layout (dùng cho _analyzeFrame).
  Size? _previewSize;

  static const int _kThreshold = 8;
  static const double _boxWidthFrac = 0.82;
  static const double _boxHeightFrac = 0.68;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    _initFuture = _initCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.stopImageStream().catchError((_) {});
    _controller?.dispose();
    _recognizer.close();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    super.dispose();
  }

  Future<void> _initCamera() async {
    final cams = await availableCameras();
    if (cams.isEmpty) throw Exception('Không tìm thấy camera trên thiết bị');
    final back = cams.firstWhere(
          (c) => c.lensDirection == CameraLensDirection.back,
      orElse: () => cams.first,
    );
    final ctrl = CameraController(
      back,
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: Platform.isIOS
          ? ImageFormatGroup.bgra8888
          : ImageFormatGroup.nv21,
    );
    await ctrl.initialize();
    if (!mounted) { await ctrl.dispose(); return; }
    _controller = ctrl;
    await _startAnalyzing();
    setState(() {});
  }

  Future<void> _startAnalyzing() async {
    final ctrl = _controller;
    if (ctrl == null || !ctrl.value.isInitialized) return;
    await ctrl.startImageStream(_processFrame);
  }

  void _processFrame(CameraImage img) {
    final now = DateTime.now();
    if (now.difference(_lastAnalyze).inMilliseconds < 330) return;
    if (_analyzing || _busy) return;
    if (_previewSize == null) return; // layout chưa xong
    _lastAnalyze = now;
    _analyzing = true;

    _analyzeFrame(img).then((count) {
      if (!mounted) return;
      if (_blocksInBox != count) setState(() => _blocksInBox = count);
    }).catchError((e, _) {
      if (kDebugMode) debugPrint('[OrderScan] analyze err: $e');
    }).whenComplete(() => _analyzing = false);
  }

  Future<int> _analyzeFrame(CameraImage image) async {
    final ctrl = _controller!;
    final input = _cameraImageToInputImage(image, ctrl.description);
    if (input == null) return _blocksInBox;
    final previewSize = _previewSize;
    if (previewSize == null) return _blocksInBox;

    final recognized = await _recognizer.processImage(input);

    // Khung guideline trong toạ độ PREVIEW-LOCAL (0..previewW, 0..previewH)
    final boxW = previewSize.width * _boxWidthFrac;
    final boxH = previewSize.height * _boxHeightFrac;
    final boxLeft = (previewSize.width - boxW) / 2;
    final boxTop = (previewSize.height - boxH) / 2;

    // Sau khi rotate 90°, image dimensions bị swap:
    //   Portrait width = image.height (short side)
    //   Portrait height = image.width (long side)
    // ML Kit trả bbox trong toạ độ ROTATED (portrait).
    final imgPortraitW = image.height.toDouble();
    final imgPortraitH = image.width.toDouble();

    // Scale linear: preview ↔ image (cùng aspect ratio nhờ BoxFit.contain)
    final scale = imgPortraitW / previewSize.width;
    final boxImgLeft   = boxLeft * scale;
    final boxImgTop    = boxTop * scale;
    final boxImgRight  = (boxLeft + boxW) * scale;
    final boxImgBottom = (boxTop + boxH) * scale;

    var count = 0;
    for (final block in recognized.blocks) {
      final r = block.boundingBox;
      final cx = r.center.dx;
      final cy = r.center.dy;
      if (cx >= boxImgLeft && cx <= boxImgRight &&
          cy >= boxImgTop && cy <= boxImgBottom) {
        // Sanity check: bbox center phải nằm trong ảnh
        if (cx >= 0 && cx <= imgPortraitW && cy >= 0 && cy <= imgPortraitH) {
          count++;
        }
      }
    }
    return count;
  }

  InputImage? _cameraImageToInputImage(
      CameraImage image, CameraDescription camera) {
    final WriteBuffer buf = WriteBuffer();
    for (final Plane plane in image.planes) {
      buf.putUint8List(plane.bytes);
    }
    final bytes = buf.done().buffer.asUint8List();

    final Size size = Size(image.width.toDouble(), image.height.toDouble());
    final rotation = InputImageRotationValue.fromRawValue(camera.sensorOrientation)
        ?? InputImageRotation.rotation0deg;
    final format = InputImageFormatValue.fromRawValue(image.format.raw) ??
        (Platform.isIOS ? InputImageFormat.bgra8888 : InputImageFormat.nv21);
    final bytesPerRow = image.planes[0].bytesPerRow;

    return InputImage.fromBytes(
      bytes: bytes,
      metadata: InputImageMetadata(
        size: size,
        rotation: rotation,
        format: format,
        bytesPerRow: bytesPerRow,
      ),
    );
  }

  Future<void> _capture({bool force = false}) async {
    if (_busy) return;
    final ctrl = _controller;
    if (ctrl == null || !ctrl.value.isInitialized) return;
    if (!force && _blocksInBox < _kThreshold) return;

    setState(() => _busy = true);
    try {
      await ctrl.stopImageStream();
      final xfile = await ctrl.takePicture();
      if (!mounted) return;
      Navigator.of(context).pop(File(xfile.path));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Không chụp được: $e')));
      setState(() => _busy = false);
      _startAnalyzing();
    }
  }

  // ═══════════════════════════════════════════════════════════
  //  BUILD
  // ═══════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _initFuture,
      builder: (context, snap) {
        if (snap.hasError) {
          return Scaffold(
            backgroundColor: Colors.black,
            appBar: AppBar(backgroundColor: Colors.black),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('Lỗi camera: ${snap.error}',
                    style: const TextStyle(color: Colors.white)),
              ),
            ),
          );
        }
        if (_controller == null || !_controller!.value.isInitialized) {
          return const Scaffold(
              backgroundColor: Colors.black,
              body: Center(child: CircularProgressIndicator(color: Colors.white)));
        }
        final aligned = _blocksInBox >= _kThreshold;

        return Scaffold(
          backgroundColor: Colors.black,
          body: Stack(children: [
            // Camera preview + guideline (aspect-fit, letterbox)
            Positioned.fill(child: _cameraStack(aligned)),

            // Top bar
            Positioned(
              top: 0, left: 0, right: 0,
              child: SafeArea(child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(children: [
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white, size: 28),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const Expanded(child: Text(
                    'Đưa phiếu đặt hàng vào khung',
                    style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
                    textAlign: TextAlign.center,
                  )),
                  const SizedBox(width: 48),
                ]),
              )),
            ),

            // Status text
            Positioned(
              bottom: 150, left: 0, right: 0,
              child: Center(child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.55),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Text(
                  aligned
                      ? '✓ Đã canh đúng, bấm chụp'
                      : 'Canh chỉnh phiếu vào khung ($_blocksInBox / $_kThreshold)',
                  style: TextStyle(
                    color: aligned ? Colors.greenAccent : Colors.white,
                    fontSize: 13, fontWeight: FontWeight.w600,
                  ),
                ),
              )),
            ),

            // Capture button
            Positioned(
              bottom: 40, left: 0, right: 0,
              child: SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
                _CaptureButton(
                  enabled: aligned && !_busy,
                  busy: _busy,
                  onPressed: () => _capture(),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: _busy ? null : () => _capture(force: true),
                  child: const Text(
                    'Chụp dù sao',
                    style: TextStyle(color: Colors.white70, decoration: TextDecoration.underline),
                  ),
                ),
              ])),
            ),
          ]),
        );
      },
    );
  }

  /// Camera preview + guideline overlay, đều được đặt trong PREVIEW RECT
  /// (aspect-fit, không phải full screen). Letterbox đen ở trên/dưới nếu
  /// screen tall hơn preview.
  Widget _cameraStack(bool aligned) {
    final ctrl = _controller!;
    // camera.value.aspectRatio là ratio LANDSCAPE của cảm biến (VD 4/3).
    // Khi hiển thị dọc, ta lấy nghịch đảo để có aspect portrait.
    final portraitAspect = 1 / ctrl.value.aspectRatio;

    return LayoutBuilder(builder: (ctx, constraints) {
      final container = constraints.biggest;
      final previewSize = _fitInside(portraitAspect, container);

      // Notify state để _analyzeFrame biết preview size hiện tại
      if (_previewSize != previewSize) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) setState(() => _previewSize = previewSize);
        });
      }

      final previewOffset = Offset(
        (container.width - previewSize.width) / 2,
        (container.height - previewSize.height) / 2,
      );
      final previewRect = previewOffset & previewSize;

      return Stack(children: [
        // Camera preview at fitted rect
        Positioned.fromRect(
          rect: previewRect,
          child: CameraPreview(ctrl),
        ),
        // Guideline overlay TRÊN preview area
        Positioned.fromRect(
          rect: previewRect,
          child: IgnorePointer(child: CustomPaint(
            painter: _GuidelinePainter(
              widthFrac: _boxWidthFrac,
              heightFrac: _boxHeightFrac,
              aligned: aligned,
            ),
          )),
        ),
      ]);
    });
  }

  /// Fit portrait-aspect vào container (aspect-fit).
  Size _fitInside(double aspect, Size container) {
    final containerAspect = container.width / container.height;
    if (aspect > containerAspect) {
      // Preview rộng hơn → fit theo width
      return Size(container.width, container.width / aspect);
    } else {
      // Preview cao hơn → fit theo height
      return Size(container.height * aspect, container.height);
    }
  }
}

// ═══════════════════════════════════════════════════════════
//  Guideline painter
// ═══════════════════════════════════════════════════════════

class _GuidelinePainter extends CustomPainter {
  final double widthFrac;
  final double heightFrac;
  final bool aligned;
  _GuidelinePainter({
    required this.widthFrac,
    required this.heightFrac,
    required this.aligned,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final boxW = size.width * widthFrac;
    final boxH = size.height * heightFrac;
    final left = (size.width - boxW) / 2;
    final top = (size.height - boxH) / 2;
    final rect = Rect.fromLTWH(left, top, boxW, boxH);
    final rr = RRect.fromRectAndRadius(rect, const Radius.circular(16));

    // Tối phần ngoài khung
    final overlay = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRRect(rr)
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(overlay, Paint()..color = Colors.black.withOpacity(0.55));

    final borderColor = aligned ? const Color(0xFF22C55E) : Colors.white;
    canvas.drawRRect(rr, Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5);

    final cornerPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;
    const cLen = 26.0;
    // Top-left
    canvas.drawLine(Offset(left, top + cLen), Offset(left, top), cornerPaint);
    canvas.drawLine(Offset(left, top), Offset(left + cLen, top), cornerPaint);
    // Top-right
    canvas.drawLine(Offset(left + boxW - cLen, top), Offset(left + boxW, top), cornerPaint);
    canvas.drawLine(Offset(left + boxW, top), Offset(left + boxW, top + cLen), cornerPaint);
    // Bottom-left
    canvas.drawLine(Offset(left, top + boxH - cLen), Offset(left, top + boxH), cornerPaint);
    canvas.drawLine(Offset(left, top + boxH), Offset(left + cLen, top + boxH), cornerPaint);
    // Bottom-right
    canvas.drawLine(Offset(left + boxW - cLen, top + boxH), Offset(left + boxW, top + boxH), cornerPaint);
    canvas.drawLine(Offset(left + boxW, top + boxH), Offset(left + boxW, top + boxH - cLen), cornerPaint);
  }

  @override
  bool shouldRepaint(covariant _GuidelinePainter old) =>
      old.aligned != aligned || old.widthFrac != widthFrac || old.heightFrac != heightFrac;
}

// ═══════════════════════════════════════════════════════════
//  Nút chụp
// ═══════════════════════════════════════════════════════════

class _CaptureButton extends StatelessWidget {
  final bool enabled;
  final bool busy;
  final VoidCallback onPressed;
  const _CaptureButton({required this.enabled, required this.busy, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onPressed : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        width: 76, height: 76,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: enabled ? const Color(0xFF22C55E) : Colors.white54,
            width: 4,
          ),
        ),
        child: Center(child: Container(
          width: 58, height: 58,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: busy
                ? Colors.grey
                : (enabled ? const Color(0xFF22C55E) : Colors.white24),
          ),
          child: busy
              ? const Padding(
            padding: EdgeInsets.all(14),
            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
          )
              : null,
        )),
      ),
    );
  }
}