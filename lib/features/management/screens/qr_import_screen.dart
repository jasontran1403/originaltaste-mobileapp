// lib/features/management/screens/qr_import_screen.dart
// 1:1 với GetX gốc — ImportWarehouseController → Riverpod NotifierProvider
// UI: full-screen camera, dark overlay, scan frame animation, product modal, error modal
// Requires: mobile_scanner: ^5.x in pubspec.yaml

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../data/models/management/management_models.dart';

// iOS Simulator không có camera thật → native crash
// Detect simulator: không có SIMULATOR_DEVICE_NAME trên device thật
bool get _isSimulator {
  if (kIsWeb) return false;
  if (!Platform.isIOS) return false;
  return !bool.fromEnvironment('dart.vm.product') &&
      Platform.environment['SIMULATOR_DEVICE_NAME'] != null;
}

// ══════════════════════════════════════════════════════════════════
// STATE
// ══════════════════════════════════════════════════════════════════

class QrImportState {
  final bool showProductInfo;
  final String? scanErrorMessage;
  final bool shouldResetScanLine;
  final ImportProductItem? scannedProduct;

  // currentImport: sản phẩm đã confirm trong phiên này
  final ImportWarehouseModel? currentImport;

  const QrImportState({
    this.showProductInfo    = false,
    this.scanErrorMessage,
    this.shouldResetScanLine = false,
    this.scannedProduct,
    this.currentImport,
  });

  QrImportState copyWith({
    bool? showProductInfo,
    String? scanErrorMessage,
    bool clearError           = false,
    bool? shouldResetScanLine,
    ImportProductItem? scannedProduct,
    bool clearProduct         = false,
    ImportWarehouseModel? currentImport,
    bool clearImport          = false,
  }) =>
      QrImportState(
        showProductInfo:    showProductInfo    ?? this.showProductInfo,
        scanErrorMessage:   clearError ? null  : (scanErrorMessage ?? this.scanErrorMessage),
        shouldResetScanLine: shouldResetScanLine ?? this.shouldResetScanLine,
        scannedProduct:     clearProduct ? null : (scannedProduct ?? this.scannedProduct),
        currentImport:      clearImport  ? null : (currentImport  ?? this.currentImport),
      );
}

// ══════════════════════════════════════════════════════════════════
// NOTIFIER  (replaces ImportWarehouseController)
// ══════════════════════════════════════════════════════════════════

class QrImportNotifier extends AutoDisposeNotifier<QrImportState> {
  final quantityController = TextEditingController();
  bool _isProcessingScan   = false;

  @override
  QrImportState build() {
    ref.onDispose(() => quantityController.dispose());
    return const QrImportState();
  }

  /// Parse + debounce — 1:1 với GetX gốc
  Future<void> onQRDetected(String rawValue) async {
    if (_isProcessingScan) return;
    _isProcessingScan = true;

    await Future.delayed(const Duration(milliseconds: 1200));

    final parsed = _parseQRData(rawValue);
    if (parsed == null) {
      state = state.copyWith(
        scanErrorMessage:  'Định dạng QR không hợp lệ.\nVui lòng kiểm tra lại mã QR.',
        showProductInfo:   false,
        clearProduct:      true,
      );
    } else {
      quantityController.text = '1';
      state = state.copyWith(
        clearError:      true,
        scannedProduct:  parsed,
        showProductInfo: true,
      );
    }

    await Future.delayed(const Duration(seconds: 1));
    _isProcessingScan = false;
  }

