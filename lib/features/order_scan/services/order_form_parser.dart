// lib/features/order_scan/services/order_form_parser.dart
//
// Parser dùng BOUNDING BOX + validation nhiều lớp để không nhầm hàng
// ký tên ("Trưởng bộ phận, Thủ kho, Người giao, Người nhận, Người lập
// phiếu") thành sản phẩm.
//
// 2 lớp bảo vệ:
//   1. Footer detection dùng NHIỀU marker + chọn Y NHỎ NHẤT — kể cả OCR
//      tách "Thành tiền:" nhầm hoặc thiếu 1 mốc, các mốc khác bù cho nhau.
//   2. Row validation: 1 dòng chỉ là sản phẩm nếu có ĐVT hoặc SL hoặc
//      (Đơn giá + Thành tiền). Hàng ký tên không có cột nào trong bảng
//      giá tiền → auto bị reject.

import 'dart:math';

import '../models/parsed_order_form.dart';
import 'order_form_ocr_service.dart';

class OrderFormParser {
  static ParsedOrderForm parse(OcrText ocr) {
    return ParsedOrderForm(
      rawText: ocr.rawText,
      customerName: _extractCustomerName(ocr),
      orderNumber: _extractOrderNumber(ocr),
      items: _extractItems(ocr),
    );
  }

  // ═══════════════════════════════════════════════════════════
  //  1. TÊN KHÁCH HÀNG
  // ═══════════════════════════════════════════════════════════

  static String? _extractCustomerName(OcrText doc) {
    final labelRe = RegExp(
        r'T[êe]n\s*kh[áa]ch\s*h[àa]ng', caseSensitive: false);
    final label = _firstWhere(doc.lines, (l) => labelRe.hasMatch(l.text));

    if (label != null) {
      final after = _afterColon(label.text);
      if (after != null && after.isNotEmpty && !_looksLikeLabel(after)) {
        return _clean(after);
      }
      final rightValue = _findRightValueOnSameRow(doc, label);
      if (rightValue != null) return _clean(rightValue);
      final belowValue = _findBelowValue(doc, label);
      if (belowValue != null) return _clean(belowValue);
    }
    final ot = _firstWhere(doc.lines,
            (l) => RegExp(r'original\s*taste', caseSensitive: false).hasMatch(l.text));
    if (ot != null) return _clean(ot.text);
    return null;
  }

  static String? _findRightValueOnSameRow(OcrText doc, OcrLine label) {
    final yTol = label.h * 0.7;
    final candidates = doc.lines.where((l) {
      if (identical(l, label)) return false;
      if ((l.cy - label.cy).abs() > yTol) return false;
      if (l.left < label.right - label.w * 0.2) return false;
      return true;
    }).toList()..sort((a, b) => a.left.compareTo(b.left));
    for (final c in candidates) {
      if (!_looksLikeLabel(c.text)) return c.text;
    }
    return null;
  }

  static String? _findBelowValue(OcrText doc, OcrLine label) {
    final xTol = max(label.w * 1.5, 200.0);
    final candidates = doc.lines.where((l) {
      if (identical(l, label)) return false;
      if (l.cy <= label.bottom) return false;
      if (l.cy - label.bottom > label.h * 3) return false;
      if ((l.cx - label.cx).abs() > xTol) return false;
      return true;
    }).toList()..sort((a, b) => a.top.compareTo(b.top));
    for (final c in candidates.take(3)) {
      if (!_looksLikeLabel(c.text)) return c.text;
    }
    return null;
  }

  // ═══════════════════════════════════════════════════════════
  //  2. SỐ PHIẾU
  // ═══════════════════════════════════════════════════════════
  //
  // OCR thường mất dấu tiếng Việt trên chữ nhỏ (đặc biệt chữ đỏ):
  //   "NĐ" → đọc thành "ND"     (mất dấu chấm dưới Đ)
  //   "OĐ" → đọc thành "OD"
  //   "PĐH" → đọc thành "PDH"
  //
  // Trong tiếng Việt, prefix mã phiếu chuẩn HẦU NHƯ luôn dùng "Đ" chứ
  // không dùng "D" thuần (vì "Đơn" là từ viết tắt phổ biến nhất). Do
  // đó áp dụng rule tổng quát: mọi "D"/"d" trong prefix → "Đ"/"đ".
  //
  // Nếu sau này gặp prefix thật sự dùng "D" (hiếm), thêm vào whitelist
  // [_keepAsD] để giữ nguyên.

