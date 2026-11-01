// lib/data/models/pos/pos_discount_model.dart

enum DiscountType {
  percentBill,
  fixedBill,
  percentItem,
  fixedItem;

  String get apiValue => switch (this) {
    DiscountType.percentBill => 'PERCENT_BILL',
    DiscountType.fixedBill   => 'FIXED_BILL',
    DiscountType.percentItem => 'PERCENT_ITEM',
    DiscountType.fixedItem   => 'FIXED_ITEM',
  };

  bool get isItemType =>
      this == DiscountType.percentItem || this == DiscountType.fixedItem;

  bool get isPercentType =>
      this == DiscountType.percentBill || this == DiscountType.percentItem;

  static DiscountType fromApi(String s) => switch (s) {
    'PERCENT_BILL' => DiscountType.percentBill,
    'FIXED_BILL'   => DiscountType.fixedBill,
    'PERCENT_ITEM' => DiscountType.percentItem,
    'FIXED_ITEM'   => DiscountType.fixedItem,
    _              => DiscountType.percentBill,
  };
}

class PosDiscountOption {
  final int          id;
  final DiscountType discountType;
  final double       discountValue;
  final double?      maxPerUse;
  final String?      label;

  const PosDiscountOption({
    required this.id,
    required this.discountType,
    required this.discountValue,
    this.maxPerUse,
    this.label,
  });

  factory PosDiscountOption.fromJson(Map<String, dynamic> j) =>
      PosDiscountOption(
        id:            j['id'] as int,
        discountType:  DiscountType.fromApi(j['discountType'] as String),
        discountValue: (j['discountValue'] as num).toDouble(),
        maxPerUse:     (j['maxPerUse'] as num?)?.toDouble(),
        label:         j['label'] as String?,
      );

  /// Tính discount thực tế cho 1 lần dùng
  /// [base] = subtotal bill HOẶC giá món tuỳ theo type
  double calculate(double base) {
    double raw = discountType.isPercentType
        ? base * discountValue / 100
        : discountValue;
    raw = raw.clamp(0, base);
    if (maxPerUse != null) raw = raw.clamp(0, maxPerUse!);
    return raw;
  }

  String get displayLabel {
    if (label != null && label!.isNotEmpty) return label!;
    final val = discountType.isPercentType
        ? '${discountValue.toStringAsFixed(0)}%'
        : '${_fmtK(discountValue)}đ';
    final cap = maxPerUse != null ? ' (tối đa ${_fmtK(maxPerUse!)})' : '';
    return switch (discountType) {
      DiscountType.percentBill => 'Giảm $val tổng bill$cap',
      DiscountType.fixedBill   => 'Giảm $val tổng bill$cap',
      DiscountType.percentItem => 'Giảm $val trên 1 món$cap',
      DiscountType.fixedItem   => 'Giảm $val trên 1 món$cap',
    };
  }

  String _fmtK(double v) {
    final k = (v / 1000).truncate();
    return k > 0 ? '${k}k' : v.toStringAsFixed(0);
  }
}

class CustomerDiscountInfo {
  final int    id;
  final int    programId;
  final String programName;
  final String applyFrom;
  final String applyTo;
  final double maxDiscount;
  final double budgetUsed;
  final double budgetRemaining;
  final bool   exhausted;
  final int?   selectedOptionId;
  final List<PosDiscountOption> options;

  const CustomerDiscountInfo({
    required this.id,
    required this.programId,
    required this.programName,
    required this.applyFrom,
    required this.applyTo,
    required this.maxDiscount,
    required this.budgetUsed,
    required this.budgetRemaining,
    required this.exhausted,
    this.selectedOptionId,
    required this.options,
  });

  factory CustomerDiscountInfo.fromJson(Map<String, dynamic> j) =>
      CustomerDiscountInfo(
        id:               j['id'] as int,
        programId:        j['programId'] as int,
        programName:      j['programName'] as String,
        applyFrom:        j['applyFrom'] as String? ?? '',
        applyTo:          j['applyTo'] as String? ?? '',
        maxDiscount:      (j['maxDiscount'] as num).toDouble(),
        budgetUsed:       (j['budgetUsed'] as num).toDouble(),
        budgetRemaining:  (j['budgetRemaining'] as num).toDouble(),
        exhausted:        j['exhausted'] as bool? ?? false,
        selectedOptionId: j['selectedOptionId'] as int?,
        options: (j['options'] as List? ?? [])
            .map((e) => PosDiscountOption.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  PosDiscountOption? get selectedOption => selectedOptionId == null
      ? null
      : options.where((o) => o.id == selectedOptionId).firstOrNull;
}