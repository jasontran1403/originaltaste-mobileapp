// lib/data/models/order/order_models.dart
// Tất cả models liên quan đến Order, Cart, Customer — tách ra khỏi service

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ══════════════════════════════════════════════════════════════════
// ENUMS
// ══════════════════════════════════════════════════════════════════

enum OrderMode {
  retail,
  wholesale;

  String get label => this == retail ? 'Khách lẻ' : 'Khách sỉ';
}

enum ItemPriceMode {
  base,
  tier,
  discountPercent;

  String get apiValue => switch (this) {
    base            => 'BASE',
    tier            => 'TIER',
    discountPercent => 'DISCOUNT_PERCENT',
  };

  static ItemPriceMode fromApi(String? v) => switch (v?.toUpperCase()) {
    'TIER'             => tier,
    'DISCOUNT_PERCENT' => discountPercent,
    _                  => base,
  };
}

// ══════════════════════════════════════════════════════════════════
// CATEGORY
// ══════════════════════════════════════════════════════════════════

class CategoryModel {
  final int id;
  final String name;
  final String? imageUrl;
  final bool isActive;

  const CategoryModel({
    required this.id,
    required this.name,
    this.imageUrl,
    required this.isActive,
  });

  factory CategoryModel.fromJson(Map<String, dynamic> json) => CategoryModel(
    id:       json['id'] ?? 0,
    name:     json['name'] ?? '',
    imageUrl: json['imageUrl'],
    isActive: json['isActive'] ?? true,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is CategoryModel && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

// ══════════════════════════════════════════════════════════════════
// PRODUCT PRICE TIER
// ══════════════════════════════════════════════════════════════════

class ProductPriceTierModel {
  final int id;
  final String tierName;
  final double minQuantity;
  final double? maxQuantity;
  final double price;
  final int sortOrder;
  final bool isActive;

  const ProductPriceTierModel({
    required this.id,
    required this.tierName,
    required this.minQuantity,
    this.maxQuantity,
    required this.price,
    required this.sortOrder,
    required this.isActive,
  });

  factory ProductPriceTierModel.fromJson(Map<String, dynamic> json) =>
      ProductPriceTierModel(
        id:          json['id'] ?? 0,
        tierName:    json['tierName'] ?? '',
        minQuantity: double.tryParse(json['minQuantity']?.toString() ?? '0') ?? 0,
        maxQuantity: json['maxQuantity'] != null
            ? double.tryParse(json['maxQuantity'].toString())
            : null,
        price:     double.tryParse(json['price']?.toString() ?? '0') ?? 0,
        sortOrder: json['sortOrder'] ?? 0,
        isActive:  json['isActive'] ?? true,
      );

  String get rangeLabel {
    final mn = _fq(minQuantity);
    if (maxQuantity == null) return '≥ $mn';
    return '$mn – <${_fq(maxQuantity!)}';
  }

  String _fq(double q) =>
      q == q.truncateToDouble() ? q.toInt().toString() : q.toString();
}

// ══════════════════════════════════════════════════════════════════
// PRODUCT
// ══════════════════════════════════════════════════════════════════

class ProductModel {
  final int id;
  final String name;
  final String? description;
  final String? unit;
  final String? imageUrl;
  final int? categoryId;
  final String? categoryName;
  final double basePrice;
  final List<ProductPriceTierModel> priceTiers;
  final int vatRate;

  const ProductModel({
    required this.id,
    required this.name,
    this.description,
    this.unit,
    this.imageUrl,
    this.categoryId,
    this.categoryName,
    required this.basePrice,
    required this.priceTiers,
    this.vatRate = 0,
  });

  factory ProductModel.fromJson(Map<String, dynamic> json) => ProductModel(
    id:           json['id'] ?? 0,
    name:         json['name'] ?? '',
    description:  json['description'],
    unit:         json['unit'],
    imageUrl:     json['imageUrl'],
    categoryId:   json['categoryId'],
    categoryName: json['categoryName'] ?? json['category'],
    basePrice:    double.tryParse(json['basePrice']?.toString() ?? '0') ?? 0,
    priceTiers: (() {
      final raw = (json['priceTiers'] as List<dynamic>?)
          ?? (json['tiers'] as List<dynamic>?)
          ?? [];
      return raw
          .map((e) => ProductPriceTierModel.fromJson(e))
          .where((t) => t.isActive)
          .toList()
        ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    })(),
    vatRate: json['vatRate'] ?? 0,
  );

  ProductPriceTierModel? tierForQty(double qty) {
    ProductPriceTierModel? best;
    for (final t in priceTiers) {
      if (qty >= t.minQuantity) {
        final max = t.maxQuantity;
        if (max == null || qty < max) best = t;
      }
    }
    return best;
  }

  ProductPriceTierModel? get firstTier =>
      priceTiers.isNotEmpty ? priceTiers.first : null;
}

// ══════════════════════════════════════════════════════════════════
// CUSTOMER
// ══════════════════════════════════════════════════════════════════

class CustomerAddressModel {
  final int? id;
  final String address;
  final bool isDefault;

  const CustomerAddressModel({
    this.id,
    required this.address,
    required this.isDefault,
  });

  factory CustomerAddressModel.fromJson(Map<String, dynamic> json) =>
      CustomerAddressModel(
        id:        json['id'],
        address:   json['address'] ?? '',
        isDefault: json['isDefault'] ?? false,
      );

  Map<String, dynamic> toJson() =>
      {'address': address, 'isDefault': isDefault};
}

class CustomerModel {
  final int id;
  final String phone;
  final String? name;
  final String? email;
  final int discountRate;
  final bool isActive;
  final List<CustomerAddressModel> addresses;

  const CustomerModel({
    required this.id,
    required this.phone,
    this.name,
    this.email,
    required this.discountRate,
    required this.isActive,
    required this.addresses,
  });

  factory CustomerModel.fromJson(Map<String, dynamic> json) => CustomerModel(
    id:           json['id'] ?? 0,
    phone:        json['phone'] ?? '',
    name:         json['name'],
    email:        json['email'],
    discountRate: json['discountRate'] ?? 0,
    isActive:     json['isActive'] ?? true,
    addresses: (json['addresses'] as List<dynamic>? ?? [])
        .map((e) => CustomerAddressModel.fromJson(e))
        .toList(),
  );

  CustomerAddressModel? get defaultAddress =>
      addresses.where((a) => a.isDefault).firstOrNull ?? addresses.firstOrNull;
}

class SelectedCustomer {
  final int? id;
  final String name;
  final String phone;
  final String email;
  final String address;
  final int discountRate;

  const SelectedCustomer({
    this.id,
    required this.name,
    required this.phone,
    this.email = '',
    this.address = '',
    this.discountRate = 0,
  });
}

// ══════════════════════════════════════════════════════════════════
// CART ITEM
// ══════════════════════════════════════════════════════════════════

class CartItem {
  final ProductModel product;
  final TextEditingController qtyController;
  double quantity;
  ItemPriceMode priceMode;
  ProductPriceTierModel? selectedTier;
  int? discountPercent;

  CartItem({
    required this.product,
    required this.quantity,
    required OrderMode orderMode,
  })  : qtyController = TextEditingController(text: fmtQty(quantity)),
        priceMode     = ItemPriceMode.tier,
        selectedTier  = null,
        discountPercent = null;

  double baseForDiscount(OrderMode orderMode) {
    if (orderMode == OrderMode.retail) return product.basePrice;
    return product.firstTier?.price ?? product.basePrice;
  }

  double get unitPrice {
    switch (priceMode) {
      case ItemPriceMode.base:
        return product.basePrice;
      case ItemPriceMode.discountPercent:
        final pct = discountPercent ?? 0;
        return product.basePrice * (100 - pct) / 100;
      case ItemPriceMode.tier:
        final tier = selectedTier ?? product.tierForQty(quantity);
        return tier?.price ?? product.basePrice;
    }
  }

  ProductPriceTierModel? get activeTier {
    if (priceMode != ItemPriceMode.tier) return null;
    return selectedTier ?? product.tierForQty(quantity);
  }

  double get subtotal => unitPrice * quantity;
  double get vatAmount => subtotal * product.vatRate / 100;

  void dispose() => qtyController.dispose();

  static String fmtQty(double q) =>
      q == q.truncateToDouble() ? q.toInt().toString() : q.toStringAsFixed(2);
}

// ══════════════════════════════════════════════════════════════════
// ORDER MODELS (response from API)
// ══════════════════════════════════════════════════════════════════

class OrderItemIngredientModel {
  final int ingredientId;
  final String ingredientName;
  final double quantityUsed;
  final String unit;

  const OrderItemIngredientModel({
    required this.ingredientId,
    required this.ingredientName,
    required this.quantityUsed,
    required this.unit,
  });

  factory OrderItemIngredientModel.fromJson(Map<String, dynamic> json) =>
      OrderItemIngredientModel(
        ingredientId:   json['ingredientId'] ?? 0,
        ingredientName: json['ingredientName'] ?? '',
        quantityUsed:   double.tryParse(json['quantityUsed']?.toString() ?? '0') ?? 0,
        unit:           json['unit'] ?? '',
      );
}

class OrderItemModel {
  final int id;
  final int productId;
  final String productName;
  final String? productImageUrl;
  final double basePrice;
  final double unitPrice;
  final String priceMode;
  final int? tierId;
  final String? tierName;
  final int? discountPercent;
  final int vatRate;
  final double vatAmount;
  final double quantity;
  final double subtotal;
  final String? unit;
  final String? notes;

  const OrderItemModel({
    required this.id,
    required this.productId,
    required this.productName,
    this.productImageUrl,
    required this.basePrice,
    required this.unitPrice,
    required this.priceMode,
    this.tierId,
    this.tierName,
    this.discountPercent,
    this.vatRate = 0,
    this.vatAmount = 0,
    required this.quantity,
    required this.subtotal,
    this.unit,
    this.notes,
  });

  factory OrderItemModel.fromJson(Map<String, dynamic> json) => OrderItemModel(
    id:             json['id'] ?? 0,
    productId:      json['productId'] ?? 0,
    productName:    json['productName'] ?? '',
    productImageUrl: json['productImageUrl'],
    basePrice:      double.tryParse(json['basePrice']?.toString() ?? '0') ?? 0,
    unitPrice:      double.tryParse(json['unitPrice']?.toString() ?? '0') ?? 0,
    priceMode:      json['priceMode'] ?? 'BASE',
    tierId:         json['tierId'],
    tierName:       json['tierName'],
    discountPercent: json['discountPercent'],
    vatRate:        json['vatRate'] ?? 0,
    vatAmount:      double.tryParse(json['vatAmount']?.toString() ?? '0') ?? 0,
    quantity:       double.tryParse(json['quantity']?.toString() ?? '0') ?? 0,
    subtotal:       double.tryParse(json['subtotal']?.toString() ?? '0') ?? 0,
    unit:           json['unit'],
    notes:          json['notes'],
  );

  String get priceModeLabel => switch (priceMode) {
    'TIER'             => tierName != null ? 'Khung: $tierName' : 'Giá khung',
    'DISCOUNT_PERCENT' => discountPercent != null ? 'Giảm $discountPercent%' : 'Giảm giá',
    _                  => 'Giá gốc',
  };
}

class OrderModel {
  final int id;
  final String orderCode;
  final String? customerName;
  final String? customerPhone;
  final String? shippingAddress;
  final double totalAmount;
  final double discountAmount;
  final double finalAmount;
  final double vatAmount;
  final String status;
  final String paymentStatus;
  final String? paymentMethod;
  final String? notes;
  final int? createdAt;
  final List<OrderItemModel> items;

  const OrderModel({
    required this.id,
    required this.orderCode,
    this.customerName,
    this.customerPhone,
    this.shippingAddress,
    required this.totalAmount,
    required this.discountAmount,
    required this.finalAmount,
    this.vatAmount = 0,
    required this.status,
    required this.paymentStatus,
    this.paymentMethod,
    this.notes,
    this.createdAt,
    required this.items,
  });

  factory OrderModel.fromJson(Map<String, dynamic> json) => OrderModel(
    id:              json['id'] ?? 0,
    orderCode:       json['orderCode'] ?? '',
    customerName:    json['customerName'],
    customerPhone:   json['customerPhone'],
    shippingAddress: json['shippingAddress'],
    totalAmount:     double.tryParse(json['totalAmount']?.toString() ?? '0') ?? 0,
    discountAmount:  double.tryParse(json['discountAmount']?.toString() ?? '0') ?? 0,
    finalAmount:     double.tryParse(json['finalAmount']?.toString() ?? '0') ?? 0,
    vatAmount:       double.tryParse(json['vatAmount']?.toString() ?? '0') ?? 0,
    status:          json['status'] ?? '',
    paymentStatus:   json['paymentStatus'] ?? '',
    paymentMethod:   json['paymentMethod'],
    notes:           json['notes'],
    createdAt:       json['createdAt'],
    items: (json['items'] as List<dynamic>? ?? [])
        .map((e) => OrderItemModel.fromJson(e))
        .toList(),
  );
}

// ══════════════════════════════════════════════════════════════════
// REQUEST MODELS
// ══════════════════════════════════════════════════════════════════

class CreateOrderItemRequest {
  final int productId;
  final double quantity;
  final String priceMode;
  final int? tierId;
  final int? discountPercent;
  final String? notes;
  final double? sentUnitPrice;
  final String? orderType;

  const CreateOrderItemRequest({
    required this.productId,
    required this.quantity,
    required this.priceMode,
    this.tierId,
    this.discountPercent,
    this.notes,
    this.sentUnitPrice,
    this.orderType,
  });

  Map<String, dynamic> toJson() => {
    'productId': productId,
    'quantity':  quantity,
    'priceMode': priceMode,
    if (tierId != null)          'tierId':          tierId,
    if (discountPercent != null) 'discountPercent': discountPercent,
    if (notes != null && notes!.isNotEmpty) 'notes': notes,
    if (sentUnitPrice != null)   'sentUnitPrice':   sentUnitPrice,
    if (orderType != null)       'orderType':       orderType,
  };
}

class CreateOrderRequest {
  final String? customerName;
  final String? customerPhone;
  final String? customerEmail;
  final String? shippingAddress;
  final String paymentMethod;
  final String? notes;
  final String? type;
  final List<CreateOrderItemRequest> items;

  const CreateOrderRequest({
    this.customerName,
    this.customerPhone,
    this.customerEmail,
    this.shippingAddress,
    this.type,
    required this.paymentMethod,
    this.notes,
    required this.items,
  });

  Map<String, dynamic> toJson() => {
    if (customerName != null)    'customerName':    customerName,
    if (customerPhone != null)   'customerPhone':   customerPhone,
    if (customerEmail != null)   'customerEmail':   customerEmail,
    if (shippingAddress != null) 'shippingAddress': shippingAddress,
    'type':          type,
    'paymentMethod': paymentMethod,
    if (notes != null) 'notes': notes,
    'items': items.map((e) => e.toJson()).toList(),
  };
}

class OrderHistoryResult {
  final List<OrderModel> items;
  final bool hasNext;
  const OrderHistoryResult({
    required this.items,
    required this.hasNext,
  });
}
