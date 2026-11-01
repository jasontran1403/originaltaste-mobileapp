import 'dart:io';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:file_saver/file_saver.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

Future<void> saveFile({
  required Response response,
  required BuildContext context,
  String fallbackName = 'file',
}) async {
  try {
    await Future.delayed(const Duration(milliseconds: 200));

    final bytes = response.data as List<int>;

    final contentType = response.headers.value('content-type');
    final mime = _mapMime(contentType);
    final ext  = _mapExt(mime);

    final headerName = _getFileName(response.headers);

    final fileName = headerName ??
        '$fallbackName.$ext';

    // ================== 1. Lưu file tạm (để open) ==================
    final tempDir = await getTemporaryDirectory();
    final tempFile = File('${tempDir.path}/$fileName');
    await tempFile.writeAsBytes(bytes);

    // ================== 2. Save bằng file_saver ==================
    await FileSaver.instance.saveFile(
      name: fileName.replaceAll('.$ext', ''),
      bytes: Uint8List.fromList(bytes),
      ext: ext,
      mimeType: mime,
    );

    if (!context.mounted) return;

    // ================== 3. Show action UI ==================
    final messenger = ScaffoldMessenger.of(context);

    messenger.hideCurrentSnackBar();

    messenger.showSnackBar(
      SnackBar(
        duration: const Duration(days: 1), // không tự tắt
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF14B8A6),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded,
                color: Colors.white, size: 18),
            const SizedBox(width: 10),

            // Text
            Expanded(
              child: Text(
                'Đã lưu $fileName',
                style: const TextStyle(fontSize: 13),
                overflow: TextOverflow.ellipsis,
              ),
            ),

            // Nút MỞ
            GestureDetector(
              onTap: () async {
                final result = await OpenFilex.open(tempFile.path);

                // fallback nếu không mở được
                if (result.type != ResultType.done) {
                  await Share.shareXFiles([XFile(tempFile.path)]);
                }
              },
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  'MỞ',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ),

            // Nút ĐÓNG
            GestureDetector(
              onTap: () {
                messenger.hideCurrentSnackBar();
              },
              child: const Padding(
                padding: EdgeInsets.only(left: 4),
                child: Icon(Icons.close,
                    size: 16, color: Colors.white70),
              ),
            ),
          ],
        ),
      ),
    );

  } catch (e) {
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('❌ Lỗi lưu file: $e'),
        backgroundColor: Colors.red,
      ),
    );
  }
}

String? _getFileName(Headers headers) {
  final dispo = headers.value('content-disposition');
  if (dispo == null) return null;

  final regex = RegExp(r'filename="(.+?)"');
  final match = regex.firstMatch(dispo);
  return match?.group(1);
}

MimeType _mapMime(String? contentType) {
  if (contentType == null) return MimeType.other;

  if (contentType.contains('pdf')) return MimeType.pdf;

  if (contentType.contains('sheet') ||
      contentType.contains('excel')) {
    return MimeType.microsoftExcel;
  }

  return MimeType.other;
}

String _mapExt(MimeType mime) {
  switch (mime) {
    case MimeType.pdf:
      return 'pdf';
    case MimeType.microsoftExcel:
      return 'xlsx';
    default:
      return 'bin';
  }
}