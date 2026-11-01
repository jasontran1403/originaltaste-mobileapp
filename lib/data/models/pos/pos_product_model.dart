// lib/data/models/pos/pos_product_model.dart

class AppMenuModel {
  final int     id;
  final String  platform;  // 'SHOPEE_FOOD' | 'GRAB_FOOD'
  final double  price;
  final bool    isActive;

  const AppMenuModel({
    required this.id,
    required this.platform,
    required this.price,
    required this.isActive,
  });

  factory AppMenuModel.fromJson(Map<String, dynamic> j) => AppMenuModel(
    id:       j['id'] as int,
    platform: j['platform'] as String,
    price:    (j['price'] as num).toDouble(),
    isActive: j['isActive'] as bool? ?? true,
  );
}


class PosCategoryModel {
  final int     id;
  final String  name;
  final String? imageUrl;
  final int     displayOrder;
  final bool    isActive;
  final bool    singlePrice;
  final int     productCount;

  const PosCategoryModel({
    required this.id,
    required this.name,
    this.imageUrl,
    required this.displayOrder,
    required this.isActive,
    required this.singlePrice,
    required this.productCount,
  });

  factory PosCategoryModel.fromJson(Map<String, dynamic> j) => PosCategoryModel(
    id:           j['id'] as int,
    name:         j['name'] as String,
    imageUrl:     j['imageUrl'] as String?,
    displayOrder: j['displayOrder'] as int? ?? 0,
    isActive:     j['isActive'] as bool? ?? true,
    singlePrice:  j['singlePrice'] as bool? ?? false,
    productCount: j['productCount'] as int? ?? 0,
  );
}

class PriceOption {
  final int    discountPercent;
  final double price;
  final String label;

  const PriceOption({
    required this.discountPercent,
    required this.price,
    required this.label,
  });

  factory PriceOption.fromJson(Map<String, dynamic> j) => PriceOption(
    discountPercent: j['discountPercent'] as int,
    price:           (j['price'] as num).toDouble(),
    label:           j['label'] as String,
  );
}

class PosVariantIngredientModel {
  final int     id;
  final int     ingredientId;
  final String  ingredientName;
  final String? ingredientImageUrl;
  final double  stockDeductPerUnit;
  final int?    maxSelectableCount;
  final String? subGroupTag;
  final int?    subGroupMaxSelect;
  final int     displayOrder;

  /// Giá addon áp dụng khi bán TẠI QUÁN (= override nếu có, ngược lại giá
  /// mặc định của nguyên liệu). Đơn app dùng priceFor() thay vì trường này.
  final double  addonPrice;

  /// Giá bán TẠI QUÁN do món này set riêng. null = đang dùng giá mặc định.
  final double? addonPriceOverride;

  /// Giá bán trên ShopeeFood. null = chưa set → dùng giá tại quán.
  final double? addonPriceShopee;

  /// Giá bán trên GrabFood. null = chưa set → dùng giá tại quán.
  final double? addonPriceGrab;

  /// Giá addon mặc định khai báo ở nguyên liệu (để hiển thị gợi ý khi sửa giá).
  final double  defaultAddonPrice;
  final double  unitPerPack;       // 1 bịch = ? miếng/kg (cho phép số lẻ)
  final bool    looseSaleEnabled;  // Ý 2
  final bool    hotSaleEnabled;    // Ý 1
  final String  unit;              // đơn vị chính (Túi/Kg)
  final String  looseUnit;         // đơn vị nhỏ nhất khi xé lẻ (Miếng/Kg)

  const PosVariantIngredientModel({
    required this.id,
    required this.ingredientId,
    required this.ingredientName,
    this.ingredientImageUrl,
    required this.stockDeductPerUnit,
    this.maxSelectableCount,
    this.subGroupTag,
    this.subGroupMaxSelect,
    required this.displayOrder,
    this.addonPrice = 0,
    this.addonPriceOverride,
    this.addonPriceShopee,
    this.addonPriceGrab,
    this.defaultAddonPrice = 0,
    this.unitPerPack = 1.0,
    this.looseSaleEnabled = false,
    this.hotSaleEnabled = false,
    this.unit = '',
    this.looseUnit = '',
  });

  factory PosVariantIngredientModel.fromJson(Map<String, dynamic> j) =>
      PosVariantIngredientModel(
        id:                 j['id'] as int,
        ingredientId:       j['ingredientId'] as int,
        ingredientName:     j['ingredientName'] as String,
        ingredientImageUrl: j['ingredientImageUrl'] as String?,
        stockDeductPerUnit: (j['stockDeductPerUnit'] as num?)?.toDouble() ?? 1.0,
        maxSelectableCount: j['maxSelectableCount'] as int?,
        subGroupTag:        j['subGroupTag'] as String?,
        subGroupMaxSelect:  j['subGroupMaxSelect'] as int?,
        displayOrder:       j['displayOrder'] as int? ?? 0,
        addonPrice:         (j['addonPrice'] as num?)?.toDouble() ?? 0.0,
        addonPriceOverride: (j['addonPriceOverride'] as num?)?.toDouble(),
        addonPriceShopee:   (j['addonPriceShopee'] as num?)?.toDouble(),
        addonPriceGrab:     (j['addonPriceGrab'] as num?)?.toDouble(),
        defaultAddonPrice:  (j['defaultAddonPrice'] as num?)?.toDouble()
            ?? (j['addonPrice'] as num?)?.toDouble() ?? 0.0,
        unitPerPack:        (j['unitPerPack'] as num?)?.toDouble() ?? 1.0,
        looseSaleEnabled:   j['looseSaleEnabled'] as bool? ?? false,
        hotSaleEnabled:     j['hotSaleEnabled'] as bool? ?? false,
        unit:               j['unit'] as String? ?? '',
        looseUnit:          j['looseUnit'] as String? ?? '',
      );

