// lib/data/models/management/management_models.dart

// ══════════════════════════════════════════════════════════════════
// INGREDIENT
// ══════════════════════════════════════════════════════════════════

class IngredientModel {
  final int id;
  final String name;
  final String unit;
  final double stockQuantity;
  final int? importDate;
  final int? expiryDate;

  const IngredientModel({
    required this.id,
    required this.name,
    required this.unit,
    required this.stockQuantity,
    this.importDate,
    this.expiryDate,
  });

  factory IngredientModel.fromJson(Map<String, dynamic> json) =>
      IngredientModel(
        id:            json['id'] ?? 0,
        name:          json['name'] ?? '',
        unit:          json['unit'] ?? '',
        stockQuantity: (json['stockQuantity'] ?? 0).toDouble(),
        importDate:    json['importDate'],
        expiryDate:    json['expiryDate'],
      );

  Map<String, dynamic> toJson() => {
    'id':            id,
    'name':          name,
    'unit':          unit,
    'stockQuantity': stockQuantity,
    if (importDate != null) 'importDate': importDate,
    if (expiryDate != null) 'expiryDate': expiryDate,
  };

  IngredientModel copyWith({
    int? id, String? name, String? unit,
    double? stockQuantity, int? importDate, int? expiryDate,
  }) =>
      IngredientModel(
        id:            id ?? this.id,
        name:          name ?? this.name,
        unit:          unit ?? this.unit,
        stockQuantity: stockQuantity ?? this.stockQuantity,
        importDate:    importDate ?? this.importDate,
        expiryDate:    expiryDate ?? this.expiryDate,
      );
}

// ══════════════════════════════════════════════════════════════════
// PRODUCT INGREDIENT ITEM  (nguyên liệu gắn với sản phẩm + số lượng)
// ══════════════════════════════════════════════════════════════════

class ProductIngredientItem {
  final int ingredientId;
  final String name;
  final String unit;
  final double quantity; // số lượng nguyên liệu cho 1 đơn vị sản phẩm

  const ProductIngredientItem({
    required this.ingredientId,
    required this.name,
    required this.unit,
    required this.quantity,
  });

  /// Parse từ cấu trúc server: variants[0].ingredients[i]
  factory ProductIngredientItem.fromJson(Map<String, dynamic> json) =>
      ProductIngredientItem(
        ingredientId: json['ingredientId'] ?? 0,
        name:         json['ingredientName'] ?? json['name'] ?? '',
        unit:         json['unit'] ?? '',
        quantity:     (json['quantity'] ?? 1.0).toDouble(),
      );

  /// Gửi lên server khi tạo/sửa sản phẩm
  Map<String, dynamic> toJson() => {
    'ingredientId': ingredientId,
    'quantity':     quantity,
  };
}

// ══════════════════════════════════════════════════════════════════
// INVENTORY LOG  (lịch sử xuất/nhập kho)
// ══════════════════════════════════════════════════════════════════

class InventoryLogModel {
  final int? id;
  final String? ingredientName;
  final double quantity;
  final String? unit;
  final String? purpose;
  final String? status;
  final int? createdAt;

  const InventoryLogModel({
    this.id,
    this.ingredientName,
    required this.quantity,
    this.unit,
    this.purpose,
    this.status,
    this.createdAt,
  });

  factory InventoryLogModel.fromJson(Map<String, dynamic> j) =>
      InventoryLogModel(
        id:             j['id'],
        ingredientName: j['ingredientName'] ?? j['ingredient']?['name'],
        quantity:       (j['quantity'] ?? 0).toDouble(),
        unit:           j['unit'] ?? j['ingredient']?['unit'],
        purpose:        j['purpose'],
        status:         j['status'],
        createdAt:      j['createdAt'],
      );
}

// ── Paginated wrapper ─────────────────────────────────────────────

class PaginatedLogs {
  final List<InventoryLogModel> content;
  final bool hasMore;

  const PaginatedLogs({required this.content, required this.hasMore});

