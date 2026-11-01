// lib/data/models/pos/pos_cart_model.dart

import 'package:originaltaste/data/models/pos/pos_product_model.dart';

class AddonItem {
  final int    ingredientId;
  final String ingredientName;
  final double baseAddonPrice;
  final double discountedAddonPrice;
  final int    quantity;

  const AddonItem({
    required this.ingredientId,
    required this.ingredientName,
    required this.baseAddonPrice,
    required this.discountedAddonPrice,
    required this.quantity,
  });

  AddonItem copyWith({int? quantity}) => AddonItem(
    ingredientId: ingredientId,
    ingredientName: ingredientName,
    baseAddonPrice: baseAddonPrice,
    discountedAddonPrice: discountedAddonPrice,
    quantity: quantity ?? this.quantity,
  );
}

class VariantGroupSelection {
  final int variantId;
  final String groupName;
  final bool isAddonGroup;

  final Map<int, int> selectedIngredients;
  final List<AddonItem>? addonItems;
  final Map<int, List<double>> unitWeightsMap;

  const VariantGroupSelection({
    required this.variantId,
    required this.groupName,
    required this.isAddonGroup,
    required this.selectedIngredients,
    this.addonItems,
    this.unitWeightsMap = const {},
  });

  VariantGroupSelection copyWith({
    Map<int, List<double>>? unitWeightsMap,
  }) =>
      VariantGroupSelection(
        variantId: variantId,
        groupName: groupName,
        isAddonGroup: isAddonGroup,
        selectedIngredients: selectedIngredients,
        addonItems: addonItems,
        unitWeightsMap: unitWeightsMap ?? this.unitWeightsMap,
      );

  double totalWeightFor(int ingredientId, double defaultDeductPerUnit) {
    final weights = unitWeightsMap[ingredientId];
    if (weights != null && weights.isNotEmpty) {
      return weights.fold(0.0, (s, w) => s + w);
    }
    final count = selectedIngredients[ingredientId] ?? 0;
    return count * defaultDeductPerUnit;
  }
}

// ==================== CARTITEM ====================

/// Bộ đếm tạo id duy nhất cho từng DÒNG trong giỏ.
/// Cần thiết để 2 lần bán xé lẻ cùng 1 món vẫn là 2 dòng độc lập
/// (và để Dismissible/ValueKey không bị trùng).
int _cartLineSeq = 0;

String _newCartLineId() =>
    '${DateTime.now().microsecondsSinceEpoch}_${_cartLineSeq++}';

class CartItem {
  /// ID duy nhất cho dòng giỏ hàng. KHÔNG đổi khi copyWith.
  final String lineId;

  final PosProductModel product;
  final PriceOption selectedPrice;
  final List<VariantGroupSelection> variantSelections;
  final int quantity;
  final String? note;

  /// GIÁ GHI ĐÈ CHO ĐƠN APP (quan trọng nhất)
  final double? overriddenUnitPrice;

  /// Ý 2: bán xé lẻ — dòng này là hàng xé lẻ, giá nhập tay.
  final bool looseSale;

  /// Số lượng xé lẻ theo đơn vị nhỏ nhất (2 miếng / 0.25 kg...).
  final double? looseQuantity;

  /// Đơn vị nhỏ nhất khi xé lẻ ("Miếng" / "Kg"...).
  final String? looseUnit;

  /// Đơn vị chính của nguyên liệu ("Túi" / "Kg"...) — dùng để hiển thị/bill.
  final String? looseMainUnit;

  /// Nguyên liệu được xé lẻ (để cart hiển thị đúng dòng nguyên liệu).
  final int? looseIngredientId;

  CartItem({
    String? lineId,
    required this.product,
    required this.selectedPrice,
    required this.variantSelections,
    required this.quantity,
    this.note,
    this.overriddenUnitPrice,
    this.looseSale = false,
    this.looseQuantity,
    this.looseUnit,
    this.looseMainUnit,
    this.looseIngredientId,
  }) : lineId = lineId ?? _newCartLineId();

  /// Giá thực tế sẽ gửi lên server
  double get finalUnitPrice {
    if (overriddenUnitPrice != null && overriddenUnitPrice! > 0) {
      return overriddenUnitPrice!;
    }
    return selectedPrice.price;
  }

  double get addonPerUnit {
    double total = 0;
    for (final sel in variantSelections) {
      if (!sel.isAddonGroup || sel.addonItems == null) continue;
      for (final a in sel.addonItems!) {
        total += a.discountedAddonPrice * a.quantity;
      }
    }
    return total;
  }

  double get subtotal => (finalUnitPrice + addonPerUnit) * quantity;

  // ── Ý 2: helper cho hàng xé lẻ ────────────────────────────────

  /// Hàng xé lẻ KHÔNG cho sửa số lượng trong đơn (chỉ được xoá).
  bool get canEditQuantity => !looseSale;

  /// Hàng xé lẻ KHÔNG mở sheet định lượng (số lượng đã chốt lúc nhập).
  bool get canEditWeight => !looseSale;

  /// Format số gọn: 2.0 → "2", 0.250 → "0.25"
  static String fmtLooseAmount(double v) {
    if (v == v.roundToDouble()) return v.toInt().toString();
    return v
        .toStringAsFixed(3)
        .replaceAll(RegExp(r'0+$'), '')
        .replaceAll(RegExp(r'\.$'), '');
  }

  /// Nhãn hiển thị trong giỏ: "2 Miếng", "0.25 Kg". null nếu không phải xé lẻ.
  String? get looseLabel {
    if (!looseSale || looseQuantity == null || looseQuantity! <= 0) return null;
    final unit = (looseUnit ?? '').trim();
    final amount = fmtLooseAmount(looseQuantity!);
    return unit.isEmpty ? amount : '$amount $unit';
  }

  CartItem copyWith({
    PriceOption? selectedPrice,
    int? quantity,
    String? note,
    List<VariantGroupSelection>? variantSelections,
    double? overriddenUnitPrice,
    bool? looseSale,
    double? looseQuantity,
    String? looseUnit,
    String? looseMainUnit,
    int? looseIngredientId,
  }) =>
      CartItem(
        lineId: lineId, // ← giữ nguyên identity của dòng
        product: product,
        selectedPrice: selectedPrice ?? this.selectedPrice,
        variantSelections: variantSelections ?? this.variantSelections,
        quantity: quantity ?? this.quantity,
        note: note ?? this.note,
        overriddenUnitPrice: overriddenUnitPrice ?? this.overriddenUnitPrice,
        looseSale: looseSale ?? this.looseSale,
        looseQuantity: looseQuantity ?? this.looseQuantity,
        looseUnit: looseUnit ?? this.looseUnit,
        looseMainUnit: looseMainUnit ?? this.looseMainUnit,
        looseIngredientId: looseIngredientId ?? this.looseIngredientId,
      );
}