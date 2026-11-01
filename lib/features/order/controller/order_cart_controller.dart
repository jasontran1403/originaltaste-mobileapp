// lib/features/order/controller/order_cart_controller.dart

import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/order/order_models.dart';
import '../../../services/order_service.dart';

// ══════════════════════════════════════════════════════════════════
// QTY FORMATTER
// ══════════════════════════════════════════════════════════════════

class QtyInputFormatter extends TextInputFormatter {
  static final _instance = QtyInputFormatter._();
  QtyInputFormatter._();
  static TextInputFormatter get instance => _instance;

  @override
  TextEditingValue formatEditUpdate(TextEditingValue old, TextEditingValue next) {
    if (next.text.isEmpty) return next;
    if (!RegExp(r'^\d*\.?\d{0,2}$').hasMatch(next.text)) return old;
    return next;
  }
}

class MaxValueFormatter extends TextInputFormatter {
  final int max;
  const MaxValueFormatter(this.max);

  @override
  TextEditingValue formatEditUpdate(TextEditingValue old, TextEditingValue next) {
    if (next.text.isEmpty) return next;
    final val = int.tryParse(next.text);
    if (val == null || val > max) return old;
    return next;
  }
}

// ══════════════════════════════════════════════════════════════════
// STATE
// ══════════════════════════════════════════════════════════════════

class OrderCartState {
  // Data
  final List<ProductModel> allProducts;
  final List<ProductModel> filteredProducts;
  final List<CategoryModel> categories;
  final List<CartItem> cartItems;
  final SelectedCustomer? selectedCustomer;

  // UI state
  final bool isLoadingProducts;
  final bool isSubmitting;
  final bool isSearching;
  final OrderMode orderMode;
  final String searchQuery;
  final CategoryModel? selectedCategory;
  final String sortMode;
  final String paymentMethod;
  final String orderNotes;

  // Animated totals (read-only snapshot cho UI)
  final double animSubtotal;
  final double animDiscount;
  final double animVat;
  final double animGrand;

  const OrderCartState({
    this.allProducts     = const [],
    this.filteredProducts = const [],
    this.categories      = const [],
    this.cartItems       = const [],
    this.selectedCustomer,
    this.isLoadingProducts = false,
    this.isSubmitting    = false,
    this.isSearching     = false,
    this.orderMode       = OrderMode.wholesale,
    this.searchQuery     = '',
    this.selectedCategory,
    this.sortMode        = 'name_asc',
    this.paymentMethod   = 'CASH',
    this.orderNotes      = '',
    this.animSubtotal    = 0,
    this.animDiscount    = 0,
    this.animVat         = 0,
    this.animGrand       = 0,
  });

  OrderCartState copyWith({
    List<ProductModel>?  allProducts,
    List<ProductModel>?  filteredProducts,
    List<CategoryModel>? categories,
    List<CartItem>?      cartItems,
    SelectedCustomer?    selectedCustomer,
    bool?                clearCustomer,
    bool?                isLoadingProducts,
    bool?                isSubmitting,
    bool?                isSearching,
    OrderMode?           orderMode,
    String?              searchQuery,
    CategoryModel?       selectedCategory,
    bool?                clearCategory,
    String?              sortMode,
    String?              paymentMethod,
    String?              orderNotes,
    double?              animSubtotal,
    double?              animDiscount,
    double?              animVat,
    double?              animGrand,
  }) => OrderCartState(
    allProducts:      allProducts      ?? this.allProducts,
    filteredProducts: filteredProducts ?? this.filteredProducts,
    categories:       categories       ?? this.categories,
    cartItems:        cartItems        ?? this.cartItems,
    selectedCustomer: clearCustomer == true ? null : (selectedCustomer ?? this.selectedCustomer),
    isLoadingProducts: isLoadingProducts ?? this.isLoadingProducts,
    isSubmitting:     isSubmitting     ?? this.isSubmitting,
    isSearching:      isSearching      ?? this.isSearching,
    orderMode:        orderMode        ?? this.orderMode,
    searchQuery:      searchQuery      ?? this.searchQuery,
    selectedCategory: clearCategory == true ? null : (selectedCategory ?? this.selectedCategory),
    sortMode:         sortMode         ?? this.sortMode,
    paymentMethod:    paymentMethod    ?? this.paymentMethod,
    orderNotes:       orderNotes       ?? this.orderNotes,
    animSubtotal:     animSubtotal     ?? this.animSubtotal,
    animDiscount:     animDiscount     ?? this.animDiscount,
    animVat:          animVat          ?? this.animVat,
    animGrand:        animGrand        ?? this.animGrand,
  );

