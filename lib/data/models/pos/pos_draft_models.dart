// lib/data/models/pos/pos_draft_models.dart
//
// THAY ĐỔI:
//  - Thêm ingredientDeductMap vào VariantGroupDraft
//  - Giá addon RIÊNG của từng nguyên liệu trong món này, TÁCH THEO KÊNH BÁN:
//    ingredientAddonPriceMap        → giá tại quán
//    ingredientAddonPriceShopeeMap  → giá ShopeeFood
//    ingredientAddonPriceGrabMap    → giá GrabFood
//    Không có key = chưa set, server sẽ fallback về giá tại quán rồi giá NL.

import 'package:originaltaste/data/models/pos/pos_product_model.dart';

// ── VariantGroupDraft ─────────────────────────────────────────────────────────

class VariantGroupDraft {
  final String           name;
  final num              minSelect;
  final num              maxSelect;
  final bool             allowRepeat;
  final List<int>        ingredientIds;
  final Map<int, num>?   ingredientQuantities;

  /// Định lượng mặc định (stockDeductPerUnit) cho từng ingredient.
  /// Key = ingredientId, Value = deductPerUnit (VD: 0.2 cho 200g/miếng).
  /// null = tất cả dùng 1.0.
  final Map<int, double>? ingredientDeductMap;

  /// Giá addon TẠI QUÁN cho từng ingredient TRONG món này.
  /// Key = ingredientId, Value = giá bán (cho phép 0 = tặng kèm).
  /// Chỉ có ý nghĩa với nhóm addon.
  final Map<int, double>? ingredientAddonPriceMap;

  /// Giá addon bán trên ShopeeFood.
  final Map<int, double>? ingredientAddonPriceShopeeMap;

  /// Giá addon bán trên GrabFood.
  final Map<int, double>? ingredientAddonPriceGrabMap;

  final int? existingId;

  const VariantGroupDraft({
    required this.name,
    required this.minSelect,
    required this.maxSelect,
    required this.allowRepeat,
    required this.ingredientIds,
    this.ingredientQuantities,
    this.ingredientDeductMap,
    this.ingredientAddonPriceMap,
    this.ingredientAddonPriceShopeeMap,
    this.ingredientAddonPriceGrabMap,
    this.existingId,
  });

  /// Build body gửi lên server khi tạo / update variant
  Map<String, dynamic> toBody({required int productId}) {
    return {
      'productId':    productId,
      'groupName':    name,
      'minSelect':    minSelect,
      'maxSelect':    maxSelect,
      'allowRepeat':  allowRepeat,
      'isAddonGroup': false,
      'ingredients':  ingredientIds.map((id) {
        final qty         = ingredientQuantities?[id] ?? 1;
        final deductPerUnit = ingredientDeductMap?[id] ?? 1.0;
        return {
          'ingredientId':       id,
          'maxSelectableCount': qty,
          'stockDeductPerUnit': deductPerUnit,
        };
      }).toList(),
    };
  }

  /// Tạo từ PosVariantModel (khi edit)
  static VariantGroupDraft fromModel(PosVariantModel v) {
    return VariantGroupDraft(
      name:         v.groupName,
      minSelect:    v.minSelect,
      maxSelect:    v.maxSelect,
      allowRepeat:  v.allowRepeat,
      ingredientIds: v.ingredients.map((vi) => vi.ingredientId).toList(),
      ingredientQuantities: {
        for (final vi in v.ingredients)
          vi.ingredientId: vi.maxSelectableCount ?? 1,
      },
      ingredientDeductMap: {
        for (final vi in v.ingredients)
          vi.ingredientId: vi.stockDeductPerUnit,
      },
      ingredientAddonPriceMap: {
        for (final vi in v.ingredients)
          if (vi.addonPriceOverride != null)
            vi.ingredientId: vi.addonPriceOverride!,
      },
      ingredientAddonPriceShopeeMap: {
        for (final vi in v.ingredients)
          if (vi.addonPriceShopee != null)
            vi.ingredientId: vi.addonPriceShopee!,
      },
      ingredientAddonPriceGrabMap: {
        for (final vi in v.ingredients)
          if (vi.addonPriceGrab != null)
            vi.ingredientId: vi.addonPriceGrab!,
      },
      existingId: v.id,
    );
  }
}