  static const Set<String> _keepAsD = {
    // Thêm vào đây các prefix mà "D" thật sự là D, không phải Đ.
    // VD: 'SD', 'DK', ... (hiện chưa có case nào)
  };

  static String? _extractOrderNumber(OcrText doc) {
    final re = RegExp(
      r'([A-Za-zĐÊÔƠƯÁÀẢÃẠĂÂÉÈẺẼẸÍÌỈĨỊÓÒỎÕỌỐỒỔỖỘỚỜỞỠỢÚÙỦŨỤỨỪỬỮỰÝỲỶỸỴđêôơưáàảãạăâéèẻẽẹíìỉĩịóòỏõọốồổỗộớờởỡợúùủũụứừửữựýỳỷỹỵ]{1,4})\s*[:：]\s*(\d{3,10})',
      unicode: true,
    );
    for (final line in doc.lines) {
      final m = re.firstMatch(line.text);
      if (m != null) {
        final prefix = m.group(1)!.replaceAll(' ', '');
        if (!_isKnownNonPrefix(prefix)) {
          return '${_fixPrefix(prefix)}-${m.group(2)}';
        }
      }
    }
    for (final m in re.allMatches(doc.rawText)) {
      final prefix = m.group(1)!.replaceAll(' ', '');
      if (_isKnownNonPrefix(prefix)) continue;
      return '${_fixPrefix(prefix)}-${m.group(2)}';
    }
    return null;
  }

  /// Khôi phục dấu Đ bị OCR bỏ sót ở prefix mã phiếu.
  /// Prefix chuẩn tiếng Việt hầu như luôn dùng Đ, nên D → Đ là an toàn.
  /// Whitelist [_keepAsD] cho các prefix thật sự dùng D thuần.
  static String _fixPrefix(String p) {
    if (_keepAsD.contains(p)) return p;
    return p.replaceAll('D', 'Đ').replaceAll('d', 'đ');
  }

  static bool _isKnownNonPrefix(String p) {
    final low = p.toLowerCase();
    return const {'kg', 'g', 'ml', 'l', 'cai', 'cái', 'pc', 'pcs'}.contains(low);
  }

  // ═══════════════════════════════════════════════════════════
  //  3. DANH SÁCH SẢN PHẨM
  // ═══════════════════════════════════════════════════════════

  static List<ParsedOrderItem> _extractItems(OcrText doc) {
    final headerCols = _detectHeader(doc);
    if (headerCols == null) return _extractItemsFallback(doc);

    final headerY = headerCols.headerBottomY;

    // ── Footer detection — dùng NHIỀU marker để không lỡ ────
    //
    // OCR có thể tách "Thành tiền:" thành 2 line rời (title + ":") hoặc
    // merge với dòng khác. Ta gom tất cả marker khả dĩ và chọn Y NHỎ NHẤT
    // — line kết thúc body sớm nhất là mốc an toàn nhất.
    final footerMarkers = doc.lines.where((l) {
      final t = l.text;
      return
        // Phần tổng kết
        RegExp(r'T[ổo]ng\s*c[ộo]ng', caseSensitive: false).hasMatch(t) ||
            RegExp(r'Gi[ảa]m\s*gi[áa]', caseSensitive: false).hasMatch(t) ||
            RegExp(r'Th[àa]nh\s*ti[êe]n\s*[:：]', caseSensitive: false).hasMatch(t) ||
            RegExp(r'vi[êe]t\s*b[ằa]ng\s*ch[ữu]', caseSensitive: false).hasMatch(t) ||
            // Hàng ký tên (nếu tới đây rồi thì chắc chắn đã qua bảng)
            RegExp(r'Tr[ưu][ởo]ng\s*b[ộo]\s*ph[ậa]n', caseSensitive: false).hasMatch(t) ||
            RegExp(r'Ng[ưu][ờo]i\s*l[ậa]p\s*phi[ếe]u', caseSensitive: false).hasMatch(t) ||
            RegExp(r'^Th[ủu]\s*kho\s*$', caseSensitive: false).hasMatch(t.trim()) ||
            RegExp(r'^Ng[ưu][ờo]i\s*giao\s*$', caseSensitive: false).hasMatch(t.trim());
    }).where((l) => l.top > headerY).toList();

    double bodyBottomY = double.infinity;
    if (footerMarkers.isNotEmpty) {
      bodyBottomY = footerMarkers.map((l) => l.top).reduce(min);
    }

    final body = doc.lines
        .where((l) => l.cy > headerY && l.cy < bodyBottomY)
        .toList();
    if (body.isEmpty) return _extractItemsFallback(doc);

    final rows = _clusterByY(body);
    final items = <ParsedOrderItem>[];
    for (final row in rows) {
      final it = _rowToItem(row, headerCols);
      if (it != null) items.add(it);
    }
    return items;
  }

