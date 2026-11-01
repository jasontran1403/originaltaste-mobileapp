// pos_customer_order_models.dart
class CustomerOrderSummary {
  final int    id;
  final String orderCode;
  final String orderSource;
  final int    createdAt;
  final int    itemCount;
  final double totalAmount;
  final double discountAmount;
  final double finalAmount;
  final double platformFeeAmount;
  final String paymentMethod;
  final String status;

  const CustomerOrderSummary({
    required this.id,
    required this.orderCode,
    required this.orderSource,
    required this.createdAt,
    required this.itemCount,
    required this.totalAmount,
    required this.discountAmount,
    required this.finalAmount,
    required this.platformFeeAmount,
    required this.paymentMethod,
    required this.status,
  });

  factory CustomerOrderSummary.fromJson(Map<String, dynamic> j) =>
      CustomerOrderSummary(
        id:                 (j['id'] as num).toInt(),
        orderCode:          j['orderCode'] as String,
        orderSource:        j['orderSource'] as String,
        createdAt:          (j['createdAt'] as num).toInt(),
        itemCount:          (j['itemCount'] as num).toInt(),
        totalAmount:        (j['totalAmount'] as num).toDouble(),
        discountAmount:     (j['discountAmount'] as num? ?? 0).toDouble(),
        finalAmount:        (j['finalAmount'] as num).toDouble(),
        platformFeeAmount:  (j['platformFeeAmount'] as num? ?? 0).toDouble(),
        paymentMethod:      j['paymentMethod'] as String? ?? 'CASH',
        status:             j['status'] as String,
      );

  double get displayAmount => finalAmount + platformFeeAmount;
}

// ── Addon Model ─────────────────────────────────────
class OrderItemAddon {
  final String ingredientName;
  final int selectedCount;
  /// Giá khách trả cho 1 lần chọn addon (gross).
  final double addonPriceSnapshot;

  /// Giá quán thực nhận sau khi trừ giảm giá app + phí sàn.
  /// Đơn offline = addonPriceSnapshot.
  final double addonPriceNet;

  const OrderItemAddon({
    required this.ingredientName,
    required this.selectedCount,
    required this.addonPriceSnapshot,
    required this.addonPriceNet,
  });

  factory OrderItemAddon.fromJson(Map<String, dynamic> j) {
    final gross = (j['addonPriceSnapshot'] as num).toDouble();
    return OrderItemAddon(
      ingredientName: j['ingredientName'] as String,
      selectedCount: (j['selectedCount'] as num).toInt(),
      addonPriceSnapshot: gross,
      addonPriceNet: (j['addonPriceNet'] as num?)?.toDouble() ?? gross,
    );
  }
}

// ── CustomerOrderItem ─────────────────────────────────
class CustomerOrderItem {
  final int    productId;
  final String productName;
  final String? categoryName;
  final int    quantity;
  final double basePrice;
  final double finalUnitPrice;
  final double subtotal;
  final int    discountPercent;
  final int    vatPercent;
  final double vatAmount;
  final String? note;

  final List<OrderItemAddon> addons;   // ← THÊM

  const CustomerOrderItem({
    required this.productId,
    required this.productName,
    this.categoryName,
    required this.quantity,
    required this.basePrice,
    required this.finalUnitPrice,
    required this.subtotal,
    required this.discountPercent,
    required this.vatPercent,
    required this.vatAmount,
    this.note,
    this.addons = const [],
  });

  factory CustomerOrderItem.fromJson(Map<String, dynamic> j) =>
      CustomerOrderItem(
        productId:       (j['productId'] as num).toInt(),
        productName:     j['productName'] as String,
        categoryName:    j['categoryName'] as String?,
        quantity:        (j['quantity'] as num).toInt(),
        basePrice:       (j['basePrice'] as num).toDouble(),
        finalUnitPrice:  (j['finalUnitPrice'] as num).toDouble(),
        subtotal:        (j['subtotal'] as num).toDouble(),
        discountPercent: (j['discountPercent'] as num).toInt(),
        vatPercent:      (j['vatPercent'] as num? ?? 0).toInt(),
        vatAmount:       (j['vatAmount'] as num? ?? 0).toDouble(),
        note:            j['note'] as String?,
        addons:          (j['addons'] as List? ?? [])
            .map((e) => OrderItemAddon.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class CustomerOrderDetail {
  final int id;
  final String orderCode;
  final String? appOrderCode;
  final String orderSource;
  final int createdAt;
  final String paymentMethod;
  final String status;
  final String? note;

  final List<CustomerOrderItem> items;

  final double totalAmount;           // tạm tính
  final double discountAmount;
  final String? discountNote;
  final String? eVoucherCode;
  final double? eVoucherDiscountAmount;
  final double totalVatAmount;
  final double platformFeeAmount;
  final double finalAmount;           // tiền khách trả cuối cùng
  final bool isAppOrder;              // ← Rất quan trọng

  const CustomerOrderDetail({
    required this.id,
    required this.orderCode,
    this.appOrderCode,
    required this.orderSource,
    required this.createdAt,
    required this.paymentMethod,
    required this.status,
    this.note,
    required this.items,
    required this.totalAmount,
    required this.discountAmount,
    this.discountNote,
    this.eVoucherCode,
    this.eVoucherDiscountAmount,
    required this.totalVatAmount,
    required this.platformFeeAmount,
    required this.finalAmount,
    required this.isAppOrder,
  });

  factory CustomerOrderDetail.fromJson(Map<String, dynamic> j) {
    return CustomerOrderDetail(
      id: (j['id'] as num).toInt(),
      orderCode: j['orderCode'] as String,
      appOrderCode: j['appOrderCode'] as String?,
      orderSource: j['orderSource'] as String,
      createdAt: (j['createdAt'] as num).toInt(),
      paymentMethod: j['paymentMethod'] as String? ?? 'CASH',
      status: j['status'] as String,
      note: j['note'] as String?,
      items: (j['items'] as List? ?? [])
          .map((e) => CustomerOrderItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      totalAmount: (j['totalAmount'] as num).toDouble(),
      discountAmount: (j['discountAmount'] as num? ?? 0).toDouble(),
      discountNote: j['discountNote'] as String?,
      eVoucherCode: j['eVoucherCode'] as String?,
      eVoucherDiscountAmount: (j['eVoucherDiscountAmount'] as num?)?.toDouble(),
      totalVatAmount: (j['totalVatAmount'] as num? ?? 0).toDouble(),
      platformFeeAmount: (j['platformFeeAmount'] as num? ?? 0).toDouble(),
      finalAmount: (j['finalAmount'] as num).toDouble(),
      isAppOrder: j['isAppOrder'] as bool? ?? false,
    );
  }
}