  /// Format QR:
  /// Sản phẩm: Hải sản tươi sống
  /// NSX: 10/12/2025
  /// HSD: 10/12/2026
  /// KL Gói: 400gr
  /// KL Mẻ: 10kg
  ImportProductItem? _parseQRData(String raw) {
    try {
      final lines = raw.trim().split('\n');
      final Map<String, String> data = {};

      for (final line in lines) {
        final idx = line.indexOf(':');
        if (idx == -1) continue;
        String key = line.substring(0, idx).trim().toLowerCase();
        // Normalize Vietnamese diacritics → ASCII for key matching
        key = key
            .replaceAll(RegExp(r'[àáâãäåæ]'), 'a')
            .replaceAll(RegExp(r'[èéêë]'), 'e')
            .replaceAll(RegExp(r'[ìíîï]'), 'i')
            .replaceAll(RegExp(r'[òóôõö]'), 'o')
            .replaceAll(RegExp(r'[ùúûü]'), 'u')
            .replaceAll(RegExp(r'[ăắặằẳẵ]'), 'a')
            .replaceAll(RegExp(r'[âấậầẩẫ]'), 'a')
            .replaceAll(RegExp(r'[đ]'), 'd')
            .replaceAll(RegExp(r'[êếệềểễ]'), 'e')
            .replaceAll(RegExp(r'[ôốộồổỗ]'), 'o')
            .replaceAll(RegExp(r'[ơớợờởỡ]'), 'o')
            .replaceAll(RegExp(r'[ưứựừửữ]'), 'u')
            .replaceAll(' ', '_');
        data[key] = line.substring(idx + 1).trim();
      }

      String? find(List<String> keys) {
        for (final k in keys) {
          if (data.containsKey(k)) return data[k];
        }
        return null;
      }

      final productName   = find(['san_pham', 'ten']);
      final nsxRaw        = find(['nsx', 'ngay_sx', 'manufacturing_date']);
      final hsdRaw        = find(['hsd', 'han_dung', 'expiry_date']);
      final packageWeight = find(['kl_goi', 'package_weight']) ?? '--';
      final batchWeight   = find(['kl_me', 'batch_weight'])    ?? '--';

      if (productName == null || nsxRaw == null || hsdRaw == null) return null;

      DateTime parseDate(String s) {
        if (s.contains('/')) {
          final p = s.split('/');
          return DateTime(int.parse(p[2]), int.parse(p[1]), int.parse(p[0]));
        }
        return DateTime.parse(s);
      }

      return ImportProductItem(
        productName:       productName,
        manufacturingDate: parseDate(nsxRaw),
        expiryDate:        parseDate(hsdRaw),
        packageWeight:     packageWeight,
        batchWeight:       batchWeight,
        quantity:          1,
      );
    } catch (e) {
      return null;
    }
  }

  void scanAgain() {
    _isProcessingScan = false;
    state = state.copyWith(
      clearError:       true,
      showProductInfo:  false,
      clearProduct:     true,
      shouldResetScanLine: true,
    );
    quantityController.clear();
  }

  void addProductToCurrentImport(BuildContext context) {
    if (state.scannedProduct == null) return;
    final qtyText = quantityController.text.trim();
    final qty     = double.tryParse(qtyText) ?? 1.0;
    if (qty <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Số lượng phải lớn hơn 0')),
      );
      return;
    }

    final product    = state.scannedProduct!;
    final isDuplicate = state.currentImport?.products.any((p) =>
    p.productName == product.productName &&
        p.manufacturingDate.isAtSameMomentAs(product.manufacturingDate) &&
        p.expiryDate.isAtSameMomentAs(product.expiryDate)) ??
        false;

    if (isDuplicate) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:         const Text('Sản phẩm này đã có trong phiếu nhập!'),
          backgroundColor: Colors.orange.shade800,
        ),
      );
      scanAgain();
      return;
    }

    final newItem = ImportProductItem(
      productName:       product.productName,
      manufacturingDate: product.manufacturingDate,
      expiryDate:        product.expiryDate,
      packageWeight:     product.packageWeight,
      batchWeight:       product.batchWeight,
      quantity:          qty,
    );

    final existing = state.currentImport ??
        ImportWarehouseModel(
          id:           'temp_${DateTime.now().millisecondsSinceEpoch}',
          importerName: 'Đang soạn',
          importTime:   DateTime.now(),
          products:     [],
        );

    final updated = ImportWarehouseModel(
      id:           existing.id,
      importerName: existing.importerName,
      importTime:   existing.importTime,
      products:     [...existing.products, newItem],
    );

    state = state.copyWith(
      currentImport:   updated,
      showProductInfo: false,
      clearProduct:    true,
    );
    quantityController.clear();
  }

  void removeProduct(int index) {
    if (state.currentImport == null) return;
    final products = List<ImportProductItem>.from(
        state.currentImport!.products)..removeAt(index);
    if (products.isEmpty) {
      state = state.copyWith(clearImport: true);
    } else {
      state = state.copyWith(
        currentImport: ImportWarehouseModel(
          id:           state.currentImport!.id,
          importerName: state.currentImport!.importerName,
          importTime:   state.currentImport!.importTime,
          products:     products,
        ),
      );
    }
  }
}