  static _HeaderCols? _detectHeader(OcrText doc) {
    OcrLine? stt = _firstWhere(doc.lines, (l) =>
        RegExp(r'^\s*STT\b', caseSensitive: false).hasMatch(l.text.trim()));
    OcrLine? name = _firstWhere(doc.lines, (l) =>
        RegExp(r'T[êe]n\s*S[ảa]n\s*Ph[ẩa]m', caseSensitive: false)
            .hasMatch(l.text));
    if (name == null) return null;

    OcrLine? unit = _firstWhere(doc.lines, (l) =>
        RegExp(r'^\s*[ĐD]VT\b', caseSensitive: false).hasMatch(l.text.trim()));
    OcrLine? qty = _firstWhere(doc.lines, (l) =>
        RegExp(r'^\s*SL\b').hasMatch(l.text.trim()));
    OcrLine? price = _firstWhere(doc.lines, (l) =>
        RegExp(r'[ĐD][ơo]n\s*gi[áa]', caseSensitive: false).hasMatch(l.text));
    OcrLine? total = _firstWhere(doc.lines, (l) {
      if (!RegExp(r'Th[àa]nh\s*ti[êe]n', caseSensitive: false)
          .hasMatch(l.text)) return false;
      if (l.text.contains(':') || l.text.contains('：')) return false;
      return (l.cy - name.cy).abs() < name.h * 1.5;
    });

    final headers = [stt, name, unit, qty, price, total].whereType<OcrLine>().toList();
    final headerBottomY = headers.map((h) => h.bottom).reduce(max);
    final headerCy = headers.map((h) => h.cy).reduce((a, b) => a + b) / headers.length;

    bool sameRow(OcrLine? h) =>
        h != null && (h.cy - name.cy).abs() < name.h * 1.5;

    return _HeaderCols(
      sttX: sameRow(stt) ? stt!.cx : null,
      nameX: name.cx,
      unitX: sameRow(unit) ? unit!.cx : null,
      qtyX: sameRow(qty) ? qty!.cx : null,
      priceX: sameRow(price) ? price!.cx : null,
      totalX: sameRow(total) ? total!.cx : null,
      headerY: headerCy,
      headerBottomY: headerBottomY,
    );
  }

  static List<List<OcrLine>> _clusterByY(List<OcrLine> lines) {
    if (lines.isEmpty) return [];
    final sorted = [...lines]..sort((a, b) => a.cy.compareTo(b.cy));
    final avgH = sorted.map((l) => l.h).reduce((a, b) => a + b) / sorted.length;
    final tol = avgH * 0.8;

    final rows = <List<OcrLine>>[];
    var cur = <OcrLine>[sorted.first];
    var curY = sorted.first.cy;
    for (var i = 1; i < sorted.length; i++) {
      final l = sorted[i];
      if ((l.cy - curY).abs() <= tol) {
        cur.add(l);
        curY = cur.map((x) => x.cy).reduce((a, b) => a + b) / cur.length;
      } else {
        rows.add(cur);
        cur = [l];
        curY = l.cy;
      }
    }
    rows.add(cur);
    return rows;
  }