  factory PaginatedLogs.fromJson(Map<String, dynamic> j) {
    final list = (j['content'] ?? j['data'] ?? []) as List;
    final totalPages = j['totalPages'] ?? 1;
    final number     = j['number'] ?? j['page'] ?? 0;
    return PaginatedLogs(
      content: list.map((e) => InventoryLogModel.fromJson(e)).toList(),
      hasMore: number + 1 < totalPages,
    );
  }
}

// ══════════════════════════════════════════════════════════════════
// MANUAL IMPORT
// ══════════════════════════════════════════════════════════════════

class ManualImportItem {
  final int ingredientId;
  final double quantity;
  final int? expiryDate;

  const ManualImportItem({
    required this.ingredientId,
    required this.quantity,
    this.expiryDate,
  });

  Map<String, dynamic> toJson() => {
    'ingredientId': ingredientId,
    'quantity':     quantity,
    if (expiryDate != null) 'expiryDate': expiryDate,
  };
}

class ManualImportResult {
  final String? batchCode;
  const ManualImportResult({this.batchCode});

  factory ManualImportResult.fromJson(Map<String, dynamic> j) =>
      ManualImportResult(batchCode: j['batchCode']?.toString());
}

// ══════════════════════════════════════════════════════════════════
// QR IMPORT
// ══════════════════════════════════════════════════════════════════

class ImportProductItem {
  final String productName;
  final DateTime manufacturingDate;
  final DateTime expiryDate;
  final String packageWeight;
  final String batchWeight;
  double quantity;

  ImportProductItem({
    required this.productName,
    required this.manufacturingDate,
    required this.expiryDate,
    required this.packageWeight,
    required this.batchWeight,
    this.quantity = 1,
  });

  ImportProductItem copyWith({double? quantity}) => ImportProductItem(
    productName:         productName,
    manufacturingDate:   manufacturingDate,
    expiryDate:          expiryDate,
    packageWeight:       packageWeight,
    batchWeight:         batchWeight,
    quantity:            quantity ?? this.quantity,
  );
}

class ImportWarehouseModel {
  final String id;
  final String importerName;
  final DateTime importTime;
  final List<ImportProductItem> products;
  final bool isSaved;

  ImportWarehouseModel({
    required this.id,
    required this.importerName,
    required this.importTime,
    required this.products,
    this.isSaved = true,
  });
}

// ══════════════════════════════════════════════════════════════════
// MGMT CATEGORY
// ══════════════════════════════════════════════════════════════════

class MgmtCategoryModel {
  final int id;
  final String name;
  final String? imageUrl;

  const MgmtCategoryModel({
    required this.id,
    required this.name,
    this.imageUrl,
  });

  factory MgmtCategoryModel.fromJson(Map<String, dynamic> json) =>
      MgmtCategoryModel(
        id:       json['id'] ?? 0,
        name:     json['name'] ?? '',
        imageUrl: json['imageUrl'],
      );

  Map<String, dynamic> toJson() => {
    'id':       id,
    'name':     name,
    if (imageUrl != null) 'imageUrl': imageUrl,
  };

  MgmtCategoryModel copyWith({int? id, String? name, String? imageUrl}) =>
      MgmtCategoryModel(
        id:       id ?? this.id,
        name:     name ?? this.name,
        imageUrl: imageUrl ?? this.imageUrl,
      );
}

// ══════════════════════════════════════════════════════════════════
// MGMT PRODUCT
// ══════════════════════════════════════════════════════════════════

class MgmtProductModel {
  final int id;
  final String name;
  final double price;
  final String? unit;                              // đơn vị tính của sản phẩm
  final String? imageUrl;
  final String? description;
  final int? categoryId;
  final String? categoryName;
  final bool isAvailable;
  final int vatRate;
  // Raw tiers list from API
  final List<Map<String, dynamic>>? tiers;
  // ── Danh sách nguyên liệu gắn với sản phẩm (có số lượng) ──────
  final List<ProductIngredientItem> productIngredients;