final qrImportProvider =
NotifierProvider.autoDispose<QrImportNotifier, QrImportState>(
    QrImportNotifier.new);

// ══════════════════════════════════════════════════════════════════
// SCREEN
// ══════════════════════════════════════════════════════════════════

class QrImportScreen extends ConsumerStatefulWidget {
  const QrImportScreen({super.key});

  @override
  ConsumerState<QrImportScreen> createState() => _QrImportScreenState();
}

class _QrImportScreenState extends ConsumerState<QrImportScreen>
    with SingleTickerProviderStateMixin {
  MobileScannerController? _cameraController;
  late AnimationController     _scanLineController;

  @override
  void initState() {
    super.initState();
    if (!_isSimulator) {
      _cameraController = MobileScannerController(
        detectionSpeed: DetectionSpeed.normal,
        facing:         CameraFacing.back,
        torchEnabled:   false,
      );
    }
    _scanLineController = AnimationController(
      vsync:    this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _scanLineController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ctrl  = ref.watch(qrImportProvider);
    final notif = ref.read(qrImportProvider.notifier);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ── Camera ─────────────────────────────────────
          if (_isSimulator)
            _buildSimulatorPlaceholder(notif)
          else
            MobileScanner(
              controller: _cameraController!,
              onDetect: (capture) {
                final raw = capture.barcodes.firstOrNull?.rawValue;
                if (raw != null) {
                  _cameraController!.stop();
                  notif.onQRDetected(raw);
                }
              },
            ),

          // ── Dark overlay ────────────────────────────────
          CustomPaint(
            painter: _ScanOverlayPainter(),
            child: const SizedBox.expand(),
          ),

          // ── Header ──────────────────────────────────────
          _buildHeader(notif),

          // ── Scan frame ──────────────────────────────────
          _buildScanFrame(ctrl),

          // ── Hint text ───────────────────────────────────
          if (!ctrl.showProductInfo && ctrl.scanErrorMessage == null)
            Positioned(
              bottom: 120,
              left: 0, right: 0,
              child: Center(
                child: Text(
                  'Hướng camera vào mã QR trên bao bì',
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 14),
                ),
              ),
            ),

          // ── Phiếu hiện tại (bottom sheet khi có sản phẩm) ──
          if (ctrl.currentImport != null &&
              !ctrl.showProductInfo &&
              ctrl.scanErrorMessage == null)
            Positioned(
              bottom: 24,
              left: 16, right: 16,
              child: _buildCurrentImportChip(ctrl, notif),
            ),

          // ── Product info modal ───────────────────────────
          if (ctrl.showProductInfo && ctrl.scannedProduct != null)
            Positioned(
              bottom: 0, left: 0, right: 0,
              child: _buildProductInfoModal(ctrl, notif),
            ),

          // ── Error modal ──────────────────────────────────
          if (ctrl.scanErrorMessage != null)
            Positioned(
              bottom: 80,
              left: 24, right: 24,
              child: _buildErrorModal(ctrl, notif),
            ),
        ],
      ),
    );
  }


  // ── Simulator placeholder (không có camera thật) ─────────────────
  Widget _buildSimulatorPlaceholder(QrImportNotifier notif) {
    return Container(
      color: const Color(0xFF1A1A2E),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.no_photography_outlined,
              size: 64, color: Colors.white38),
          const SizedBox(height: 16),
          const Text('Camera không khả dụng trên Simulator',
              style: TextStyle(color: Colors.white54, fontSize: 14),
              textAlign: TextAlign.center),
          const SizedBox(height: 8),
          const Text('Dùng ô nhập dưới để test',
              style: TextStyle(color: Colors.white38, fontSize: 12)),
          const SizedBox(height: 32),
          // Manual QR input for testing
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: _SimulatorQrInput(notif: notif),
          ),
        ],
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────────

  Widget _buildHeader(QrImportNotifier notif) => Positioned(
    top: 0, left: 0, right: 0,
    child: SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: 16, vertical: 12),
        child: Row(children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                  color:  Colors.white.withOpacity(0.15),
                  shape: BoxShape.circle),
              child: const Icon(Icons.arrow_back_rounded,
                  color: Colors.white, size: 22),
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text('Nhập kho',
                style: TextStyle(
                    color:      Colors.white,
                    fontSize:   20,
                    fontWeight: FontWeight.w700)),
          ),
          GestureDetector(
            onTap: () => _cameraController?.toggleTorch(),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  shape: BoxShape.circle),
              child: const Icon(Icons.flashlight_on_rounded,
                  color: Colors.white, size: 22),
            ),
          ),
        ]),
      ),
    ),
  );

  // ── Scan frame ────────────────────────────────────────────────────

  Widget _buildScanFrame(QrImportState ctrl) => Center(
    child: SizedBox(
      width: 260, height: 260,
      child: Stack(children: [
        // 4 góc teal
        ...[
          Alignment.topLeft,
          Alignment.topRight,
          Alignment.bottomLeft,
          Alignment.bottomRight,
        ].map(_buildCorner),

        // Scan line
        if (!ctrl.showProductInfo && ctrl.scanErrorMessage == null)
          AnimatedBuilder(
            animation: _scanLineController,
            builder: (_, __) {
              if (ctrl.shouldResetScanLine) {
                _scanLineController.value = 0.0;
                _scanLineController.forward(from: 0.0);
              }
              final topPos =
                  _scanLineController.value * 240 + 10;
              return Positioned(
                top: topPos, left: 8, right: 8,
                child: Container(
                  height: 3,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [
                      Color(0x00009688),
                      Color(0xFF009688),
                      Color(0x00009688),
                    ], stops: [0.0, 0.5, 1.0]),
                    boxShadow: [
                      BoxShadow(
                          color: const Color(0xFF009688)
                              .withOpacity(0.8),
                          blurRadius: 10,
                          spreadRadius: 2),
                    ],
                  ),
                ),
              );
            },
          ),
      ]),
    ),
  );

  Widget _buildCorner(Alignment alignment) {
    final isTop  = alignment == Alignment.topLeft ||
        alignment == Alignment.topRight;
    final isLeft = alignment == Alignment.topLeft ||
        alignment == Alignment.bottomLeft;
    return Align(
      alignment: alignment,
      child: Container(
        width: 28, height: 28,
        decoration: BoxDecoration(
          border: Border(
            top:    isTop  ? const BorderSide(color: Color(0xFF009688), width: 4) : BorderSide.none,
            left:   isLeft ? const BorderSide(color: Color(0xFF009688), width: 4) : BorderSide.none,
            right:  !isLeft ? const BorderSide(color: Color(0xFF009688), width: 4) : BorderSide.none,
            bottom: !isTop  ? const BorderSide(color: Color(0xFF009688), width: 4) : BorderSide.none,
          ),
        ),
      ),
    );
  }

  // ── Current import chip ───────────────────────────────────────────

  Widget _buildCurrentImportChip(
      QrImportState ctrl, QrImportNotifier notif) {
    final count = ctrl.currentImport!.products.length;
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color:        Colors.white.withOpacity(0.95),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color:      Colors.black.withOpacity(0.2),
              blurRadius: 12)
        ],
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.symmetric(
              horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
              color:        const Color(0xFF009688).withOpacity(0.12),
              borderRadius: BorderRadius.circular(20)),
          child: Text('$count sản phẩm',
              style: const TextStyle(
                  color:      Color(0xFF009688),
                  fontWeight: FontWeight.w700,
                  fontSize:   12)),
        ),
        const SizedBox(width: 8),
        const Expanded(
          child: Text('trong phiếu',
              style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize:   13,
                  color:      Colors.black87)),
        ),
        TextButton(
          onPressed: () => _showCurrentImportSheet(ctrl, notif),
          child: const Text('Xem',
              style: TextStyle(color: Color(0xFF009688))),
        ),
      ]),
    );
  }

  void _showCurrentImportSheet(
      QrImportState ctrl, QrImportNotifier notif) {
    showModalBottomSheet(
      context:       context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius:
          BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _CurrentImportSheet(
        model:   ctrl.currentImport!,
        notif:   notif,
        onClose: () => Navigator.pop(context),
        onDone:  () {
          Navigator.pop(context); // sheet
          Navigator.pop(context, true); // screen
        },
      ),
    );
  }

  // ── Product info modal ────────────────────────────────────────────

  Widget _buildProductInfoModal(
      QrImportState ctrl, QrImportNotifier notif) {
    final p = ctrl.scannedProduct!;
    return Container(
      margin:  const EdgeInsets.all(16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color:        Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color:      Colors.black.withOpacity(0.3),
              blurRadius: 30, spreadRadius: 5,
              offset:     const Offset(0, -5))
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.check_circle_outline_rounded,
                  color: Colors.green, size: 28),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text('Quét QR thành công!',
                  style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize:   18,
                      color:      Color(0xFF1B5E20))),
            ),
          ]),
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 12),
          _infoRow('Sản phẩm:', p.productName),
          _infoRow('NSX:',
              DateFormat('dd/MM/yyyy').format(p.manufacturingDate)),
          _infoRow('HSD:',
              DateFormat('dd/MM/yyyy').format(p.expiryDate)),
          _infoRow('KL gói:', p.packageWeight),
          _infoRow('KL mẻ:',  p.batchWeight),
          const SizedBox(height: 16),
          const Text('Nhập số lượng:',
              style: TextStyle(
                  fontWeight: FontWeight.w700, fontSize: 15)),
          const SizedBox(height: 8),
          TextField(
            controller: notif.quantityController,
            keyboardType: TextInputType.number,
            autofocus:    true,
            textAlign:    TextAlign.center,
            style: const TextStyle(
                fontSize: 18, fontWeight: FontWeight.w600),
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly
            ],
            decoration: InputDecoration(
              hintText:  'Nhập số lượng',
              hintStyle: TextStyle(color: Colors.grey[400]),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12)),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                      color: Color(0xFF009688), width: 2)),
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 14),
            ),
          ),
          const SizedBox(height: 20),
          Row(children: [
            Expanded(
              child: OutlinedButton(
                focusNode:  FocusNode(canRequestFocus: false),
                onPressed:  () {
                  notif.scanAgain();
                  _cameraController?.start();
                },
                style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        vertical: 14),
                    side: const BorderSide(
                        color: Colors.grey, width: 1.5),
                    shape: RoundedRectangleBorder(
                        borderRadius:
                        BorderRadius.circular(12))),
                child: const Text('Quét tiếp',
                    style: TextStyle(
                        color:      Colors.grey,
                        fontWeight: FontWeight.w600)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                focusNode: FocusNode(canRequestFocus: false),
                onPressed: () {
                  notif.addProductToCurrentImport(context);
                  _cameraController?.start();
                },
                style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        vertical: 14),
                    backgroundColor: const Color(0xFF009688),
                    foregroundColor: Colors.white,
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                        borderRadius:
                        BorderRadius.circular(12))),
                child: const Text('Xác nhận',
                    style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize:   15)),
              ),
            ),
          ]),
        ],
      ),
    );
  }

  // ── Error modal ───────────────────────────────────────────────────

  Widget _buildErrorModal(
      QrImportState ctrl, QrImportNotifier notif) =>
      Material(
        color: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color:        Colors.redAccent.withOpacity(0.95),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                  color:      Colors.black.withOpacity(0.3),
                  blurRadius: 20)
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded,
                  color: Colors.white, size: 44),
              const SizedBox(height: 10),
              const Text('Lỗi quét QR',
                  style: TextStyle(
                      color:      Colors.white,
                      fontSize:   18,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(ctrl.scanErrorMessage!,
                  style: const TextStyle(
                      color: Colors.white, fontSize: 14),
                  textAlign: TextAlign.center),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  OutlinedButton(
                    focusNode: FocusNode(canRequestFocus: false),
                    onPressed: () {
                      notif.scanAgain();
                      _cameraController?.start();
                    },
                    style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(
                            color: Colors.white),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 12)),
                    child: const Text('Quét lại'),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton(
                    focusNode: FocusNode(canRequestFocus: false),
                    onPressed: () =>
                        Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.red,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 12)),
                    child: const Text('Đóng'),
                  ),
                ],
              ),
            ],
          ),
        ),
      );

  Widget _infoRow(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(children: [
      SizedBox(
          width: 85,
          child: Text(label,
              style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize:   13))),
      Expanded(
          child: Text(value,
              style: const TextStyle(
                  color:    Color(0xFF009688),
                  fontSize: 13))),
    ]),
  );
}


