// lib/features/pos/widgets/ocr_camera_button.dart
//
// Nút "Chụp ảnh" cho kho đầu ca / cuối ca.
//
// Flow:
//   1. Tap nút → bottom sheet chọn Camera hoặc Thư viện
//   2. Ảnh được add vào danh sách preview (có thể xóa từng ảnh)
//   3. Trong preview có nút "Chụp thêm" để thêm ảnh tiếp theo
//   4. Nhấn "Gửi X ảnh" → upload lên server → show OcrResultDialog
//   5. User xác nhận / chỉnh sửa → onOcrFill được gọi

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../services/pos_service.dart';
import 'ocr_result_dialog.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Public widget — thay thế _OcrCameraButton cũ trong pos_shift_screen.dart
// ─────────────────────────────────────────────────────────────────────────────

class OcrCameraButton extends StatefulWidget {
  final bool   isClose;
  final int?   shiftId;
  final List<Map<String, dynamic>> allIngredients;
  final void Function(ShiftOcrResult result)? onOcrFill;

  const OcrCameraButton({
    super.key,
    required this.isClose,
    required this.allIngredients,
    this.shiftId,
    this.onOcrFill,
  });

  @override
  State<OcrCameraButton> createState() => _OcrCameraButtonState();
}

class _OcrCameraButtonState extends State<OcrCameraButton> {
  bool _uploading = false;

  // ── Tap nút → mở bottom sheet preview / chọn ảnh ─────────────────────────
  Future<void> _onTap() async {
    // Mở ImagePreviewSheet — sheet tự quản lý danh sách ảnh
    final List<File>? files = await showModalBottomSheet<List<File>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ImagePreviewSheet(isClose: widget.isClose),
    );

    if (files == null || files.isEmpty || !mounted) return;

    // Upload
    setState(() => _uploading = true);
    try {
      final ShiftOcrResult result;
      if (widget.isClose && widget.shiftId != null) {
        result = await PosService.instance.uploadCloseShiftImages(
          files:   files,
          shiftId: widget.shiftId!,
        );
      } else {
        result = await PosService.instance.uploadOpenShiftImages(
          files:   files,
          shiftId: widget.shiftId,
        );
      }

      if (!mounted) return;

      if (!result.isSuccess) {
        _snack('OCR thất bại: ${result.errorMessage ?? "Lỗi không xác định"}',
            isError: true);
        return;
      }

      if (result.inventoryList.isEmpty) {
        _snack('Không nhận dạng được nguyên liệu nào từ ${files.length} ảnh',
            isError: true);
        return;
      }

      // Show dialog xác nhận
      await OcrResultDialog.show(
        context,
        ocrResult:      result,
        allIngredients: widget.allIngredients,
        onConfirm: (confirmedItems) {
          final confirmed = ShiftOcrResult(
            imagePath:     result.imagePath,
            ocrStatus:     'SUCCESS',
            staffName:     result.staffName,
            date:          result.date,
            inventoryList: confirmedItems,
          );
          widget.onOcrFill?.call(confirmed);
          _snack('Đã điền ${confirmedItems.length} nguyên liệu từ ${files.length} ảnh');
        },
      );
    } catch (e) {
      if (mounted) _snack('Lỗi upload: $e', isError: true);
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  void _snack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content:         Text(msg),
      backgroundColor: isError ? Colors.red.shade600 : Colors.green.shade600,
      behavior:        SnackBarBehavior.floating,
      duration:        Duration(seconds: isError ? 4 : 2),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.isClose ? Colors.blue.shade700 : Colors.orange.shade700;
    return GestureDetector(
      onTap: _uploading ? null : _onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color:        color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(8),
          border:       Border.all(color: color.withOpacity(0.35)),
        ),
        child: _uploading
            ? SizedBox(
            width: 16, height: 16,
            child: CircularProgressIndicator(strokeWidth: 2, color: color))
            : Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.camera_alt_outlined, size: 15, color: color),
          const SizedBox(width: 5),
          Text('Chụp ảnh',
              style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w700, color: color)),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _ImagePreviewSheet — bottom sheet quản lý danh sách ảnh đã chụp
// ─────────────────────────────────────────────────────────────────────────────

class _ImagePreviewSheet extends StatefulWidget {
  final bool isClose;
  const _ImagePreviewSheet({required this.isClose});

  @override
  State<_ImagePreviewSheet> createState() => _ImagePreviewSheetState();
}

class _ImagePreviewSheetState extends State<_ImagePreviewSheet> {
  final _picker = ImagePicker();
  final List<File> _files = [];
  bool _picking = false;

  Color get _accent =>
      widget.isClose ? Colors.blue.shade700 : Colors.orange.shade700;