  static ParsedOrderItem? _rowToItem(List<OcrLine> row, _HeaderCols h) {
    row.sort((a, b) => a.left.compareTo(b.left));

    String? name;
    String? unit;
    num? qty;
    num? price;
    num? total;

    final unitRe = RegExp(
        r'^(Kg|kg|KG|g|Gam|gam|Lít|Lit|lit|L|Ml|ml|Cái|cái|Cai|Chai|Hộp|Thùng|Bịch|Gói|Kiện|Cuộn)\.?$',
        unicode: true);
    final qtyRe = RegExp(r'^\d+(?:[.,]\d+)?$');
    final sttRe = RegExp(r'^\d{1,3}$');
    final moneyRe = RegExp(r'^\s*([\d][\d.,\s]*)\s*(?:đ|d|₫)?\s*$', caseSensitive: false);

    for (final line in row) {
      final txt = line.text.trim();
      if (txt.isEmpty) continue;
      final col = _nearestColumn(line.cx, h);

      switch (col) {
        case _Col.stt:
          break;
        case _Col.unit:
          if (unitRe.hasMatch(txt)) unit = txt;
          break;
        case _Col.qty:
          if (qtyRe.hasMatch(txt)) {
            qty = num.tryParse(txt.replaceAll(',', '.'));
          } else if (sttRe.hasMatch(txt) && qty == null) {
            qty = num.tryParse(txt);
          }
          break;
        case _Col.price:
          final m = moneyRe.firstMatch(txt);
          if (m != null) {
            final v = _parseVNAmount(m.group(1)!);
            if (v != null && v > 0) price = v;
          }
          break;
        case _Col.total:
          final m = moneyRe.firstMatch(txt);
          if (m != null) {
            final v = _parseVNAmount(m.group(1)!);
            if (v != null && v > 0) total = v;
          }
          break;
        case _Col.name:
          if (sttRe.hasMatch(txt) && txt.length <= 2) break;
          name = (name == null) ? txt : '$name $txt';
          break;
      }
    }

    if (name == null || name.trim().isEmpty) return null;
    if (!RegExp(r'\p{L}', unicode: true).hasMatch(name)) return null;
    if (_looksLikeLabel(name)) return null;

    // ── VALIDATION: phải là hàng sản phẩm thật ────────────────
    // Một hàng sản phẩm PHẢI có ít nhất một trong:
    //   • ĐVT (Kg, Cái…)
    //   • SL (số lượng)
    //   • Đơn giá + Thành tiền (đủ 2 để tính SL)
    //
    // Hàng ký tên "Trưởng bộ phận | Thủ kho | Người giao | Người nhận |
    // Người lập phiếu" không có gì trong 3 → tự động bị reject.
    final hasValueColumn =
        unit != null || qty != null || (price != null && total != null);
    if (!hasValueColumn) return null;

    // Fallback: SL từ Thành tiền / Đơn giá
    if (qty == null && price != null && total != null && price > 0) {
      final computed = total / price;
      if ((computed - computed.round()).abs() < 0.02) {
        qty = computed.round();
      } else {
        qty = num.parse(computed.toStringAsFixed(3));
      }
    }

    return ParsedOrderItem(name: name.trim(), unit: unit, quantity: qty);
  }

  static _Col _nearestColumn(double x, _HeaderCols h) {
    final cols = <MapEntry<_Col, double>>[
      if (h.sttX != null)   MapEntry(_Col.stt,   h.sttX!),
      MapEntry(_Col.name,  h.nameX),
      if (h.unitX != null)  MapEntry(_Col.unit,  h.unitX!),
      if (h.qtyX != null)   MapEntry(_Col.qty,   h.qtyX!),
      if (h.priceX != null) MapEntry(_Col.price, h.priceX!),
      if (h.totalX != null) MapEntry(_Col.total, h.totalX!),
    ];
    var best = cols.first;
    var bestDist = (x - best.value).abs();
    for (final c in cols.skip(1)) {
      final d = (x - c.value).abs();
      if (d < bestDist) { best = c; bestDist = d; }
    }
    return best.key;
  }