// ══════════════════════════════════════════════════════════════════
// SIMULATOR QR INPUT  (chỉ hiện trên iOS Simulator để test)
// ══════════════════════════════════════════════════════════════════

class _SimulatorQrInput extends StatefulWidget {
  final QrImportNotifier notif;
  const _SimulatorQrInput({required this.notif});

  @override
  State<_SimulatorQrInput> createState() => _SimulatorQrInputState();
}

class _SimulatorQrInputState extends State<_SimulatorQrInput> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      TextField(
        controller: _ctrl,
        style: const TextStyle(color: Colors.white, fontSize: 13),
        maxLines: 5,
        decoration: InputDecoration(
          hintText: 'Dán nội dung QR vào đây\nVD:\nSản phẩm: Hải sản\nNSX: 10/12/2025\nHSD: 10/12/2026\nKL Gói: 400gr\nKL Mẻ: 10kg',
          hintStyle: const TextStyle(color: Colors.white24, fontSize: 11),
          filled: true,
          fillColor: Colors.white10,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.white24)),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.white24)),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF009688), width: 1.5)),
        ),
      ),
      const SizedBox(height: 12),
      SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: () {
            final text = _ctrl.text.trim();
            if (text.isNotEmpty) {
              widget.notif.onQRDetected(text);
              _ctrl.clear();
            }
          },
          icon: const Icon(Icons.qr_code_scanner_rounded, size: 16),
          label: const Text('Giả lập quét QR'),
          style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF009688),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12))),
        ),
      ),
    ]);
  }
}