  // ── Chọn ảnh từ camera hoặc gallery ─────────────────────────────────────────
  Future<void> _pickOne(ImageSource source) async {
    if (_picking) return;
    setState(() => _picking = true);
    try {
      final picked = await _picker.pickImage(
        source:       source,
        imageQuality: 85,
        maxWidth:     1920,
      );
      if (picked != null && mounted) {
        setState(() => _files.add(File(picked.path)));
      }
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  // ── Chọn nhiều từ gallery một lúc ────────────────────────────────────────────
  Future<void> _pickMultipleFromGallery() async {
    if (_picking) return;
    setState(() => _picking = true);
    try {
      final picked = await _picker.pickMultiImage(
        imageQuality: 85,
        maxWidth:     1920,
      );
      if (picked.isNotEmpty && mounted) {
        setState(() => _files.addAll(picked.map((x) => File(x.path))));
      }
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  void _remove(int index) => setState(() => _files.removeAt(index));

  void _submit() => Navigator.of(context).pop(List<File>.from(_files));

  // ── Build ─────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final cs     = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasFiles = _files.isNotEmpty;

    return Container(
      // Chiều cao tối đa 75% màn hình
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.75,
      ),
      margin:     const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color:        isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Handle ─────────────────────────────────────────────────
          Container(
            width: 40, height: 4,
            margin: const EdgeInsets.only(top: 12, bottom: 4),
            decoration: BoxDecoration(
                color:        cs.outline.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2)),
          ),

          // ── Header ─────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Row(children: [
              Container(
                padding:     const EdgeInsets.all(8),
                decoration:  BoxDecoration(
                  color:        _accent.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.photo_library_outlined, size: 18, color: _accent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(
                    widget.isClose ? 'Ảnh kiểm kho cuối ca' : 'Ảnh kiểm kho đầu ca',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    hasFiles
                        ? 'Đã chọn ${_files.length} ảnh — có thể thêm hoặc xóa'
                        : 'Chụp ảnh bảng kiểm kho để OCR tự động điền',
                    style: TextStyle(
                        fontSize: 12, color: cs.onSurface.withOpacity(0.5)),
                  ),
                ]),
              ),
              // Badge số ảnh
              if (hasFiles)
                Container(
                  padding:    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color:        _accent,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text('${_files.length}',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.bold)),
                ),
            ]),
          ),

          const Divider(height: 1),

          // ── Grid preview ảnh đã chọn ──────────────────────────────
          if (hasFiles)
            Flexible(
              child: GridView.builder(
                padding:     const EdgeInsets.all(12),
                shrinkWrap:  true,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount:   3,
                  crossAxisSpacing: 8,
                  mainAxisSpacing:  8,
                ),
                itemCount: _files.length,
                itemBuilder: (_, i) => _ImageTile(
                  file:     _files[i],
                  index:    i,
                  onRemove: () => _remove(i),
                ),
              ),
            ),

          // ── Empty state ───────────────────────────────────────────
          if (!hasFiles)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 28),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.add_a_photo_outlined,
                    size: 48, color: cs.onSurface.withOpacity(0.2)),
                const SizedBox(height: 8),
                Text('Chưa có ảnh nào',
                    style: TextStyle(
                        color: cs.onSurface.withOpacity(0.35), fontSize: 14)),
              ]),
            ),

          const Divider(height: 1),

          // ── Action buttons ────────────────────────────────────────
          Padding(
            padding: EdgeInsets.fromLTRB(
                16, 10, 16, MediaQuery.of(context).padding.bottom + 12),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              // Hàng nút thêm ảnh
              Row(children: [
                // Nút Camera
                Expanded(
                  child: _ActionBtn(
                    icon:    Icons.camera_alt_rounded,
                    label:   _files.isEmpty ? 'Chụp ảnh' : 'Chụp thêm',
                    color:   _accent,
                    loading: _picking,
                    onTap:   () => _pickOne(ImageSource.camera),
                  ),
                ),
                const SizedBox(width: 8),
                // Nút Thư viện
                Expanded(
                  child: _ActionBtn(
                    icon:    Icons.photo_library_rounded,
                    label:   'Thư viện',
                    color:   Colors.grey.shade600,
                    loading: _picking,
                    onTap:   _pickMultipleFromGallery,
                  ),
                ),
              ]),

              const SizedBox(height: 10),

              // Nút Gửi — chỉ hiện khi có ảnh
              if (hasFiles)
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    icon: const Icon(Icons.upload_rounded, size: 18),
                    label: Text(
                      'Gửi ${_files.length} ảnh để nhận dạng',
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: _accent,
                      foregroundColor: Colors.white,
                      padding:         const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: _submit,
                  ),
                ),

              // Nút Hủy
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text('Hủy',
                    style: TextStyle(color: cs.onSurface.withOpacity(0.5))),
              ),
            ]),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _ImageTile — ô ảnh trong grid với nút xóa
// ─────────────────────────────────────────────────────────────────────────────

class _ImageTile extends StatelessWidget {
  final File     file;
  final int      index;
  final VoidCallback onRemove;

  const _ImageTile({
    required this.file,
    required this.index,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Ảnh
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image.file(file, fit: BoxFit.cover),
        ),
        // Số thứ tự
        Positioned(
          left: 6, bottom: 6,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color:        Colors.black54,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text('${index + 1}',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold)),
          ),
        ),
        // Nút xóa
        Positioned(
          top: 4, right: 4,
          child: GestureDetector(
            onTap: onRemove,
            child: Container(
              width: 22, height: 22,
              decoration: const BoxDecoration(
                  color: Colors.black54, shape: BoxShape.circle),
              child: const Icon(Icons.close_rounded,
                  size: 14, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _ActionBtn — nút thêm ảnh (camera / gallery)
// ─────────────────────────────────────────────────────────────────────────────

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String   label;
  final Color    color;
  final bool     loading;
  final VoidCallback onTap;

  const _ActionBtn({
    required this.icon,
    required this.label,
    required this.color,
    required this.loading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: loading ? null : onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color:        color.withOpacity(0.09),
          borderRadius: BorderRadius.circular(12),
          border:       Border.all(color: color.withOpacity(0.3)),
        ),
        child: loading
            ? Center(
            child: SizedBox(
              width: 18, height: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: color),
            ))
            : Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 22, color: color),
          const SizedBox(height: 4),
          Text(label,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: color)),
        ]),
      ),
    );
  }
}