  // ── Computed totals ────────────────────────────────────────────
  double effectiveUnitPrice(CartItem item) {
    if (orderMode == OrderMode.retail) {
      if (item.priceMode == ItemPriceMode.discountPercent) {
        final pct = item.discountPercent ?? 0;
        return item.product.basePrice * (100 - pct) / 100;
      }
      return item.product.basePrice;
    }
    return item.quantity > 0
        ? item.subtotal / item.quantity
        : item.product.basePrice;
  }

  double effectiveSubtotal(CartItem item) =>
      effectiveUnitPrice(item) * item.quantity;

  double get subtotal =>
      cartItems.fold(0.0, (s, c) => s + effectiveSubtotal(c));

  double get discountAmount {
    final rate = selectedCustomer?.discountRate ?? 0;
    return subtotal * rate / 100;
  }

  double get afterDiscount => subtotal - discountAmount;

  double get vatAmount {
    if (cartItems.isEmpty || subtotal == 0) return 0.0;
    double total = 0.0;
    for (final item in cartItems) {
      final vr = item.product.vatRate;
      if (vr <= 0) continue;
      final proportion   = item.subtotal / subtotal;
      final itemAfterDisc = afterDiscount * proportion;
      total += itemAfterDisc * vr / 100;
    }
    return total;
  }

  Map<int, double> get vatBreakdown {
    if (cartItems.isEmpty || subtotal == 0) return {};
    final map = <int, double>{};
    for (final item in cartItems) {
      final vr = item.product.vatRate;
      if (vr <= 0) continue;
      final proportion   = item.subtotal / subtotal;
      final itemAfterDisc = afterDiscount * proportion;
      final vat          = itemAfterDisc * vr / 100;
      map[vr] = (map[vr] ?? 0) + vat;
    }
    return map;
  }

  double get grandTotal => afterDiscount + vatAmount;

  bool get canCreateOrder =>
      cartItems.isNotEmpty && !isSubmitting && selectedCustomer != null;
}

// ══════════════════════════════════════════════════════════════════
// NOTIFIER
// ══════════════════════════════════════════════════════════════════

final orderCartProvider =
NotifierProvider<OrderCartNotifier, OrderCartState>(OrderCartNotifier.new);

class OrderCartNotifier extends Notifier<OrderCartState> {
  Timer? _searchDebounce;

  @override
  OrderCartState build() {
    ref.onDispose(() {
      _searchDebounce?.cancel();
      for (final item in state.cartItems) item.dispose();
    });
    Future.microtask(_loadData);
    return const OrderCartState();
  }

  void _autoAdjustTier(CartItem item) {
    // Chỉ áp dụng cho wholesale và khi đang ở priceMode.tier
    if (state.orderMode != OrderMode.wholesale) return;
    if (item.priceMode == ItemPriceMode.base ||
        item.priceMode == ItemPriceMode.discountPercent) return;

    final tiers = item.product.priceTiers; // List<ProductPriceTierModel>
    if (tiers == null || tiers.isEmpty) return;

    // Tìm tier phù hợp nhất với qty hiện tại
    // Giả sử tier có minQty, sắp xếp giảm dần → lấy tier đầu tiên thỏa minQty
    final sorted = [...tiers]
      ..sort((a, b) => b.minQuantity.compareTo(a.minQuantity));

    ProductPriceTierModel? best;
    for (final t in sorted) {
      if (item.quantity >= t.minQuantity) {
        best = t;
        break;
      }
    }

    // Nếu tìm được tier phù hợp và khác tier hiện tại → cập nhật
    if (best != null && best.id != item.selectedTier?.id) {
      item.priceMode    = ItemPriceMode.tier;
      item.selectedTier = best;
    } else if (best == null) {
      // Qty < minQty của bất kỳ tier nào → về giá gốc
      item.priceMode    = ItemPriceMode.base;
      item.selectedTier = null;
    }
  }