// ══════════════════════════════════════════════════════════════════
// CURRENT IMPORT BOTTOM SHEET
// ══════════════════════════════════════════════════════════════════

class _CurrentImportSheet extends ConsumerWidget {
  final ImportWarehouseModel model;
  final QrImportNotifier notif;
  final VoidCallback onClose;
  final VoidCallback onDone;

  const _CurrentImportSheet({
    required this.model,
    required this.notif,
    required this.onClose,
    required this.onDone,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(qrImportProvider);
    final current = state.currentImport ?? model;

    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Expanded(
              child: Text('Phiếu nhập hiện tại',
                  style: TextStyle(
                      fontSize:   18,
                      fontWeight: FontWeight.w800)),
            ),
            IconButton(
                onPressed: onClose,
                icon: const Icon(Icons.close_rounded)),
          ]),
          const Divider(),
          ...List.generate(
            current.products.length,
                (i) => ListTile(
              dense: true,
              leading: Container(
                width: 32, height: 32,
                decoration: BoxDecoration(
                    color: const Color(0xFF009688).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8)),
                child: Center(
                  child: Text('${i + 1}',
                      style: const TextStyle(
                          color:      Color(0xFF009688),
                          fontWeight: FontWeight.w700,
                          fontSize:   12)),
                ),
              ),
              title: Text(current.products[i].productName,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize:   13)),
              subtitle: Text(
                  'HSD: ${DateFormat('dd/MM/yyyy').format(current.products[i].expiryDate)} '
                      '· SL: ${current.products[i].quantity.toStringAsFixed(0)}',
                  style: const TextStyle(fontSize: 11)),
              trailing: IconButton(
                icon: const Icon(Icons.remove_circle_outline,
                    color: Colors.red, size: 20),
                onPressed: () => notif.removeProduct(i),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onDone,
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF009688),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12))),
              child: Text(
                  'Hoàn tất (${current.products.length} sản phẩm)',
                  style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize:   15)),
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════
// SCAN OVERLAY PAINTER  (4 vùng tối quanh khung)
// ══════════════════════════════════════════════════════════════════

class _ScanOverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const frameSize = 260.0;
    final frameLeft = (size.width  - frameSize) / 2;
    final frameTop  = (size.height - frameSize) / 2;
    final paint     = Paint()..color = Colors.black.withOpacity(0.6);

    canvas.drawRect(
        Rect.fromLTWH(0, 0, size.width, frameTop), paint);
    canvas.drawRect(
        Rect.fromLTWH(0, frameTop + frameSize, size.width,
            size.height - frameTop - frameSize),
        paint);
    canvas.drawRect(
        Rect.fromLTWH(0, frameTop, frameLeft, frameSize), paint);
    canvas.drawRect(
        Rect.fromLTWH(frameLeft + frameSize, frameTop,
            size.width - frameLeft - frameSize, frameSize),
        paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter _) => false;
}