  /// Giá addon áp dụng theo KÊNH BÁN.
  /// [platform]: null = bán tại quán, 'SHOPEE_FOOD', 'GRAB_FOOD'.
  /// Chưa set giá app → rơi về giá tại quán (giữ hành vi cũ).
  double priceFor(String? platform) {
    if (platform == 'SHOPEE_FOOD' && addonPriceShopee != null) {
      return addonPriceShopee!;
    }
    if (platform == 'GRAB_FOOD' && addonPriceGrab != null) {
      return addonPriceGrab!;
    }
    return addonPrice;
  }
}

class PosVariantModel {
  final int    id;
  final String groupName;
  final int    minSelect;
  final int    maxSelect;
  final bool   allowRepeat;
  final int    displayOrder;
  final bool   isActive;
  final bool   isAddonGroup;
  final bool   isDefault;
  final List<PosVariantIngredientModel> ingredients;

  const PosVariantModel({
    required this.id,
    required this.groupName,
    required this.minSelect,
    required this.maxSelect,
    required this.allowRepeat,
    required this.displayOrder,
    required this.isActive,
    this.isAddonGroup = false,
    this.isDefault    = false,
    required this.ingredients,
  });

  factory PosVariantModel.fromJson(Map<String, dynamic> j) => PosVariantModel(
    id:           j['id'] as int,
    groupName:    j['groupName'] as String,
    minSelect:    j['minSelect'] as int,
    maxSelect:    j['maxSelect'] as int,
    allowRepeat:  j['allowRepeat'] as bool? ?? true,
    displayOrder: j['displayOrder'] as int? ?? 0,
    isActive:     j['isActive'] as bool? ?? true,
    isAddonGroup: j['isAddonGroup'] as bool? ?? false,
    isDefault:    j['isDefault'] as bool? ?? false,
    ingredients:  (j['ingredients'] as List<dynamic>? ?? [])
        .map((e) => PosVariantIngredientModel.fromJson(e as Map<String, dynamic>))
        .toList(),
  );
}

class PosProductModel {
  final int     id;
  final String  name;
  final String? description;
  final String? imageUrl;
  final bool    isActive;
  final int     categoryId;
  final String  categoryName;
  final bool    singlePrice;
  final double  basePrice;
  final int     displayOrder;
  final List<PriceOption>      priceOptions;
  final List<PosVariantModel>  variants;
  final bool    hasVariants;
  final int     vatPercent;
  final bool    isShopeeFood;
  final bool    isGrabFood;
  final List<AppMenuModel> appMenus;

  const PosProductModel({
    required this.id,
    required this.name,
    this.description,
    this.imageUrl,
    required this.isActive,
    required this.categoryId,
    required this.categoryName,
    required this.singlePrice,
    required this.basePrice,
    this.displayOrder = 0,
    required this.priceOptions,
    required this.variants,
    required this.hasVariants,
    this.vatPercent  = 0,
    this.isShopeeFood = false,
    this.isGrabFood   = false,
    this.appMenus = const [],
  });

  factory PosProductModel.fromJson(Map<String, dynamic> j) => PosProductModel(
    id:           j['id'] as int,
    name:         j['name'] as String,
    description:  j['description'] as String?,
    imageUrl:     j['imageUrl'] as String?,
    isActive:     j['isActive'] as bool? ?? true,
    categoryId:   j['categoryId'] as int,
    categoryName: j['categoryName'] as String,
    singlePrice:  j['singlePrice'] as bool? ?? false,
    basePrice:    (j['basePrice'] as num).toDouble(),
    displayOrder: j['displayOrder'] as int? ?? 0,
    priceOptions: (j['priceOptions'] as List<dynamic>? ?? [])
        .map((e) => PriceOption.fromJson(e as Map<String, dynamic>))
        .toList(),
    variants: (j['variants'] as List<dynamic>? ?? [])
        .map((e) => PosVariantModel.fromJson(e as Map<String, dynamic>))
        .toList(),
    hasVariants:  j['hasVariants'] as bool? ?? false,
    vatPercent:   j['vatPercent'] as int? ?? 0,
    isShopeeFood: j['isShopeeFood'] as bool? ?? false,
    isGrabFood:   j['isGrabFood'] as bool? ?? false,
    appMenus: (j['appMenus'] as List<dynamic>? ?? [])
        .map((e) => AppMenuModel.fromJson(e as Map<String, dynamic>))
        .toList(),
  );

  /// Ý 2: nguyên liệu (không phải addon) có bật bán xé lẻ — nếu có.
  PosVariantIngredientModel? get looseIngredient {
    for (final v in variants) {
      if (v.isAddonGroup) continue;
      for (final ing in v.ingredients) {
        if (ing.looseSaleEnabled) return ing;
      }
    }
    return null;
  }

  bool get canSellLoose => looseIngredient != null;

  /// 1 bịch = ? miếng (tỷ lệ quy đổi), mặc định 1.
  double get looseRatio => looseIngredient?.unitPerPack ?? 1.0;

  /// Đơn vị chính của nguyên liệu xé lẻ (Túi/Kg...).
  String get looseMainUnit {
    final u = looseIngredient?.unit ?? '';
    return u.isEmpty ? 'bịch' : u;
  }

  /// Đơn vị nhỏ nhất khi xé lẻ (Miếng/Kg...).
  String get looseSmallUnit {
    final u = looseIngredient?.looseUnit ?? '';
    return u.isEmpty ? 'miếng' : u;
  }
}