// ── AddonGroupDraft ───────────────────────────────────────────────────────────

class AddonGroupDraft {
  final String    name;
  final List<int> ingredientIds;

  /// Định lượng mặc định cho addon ingredients (stockDeductPerUnit)
  /// Key = ingredientId, Value = deductPerUnit
  /// null = tất cả dùng 1.0
  final Map<int, double>? ingredientDeductMap;

  /// Giá addon TẠI QUÁN của món này cho từng nguyên liệu.
  final Map<int, double>? ingredientAddonPriceMap;

  /// Giá addon trên ShopeeFood.
  final Map<int, double>? ingredientAddonPriceShopeeMap;

  /// Giá addon trên GrabFood.
  final Map<int, double>? ingredientAddonPriceGrabMap;

  final int?      existingId;

  const AddonGroupDraft({
    required this.name,
    required this.ingredientIds,
    this.ingredientDeductMap,
    this.ingredientAddonPriceMap,
    this.ingredientAddonPriceShopeeMap,
    this.ingredientAddonPriceGrabMap,
    this.existingId,
  });

  Map<String, dynamic> toBody({required int productId}) {
    return {
      'productId':    productId,
      'groupName':    name,
      'minSelect':    0,
      'maxSelect':    999,
      'allowRepeat':  false,
      'isAddonGroup': true,
      'ingredients':  ingredientIds.map((id) {
        final deductPerUnit = ingredientDeductMap?[id] ?? 1.0;
        return {
          'ingredientId':       id,
          'maxSelectableCount': 1,
          'stockDeductPerUnit': deductPerUnit,
          // null → server hiểu là "chưa set", sẽ fallback khi bán
          'addonPrice':         ingredientAddonPriceMap?[id],
          'addonPriceShopee':   ingredientAddonPriceShopeeMap?[id],
          'addonPriceGrab':     ingredientAddonPriceGrabMap?[id],
        };
      }).toList(),
    };
  }

  static AddonGroupDraft fromVariant(VariantGroupDraft v) => AddonGroupDraft(
    name:         v.name,
    ingredientIds: v.ingredientIds,
    ingredientDeductMap: v.ingredientDeductMap,
    ingredientAddonPriceMap: v.ingredientAddonPriceMap,
    ingredientAddonPriceShopeeMap: v.ingredientAddonPriceShopeeMap,
    ingredientAddonPriceGrabMap: v.ingredientAddonPriceGrabMap,
    existingId:   v.existingId,
  );

  /// Chuyển ngược về VariantGroupDraft để mở lại sheet cấu hình khi sửa.
  VariantGroupDraft toVariantDraft() => VariantGroupDraft(
    name:         name,
    minSelect:    0,
    maxSelect:    ingredientIds.length,
    allowRepeat:  false,
    ingredientIds: ingredientIds,
    ingredientDeductMap: ingredientDeductMap,
    ingredientAddonPriceMap: ingredientAddonPriceMap,
    ingredientAddonPriceShopeeMap: ingredientAddonPriceShopeeMap,
    ingredientAddonPriceGrabMap: ingredientAddonPriceGrabMap,
    existingId:   existingId,
  );

  static AddonGroupDraft fromModel(PosVariantModel v) => AddonGroupDraft(
    name:         v.groupName,
    ingredientIds: v.ingredients.map((vi) => vi.ingredientId).toList(),
    ingredientDeductMap: {
      for (final vi in v.ingredients)
        vi.ingredientId: vi.stockDeductPerUnit,
    },
    ingredientAddonPriceMap: {
      for (final vi in v.ingredients)
        if (vi.addonPriceOverride != null)
          vi.ingredientId: vi.addonPriceOverride!,
    },
    ingredientAddonPriceShopeeMap: {
      for (final vi in v.ingredients)
        if (vi.addonPriceShopee != null)
          vi.ingredientId: vi.addonPriceShopee!,
    },
    ingredientAddonPriceGrabMap: {
      for (final vi in v.ingredients)
        if (vi.addonPriceGrab != null)
          vi.ingredientId: vi.addonPriceGrab!,
    },
    existingId:   v.id,
  );
}
