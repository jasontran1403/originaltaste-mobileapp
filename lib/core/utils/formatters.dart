// lib/core/utils/formatters.dart

import 'package:intl/intl.dart';

/// Format số tiền VN: 1000000 → "1.000.000"
/// Dấu . ngăn hàng nghìn, không có phần thập phân
final _moneyFormatter = NumberFormat('#,###', 'vi_VN');

/// Format số lượng VN: 1000.5 → "1.000,5"
/// Dấu . ngăn hàng nghìn, dấu , thập phân
final _quantityFormatter = NumberFormat('#,##0.###', 'vi_VN');

class AppFormatter {
  AppFormatter._();

  // ── Tiền (VND) ────────────────────────────────────────────────
  /// double/int → "1.000.000"
  static String money(num value) {
    if (value == 0) return '0';
    return _moneyFormatter.format(value);
  }

  /// String raw từ input → format tiền real-time
  /// Input: "1000000" → "1.000.000"
  static String moneyInput(String raw) {
    final digits = raw.replaceAll(RegExp(r'[^\d]'), '');
    if (digits.isEmpty) return '';
    final number = int.tryParse(digits) ?? 0;
    return _moneyFormatter.format(number);
  }

  /// Parse string đã format → double
  /// "1.000.000" → 1000000.0
  static double parseMoney(String formatted) {
    final digits = formatted.replaceAll(RegExp(r'[^\d]'), '');
    return double.tryParse(digits) ?? 0.0;
  }

  // ── Số lượng (có thập phân) ───────────────────────────────────
  /// double → "1.000,5"
  static String quantity(num value) {
    if (value == 0) return '0';
    return _quantityFormatter.format(value);
  }

  /// String raw từ input → format số lượng real-time
  /// Cho phép nhập số thập phân với dấu , hoặc .
  /// Input: "1000,5" → "1.000,5"
  static String quantityInput(String raw) {
    // Normalize: thay . (nếu dùng làm dấu thập phân) → ,
    // Nhưng giữ . nếu là dấu phân cách hàng nghìn → bỏ đi
    // Logic: chỉ giữ digits và 1 dấu ,
    final normalized = raw.replaceAll('.', '').replaceAll(',', '.');
    final parts = normalized.split('.');

    final intPart = parts[0].replaceAll(RegExp(r'[^\d]'), '');
    final decPart = parts.length > 1 ? parts[1].replaceAll(RegExp(r'[^\d]'), '') : null;

    if (intPart.isEmpty) return '';

    final intNum = int.tryParse(intPart) ?? 0;
    final formattedInt = _moneyFormatter.format(intNum);

    if (decPart != null) {
      // Đang gõ phần thập phân
      return raw.endsWith(',') || raw.endsWith('.')
          ? '$formattedInt,'
          : '$formattedInt,${decPart.length > 3 ? decPart.substring(0, 3) : decPart}';
    }
    return formattedInt;
  }

  /// Parse "1.000,5" → 1000.5
  static double parseQuantity(String formatted) {
    final s = formatted.replaceAll('.', '').replaceAll(',', '.');
    return double.tryParse(s) ?? 0.0;
  }

  // ── Tiện ích ──────────────────────────────────────────────────
  static String moneyWithUnit(num value) => '${money(value)}đ';
}