  // ── Load ───────────────────────────────────────────────────────
  Future<void> _loadData() async {
    state = state.copyWith(isLoadingProducts: true);

    final catRes  = await OrderService.instance.getCategories();
    final prodRes = await OrderService.instance.getProducts();

    final cats  = catRes.isSuccess  ? (catRes.data  ?? []) : <CategoryModel>[];
    final prods = prodRes.isSuccess ? (prodRes.data ?? []) : <ProductModel>[];

    state = state.copyWith(
      categories:        cats,
      allProducts:       prods,
      isLoadingProducts: false,
    );
    _applyFilter();
  }

  Future<void> refreshProducts() => _loadData();

  // ── Order mode ─────────────────────────────────────────────────
  void setOrderModeConfirmed(OrderMode mode) {
    if (state.orderMode == mode) return;
    final items = state.cartItems;
    for (final i in items) i.dispose();
    state = state.copyWith(orderMode: mode, cartItems: []);
    _applyFilter();
    _snapAndNotify();
  }

  // ── Cart ops ───────────────────────────────────────────────────
  void addToCart(ProductModel product) {
    final items = List<CartItem>.from(state.cartItems);
    final existing = items.where((c) => c.product.id == product.id).firstOrNull;

    if (existing != null) {
      existing.quantity = double.parse(
          (existing.quantity + 1.0).toStringAsFixed(2));
      existing.qtyController.text = CartItem.fmtQty(existing.quantity);
    } else {
      final item = CartItem(
        product:   product,
        quantity:  1.0,
        orderMode: state.orderMode,
      );
      if (state.orderMode == OrderMode.retail) {
        item.priceMode    = ItemPriceMode.base;
        item.selectedTier = null;
      }
      items.add(item);
    }
    state = state.copyWith(cartItems: items);
    _snapAndNotify();
  }

  void removeFromCart(int index) {
    final items = List<CartItem>.from(state.cartItems);
    items[index].dispose();
    items.removeAt(index);
    state = state.copyWith(cartItems: items);
    _snapAndNotify();
  }

  void clearCart() {
    for (final item in state.cartItems) item.dispose();
    state = state.copyWith(cartItems: []);
    _snapAndNotify();
  }

  // ── Qty ────────────────────────────────────────────────────────
  void onQtyTap(CartItem item) {
    item.qtyController.selection = TextSelection(
      baseOffset:   0,
      extentOffset: item.qtyController.text.length,
    );
  }

  void onQtyChanged(CartItem item, String value) {
    final parsed = double.tryParse(value);
    if (parsed != null && parsed >= 0.01) {
      item.quantity = parsed;
      _autoAdjustTier(item);
      _snapAndNotify();
    }
  }

  void onQtySubmitted(CartItem item) {
    final parsed  = double.tryParse(item.qtyController.text);
    item.quantity = (parsed != null && parsed >= 0.01) ? parsed : 0.01;
    item.qtyController.text = CartItem.fmtQty(item.quantity);
    _autoAdjustTier(item);
    _snapAndNotify();
  }

  void incrementQty(CartItem item) {
    item.quantity = double.parse((item.quantity + 1.0).toStringAsFixed(2));
    item.qtyController.text = CartItem.fmtQty(item.quantity);
    _autoAdjustTier(item);
    _snapAndNotify();
  }

  void decrementQty(CartItem item) {
    item.quantity = double.parse(
        (item.quantity - 1.0).clamp(0.01, 99999.0).toStringAsFixed(2));
    item.qtyController.text = CartItem.fmtQty(item.quantity);
    _autoAdjustTier(item);
    _snapAndNotify();
  }

  // ── Price mode ops ─────────────────────────────────────────────
  void selectTierForItem(CartItem item, ProductPriceTierModel tier) {
    item.priceMode      = ItemPriceMode.tier;
    item.selectedTier   = tier;
    item.discountPercent = null;
    _snapAndNotify();
  }

  void selectBasePriceForItem(CartItem item) {
    item.priceMode      = ItemPriceMode.base;
    item.selectedTier   = null;
    item.discountPercent = null;
    _snapAndNotify();
  }

  void setDiscountPercentForItem(CartItem item, int percent) {
    item.priceMode      = ItemPriceMode.discountPercent;
    item.selectedTier   = null;
    item.discountPercent = percent.clamp(1, 100);
    _snapAndNotify();
  }

