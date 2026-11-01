// lib/features/order_scan/services/order_form_ocr_service.dart
//
// OCR + rasterize PDF, trả về [OcrText] gồm text + bounding boxes.
//
// Preprocess PDF page: SOFT-THRESHOLD thay vì binary thuần.
//   • Watermark hồng nhạt (grayscale ~210-230)   → thành trắng thuần
//   • Chữ đen đậm (grayscale ~0-100)              → GIỮ NGUYÊN grayscale
//   • Anti-aliasing chữ đỏ / xám (grayscale 100-200) → GIỮ NGUYÊN
//
// Vì sao không binary thuần: chữ đỏ nhỏ "NĐ: 05984" bị mất chi tiết khi
// threshold đen/trắng thuần → ML Kit không đọc được. Giữ lại grayscale
// preserved anti-aliasing → ML Kit đọc chuẩn.

import 'dart:developer' as dev;
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' show Rect;

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:pdfx/pdfx.dart';

import '../models/parsed_order_form.dart';
import 'order_form_parser.dart';

/// Kết quả OCR: tất cả text lines đã kèm bounding box (toạ độ pixel).
class OcrText {
  final String rawText;
  final List<OcrLine> lines;
  const OcrText({required this.rawText, required this.lines});
}

class OcrLine {
  final String text;
  final Rect box;
  OcrLine({required this.text, required this.box});

  double get left => box.left;
  double get top => box.top;
  double get right => box.right;
  double get bottom => box.bottom;
  double get cx => box.center.dx;
  double get cy => box.center.dy;
  double get w => box.width;
  double get h => box.height;
}

class OrderFormOcrService {
  OrderFormOcrService._();
  static final instance = OrderFormOcrService._();

  final TextRecognizer _recognizer =
  TextRecognizer(script: TextRecognitionScript.latin);

  Future<void> dispose() async => _recognizer.close();

  Future<ParsedOrderForm> recognize(File file) async {
    final ext = file.path.toLowerCase();
    final ocr = ext.endsWith('.pdf')
        ? await _recognizePdf(file)
        : await _recognizeImage(file);
    dev.log('[OrderScan] OCR xong: ${ocr.lines.length} lines, '
        '${ocr.rawText.length} ký tự.', name: 'OrderScan');
    return OrderFormParser.parse(ocr);
  }

  Future<OcrText> _recognizeImage(File imageFile) async {
    dev.log('[OrderScan] OCR ảnh: ${imageFile.path}', name: 'OrderScan');
    final input = InputImage.fromFile(imageFile);
    final rec = await _recognizer.processImage(input);
    return _flatten(rec, yOffset: 0);
  }

  Future<OcrText> _recognizePdf(File pdfFile) async {
    dev.log('[OrderScan] Đọc PDF: ${pdfFile.path}', name: 'OrderScan');
    final doc = await PdfDocument.openFile(pdfFile.path);
    dev.log('[OrderScan] PDF có ${doc.pagesCount} trang.', name: 'OrderScan');

    final tmpDir = await getTemporaryDirectory();
    final buf = StringBuffer();
    final allLines = <OcrLine>[];
    double yOffset = 0;

    const dpi = 300.0;
    final scale = dpi / 72.0;

    for (var i = 1; i <= doc.pagesCount; i++) {
      final page = await doc.getPage(i);
      final w = (page.width * scale).round();
      final h = (page.height * scale).round();
      final pageImage = await page.render(
        width: w.toDouble(),
        height: h.toDouble(),
        format: PdfPageImageFormat.png,
      );
      await page.close();
      if (pageImage == null) continue;

      final cleanedBytes = _preprocess(pageImage.bytes as Uint8List);

      final tmpFile = File(
          '${tmpDir.path}/order_scan_pdf_${DateTime.now().microsecondsSinceEpoch}_p$i.png');
      await tmpFile.writeAsBytes(cleanedBytes);

      dev.log('[OrderScan] OCR trang PDF $i (${w}×$h, đã xử lý)…',
          name: 'OrderScan');
      final rec = await _recognizer.processImage(InputImage.fromFile(tmpFile));

      buf.writeln('--- PAGE $i ---');
      buf.writeln(rec.text);

      final pageOcr = _flatten(rec, yOffset: yOffset);
      allLines.addAll(pageOcr.lines);
      yOffset += h.toDouble() + 40;

      try { await tmpFile.delete(); } catch (_) {}
    }
    await doc.close();

    return OcrText(rawText: buf.toString(), lines: allLines);
  }

  /// SOFT threshold:
  ///   pixel sáng hơn 205 (nền + watermark hồng nhạt) → trắng thuần
  ///   pixel tối hơn 205 (chữ + anti-aliasing)         → GIỮ NGUYÊN
  ///
  /// Khác binary thuần: giữ được chi tiết anti-aliasing của chữ nhỏ
  /// (đặc biệt chữ đỏ "NĐ: 05984") → ML Kit đọc chuẩn hơn.
  ///
  /// Nếu watermark chưa biến mất hết (đậm hơn thường), giảm ngưỡng xuống 190.
  /// Nếu chữ bị mất chi tiết (mờ), tăng ngưỡng lên 220.
  Uint8List _preprocess(Uint8List pngBytes) {
    try {
      final image = img.decodePng(pngBytes);
      if (image == null) return pngBytes;

      const int threshold = 205;
      final gray = img.grayscale(image);
      for (final p in gray) {
        if (p.r > threshold) {
          p.setRgb(255, 255, 255);
        }
        // else: giữ nguyên grayscale — bảo toàn anti-aliasing cho OCR
      }
      return Uint8List.fromList(img.encodePng(gray));
    } catch (e) {
      dev.log('[OrderScan] Preprocess fail, dùng ảnh gốc: $e', name: 'OrderScan');
      return pngBytes;
    }
  }

  OcrText _flatten(RecognizedText rec, {required double yOffset}) {
    final lines = <OcrLine>[];
    for (final block in rec.blocks) {
      for (final line in block.lines) {
        final r = line.boundingBox;
        lines.add(OcrLine(
          text: line.text,
          box: Rect.fromLTRB(
            r.left.toDouble(),
            r.top.toDouble() + yOffset,
            r.right.toDouble(),
            r.bottom.toDouble() + yOffset,
          ),
        ));
      }
    }
    return OcrText(rawText: rec.text, lines: lines);
  }
}