// lib/shared/widgets/image_picker_field.dart
// Widget chọn ảnh tái sử dụng: hiển thị preview local (khi chọn)
// và CachedNetworkImage (sau khi upload thành công / edit mode)

import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../core/constants/api_constants.dart';
import 'network_image_viewer.dart';

// ── Callback typedefs ─────────────────────────────────────────────
typedef OnImagePicked = Future<void> Function(String filePath);

class ImagePickerField extends StatelessWidget {
  /// URL từ server (sau upload hoặc từ edit model)
  final String? imageUrl;

  /// Bytes preview local (file vừa chọn, trước khi upload xong)
  final Uint8List? previewBytes;

  /// Đường dẫn file local (non-web)
  final String? previewPath;

  /// Đang upload
  final bool isUploading;

  /// Lỗi upload
  final String? uploadError;

  /// Callback khi user chọn file
  final OnImagePicked onPick;

  /// Callback khi user xóa ảnh
  final VoidCallback? onClear;

  /// Label hiển thị
  final String label;

  /// Kích thước preview
  final double height;

  const ImagePickerField({
    super.key,
    this.imageUrl,
    this.previewBytes,
    this.previewPath,
    this.isUploading = false,
    this.uploadError,
    required this.onPick,
    this.onClear,
    this.label = 'Ảnh',
    this.height = 160,
  });

  bool get _hasLocalPreview =>
      previewBytes != null || (previewPath != null && previewPath!.isNotEmpty);

  bool get _hasNetworkImage =>
      imageUrl != null && imageUrl!.isNotEmpty;

  String _fullUrl(String url) {
    if (url.startsWith('http')) return url;
    return '${ApiConstants.baseUrl}${ApiConstants.images}$url';
  }

  @override
  Widget build(BuildContext context) {
    final isDark    = Theme.of(context).brightness == Brightness.dark;
    final primary   = isDark ? AppColors.primary : AppColors.primaryDark;
    final secondary = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final border    = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final bg        = isDark ? AppColors.darkBg : AppColors.lightBg;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Label
        Text(label,
            style: TextStyle(
                fontSize: 13,
                color: secondary,
                fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),

        // Preview box
        GestureDetector(
          onTap: isUploading ? null : _pickFile,
          child: Container(
            height: height,
            width:  double.infinity,
            decoration: BoxDecoration(
              color:        bg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: uploadError != null
                      ? AppColors.error
                      : (_hasLocalPreview || _hasNetworkImage)
                      ? primary.withOpacity(0.4)
                      : border),
            ),
            clipBehavior: Clip.hardEdge,
            child: Stack(fit: StackFit.expand, children: [
              // ── Image content ──────────────────────────────────
              _buildImageContent(primary, secondary),

              // ── Upload overlay ─────────────────────────────────
              if (isUploading)
                Container(
                  color: Colors.black.withOpacity(0.45),
                  child: const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2.5),
                        SizedBox(height: 10),
                        Text('Đang upload...',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ),

              // ── Clear button ───────────────────────────────────
              if ((_hasLocalPreview || _hasNetworkImage) &&
                  !isUploading &&
                  onClear != null)
                Positioned(
                  top: 8, right: 8,
                  child: GestureDetector(
                    onTap: onClear,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                          color:  Colors.black.withOpacity(0.6),
                          shape:  BoxShape.circle),
                      child: const Icon(Icons.close_rounded,
                          color: Colors.white, size: 14),
                    ),
                  ),
                ),

              // ── Upload done badge ──────────────────────────────
              if (_hasNetworkImage && !isUploading && !_hasLocalPreview)
                Positioned(
                  bottom: 8, right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color:        AppColors.success.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_rounded,
                            color: Colors.white, size: 12),
                        SizedBox(width: 4),
                        Text('Đã upload',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                ),
            ]),
          ),
        ),

        // Error message
        if (uploadError != null) ...[
          const SizedBox(height: 6),
          Row(children: [
            Icon(Icons.error_outline_rounded,
                size: 13, color: AppColors.error),
            const SizedBox(width: 4),
            Expanded(
              child: Text(uploadError!,
                  style: TextStyle(
                      fontSize: 11, color: AppColors.error)),
            ),
          ]),
        ],

        // Change image hint
        if ((_hasLocalPreview || _hasNetworkImage) && !isUploading) ...[
          const SizedBox(height: 6),
          Center(
            child: Text('Nhấn để đổi ảnh',
                style: TextStyle(
                    fontSize: 11,
                    color: secondary.withOpacity(0.7))),
          ),
        ],
      ],
    );
  }

  Widget _buildImageContent(Color primary, Color secondary) {
    // 1. Local preview bytes (web hoặc ngay sau khi chọn)
    if (previewBytes != null) {
      return Image.memory(previewBytes!, fit: BoxFit.cover);
    }

    // 2. Local file path (mobile sau khi chọn, trước khi upload xong)
    if (previewPath != null && previewPath!.isNotEmpty && !kIsWeb) {
      return Image.file(File(previewPath!), fit: BoxFit.cover);
    }

    // 3. Network URL (sau upload hoặc từ edit mode)
    if (_hasNetworkImage) {
      return NetworkImageViewer(
        imageUrl: imageUrl!,
        fit: BoxFit.cover,
      );
    }

    // 4. Empty state
    return _buildEmptyState(primary, secondary);
  }

  Widget _buildEmptyState(Color primary, Color secondary) => Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color:        primary.withOpacity(0.08),
          shape:        BoxShape.circle,
        ),
        child: Icon(Icons.add_photo_alternate_outlined,
            size: 28, color: primary.withOpacity(0.6)),
      ),
      const SizedBox(height: 10),
      Text('Nhấn để chọn ảnh',
          style: TextStyle(
              fontSize: 13,
              color: secondary,
              fontWeight: FontWeight.w500)),
      const SizedBox(height: 4),
      Text('JPG, PNG, WEBP',
          style: TextStyle(
              fontSize: 11,
              color: secondary.withOpacity(0.6))),
    ],
  );

  Future<void> _pickFile() async {
    final picked = await ImagePicker().pickImage(
      source:              ImageSource.gallery,
      imageQuality:        85,
      requestFullMetadata: false,
    );
    if (picked == null) return;
    await onPick(picked.path);
  }
}