  static num? _parseVNAmount(String s) {
    final cleaned = s.replaceAll(RegExp(r'\s+'), '');
    if (cleaned.isEmpty) return null;
    final lastDot = cleaned.lastIndexOf('.');
    final lastComma = cleaned.lastIndexOf(',');
    String normalized;
    if (lastDot >= 0 && lastComma >= 0) {
      if (lastDot > lastComma) {
        normalized = cleaned.replaceAll(',', '');
      } else {
        normalized = cleaned.replaceAll('.', '').replaceAll(',', '.');
      }
    } else if (lastDot >= 0) {
      if (RegExp(r'^\d{1,3}(?:\.\d{3})+$').hasMatch(cleaned)) {
        normalized = cleaned.replaceAll('.', '');
      } else {
        normalized = cleaned;
      }
    } else if (lastComma >= 0) {
      if (RegExp(r'^\d{1,3}(?:,\d{3})+$').hasMatch(cleaned)) {
        normalized = cleaned.replaceAll(',', '');
      } else {
        normalized = cleaned.replaceAll(',', '.');
      }
    } else {
      normalized = cleaned;
    }
    return num.tryParse(normalized);
  }

  static List<ParsedOrderItem> _extractItemsFallback(OcrText doc) {
    final productRe = RegExp(
      r'(X[úu]c\s*x[íi]ch|B[áa]nh|Ph[ôo]|Th[ịi]t|G[àa]|Heo|B[òo]|Rau|C[àa]|Ru[ợo]u|N[ưu][ớo]c)\b',
      caseSensitive: false, unicode: true,
    );
    final items = <ParsedOrderItem>[];
    for (final line in doc.lines) {
      final t = line.text.trim();
      if (!productRe.hasMatch(t)) continue;
      if (_looksLikeLabel(t)) continue;
      items.add(ParsedOrderItem(name: t, unit: null, quantity: null));
    }
    return items;
  }

  // ── Helpers ──────────────────────────────────────────────

  static T? _firstWhere<T>(Iterable<T> list, bool Function(T) test) {
    for (final e in list) { if (test(e)) return e; }
    return null;
  }

  static String? _afterColon(String s) {
    final idx = s.indexOf(RegExp(r'[:：]'));
    if (idx < 0 || idx == s.length - 1) return null;
    return s.substring(idx + 1).trim();
  }

  static bool _looksLikeLabel(String s) {
    final labels = [
      RegExp(r'T[êe]n\s*kh[áa]ch', caseSensitive: false),
      RegExp(r'[Đđ]i[ệe]n\s*tho[aạ]i', caseSensitive: false),
      RegExp(r'Thanh\s*to[áa]n', caseSensitive: false),
      RegExp(r'[Đđ][ịi]a\s*ch[ỉi]', caseSensitive: false),
      RegExp(r'Ng[àa]y\s*(đ[ặa]t|nh[ậa]n|giao|gi[ờo])', caseSensitive: false),
      RegExp(r'Ng[ưu][ờo]i\s*(nh[ậa]n|đ[ặa]t|giao|l[ậa]p)', caseSensitive: false),
      RegExp(r'^STT$', caseSensitive: false),
      RegExp(r'T[êe]n\s*S[ảa]n\s*Ph[ẩa]m', caseSensitive: false),
      RegExp(r'[ĐD][ơo]n\s*gi[áa]', caseSensitive: false),
      RegExp(r'Th[àa]nh\s*ti[êe]n', caseSensitive: false),
      RegExp(r'Tr[ưu][ởo]ng\s*b[ộo]\s*ph[ậa]n', caseSensitive: false),
      RegExp(r'Th[ủu]\s*kho', caseSensitive: false),
    ];
    return labels.any((r) => r.hasMatch(s));
  }

  static String _clean(String s) => s
      .replaceAll(RegExp(r'^[\s:.\-–—]+'), '')
      .replaceAll(RegExp(r'[\s.]+$'), '')
      .trim();
}

enum _Col { stt, name, unit, qty, price, total }

class _HeaderCols {
  final double? sttX, unitX, qtyX, priceX, totalX;
  final double nameX;
  final double headerY;
  final double headerBottomY;
  const _HeaderCols({
    required this.sttX,
    required this.nameX,
    required this.unitX,
    required this.qtyX,
    required this.priceX,
    required this.totalX,
    required this.headerY,
    required this.headerBottomY,
  });
}