  void resetToAutoTier(CartItem item) {
    item.priceMode      = ItemPriceMode.tier;
    item.selectedTier   = null;
    item.discountPercent = null;
    _snapAndNotify();
  }

  // ── Customer ───────────────────────────────────────────────────
  void setCustomer(SelectedCustomer c) {
    state = state.copyWith(selectedCustomer: c);
    _snapAndNotify();
  }

  void clearCustomer() {
    state = state.copyWith(clearCustomer: true);
    _snapAndNotify();
  }

  void setOrderNotes(String notes) =>
      state = state.copyWith(orderNotes: notes);

  // ── Filter / Sort ──────────────────────────────────────────────
  void onSearch(String q) {
    _searchDebounce?.cancel();
    state = state.copyWith(isSearching: true, searchQuery: q.trim().toLowerCase());
    _searchDebounce = Timer(const Duration(milliseconds: 900), () {
      _applyFilter();
      state = state.copyWith(isSearching: false);
    });
  }

  void onSelectCategory(CategoryModel? c) {
    if (c == null) {
      state = state.copyWith(clearCategory: true);
    } else {
      state = state.copyWith(selectedCategory: c);
    }
    _applyFilter();
  }

  void onSortMode(String m) {
    state = state.copyWith(sortMode: m);
    _applyFilter();
  }

  void _applyFilter() {
    var list = List<ProductModel>.from(state.allProducts);
    if (state.selectedCategory != null) {
      list = list.where((p) => p.categoryId == state.selectedCategory!.id).toList();
    }
    if (state.searchQuery.isNotEmpty) {
      list = list.where((p) => p.name.toLowerCase().contains(state.searchQuery)).toList();
    }
    switch (state.sortMode) {
      case 'name_asc':   list.sort((a, b) => a.name.compareTo(b.name));
      case 'name_desc':  list.sort((a, b) => b.name.compareTo(a.name));
      case 'price_asc':  list.sort((a, b) => a.basePrice.compareTo(b.basePrice));
      case 'price_desc': list.sort((a, b) => b.basePrice.compareTo(a.basePrice));
    }
    state = state.copyWith(filteredProducts: list);
  }

  // ── Submit ─────────────────────────────────────────────────────
  Future<(int?, String?)> submitOrder() async {
    if (!state.canCreateOrder) return (null, null);
    state = state.copyWith(isSubmitting: true);

    final sc  = state.selectedCustomer!;
    final req = CreateOrderRequest(
      customerName:    sc.name.isEmpty ? null : sc.name,
      customerPhone:   sc.phone.isEmpty ? null : sc.phone,
      customerEmail:   sc.email.isEmpty ? null : sc.email,
      shippingAddress: sc.address.isEmpty ? null : sc.address,
      paymentMethod:   state.paymentMethod,
      type: state.orderMode == OrderMode.wholesale ? 'WHOLESALE' : 'RETAIL',
      notes: state.orderNotes.isEmpty ? null : state.orderNotes,
      items: state.cartItems.map((c) => CreateOrderItemRequest(
        productId:       c.product.id,
        quantity:        c.quantity,
        priceMode:       c.priceMode.apiValue,
        tierId:          c.priceMode == ItemPriceMode.tier ? c.selectedTier?.id : null,
        discountPercent: c.priceMode == ItemPriceMode.discountPercent ? c.discountPercent : null,
        sentUnitPrice:   state.effectiveUnitPrice(c),
        orderType:       state.orderMode == OrderMode.wholesale ? 'WHOLESALE' : 'RETAIL',
      )).toList(),
    );

    final result = await OrderService.instance.createOrder(req);
    state = state.copyWith(isSubmitting: false);

    if (result.isSuccess && result.data != null) {
      clearCart();
      clearCustomer();
      return (result.data!.id, null);
    }
    return (null, result.message ?? 'Không thể tạo đơn hàng');
  }

  // ── Helpers ────────────────────────────────────────────────────
  void _snapAndNotify() {
    // Trigger rebuild — animated values snap to current computed values
    // Animation logic handled in UI via AnimationController listener
    state = state.copyWith(
      animSubtotal: state.subtotal,
      animDiscount: state.discountAmount,
      animVat:      state.vatAmount,
      animGrand:    state.grandTotal,
    );
  }
}