  const MgmtProductModel({
    required this.id,
    required this.name,
    required this.price,
    this.unit,
    this.imageUrl,
    this.description,
    this.categoryId,
    this.categoryName,
    this.isAvailable = true,
    this.vatRate     = 0,
    this.tiers,
    this.productIngredients = const [],
  });

  factory MgmtProductModel.fromJson(Map<String, dynamic> json) {
    // Parse tiers
    final rawTiers = (json['priceTiers'] ?? json['tiers']) as List<dynamic>?;
    final tiers = rawTiers
        ?.map((e) => Map<String, dynamic>.from(e as Map))
        .toList();

    return MgmtProductModel(
      id:           json['id'] ?? 0,
      name:         json['name'] ?? '',
      price:        double.tryParse(
          (json['basePrice'] ?? json['defaultPrice'] ?? json['price'])
              ?.toString() ?? '0') ?? 0,
      unit:         json['unit'],
      imageUrl:     json['imageUrl'],
      description:  json['description'],
      categoryId:   json['categoryId'],
      categoryName: json['categoryName'] ?? json['category'],
      isAvailable:  json['isAvailable'] ?? json['isActive'] ?? true,
      vatRate:      json['vatRate'] ?? 0,
      tiers:        tiers,
      productIngredients: _parseProductIngredients(json),
    );
  }

  /// Parse danh sách nguyên liệu từ cấu trúc server:
  /// variants[0].ingredients[] hoặc productIngredients[]
  static List<ProductIngredientItem> _parseProductIngredients(
      Map<String, dynamic> json) {
    // Thử lấy từ variants[0].ingredients (cấu trúc hiện tại của server)
    final variants = json['variants'] as List<dynamic>?;
    if (variants != null && variants.isNotEmpty) {
      final firstVariant = variants.first as Map<String, dynamic>?;
      if (firstVariant != null) {
        final ings = firstVariant['ingredients'] as List<dynamic>?;
        if (ings != null && ings.isNotEmpty) {
          return ings
              .map((e) => ProductIngredientItem.fromJson(
              e as Map<String, dynamic>))
              .toList();
        }
      }
    }
    // Fallback: productIngredients trực tiếp (nếu server trả về)
    final directIngs = json['productIngredients'] as List<dynamic>?;
    if (directIngs != null && directIngs.isNotEmpty) {
      return directIngs
          .map((e) => ProductIngredientItem.fromJson(
          e as Map<String, dynamic>))
          .toList();
    }
    return [];
  }

  Map<String, dynamic> toJson() => {
    'id':          id,
    'name':        name,
    'price':       price,
    if (unit        != null) 'unit':        unit,
    if (imageUrl    != null) 'imageUrl':    imageUrl,
    if (description != null) 'description': description,
    if (categoryId  != null) 'categoryId':  categoryId,
    'isAvailable': isAvailable,
    'vatRate':     vatRate,
  };

  MgmtProductModel copyWith({
    int? id,
    String? name,
    double? price,
    String? unit,
    String? imageUrl,
    String? description,
    int? categoryId,
    String? categoryName,
    bool? isAvailable,
    int? vatRate,
    List<Map<String, dynamic>>? tiers,
    List<ProductIngredientItem>? productIngredients,
  }) =>
      MgmtProductModel(
        id:                 id                 ?? this.id,
        name:               name               ?? this.name,
        price:              price              ?? this.price,
        unit:               unit               ?? this.unit,
        imageUrl:           imageUrl           ?? this.imageUrl,
        description:        description        ?? this.description,
        categoryId:         categoryId         ?? this.categoryId,
        categoryName:       categoryName       ?? this.categoryName,
        isAvailable:        isAvailable        ?? this.isAvailable,
        vatRate:            vatRate            ?? this.vatRate,
        tiers:              tiers              ?? this.tiers,
        productIngredients: productIngredients ?? this.productIngredients,
      );
}