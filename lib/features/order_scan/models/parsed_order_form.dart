// lib/features/order_scan/models/parsed_order_form.dart
//
// Kết quả trích xuất từ PHIẾU ĐẶT HÀNG (ảnh chụp hoặc PDF).
// Đây là data model TẠM cho giai đoạn debug/verify — sau khi user OK
// thì mới map sang model chuẩn (IngredientModel + BatchRow...).

class ParsedOrderForm {
  /// Toàn bộ text OCR/PDF gộp lại — dùng cho debug/log.
  final String rawText;

  /// Tên khách hàng đọc được. `null` nếu không tìm thấy dòng "Tên khách hàng".
  final String? customerName;

  /// Số phiếu đã format lại: "NĐ-05919". `null` nếu không tìm thấy.
  /// Regex chấp nhận cả prefix khác ("PĐH", "SO"...) — miễn là dạng "PREFIX: NUMBER".
  final String? orderNumber;

  /// Danh sách sản phẩm đọc từ bảng.
  final List<ParsedOrderItem> items;

  const ParsedOrderForm({
    required this.rawText,
    required this.customerName,
    required this.orderNumber,
    required this.items,
  });

  /// Có phải khách hàng "Original Taste" không (so sánh không phân biệt hoa/thường/khoảng trắng).
  bool get isOriginalTaste {
    if (customerName == null) return false;
    final normalized = customerName!
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'\s+'), ' ');
    return normalized == 'original taste';
  }
}

class ParsedOrderItem {
  /// Tên sản phẩm — ví dụ: "Xúc xích Frankfurter"
  final String name;

  /// Đơn vị tính — ví dụ: "Kg"
  final String? unit;

  /// Số lượng — dùng num vì có thể là 3, 1.5, 0.5...
  final num? quantity;

  const ParsedOrderItem({
    required this.name,
    required this.unit,
    required this.quantity,
  });

  @override
  String toString() =>
      '  • $name  |  SL: ${quantity ?? "?"}  |  ĐVT: ${unit ?? "?"}';
}