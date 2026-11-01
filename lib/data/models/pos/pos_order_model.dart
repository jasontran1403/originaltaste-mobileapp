// lib/data/models/pos/pos_order_model.dart

import 'package:flutter/cupertino.dart';

class PosOrderItemModel {
  final int id;
  final int productId;
  final String productName;
  final String? productImageUrl;
  final double basePrice;
  final double defaultPrice;
  final int discountPercent;
  final double finalUnitPrice;
  final int quantity;
  final double subtotal;
  final int vatPercent;
  final double vatAmount;
  final double addonAmount;
  final String? note;
  final List<Map<String, dynamic>> selectedIngredients;

  /// Ý 2 — bán xé lẻ
  final bool looseSale;
  final double? looseQuantity;   // số lượng theo đơn vị nhỏ nhất
  final String? looseUnit;       // "Miếng" / "Kg"
  final String? looseMainUnit;   // "Túi" / "Kg"

  const PosOrderItemModel({
    required this.id,
    required this.productId,
    required this.productName,
    this.productImageUrl,
    required this.basePrice,
    required this.defaultPrice,
    required this.discountPercent,
    required this.finalUnitPrice,
    required this.quantity,
    required this.subtotal,
    this.vatPercent = 0,
    this.vatAmount = 0,
    this.addonAmount = 0,
    this.note,
    required this.selectedIngredients,
    this.looseSale = false,
    this.looseQuantity,
    this.looseUnit,
    this.looseMainUnit,
  });

  /// Format số gọn: 2.0 → "2", 0.250 → "0.25"
  static String fmtLooseAmount(double v) {
    if (v == v.roundToDouble()) return v.toInt().toString();
    return v
        .toStringAsFixed(3)
        .replaceAll(RegExp(r'0+$'), '')
        .replaceAll(RegExp(r'\.$'), '');
  }

  /// Nhãn hiển thị: "2 Miếng". null nếu không phải xé lẻ.
  String? get looseLabel {
    if (!looseSale || looseQuantity == null || looseQuantity! <= 0) return null;
    final u = (looseUnit ?? '').trim();
    final a = fmtLooseAmount(looseQuantity!);
    return u.isEmpty ? a : '$a $u';
  }

  factory PosOrderItemModel.fromJson(Map<String, dynamic> j) =>
      PosOrderItemModel(
        id: j['id'] as int,
        productId: j['productId'] as int,
        productName: j['productName'] as String,
        productImageUrl: j['productImageUrl'] as String?,
        basePrice: (j['basePrice'] as num).toDouble(),
        defaultPrice: (j['defaultPrice'] as num?)?.toDouble() ??
            (j['basePrice'] as num).toDouble(),
        discountPercent: j['discountPercent'] as int? ?? 0,
        finalUnitPrice: (j['finalUnitPrice'] as num).toDouble(),
        quantity: j['quantity'] as int,
        subtotal: (j['subtotal'] as num).toDouble(),
        vatPercent: j['vatPercent'] as int? ?? 0,
        vatAmount: (j['vatAmount'] as num?)?.toDouble() ?? 0.0,
        addonAmount: (j['addonAmount'] as num?)?.toDouble() ?? 0.0,
        note: j['note'] as String?,
        selectedIngredients: (j['variantSelections'] as List<dynamic>? ?? [])
            .cast<Map<String, dynamic>>(),
        looseSale: j['looseSale'] as bool? ?? false,
        looseQuantity: (j['looseQuantity'] as num?)?.toDouble(),
        looseUnit: j['looseUnit'] as String?,
        looseMainUnit: j['looseMainUnit'] as String?,
      );
}

class PosOrderModel {
  final int id;
  final String orderCode;
  final int shiftId;
  final String staffName;
  final String orderSource;
  final String status;
  final String paymentMethod;
  final double totalAmount;
  final double discountAmount;
  final double finalAmount;
  final String? note;
  final int createdAt;
  final int updatedAt;
  final double vatAmount;
  final double totalVat;
  final List<PosOrderItemModel> items;
  final String? customerPhone;
  final String? customerName;
  final String? eVoucherCode;
  final double eVoucherDiscountAmount;
  final String? appOrderCode;
  final double platformRate;
  final double platformFeeAmount;

  /// Token UUID ngẫu nhiên — dùng để tạo QR link xuất hóa đơn khi in bill.
  /// Server trả về trong field "invoiceToken".
  final String? invoiceToken;

  const PosOrderModel({
    required this.id,
    required this.orderCode,
    required this.shiftId,
    required this.staffName,
    required this.orderSource,
    required this.status,
    required this.paymentMethod,
    required this.totalAmount,
    required this.discountAmount,
    required this.finalAmount,
    required this.vatAmount,
    required this.totalVat,
    this.note,
    required this.createdAt,
    required this.updatedAt,
    required this.items,
    this.customerPhone,
    this.customerName,
    this.platformRate = 0.0,
    this.platformFeeAmount = 0.0,
    this.eVoucherCode,
    this.eVoucherDiscountAmount = 0.0,
    this.appOrderCode,
    this.invoiceToken,          // ← THÊM
  });

  bool get isAppOrder =>
      orderSource == 'SHOPEE_FOOD' || orderSource == 'GRAB_FOOD';

  double get grossAfterDiscount => totalAmount - discountAmount;

  factory PosOrderModel.fromJson(Map<String, dynamic> j) {
    return PosOrderModel(
      id: j['id'] as int,
      orderCode: j['orderCode'] as String,
      shiftId: j['shiftId'] as int,
      staffName: j['staffName'] as String? ?? '',
      orderSource: j['orderSource'] as String? ?? 'TAKE_AWAY',
      status: j['status'] as String? ?? '',
      paymentMethod: j['paymentMethod'] as String? ?? 'CASH',
      totalAmount: (j['totalAmount'] as num?)?.toDouble() ?? 0.0,
      discountAmount: (j['discountAmount'] as num?)?.toDouble() ?? 0.0,
      finalAmount: (j['finalAmount'] as num?)?.toDouble() ?? 0.0,
      vatAmount: (j['vatAmount'] as num?)?.toDouble() ?? 0.0,
      totalVat: (j['totalVat'] as num?)?.toDouble() ?? 0.0,
      note: j['note'] as String?,
      createdAt: j['createdAt'] as int? ?? 0,
      updatedAt: j['updatedAt'] as int? ?? 0,
      items: (j['items'] as List<dynamic>? ?? [])
          .map((e) => PosOrderItemModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      customerPhone: j['customerPhone'] as String?,
      customerName: j['customerName'] as String?,
      platformRate: (j['platformRate'] as num?)?.toDouble() ?? 0.0,
      platformFeeAmount: (j['platformFeeAmount'] as num?)?.toDouble() ??
          (j['platformFee'] as num?)?.toDouble() ??
          0.0,
      eVoucherCode: j['evoucherCode'] as String?,
      eVoucherDiscountAmount:
      (j['evoucherDiscountAmount'] as num?)?.toDouble() ?? 0.0,
      appOrderCode: j['appOrderCode'] as String?,
      invoiceToken: j['invoiceToken'] as String?,   // ← THÊM
    );
  }
}