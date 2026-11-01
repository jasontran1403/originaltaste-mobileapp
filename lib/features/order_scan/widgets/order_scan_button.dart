// lib/features/order_scan/widgets/order_scan_button.dart
//
// Nút chính "Quét phiếu đặt hàng" trong tab "Nhập" của SELLER.
//
// Bấm → bottom sheet 3 lựa chọn:
//   • Chụp ảnh              → mở custom camera có guideline
//   • Chọn ảnh có sẵn        → image_picker gallery
//   • Chọn file PDF          → file_picker
//
// Sau khi có File → gọi OrderFormOcrService → in log + mở dialog debug.

import 'dart:developer' as dev;
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/parsed_order_form.dart';
import '../screens/order_scan_camera_screen.dart';
import '../screens/order_scan_result_dialog.dart';
import '../services/order_form_ocr_service.dart';

class OrderScanButton extends StatefulWidget {
  final Color? accent;
  const OrderScanButton({super.key, this.accent});

  @override
  State<OrderScanButton> createState() => _OrderScanButtonState();
}

class _OrderScanButtonState extends State<OrderScanButton> {
  bool _busy = false;

  Future<void> _openMenu() async {
    final choice = await showModalBottomSheet<_ScanSource>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => const _ScanSourceSheet(),
    );
    if (choice == null || !mounted) return;

    File? file;
    switch (choice) {
      case _ScanSource.camera:
        file = await Navigator.of(context).push<File?>(MaterialPageRoute(
          builder: (_) => const OrderScanCameraScreen(),
          fullscreenDialog: true,
        ));
        break;

      case _ScanSource.gallery:
        final xf = await ImagePicker().pickImage(
            source: ImageSource.gallery, imageQuality: 92, maxWidth: 2400);
        if (xf != null) file = File(xf.path);
        break;

      case _ScanSource.pdf:
        final r = await FilePicker.platform.pickFiles(
            type: FileType.custom, allowedExtensions: ['pdf']);
        final p = r?.files.single.path;
        if (p != null) file = File(p);
        break;
    }
    if (file == null || !mounted) return;
    await _process(file);
  }

  Future<void> _process(File file) async {
    setState(() => _busy = true);
    try {
      dev.log('[OrderScan] Bắt đầu xử lý: ${file.path}', name: 'OrderScan');
      final result = await OrderFormOcrService.instance.recognize(file);
      _logResult(result);
      if (!mounted) return;
      await OrderScanResultDialog.show(context, result);
    } catch (e, st) {
      dev.log('[OrderScan] LỖI: $e', name: 'OrderScan', error: e, stackTrace: st);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Không đọc được phiếu: $e'),
        backgroundColor: Colors.red,
      ));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _logResult(ParsedOrderForm r) {
    final buf = StringBuffer()
      ..writeln('══════════════════════════════════════════════')
      ..writeln('  KẾT QUẢ TRÍCH XUẤT PHIẾU ĐẶT HÀNG')
      ..writeln('══════════════════════════════════════════════');

    if (r.customerName == null) {
      buf.writeln('❌ BƯỚC 1: KHÔNG lấy được tên khách hàng.');
    } else if (r.isOriginalTaste) {
      buf.writeln('✅ BƯỚC 1: Tên khách hàng = "${r.customerName}" — đúng Original Taste.');
    } else {
      buf.writeln('⚠ BƯỚC 1: Tên khách hàng = "${r.customerName}" — KHÔNG phải Original Taste.');
      buf.writeln('           → Theo yêu cầu, sẽ DỪNG xử lý ở đây.');
    }

    if (r.orderNumber == null) {
      buf.writeln('❌ BƯỚC 2: KHÔNG lấy được số phiếu.');
    } else {
      buf.writeln('✅ BƯỚC 2: Số phiếu = ${r.orderNumber}');
    }

    if (r.items.isEmpty) {
      buf.writeln('❌ BƯỚC 3: KHÔNG trích xuất được sản phẩm nào từ bảng.');
    } else {
      buf.writeln('✅ BƯỚC 3: Trích xuất ${r.items.length} sản phẩm:');
      for (final it in r.items) {
        buf.writeln(it.toString());
      }
    }
    buf.writeln('══════════════════════════════════════════════');
    dev.log(buf.toString(), name: 'OrderScan');
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.accent ?? const Color(0xFF0EA5E9);
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: _busy ? null : _openMenu,
        icon: _busy
            ? const SizedBox(
            width: 16, height: 16,
            child: CircularProgressIndicator(strokeWidth: 2))
            : Icon(Icons.document_scanner_outlined, color: color, size: 18),
        label: Text(
          _busy ? 'Đang xử lý...' : 'Quét phiếu đặt hàng',
          style: TextStyle(color: color, fontWeight: FontWeight.w700),
        ),
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: color.withOpacity(0.4)),
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          backgroundColor: color.withOpacity(0.06),
        ),
      ),
    );
  }
}

enum _ScanSource { camera, gallery, pdf }

class _ScanSourceSheet extends StatelessWidget {
  const _ScanSourceSheet();

  @override
  Widget build(BuildContext context) {
    Widget tile(IconData icon, String label, String hint, _ScanSource src) =>
        ListTile(
          leading: Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFF0EA5E9).withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: const Color(0xFF0EA5E9)),
          ),
          title: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
          subtitle: Text(hint, style: const TextStyle(fontSize: 12)),
          onTap: () => Navigator.of(context).pop(src),
        );

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(top: false, child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 40, height: 4, margin: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(4))),
        const Padding(
          padding: EdgeInsets.only(bottom: 8),
          child: Text(
            'Chọn nguồn phiếu đặt hàng',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          ),
        ),
        tile(Icons.camera_alt_outlined, 'Chụp ảnh',
            'Mở camera có khung canh chỉnh', _ScanSource.camera),
        tile(Icons.photo_library_outlined, 'Chọn ảnh có sẵn',
            'Từ thư viện ảnh của thiết bị', _ScanSource.gallery),
        tile(Icons.picture_as_pdf_outlined, 'Chọn file PDF',
            'File PDF phiếu đặt hàng', _ScanSource.pdf),
        const SizedBox(height: 8),
      ])),
    );
  }
}