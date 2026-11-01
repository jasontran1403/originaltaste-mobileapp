// lib/features/pos/screens/pos_product_grid_screen.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import 'package:originaltaste/services/pos_service.dart';
import 'package:originaltaste/data/models/pos/pos_product_model.dart';
import 'package:originaltaste/data/models/pos/pos_cart_model.dart';
import 'package:originaltaste/data/models/pos/pos_shift_model.dart';
import 'package:originaltaste/data/models/pos/pos_order_model.dart';
import 'package:originaltaste/data/models/pos/pos_discount_model.dart';
import 'package:originaltaste/features/pos/components/pos_order_mode.dart';
import 'package:originaltaste/features/pos/screens/pos_import_stock_screen.dart';
import 'package:originaltaste/features/pos/screens/pos_shift_screen.dart';
import 'package:originaltaste/features/pos/components/pos_variant_modal.dart';
import 'package:originaltaste/features/pos/components/pos_quick_add_sheet.dart';
import 'package:originaltaste/features/pos/components/pos_customer_sheet.dart';
import 'package:originaltaste/services/pos_printer_service.dart';
import 'package:originaltaste/features/pos/components/printer_settings_dialog.dart';
import 'package:originaltaste/features/pos/components/pos_weight_sheet.dart';
import 'package:originaltaste/features/pos/components/pos_app_discount_sheet.dart';
import 'package:originaltaste/features/pos/components/pos_app_item_price_sheet.dart';
import 'package:originaltaste/features/pos/widgets/pos_loose_sale_sheet.dart';

import '../../../services/auth_service.dart';
import '../../../shared/widgets/network_image_viewer.dart';

class PosProductGridScreen extends StatefulWidget {
  const PosProductGridScreen({super.key});

  @override
  State<PosProductGridScreen> createState() => _PosProductGridScreenState();
}

class _PosProductGridScreenState extends State<PosProductGridScreen> {
  final _searchCtrl = TextEditingController();
  String _searchKeyword = '';
  Timer? _searchDebounce;

  PosCategoryModel? _selectedCat;
  PosOrderSource    _orderSource             = PosOrderSource.takeAway;
  String            _paymentMethod           = 'CASH';
  bool              _isLoadingProducts       = false;
  bool              _isLoadingCategories     = true;
  bool              _isCreatingOrder         = false;
  bool              _isConnectingPrinter     = false;
  bool              _printerConnected        = false;
  PosEVoucher? _appliedVoucher;
  String _appOrderCode = '';

  void _updateShiftWithNewOrder(PosOrderModel order) {
    if (_currentShift == null) return;
    final isOffline = order.orderSource != 'SHOPEE_FOOD'
        && order.orderSource != 'GRAB_FOOD';
    final addedRevenue = order.finalAmount;

    setState(() {
      _currentShift = PosShiftModel(
        id:                _currentShift!.id,
        staffName:         _currentShift!.staffName,
        status:            _currentShift!.status,
        shiftDate:         _currentShift!.shiftDate,
        isFirstShiftOfDay: _currentShift!.isFirstShiftOfDay,
        openTime:          _currentShift!.openTime,
        closeTime:         _currentShift!.closeTime,
        openingCash:       _currentShift!.openingCash,
        closingCash:       _currentShift!.closingCash,
        transferAmount:    _currentShift!.transferAmount,
        note:              _currentShift!.note,
        openDenominations:  _currentShift!.openDenominations,
        closeDenominations: _currentShift!.closeDenominations,
        openInventory:      _currentShift!.openInventory,
        closeInventory:     _currentShift!.closeInventory,
        totalOrders:   _currentShift!.totalOrders + 1,
        totalRevenue:  _currentShift!.totalRevenue + addedRevenue,
        offlineRevenue: isOffline
            ? _currentShift!.offlineRevenue + addedRevenue
            : _currentShift!.offlineRevenue,
      );
    });
  }


  final ScrollController _cartScroll = ScrollController();

  void _showVoucherDetail() {
    if (_appliedVoucher == null) return;
    final v  = _appliedVoucher!;
    final cs = Theme.of(context).colorScheme;
    const blue = Color(0xFF0284C7);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) {
        final isDark  = Theme.of(context).brightness == Brightness.dark;
        final surface = isDark ? const Color(0xFF1E293B) : Colors.white;
        final txtSec  = isDark
            ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

        return Container(
          decoration: BoxDecoration(
            color: surface,
            borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 90),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Center(child: Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 36, height: 4,
              decoration: BoxDecoration(
                  color: txtSec.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2)),
            )),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: blue.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.confirmation_num_rounded,
                  color: blue, size: 32),
            ),
            const SizedBox(height: 12),
            const Text('E-Voucher đang áp dụng',
                style: TextStyle(fontSize: 16,
                    fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text(v.code,
                style: const TextStyle(fontSize: 13,
                    color: blue, fontWeight: FontWeight.w600,
                    letterSpacing: 1.2)),
            const SizedBox(height: 20),
            _vRow('Loại giảm', v.templateName, txtSec, cs),
            _vRow('Giá trị', v.displayValue, txtSec, cs),
            _vRow('Credit đã dùng',
                '${_fmt(v.creditUsed)} điểm', txtSec, cs),
            _vRow('Hết hạn', _fmtDate(v.expiredAt), txtSec, cs),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity, height: 46,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  setState(() => _appliedVoucher = null);
                },
                icon: const Icon(Icons.remove_circle_outline_rounded,
                    size: 16),
                label: const Text('Bỏ áp dụng voucher'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: cs.error,
                  side: BorderSide(color: cs.error.withOpacity(0.5)),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ]),
        );
      },
    );
  }

  Widget _vRow(String label, String value,
      Color txtSec, ColorScheme cs) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(children: [
          Text(label, style: TextStyle(fontSize: 13, color: txtSec)),
          const Spacer(),
          Text(value, style: TextStyle(fontSize: 13,
              fontWeight: FontWeight.w600, color: cs.onSurface)),
        ]),
      );

  String _fmtDate(int ms) {
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    return '${d.day.toString().padLeft(2,'0')}/'
        '${d.month.toString().padLeft(2,'0')}/${d.year}';
  }

  String? _buildWeightLabel(CartItem cartItem) {
    // Ý 2: hàng xé lẻ → in đúng "2 Miếng" / "0.25 Kg", KHÔNG quy ra kg.
    if (cartItem.looseSale) return cartItem.looseLabel;

    for (final sel in cartItem.variantSelections) {
      if (sel.isAddonGroup) continue;
      for (final entry in sel.unitWeightsMap.entries) {
        final weights = entry.value;
        if (weights.isEmpty) continue;
        // Tổng weight của tất cả đơn vị trong ingredient này
        final totalKg = weights.fold(0.0, (s, w) => s + w);
        if (totalKg <= 0) continue;
        // Format
        if (totalKg >= 1) {
          final s = totalKg.toStringAsFixed(3)
              .replaceAll(RegExp(r'0+$'), '')
              .replaceAll(RegExp(r'\.$'), '');
          return '${s}kg';
        } else {
          final g = (totalKg * 1000).round();
          return '${g}g';
        }
      }
    }
    return null;
  }

  double _manualDiscountAmount = 0;
  String _manualDiscountType   = 'amount'; // 'amount' hoặc 'percent'
  double _manualDiscountValue  = 0;

  List<PosCategoryModel> _categories   = [];
  List<PosProductModel>  _products     = [];
  PosShiftModel?         _currentShift;

  static final List<CartItem> _persistedCart = [];
  List<CartItem> get _cart => _persistedCart;

  Orientation? _lastOrientation;

  double _appDiscountAmount = 0;   // tiền giảm app (Shopee/Grab)
  double _appFinalOverride  = 0; // 0 = không override

  static double _roundToThousand(double price) {
    final remainder = price % 1000;
    return remainder >= 500
        ? price - remainder + 1000
        : price - remainder;
  }

  // ── Customer + Discount state ─────────────────────────────────
  PosCustomerInfo?      _customer;
  CustomerDiscountInfo? _activeDiscount;
  int?                  _discountItemProductId;

  bool get _canShopee => _cart.every((i) => i.product.isShopeeFood);
  bool get _canGrab   => _cart.every((i) => i.product.isGrabFood);
  double get _subTotal => _cart.fold(0.0, (s, i) => s + i.subtotal);

  List<PosProductModel> get _filteredProducts {
    if (_searchKeyword.isEmpty) return _products;
    final kw = _searchKeyword.toLowerCase().trim();
    return _products
        .where((p) => p.name.toLowerCase().contains(kw))
        .toList();
  }

  // VAT đã làm tròn theo từng món
  Map<int, double> get _vatBreakdown {
    if (_subTotal <= 0) return {};
    final totalDiscount = _discountAmount + _manualDiscountAmount + _eVoucherDiscount; // ← THÊM
    final map = <int, double>{};

    // Nhóm món theo vatPercent
    final groups = <int, List<CartItem>>{};
    for (final item in _cart) {
      final pct = item.product.vatPercent;
      if (pct <= 0) continue;
      groups.putIfAbsent(pct, () => []).add(item);
    }

    for (final entry in groups.entries) {
      final pct   = entry.key;
      final items = entry.value;
      final rate  = pct / 100.0;

      // Tổng gross của nhóm thuế này
      final groupTotal = items.fold(0.0, (s, i) => s + i.subtotal);

      // Phân bổ discount theo tỷ trọng nhóm / tổng đơn
      final groupDiscount = totalDiscount * groupTotal / _subTotal;

      // Giá sau giảm của nhóm
      final groupAfterDiscount = groupTotal - groupDiscount;

      // VAT tính ngược từ giá đã bao gồm VAT
      final vat = (groupAfterDiscount * rate / (1 + rate)).round().toDouble();

      if (vat > 0) map[pct] = vat;
    }

    final sorted = Map.fromEntries(
      map.entries.toList()..sort((a, b) => a.key.compareTo(b.key)),
    );
    return sorted;
  }

  // Tạm tính = subTotal - tổng VAT (đã làm tròn)
  // → đảm bảo subTotalExVat + totalVat = subTotal chính xác
  double get _subTotalExVat => _subTotal;

  double get _totalVat => _vatBreakdown.values.fold(0.0, (s, v) => s + v);

  double get _discountAmount {
    final opt = _activeDiscount?.selectedOption;
    if (_activeDiscount == null || opt == null) return 0;
    if (_activeDiscount!.exhausted) return 0;

    double base;
    if (opt.discountType.isItemType) {
      base = _discountItemProductId == null
          ? 0
          : _cart
          .where((c) => c.product.id == _discountItemProductId)
          .fold(0.0, (s, c) => s + c.subtotal);
    } else {
      base = _subTotal;
    }

    final raw       = opt.calculate(base);
    final remaining = _activeDiscount!.budgetRemaining;
    return raw.clamp(0, remaining);
  }

  double get _eVoucherDiscount {
    if (_appliedVoucher == null) return 0;
    final v = _appliedVoucher!;
    switch (v.voucherType) {
      case 'FIXED_AMOUNT':
        return v.voucherValue.clamp(0, _subTotal);
      case 'PERCENT':
        return (_subTotal * v.voucherValue / 100).clamp(0, _subTotal);
      case 'ITEM_DISCOUNT':
        if (v.targetProductId == null) return v.voucherValue.clamp(0, _subTotal);
        final itemTotal = _cart
            .where((c) => c.product.id == v.targetProductId)
            .fold(0.0, (s, c) => s + c.subtotal);
        return v.voucherValue.clamp(0, itemTotal);
      default: return 0;
    }
  }

  double get _grandTotal {
    if (_isAppOrder) {
      final base = (_subTotal - _discountAmount);
      if (_appDiscountAmount > 0) {
        return (base - _appDiscountAmount).clamp(0, double.infinity);
      }
      return base.clamp(0, double.infinity);
    }
    return (_subTotal - _discountAmount - _manualDiscountAmount - _eVoucherDiscount)
        .clamp(0.0, double.infinity);
  }

  static double _roundUpToThousand(double price) {
    if (price <= 0) return 0;
    final remainder = price % 1000;
    if (remainder == 0) return price;
    return price - remainder + 1000;
  }

  void _applyManualDiscount(String type, double value) {
    setState(() {
      _manualDiscountType  = type;
      _manualDiscountValue = value;  // ← value = 10 (percent)
      final base = (_subTotal + _totalVat - _discountAmount)
          .clamp(0.0, double.infinity);
      if (type == 'percent') {
        _manualDiscountAmount = (base * value / 100).clamp(0, base); // ← = 12600
      } else {
        _manualDiscountAmount = value.clamp(0, base); // ← = value nhập vào
      }
    });
  }

  void _clearManualDiscount() => setState(() {
    _manualDiscountAmount = 0;
    _manualDiscountValue  = 0;
    _manualDiscountType   = 'amount';
  });

  Future<void> _openManualDiscountSheet() async {
    final result = await showModalBottomSheet<_ManualDiscountResult>(
      context:            context,
      isScrollControlled: true,
      useSafeArea:        false,        // ✅ tự quản lý safe area
      backgroundColor:    Colors.transparent,
      builder: (sheetCtx) => AnimatedPadding(  // ✅ tự động animate khi keyboard lên/xuống
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(sheetCtx).viewInsets.bottom,
        ),
        child: _ManualDiscountSheet(
          subTotal:     (_subTotal + _totalVat - _discountAmount)
              .clamp(0.0, double.infinity),
          currentType:  _manualDiscountType,
          currentValue: _manualDiscountValue,
        ),
      ),
    );
    if (result == null || !mounted) return;
    if (result.cleared) {
      _clearManualDiscount();
    } else {
      _applyManualDiscount(result.type, result.value);
    }
  }

  /// Kênh bán hiện tại dạng string cho variant modal.
  /// null = bán tại quán → addon dùng giá tại quán.
  String? get _appPlatformOrNull {
    if (_orderSource == PosOrderSource.shopeeFood) return 'SHOPEE_FOOD';
    if (_orderSource == PosOrderSource.grabFood)   return 'GRAB_FOOD';
    return null;
  }

  bool get _isAppOrder =>
      _orderSource == PosOrderSource.shopeeFood ||
          _orderSource == PosOrderSource.grabFood;

  double get _platformRate {
    if (_orderSource == PosOrderSource.shopeeFood)
      return PrinterConfig.shopeeRate;
    if (_orderSource == PosOrderSource.grabFood)
      return PrinterConfig.grabRate;
    return 0.0;
  }

// Phí sàn = (subTotal - appDiscountAmount) × rate
  double get _platformFee {
    if (!_isAppOrder) return 0.0;
    final afterDiscount = (_subTotal - _appDiscountAmount).clamp(0.0, double.infinity);
    return (afterDiscount * _platformRate).roundToDouble();
  }

// Tiền thực nhận = (subTotal - appDiscountAmount) - platformFee
  double get _netRevenue {
    if (!_isAppOrder) return _grandTotal;
    final afterDiscount = (_subTotal - _appDiscountAmount).clamp(0.0, double.infinity);
    // Làm tròn: >= .5 lên, < .5 xuống
    return (afterDiscount * (1 - _platformRate) * 100).roundToDouble() / 100;
  }


  int get _cartCount => _cart.fold(0, (s, i) => s + i.quantity);

  double get _scaleFactor {
    final width = MediaQuery.of(context).size.width;
    return (width / 1024).clamp(0.75, 1.3);
  }

  void _clearAppDiscount() => setState(() {
    _appDiscountAmount = 0;
    _appFinalOverride  = 0;
  });

  Future<void> _openAppDiscountSheet() async {
    final result = await showAppDiscountSheet(
      context,
      subTotal:        _subTotal,
      currentDiscount: _appDiscountAmount,
    );
    if (result == null || !mounted) return;
    setState(() {
      if (result.isCleared) {
        _appDiscountAmount = 0;
        _appFinalOverride  = 0;
      } else {
        _appDiscountAmount = result.discountAmount;
        _appFinalOverride  = result.finalAmount;
      }
    });
  }

  // ═══════════════════════════════════════════════════════════════
  // Lifecycle
  // ═══════════════════════════════════════════════════════════════

  @override
  void initState() {
    super.initState();
    _loadAll();
    _initPrinter();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchCtrl.dispose();
    _cartScroll.dispose();
    if (_lastOrientation != Orientation.landscape) {
      _persistedCart.clear();
      _appDiscountAmount = 0;
      _appFinalOverride  = 0;
    }
    _lastOrientation = null;
    super.dispose();
  }

  Future<void> _loadAll() async {
    await Future.wait([_loadCategories(), _loadShift()]);
  }

  Future<void> _initPrinter() async {
    setState(() => _isConnectingPrinter = true);
    await PrinterConfig.loadStoreInfo();
    if (mounted) {
      setState(() {
        _printerConnected = false;
        _isConnectingPrinter = false;
      });
      PrinterConfig.isConnected = false;  // ← THÊM: sync với UI
    }
  }

  Future<void> _loadShift() async {
    try {
      final s = await PosService.instance.getCurrentShift();
      if (mounted) setState(() => _currentShift = s);
    } catch (_) {}
  }

  Future<void> _loadCategories() async {
    try {
      final cats = await PosService.instance.getCategories();
      if (mounted) {
        setState(() {
          _categories          = cats
            ..sort((a, b) => a.displayOrder.compareTo(b.displayOrder));
          _isLoadingCategories = false;
          if (cats.isNotEmpty) {
            _selectedCat = cats.first;
            _loadProducts(cats.first.id);
          }
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingCategories = false);
    }
  }

  Future<void> _loadProducts(int catId) async {
    setState(() => _isLoadingProducts = true);
    try {
      final list = await PosService.instance.getProducts(categoryId: catId);
      if (mounted) {
        setState(() {
          _products = list..sort((a, b) {
            final ao = a.displayOrder == 0 ? 999999 : a.displayOrder;
            final bo = b.displayOrder == 0 ? 999999 : b.displayOrder;
            final c  = ao.compareTo(bo);
            return c != 0 ? c : a.name.compareTo(b.name);
          });
        });
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isLoadingProducts = false);
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // Cart helpers
  // ═══════════════════════════════════════════════════════════════

  void _addToCart(CartItem item) {
    setState(() {
      // ── Ý 2: hàng XÉ LẺ luôn là 1 dòng độc lập ──────────────────
      // - Không gộp xé lẻ vào món nguyên túi (và ngược lại).
      // - Bán xé lẻ 2 lần → 2 dòng riêng (giá / số lượng có thể khác nhau).
      if (item.looseSale) {
        _cart.add(item);
        _scrollToCartBottom();
        return;
      }

      final idx = _cart.indexWhere((c) =>
      !c.looseSale &&                       // ← không bao giờ gộp vào dòng xé lẻ
          c.product.id == item.product.id &&
          c.selectedPrice.discountPercent == item.selectedPrice.discountPercent &&
          _selectionsEqual(c.variantSelections, item.variantSelections));
      if (idx >= 0) {
        _cart[idx] = _cart[idx].copyWith(quantity: _cart[idx].quantity + 1);
      } else {
        _cart.add(item);
      }
    });
    _scrollToCartBottom();
  }

  void _scrollToCartBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_cartScroll.hasClients) {
        _cartScroll.animateTo(_cartScroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOut);
      }
    });
  }

  void _updateQty(int idx, int delta) {
    // Ý 2: hàng xé lẻ không cho sửa số lượng — chỉ được xoá khỏi đơn.
    if (_cart[idx].looseSale) {
      _snack('Món xé lẻ không sửa được số lượng. Hãy xoá và thêm lại.');
      return;
    }
    setState(() {
      final newQty = _cart[idx].quantity + delta;
      if (newQty <= 0) _cart.removeAt(idx);
      else _cart[idx] = _cart[idx].copyWith(quantity: newQty);
    });
  }

  void _removeFromCart(int idx) => setState(() => _cart.removeAt(idx));

  bool _selectionsEqual(
      List<VariantGroupSelection> a, List<VariantGroupSelection> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i].variantId != b[i].variantId) return false;
      if (!_mapEq(a[i].selectedIngredients, b[i].selectedIngredients)) return false;
      // Định lượng override khác nhau → là 2 dòng khác nhau, không gộp.
      if (!_weightsEq(a[i].unitWeightsMap, b[i].unitWeightsMap)) return false;
    }
    return true;
  }

  bool _mapEq(Map<int, int> a, Map<int, int> b) {
    if (a.length != b.length) return false;
    for (final k in a.keys) { if (a[k] != b[k]) return false; }
    return true;
  }

  bool _weightsEq(Map<int, List<double>> a, Map<int, List<double>> b) {
    if (a.length != b.length) return false;
    for (final k in a.keys) {
      final av = a[k], bv = b[k];
      if (bv == null || av == null) return false;
      if (av.length != bv.length) return false;
      for (int i = 0; i < av.length; i++) {
        if ((av[i] - bv[i]).abs() > 0.0001) return false;
      }
    }
    return true;
  }

  // ═══════════════════════════════════════════════════════════════
  // Customer sheet
  // ═══════════════════════════════════════════════════════════════

  Future<void> _openCustomerSheet() async {
    final result = await showPosCustomerSheet(
      context, current: _customer, cartItems: _cart,
    );
    if (result != null && mounted) {
      setState(() {
        _customer              = result.customer;
        _activeDiscount        = result.discount;
        _discountItemProductId = result.discountItemProductId;
        _appliedVoucher        = result.selectedVoucher;  // ← THÊM
      });
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // Create order + auto print
  // ═══════════════════════════════════════════════════════════════

  Future<void> _openWeightSheet(int idx) async {
    // Hàng xé lẻ đã chốt định lượng lúc nhập → không cho chỉnh lại.
    if (_cart[idx].looseSale) return;
    final updated = await showPosWeightSheet(context, _cart[idx]);
    if (updated != null && mounted) {
      setState(() => _cart[idx] = updated);
    }
  }

  Future<void> _createOrder() async {
    if (_cart.isEmpty) return;
    if (_currentShift == null || !_currentShift!.isOpen) {
      _snack('Chưa mở ca. Vui lòng mở ca để bán hàng.');
      return;
    }

    if (_isAppOrder && _appOrderCode.trim().isEmpty) {
      _snack('Vui lòng nhập mã đơn hàng App.', isError: true);
      setState(() => _isCreatingOrder = false);
      return;
    }

    setState(() => _isCreatingOrder = true);
    try {
      final order = await PosService.instance.createOrder(
        orderSource:           _orderSource.apiValue,
        paymentMethod:         _paymentMethod,
        cartItems:             _cart,
        customerPhone:         _customer?.phone,
        customerName:          _customer?.name,
        customerDiscountId:    _activeDiscount?.id,
        discountItemProductId: _discountItemProductId,
        voucherCode: _appliedVoucher?.code,
        appDiscountAmount: _isAppOrder ? _appDiscountAmount : null,
        appFinalAmount:    _isAppOrder && _appFinalOverride > 0
            ? _appFinalOverride
            : null,
        manualDiscountAmount:  !_isAppOrder && _manualDiscountAmount > 0  // ← THÊM
            ? _manualDiscountAmount : null,
        appOrderCode: _isAppOrder ? _appOrderCode : null,
      );

      final customerPhone = _customer?.phone;
      final customerName  = _customer?.name;

      // Lấy snapshot cart TRƯỚC khi clear — dùng để ghép addon vào bill
      final cartSnapshot  = List<CartItem>.from(_cart);
      final vatSnapshot     = Map<int, double>.from(_vatBreakdown); // ← THÊM
      final appliedVoucherSnapshot = _appliedVoucher;
      final eVoucherDiscountSnapshot = _eVoucherDiscount;
      final appOrderCodeSnapshot = _appOrderCodeFull;

      setState(() {
        _cart.clear();
        _customer              = null;
        _activeDiscount        = null;
        _discountItemProductId = null;
        _appDiscountAmount     = 0;
        _appFinalOverride      = 0;
        _manualDiscountAmount  = 0; // ← THÊM
        _manualDiscountValue   = 0; // ← THÊM
        _manualDiscountType    = 'amount'; // ← THÊM
        _appliedVoucher = null;
        _appOrderCode = '';
      });

      _updateShiftWithNewOrder(order);

      _autoPrint(order,
        customerPhone: customerPhone,
        customerName:  customerName,
        cartSnapshot:  cartSnapshot,
        vatSnapshot: vatSnapshot,
        eVoucherCode:     appliedVoucherSnapshot?.code,
        eVoucherDiscount: eVoucherDiscountSnapshot,
        appOrderCode:     appOrderCodeSnapshot,
      );
      _showSuccessDialog(order);
    } catch (e) {
      _snack('Lỗi tạo đơn: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isCreatingOrder = false);
    }
  }

  String get _appOrderCodeFull {
    if (!_isAppOrder || _appOrderCode.isEmpty) return '';
    final prefix = _orderSource == PosOrderSource.shopeeFood ? 'SF-' : 'GF-';
    return '$prefix$_appOrderCode';
  }

  // ── Auto print ───────────────────────────────────────────────
  void _autoPrint(PosOrderModel order, {String? customerPhone, String? customerName, List<CartItem> cartSnapshot = const [], Map<int, double> vatSnapshot = const {}, String? eVoucherCode, double eVoucherDiscount = 0.0, String? appOrderCode,}) {
    if (!PrinterConfig.isConnected) return;
    if (cartSnapshot.isEmpty) return;
    final phone = (customerPhone?.trim().isNotEmpty == true) ? customerPhone : null;
    final name  = (customerName?.trim().isNotEmpty  == true) ? customerName  : null;

    final currentUserId = AuthService.instance.currentUserId;

    final isAppOrder = order.orderSource == 'SHOPEE_FOOD' ||
        order.orderSource == 'GRAB_FOOD';
    final appPlatform = order.orderSource;

    // ── Build BillItem ───────────────────────────────────────
    double totalItemDiscount = 0.0; // ← tổng giảm từ discount % món

    final billItems = cartSnapshot.map((cartItem) {
      final addons = <BillAddon>[];

      for (final sel in cartItem.variantSelections) {
        if (!sel.isAddonGroup || sel.addonItems == null) continue;
        for (final a in sel.addonItems!) {
          if (a.quantity <= 0) continue;
          addons.add(BillAddon(
            name:      a.ingredientName,
            quantity:  a.quantity,
            unitPrice: a.discountedAddonPrice,
          ));
        }
      }

      final double unitPriceToPrint;
      if (!isAppOrder) {
        // subtotal đã tính đúng: giá × định lượng × số lượng
        // chia quantity để ra đơn giá mỗi dòng bill
        unitPriceToPrint = cartItem.quantity > 0
            ? cartItem.subtotal / cartItem.quantity
            : cartItem.selectedPrice.price;
      } else if (cartItem.selectedPrice.label == 'Giá tùy chỉnh') {
        unitPriceToPrint = cartItem.selectedPrice.price;
      } else {
        final appMenu = cartItem.product.appMenus
            .where((m) => m.platform == appPlatform && m.isActive)
            .firstOrNull;
        unitPriceToPrint = (appMenu?.price ?? cartItem.product.basePrice).toDouble();
      }

      return BillItem(
        name:             cartItem.product.name,
        quantity:         cartItem.quantity,
        unitPrice:        unitPriceToPrint,
        basePricePerUnit: unitPriceToPrint,
        discountPercent:  0,
        addons:           addons,
        weightLabel:      _buildWeightLabel(cartItem),
      );
    }).toList();

    // ── Tính tổng cho bill ───────────────────────────────────
    final billSubTotal = billItems.fold<double>(0, (sum, i) => sum + i.total);

    // Phần giảm % món đã được bake vào unitPriceToPrint (subtotal/qty)
    // nên cần trừ ra khỏi discountAmount để không tính double
    double itemDiscountBaked = 0;
    if (!isAppOrder) {
      for (final cartItem in cartSnapshot) {
        final discPct = cartItem.selectedPrice.discountPercent;
        if (discPct > 0) {
          // Giá gốc trước giảm % món
          final originalUnitPrice = cartItem.product.priceOptions.first.price;
          final discountedUnitPrice = cartItem.selectedPrice.price;
          final bakedDiscount = (originalUnitPrice - discountedUnitPrice) * cartItem.quantity;
          itemDiscountBaked += bakedDiscount;
        }
      }
    }
    final billDiscountAmount = (order.discountAmount - itemDiscountBaked).clamp(0.0, double.infinity);

    final billFinalAmount = isAppOrder
        ? (billSubTotal - order.discountAmount).clamp(0, double.infinity)
        : order.finalAmount;

    final bill = BillData(
      userId: currentUserId,
      orderCode:        order.orderCode,
      printTime:        DateTime.fromMillisecondsSinceEpoch(order.createdAt),
      cashierName:      _currentShift?.staffName ?? '',
      customerPhone:    phone,
      customerName:     name,
      orderSource:      order.orderSource,
      items:            billItems,
      subTotal:         billSubTotal,
      discountAmount:   billDiscountAmount,  // ← đã bao gồm giảm % món
      vatAmount:        order.totalVat,
      vatBreakdown:     vatSnapshot,
      finalAmount:      billFinalAmount.toDouble(),
      paymentMethod:    order.paymentMethod,
      platformFee:      0,
      platformRate:     0,
      netRevenue:       0,
      eVoucherCode:     eVoucherCode,
      eVoucherDiscount: eVoucherDiscount,
      appOrderCode: appOrderCode,
      invoiceToken:     order.invoiceToken,
    );

    // ── DEBUG PRINT ──────────────────────────────────────────────
    debugPrint('========== AUTO PRINT DEBUG ==========');
    debugPrint('orderCode    : ${bill.orderCode}');
    debugPrint('orderSource  : ${bill.orderSource}');
    debugPrint('subTotal     : ${bill.subTotal}');
    debugPrint('discountAmt  : ${bill.discountAmount}');
    debugPrint('vatAmount    : ${bill.vatAmount}');
    debugPrint('vatBreakdown : ${bill.vatBreakdown}');
    debugPrint('finalAmount  : ${bill.finalAmount}');
    debugPrint('eVoucher     : ${bill.eVoucherCode} / -${bill.eVoucherDiscount}');
    debugPrint('---------- ITEMS ----------');
    for (final it in bill.items) {
      debugPrint(
        '  [${it.name}]'
            '  qty=${it.quantity}'
            '  unitPrice=${it.unitPrice}'          // giá gốc in bill
            '  basePricePerUnit=${it.basePricePerUnit}'
            '  discountPercent=${it.discountPercent}%'
            '  addonPerUnit=${it.addons.fold(0.0, (s, a) => s + a.unitPrice * a.quantity)}'
            '  total=${it.total}',                 // unitPrice * qty + addons
      );
      for (final a in it.addons) {
        debugPrint('      addon: ${a.name} x${a.quantity} @ ${a.unitPrice}');
      }
    }
    debugPrint('totalItemDiscount (% món): $totalItemDiscount');debugPrint('---------- DISCOUNT BREAKDOWN ----------');
    debugPrint('order.discountAmount (server) : ${order.discountAmount}');
    debugPrint('itemDiscountBaked (% mon bake): $itemDiscountBaked');
    debugPrint('billDiscountAmount (tong bill): $billDiscountAmount');
    debugPrint('---------- TOTALS ----------');
    debugPrint('billSubTotal  : $billSubTotal');
    debugPrint('billFinal     : $billFinalAmount');
    debugPrint('order.finalAmount (server)    : ${order.finalAmount}');
    debugPrint('check (subTotal - discount)   : ${billSubTotal - billDiscountAmount}');
    debugPrint('Invoice token   : ${bill.invoiceToken}');
    // ── END DEBUG ────────────────────────────────────────────────

    PosPrinterService.instance.print(bill).then((result) {
      if (!result.isSuccess && mounted) {
        _snack('Lỗi in bill: ${result.errorMessage}', isError: true);
        setState(() => _printerConnected = false);
      }
    });
  }

  // ═══════════════════════════════════════════════════════════════
  // Snack / dialog
  // ═══════════════════════════════════════════════════════════════

  void _snack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content:         Text(msg),
      backgroundColor: isError ? Theme.of(context).colorScheme.error : null,
      behavior:        SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  void _showSuccessDialog(PosOrderModel order) {
    final cs = Theme.of(context).colorScheme;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        title: Row(children: [
          Icon(Icons.check_circle_rounded, color: cs.primary, size: 32),
          const SizedBox(width: 12),
          Text('Tạo đơn thành công',
              style: TextStyle(color: cs.primary,
                  fontWeight: FontWeight.bold)),
        ]),
        content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Mã đơn: ${order.orderCode}',
                  style: const TextStyle(fontWeight: FontWeight.bold,
                      fontSize: 18)),
              const SizedBox(height: 8),
              Text('Tổng tiền: ${_fmt(order.finalAmount)}đ',
                  style: const TextStyle(fontSize: 16)),
              if (_printerConnected)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Row(children: [
                    Icon(Icons.print_rounded, size: 14,
                        color: cs.primary.withOpacity(0.7)),
                    const SizedBox(width: 5),
                    Text('Đang in bill...',
                        style: TextStyle(fontSize: 13,
                            color: cs.primary.withOpacity(0.7))),
                  ]),
                ),
            ]),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Đóng', style: TextStyle(color: cs.primary)),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // Navigation
  // ═══════════════════════════════════════════════════════════════

  void _onTapProduct(PosProductModel p) {
    if (_currentShift == null || !_currentShift!.isOpen) {
      _snack('Chưa mở ca. Vui lòng mở ca để bán hàng.');
      return;
    }

    // Kiểm tra variant có nguyên liệu không
    final hasVariants = p.variants.isNotEmpty;
    final allVariantsEmpty = p.variants
        .where((v) => !v.isAddonGroup)
        .every((v) => v.ingredients.isEmpty);

    if (hasVariants && allVariantsEmpty) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(children: [
            Icon(Icons.warning_amber_rounded,
                color: Colors.orange.shade700, size: 24),
            const SizedBox(width: 8),
            const Text('Chưa có nguyên liệu'),
          ]),
          content: Text(
            '"${p.name}" chưa được thêm nguyên liệu.\nVui lòng vào Quản lý Menu để cập nhật.',
            style: const TextStyle(fontSize: 14, height: 1.5),
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(ctx),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.orange.shade700,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Đã hiểu'),
            ),
          ],
        ),
      );
      return;
    }

    _showQuickAdd(p);
  }

  // ── Ý 2: Bán xé lẻ (long-press sản phẩm có nguyên liệu bật xé lẻ) ──
  Future<void> _onLooseSale(PosProductModel p) async {
    if (_currentShift == null || !_currentShift!.isOpen) {
      _snack('Chưa mở ca. Vui lòng mở ca để bán hàng.');
      return;
    }
    final loose = p.looseIngredient;
    if (loose == null) return;

    final smallUnit = p.looseSmallUnit;
    final allowDecimal =
        smallUnit.toLowerCase() == 'kg' || smallUnit.toLowerCase() == 'lít';

    final r = await PosLooseSaleSheet.show(
      context,
      productName: p.name,
      mainUnit: p.looseMainUnit,
      smallUnit: smallUnit,
      ratio: p.looseRatio,
      allowDecimal: allowDecimal,
    );
    if (r == null) return;

    // Gắn số lượng xé lẻ vào unitWeights của đúng nguyên liệu → kho trừ đúng
    // (miếng nguyên hoặc kg số lẻ). quantity giữ = 1, giá = giá tay.
    final sels = buildQuickAddSelections(p).map((sel) {
      if (sel.isAddonGroup ||
          !sel.selectedIngredients.containsKey(loose.ingredientId)) {
        return sel;
      }
      final newMap = Map<int, List<double>>.from(sel.unitWeightsMap);
      newMap[loose.ingredientId] = [r.amount];
      return sel.copyWith(unitWeightsMap: newMap);
    }).toList();

    _addToCart(CartItem(
      product: p,
      selectedPrice:
      PriceOption(discountPercent: 0, price: r.totalPrice, label: 'Xé lẻ'),
      variantSelections: sels,
      quantity: 1,
      overriddenUnitPrice: r.totalPrice,
      looseSale: true,
      looseQuantity: r.amount,
      looseUnit: smallUnit,
      looseMainUnit: p.looseMainUnit,
      looseIngredientId: loose.ingredientId,
    ));
  }

  List<VariantGroupSelection>? _savedSelections;
  String? _savedNote;

  void _showQuickAdd(PosProductModel p, {PriceOption? fixedPrice}) {
    _savedSelections = null;
    _savedNote       = null;

    PriceOption effectivePrice;
    if (_orderSource == PosOrderSource.shopeeFood ||
        _orderSource == PosOrderSource.grabFood) {
      final platform = _orderSource == PosOrderSource.shopeeFood
          ? 'SHOPEE_FOOD' : 'GRAB_FOOD';
      final appMenu  = p.appMenus.firstWhere(
            (m) => m.platform == platform && m.isActive,
        orElse: () => AppMenuModel(id: 0, platform: platform,
            price: p.basePrice, isActive: false),
      );
      effectivePrice = appMenu.isActive
          ? PriceOption(discountPercent: 0, price: appMenu.price,
          label: _orderSource == PosOrderSource.shopeeFood
              ? 'Giá Shopee' : 'Giá Grab')
          : fixedPrice ?? p.priceOptions.first;
    } else {
      effectivePrice = fixedPrice ?? PriceOption(
        discountPercent: p.priceOptions.first.discountPercent,
        price: p.priceOptions.first.price,   // ← không làm tròn
        label: p.priceOptions.first.label,
      );
    }

    showModalBottomSheet<QuickAddResult>(
      context: context, isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => Padding(          // ← dùng sheetCtx
        padding: const EdgeInsets.only(bottom: 40),
        child: PosQuickAddSheet(
          product:         p,
          initialPrice:    effectivePrice,
          fixedPrice:      effectivePrice,
          savedSelections: _savedSelections,
          savedNote:       _savedNote,
          isAppOrder:      _isAppOrder,
          onOpenVariantModal: (price) {
            // Mở variant modal TRÊN TOP của sheet hiện tại
            showModalBottomSheet(
              context:            sheetCtx,    // ← dùng sheetCtx, không phải context
              isScrollControlled: true,
              backgroundColor:    Colors.transparent,
              builder: (_) => Padding(
                padding: const EdgeInsets.only(bottom: 40),
                child: PosVariantModal(
                  platform:      _appPlatformOrNull,
                  product:       p,
                  selectedPrice: price,
                  onConfirm: (selections, note) {
                    _savedSelections = selections;
                    _savedNote       = note;
                    Navigator.pop(sheetCtx);  // ← đóng variant modal
                    // QuickAdd sheet vẫn còn, setState để update UI
                  },
                ),
              ),
            );
          },
          onQuickAdd: (price) {
            Navigator.pop(context);
            _addToCart(CartItem(
              product:           p,
              selectedPrice:     price,
              variantSelections: _savedSelections ?? buildQuickAddSelections(p),
              quantity:          1,
              note:              _savedNote,
            ));
          },
        ),
      ),
    ).then((result) {
      if (result != null) {
        _addToCart(CartItem(
          product:           p,
          selectedPrice:     result.price,
          variantSelections: result.selections,
          quantity:          1,
          note:              result.note,
        ));
      }
    });
  }

  void _showVariantModal(PosProductModel p, PriceOption price) {
    showModalBottomSheet(
      context: context, isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Padding(
        padding: const EdgeInsets.only(bottom: 40),
        child: PosVariantModal(
          platform:      _appPlatformOrNull,
          product:       p,
          selectedPrice: price,
          onConfirm: (selections, note) {
            _savedSelections = selections;
            _savedNote       = note;
            Navigator.pop(context);
            _showQuickAddWithSelections(p, price, selections, note);
          },
        ),
      ),
    );
  }

  void _showQuickAddWithSelections(PosProductModel p, PriceOption price,
      List<VariantGroupSelection> selections, String? note) {
    showModalBottomSheet<QuickAddResult>(
      context: context, isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Padding(
        padding: const EdgeInsets.only(bottom: 40),
        child: PosQuickAddSheet(
          product:            p,
          initialPrice:       price,
          fixedPrice:         price,
          savedSelections:    selections,
          savedNote:          note,
          isAppOrder:         _isAppOrder,   // ← THÊM
          onOpenVariantModal: (p2) => _showVariantModal(p, p2),
          onQuickAdd: (price2) {
            Navigator.pop(context);
            _addToCart(CartItem(
              product:           p,
              selectedPrice:     price2,
              variantSelections: selections,
              quantity:          1,
              note:              note,
            ));
          },
        ),
      ),
    ).then((result) {
      if (result != null) {
        _addToCart(CartItem(
          product:           p,
          selectedPrice:     result.price,
          variantSelections: result.selections,
          quantity:          1,
          note:              result.note,
        ));
      }
    });
  }

  void _goToOpenShift() {
    showPosShiftModal(context, currentShift: null,
        onShiftChanged: (s) {
          if (mounted) setState(() => _currentShift = s);
        });
  }

  Future<void> _goToCloseShift() async {
    await _loadShift();

    showPosShiftModal(context, currentShift: _currentShift,
        onShiftChanged: (s) {
          if (mounted) {
            setState(() {
              _currentShift = s;
              if (s == null) {
                _cart.clear();
                _appDiscountAmount = 0;  // ← THÊM
                _appFinalOverride  = 0;  // ← THÊM
              }
            });
          }
        });
  }

  void _goToImportStock() {
    Navigator.push(context,
        MaterialPageRoute(builder: (_) => const PosImportStockScreen()));
  }

  String _fmt(double v) => NumberFormat('#,###', 'vi_VN').format(v);

  // ═══════════════════════════════════════════════════════════════
  // Customer button widget
  // ═══════════════════════════════════════════════════════════════

  Widget _buildCustomerBtn(double scale) {
    final cs   = Theme.of(context).colorScheme;
    const teal = Color(0xFF0D9488);

    if (_customer == null) {
      return OutlinedButton.icon(
        icon: Icon(Icons.person_add_outlined, size: 14 * scale,
            color: _cart.isEmpty
                ? cs.onSurface.withOpacity(0.3) : teal),
        label: Text('Khách',
            style: TextStyle(
                fontSize: 11 * scale,
                color: _cart.isEmpty
                    ? cs.onSurface.withOpacity(0.3) : teal,
                fontWeight: FontWeight.w600)),
        style: OutlinedButton.styleFrom(
          side: BorderSide(
              color: _cart.isEmpty
                  ? cs.onSurface.withOpacity(0.15)
                  : teal.withOpacity(0.5)),
          padding: EdgeInsets.symmetric(
              horizontal: 10 * scale, vertical: 7 * scale),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8 * scale)),
        ),
        onPressed: _cart.isEmpty ? null : _openCustomerSheet,
      );
    }

    return Container(
      height: 34 * scale,
      decoration: BoxDecoration(
          color: teal,
          borderRadius: BorderRadius.circular(8 * scale)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        GestureDetector(
          onTap: _openCustomerSheet,
          child: Padding(
            padding: EdgeInsets.symmetric(
                horizontal: 10 * scale, vertical: 6 * scale),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.person_rounded, size: 13 * scale,
                  color: Colors.white),
              SizedBox(width: 5 * scale),
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: 80 * scale),
                child: Text(_customer!.name,
                    style: TextStyle(fontSize: 11 * scale,
                        color: Colors.white,
                        fontWeight: FontWeight.w700),
                    overflow: TextOverflow.ellipsis),
              ),
              if (_activeDiscount != null &&
                  _activeDiscount!.selectedOption != null) ...[
                SizedBox(width: 4 * scale),
                Icon(Icons.local_offer_rounded, size: 10 * scale,
                    color: Colors.white.withOpacity(0.85)),
              ],
            ]),
          ),
        ),
        Container(width: 1, height: 20 * scale,
            color: Colors.white.withOpacity(0.3)),
        GestureDetector(
          onTap: () => setState(() {
            _customer              = null;
            _activeDiscount        = null;
            _discountItemProductId = null;
            _appliedVoucher        = null;  // ← THÊM
          }),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 8 * scale),
            child: Icon(Icons.close_rounded, size: 13 * scale,
                color: Colors.white),
          ),
        ),
      ]),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // Printer status widget
  // ═══════════════════════════════════════════════════════════════

  Widget _buildPrinterStatus(double scale) {
    if (_isConnectingPrinter) {
      return Container(
        padding: EdgeInsets.symmetric(
            horizontal: 10 * scale, vertical: 7 * scale),
        decoration: BoxDecoration(
          color: Colors.orange.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8 * scale),
          border: Border.all(color: Colors.orange.withOpacity(0.3)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          SizedBox(
              width: 12 * scale,
              height: 12 * scale,
              child: CircularProgressIndicator(
                  strokeWidth: 1.5, color: Colors.orange)),
          SizedBox(width: 6 * scale),
          Text('Máy in...',
              style: TextStyle(
                  fontSize: 11 * scale,
                  color: Colors.orange,
                  fontWeight: FontWeight.w600)),
        ]),
      );
    }

    final color = _printerConnected ? Colors.green : Colors.red;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: () async {
            final changed = await showPrinterSettingsDialog(context);
            if (changed && mounted) {
              setState(() => _printerConnected = PrinterConfig.isConnected);
            }
          },
          child: Container(
            padding: EdgeInsets.symmetric(
                horizontal: 10 * scale, vertical: 7 * scale),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8 * scale),
              border: Border.all(color: color.withOpacity(0.35)),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(
                _printerConnected
                    ? Icons.print_rounded
                    : Icons.print_disabled_rounded,
                size: 14 * scale,
                color: color,
              ),
              SizedBox(width: 5 * scale),
              Text(
                _printerConnected ? 'Máy in ✓' : 'Cài máy in',
                style: TextStyle(
                    fontSize: 11 * scale,
                    color: color,
                    fontWeight: FontWeight.w600),
              ),
            ]),
          ),
        ),
        // Nút ngắt kết nối khi đang connected
        if (_printerConnected) ...[
          SizedBox(width: 4 * scale),
          GestureDetector(
            onTap: () {
              PrinterConfig.disconnect();
              setState(() => _printerConnected = false);
              _snack('Đã ngắt kết nối máy in');
            },
            child: Container(
              padding: EdgeInsets.symmetric(
                  horizontal: 8 * scale, vertical: 7 * scale),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8 * scale),
                border: Border.all(color: Colors.red.withOpacity(0.35)),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.link_off_rounded,
                    size: 14 * scale, color: Colors.red),
                SizedBox(width: 4 * scale),
                Text('Ngắt',
                    style: TextStyle(
                        fontSize: 11 * scale,
                        color: Colors.red,
                        fontWeight: FontWeight.w600)),
              ]),
            ),
          ),
        ],
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // Build
  // ═══════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet    = screenWidth > 800;
    final cs          = Theme.of(context).colorScheme;
    final scale       = _scaleFactor;

    final currentOrientation = MediaQuery.of(context).orientation;
    if (currentOrientation == Orientation.landscape) {
      _lastOrientation = currentOrientation;
    }

    return Scaffold(
      body: Padding(
        padding: EdgeInsets.fromLTRB(
            4 * scale, 18 * scale, 4 * scale, 10 * scale),
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                flex: isTablet ? 12 : 10,
                child: Column(children: [
                  _buildTopBar(cs, isTablet, scale),
                  _buildCategoryRow(cs, scale),
                  _buildSearchBar(cs, scale),
                  Expanded(child: _buildProductGrid(isTablet, cs, scale)),
                ]),
              ),
              if (isTablet) SizedBox(width: 8 * scale),
              Expanded(
                  flex: isTablet ? 5 : 4,
                  child: _buildCart(cs, scale)),
            ]),
      ),
    );
  }

  // ── Top Bar ───────────────────────────────────────────────────
  Widget _buildTopBar(ColorScheme cs, bool isTablet, double scale) {
    final isOpen = _currentShift?.isOpen == true;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [cs.surface,
            cs.surfaceContainerHighest.withOpacity(0.6)],
          begin: Alignment.topCenter,
          end:   Alignment.bottomCenter,
        ),
        boxShadow: [BoxShadow(color: cs.shadow.withOpacity(0.08),
            blurRadius: 12 * scale,
            offset: Offset(0, 4 * scale))],
      ),
      padding: EdgeInsets.fromLTRB(
          12 * scale, 8 * scale, 12 * scale, 8 * scale),
      child: Row(children: [
        Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Icon(isOpen
                    ? Icons.storefront_rounded
                    : Icons.storefront_outlined,
                    color: isOpen ? Colors.green : cs.primary,
                    size: 24 * scale),
                SizedBox(width: 12 * scale),
                Flexible(child: Text(
                  isOpen
                      ? _currentShift!.staffName
                      : (PrinterConfig.storeProfile?.name.isNotEmpty == true
                      ? PrinterConfig.storeProfile!.name
                      : 'Original Taste POS'),
                  style: TextStyle(fontSize: 18 * scale,
                      fontWeight: FontWeight.bold,
                      color: isOpen ? Colors.green : cs.onSurface),
                  overflow: TextOverflow.ellipsis,
                )),
              ]),
              SizedBox(height: 4 * scale),
              _ClockWidget(cs: cs, scale: scale),
            ])),

        _buildPrinterStatus(scale),
        SizedBox(width: 8 * scale),

        _buildCustomerBtn(scale),
        SizedBox(width: 8 * scale),

        if (isOpen) ...[
          FilledButton.icon(
            icon:  Icon(Icons.inventory_2_outlined, size: 16 * scale),
            label: Text('Nhập kho',
                style: TextStyle(fontSize: 12 * scale)),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.blueAccent,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(
                  horizontal: 12 * scale, vertical: 8 * scale),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8 * scale)),
            ),
            onPressed: _goToImportStock,
          ),
          SizedBox(width: 12 * scale),
          FilledButton.icon(
            icon:  Icon(Icons.power_settings_new, size: 16 * scale),
            label: Text('Đóng ca',
                style: TextStyle(fontSize: 12 * scale)),
            style: FilledButton.styleFrom(
              backgroundColor: cs.error,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(
                  horizontal: 12 * scale, vertical: 8 * scale),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8 * scale)),
            ),
            onPressed: _goToCloseShift,
          ),
        ] else ...[
          FilledButton.icon(
            icon:  Icon(Icons.play_arrow_rounded, size: 16 * scale),
            label: Text('Mở ca',
                style: TextStyle(fontSize: 12 * scale)),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(
                  horizontal: 12 * scale, vertical: 8 * scale),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8 * scale)),
            ),
            onPressed: _goToOpenShift,
          ),
        ],
      ]),
    );
  }

  // ── Category row ─────────────────────────────────────────────
  Widget _buildCategoryRow(ColorScheme cs, double scale) {
    if (_isLoadingCategories) {
      return Container(
          height: 120 * scale, color: cs.surface,
          child: const Center(child: CircularProgressIndicator()));
    }
    return Container(
      height: 120 * scale, color: cs.surface,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(
            vertical: 8 * scale, horizontal: 4 * scale),
        itemCount: _categories.length,
        itemBuilder: (context, index) {
          final cat      = _categories[index];
          final isActive = _selectedCat?.id == cat.id;
          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedCat = cat;
                _searchKeyword = '';          // ← thêm
                _searchCtrl.clear();          // ← thêm
              });
              _loadProducts(cat.id);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin:   EdgeInsets.symmetric(horizontal: 4 * scale),
              width:    90 * scale,
              decoration: BoxDecoration(
                color: isActive
                    ? cs.primary.withOpacity(0.1)
                    : cs.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(20 * scale),
                border: Border.all(
                  color: isActive
                      ? cs.primary : cs.outline.withOpacity(0.3),
                  width: isActive ? 2.5 * scale : 1 * scale,
                ),
                boxShadow: isActive ? [BoxShadow(
                    color:       cs.primary.withOpacity(0.25),
                    blurRadius:  12 * scale,
                    spreadRadius: 2 * scale)] : null,
              ),
              child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12 * scale),
                      child: NetworkImageViewer(
                        imageUrl:    cat.imageUrl,
                        height:      30 * scale,
                        width:       40 * scale,
                        fit:         BoxFit.cover,
                        placeholder: Container(
                            color: cs.surfaceContainerHighest,
                            child: Icon(Icons.category_rounded,
                                size:  28 * scale,
                                color: cs.primary.withOpacity(0.4))),
                      ),
                    ),
                    SizedBox(height: 4 * scale),
                    Text(cat.name,
                        style: TextStyle(
                            fontSize:   12 * scale,
                            fontWeight: isActive
                                ? FontWeight.bold : FontWeight.w600,
                            color: isActive ? cs.primary : cs.onSurface),
                        textAlign: TextAlign.center,
                        maxLines:  2,
                        overflow:  TextOverflow.ellipsis),
                  ]),
            ),
          );
        },
      ),
    );
  }

  // ── Product grid ─────────────────────────────────────────────
  Widget _buildProductGrid(bool isTablet, ColorScheme cs, double scale) {
    if (_isLoadingProducts) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_filteredProducts.isEmpty) {
      return Center(child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
                _searchKeyword.isNotEmpty
                    ? Icons.search_off_rounded
                    : Icons.fastfood_outlined,
                size: 60 * scale,
                color: cs.onSurface.withOpacity(0.3)),
            SizedBox(height: 16 * scale),
            Text(
                _searchKeyword.isNotEmpty
                    ? 'Không tìm thấy "$_searchKeyword"'
                    : 'Chưa có sản phẩm trong danh mục này',
                style: TextStyle(fontSize: 18 * scale,
                    color: cs.onSurface.withOpacity(0.6))),
          ]));
    }

    return LayoutBuilder(builder: (context, constraints) {
      final sw         = MediaQuery.of(context).size.width;
      final crossCount = sw < 800 ? 2 : sw < 1000 ? 4 : 5;
      final spacing    = sw < 1000 ? 12.0 * scale : 16.0 * scale;

      return GridView.builder(
        padding: EdgeInsets.fromLTRB(
            spacing, spacing, spacing, spacing + 40 * scale),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount:   crossCount,
          mainAxisSpacing:  spacing,
          crossAxisSpacing: spacing,
          childAspectRatio: 0.85, // ảnh vuông hơn vì full card
        ),
        itemCount: _filteredProducts.length,
        itemBuilder: (context, index) {
          final p = _filteredProducts[index];

          // Giá hiển thị
          String displayPrice;
          if (_orderSource == PosOrderSource.shopeeFood ||
              _orderSource == PosOrderSource.grabFood) {
            final platform = _orderSource == PosOrderSource.shopeeFood
                ? 'SHOPEE_FOOD' : 'GRAB_FOOD';
            final appMenu  = p.appMenus.firstWhere(
                  (m) => m.platform == platform && m.isActive,
              orElse: () => AppMenuModel(id: 0, platform: platform,
                  price: p.basePrice, isActive: false),
            );
            displayPrice = _fmt(appMenu.isActive ? appMenu.price : p.basePrice);
          } else {
            displayPrice = _fmt(p.basePrice);
          }

          final cartQty = _cart
              .where((c) => c.product.id == p.id)
              .fold(0, (s, c) => s + c.quantity);

          final enabled = _orderSource == PosOrderSource.takeAway ||
              _orderSource == PosOrderSource.dineIn ||
              (_orderSource == PosOrderSource.shopeeFood && p.isShopeeFood) ||
              (_orderSource == PosOrderSource.grabFood  && p.isGrabFood);

          // Màu text thích nghi dark/light
          final isDark = Theme.of(context).brightness == Brightness.dark;

          return ClipRRect(
            borderRadius: BorderRadius.circular(14 * scale),
            child: AnimatedOpacity(
              opacity: enabled ? 1.0 : 0.55,
              duration: const Duration(milliseconds: 200),
              child: GestureDetector(
                onTap: enabled ? () => _onTapProduct(p) : null,
                onLongPress: (enabled && p.canSellLoose) ? () => _onLooseSale(p) : null,
                child: Stack(fit: StackFit.expand, children: [

                  // ── Ảnh full card ──────────────────────────────
                  NetworkImageViewer(
                    imageUrl: p.imageUrl,
                    width:    double.infinity,
                    height:   double.infinity,
                    fit:      BoxFit.cover,
                    placeholder: Container(
                      color: cs.surfaceContainerHighest,
                      child: Icon(Icons.fastfood_outlined,
                          size: 40 * scale,
                          color: cs.onSurface.withOpacity(0.3)),
                    ),
                  ),

                  // ── Gradient overlay (đậm hơn ở dưới) ─────────
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end:   Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.transparent,
                            Colors.black.withOpacity(isDark ? 0.5 : 0.45),
                            Colors.black.withOpacity(isDark ? 0.85 : 0.75),
                          ],
                          stops: const [0.0, 0.35, 0.65, 1.0],
                        ),
                      ),
                    ),
                  ),

                  // ── Tên + giá nằm dưới cùng ────────────────────
                  Positioned(
                    left:   7 * scale,
                    right:  7 * scale,
                    bottom: 7 * scale,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          p.name,
                          style: TextStyle(
                            fontSize:   sw < 1000
                                ? 9 * scale : 11 * scale,
                            fontWeight: FontWeight.w700,
                            color:      Colors.white,
                            height:     1.2,
                            shadows:    const [Shadow(
                              color:      Colors.black54,
                              blurRadius: 6,
                              offset:     Offset(0, 1),
                            )],
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: 2 * scale),
                        Text(
                          displayPrice,
                          style: TextStyle(
                            fontSize:   sw < 1000
                                ? 9 * scale : 11 * scale,
                            fontWeight: FontWeight.w800,
                            color:      Colors.white,
                            shadows:    const [Shadow(
                              color:      Colors.black54,
                              blurRadius: 6,
                              offset:     Offset(0, 1),
                            )],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // ── Cart badge ─────────────────────────────────
                  Positioned(
                    right: 7 * scale, top: 7 * scale,
                    child: _CartBadge(
                      cart:      _cart,
                      productId: p.id,
                      scale:     scale,
                      cs:        cs,
                    ),
                  ),

                  // ── Disabled overlay ───────────────────────────
                  if (!enabled)
                    Positioned.fill(
                      child: Container(
                        color: Colors.black.withOpacity(0.45),
                        child: Center(
                          child: Text(
                            _orderSource == PosOrderSource.shopeeFood
                                ? 'Không bán\nShopee'
                                : 'Không bán\nGrab',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color:      Colors.white,
                              fontSize:   11 * scale,
                              fontWeight: FontWeight.bold,
                              height:     1.4,
                            ),
                          ),
                        ),
                      ),
                    ),
                ]),
              ),
            ),
          );
        },
      );
    });
  }

  Widget _buildSearchBar(ColorScheme cs, double scale) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          8 * scale, 4 * scale, 8 * scale, 6 * scale),
      child: TextField(
        controller: _searchCtrl,
        style: TextStyle(fontSize: 14 * scale),
        decoration: InputDecoration(
          hintText: _selectedCat != null
              ? 'Tìm trong "${_selectedCat!.name}"...'
              : 'Tìm sản phẩm...',
          hintStyle: TextStyle(
              fontSize: 13 * scale,
              color: cs.onSurface.withOpacity(0.45)),
          prefixIcon: Icon(Icons.search_rounded,
              size: 20 * scale,
              color: cs.onSurface.withOpacity(0.5)),
          suffixIcon: _searchKeyword.isNotEmpty
              ? GestureDetector(
            onTap: () {
              _searchCtrl.clear();
              setState(() => _searchKeyword = '');
            },
            child: Icon(Icons.close_rounded,
                size: 18 * scale,
                color: cs.onSurface.withOpacity(0.4)),
          )
              : null,
          isDense: true,
          contentPadding: EdgeInsets.symmetric(
              vertical: 10 * scale, horizontal: 12 * scale),
          filled: true,
          fillColor: cs.surfaceContainerHighest.withOpacity(0.6),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10 * scale),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10 * scale),
            borderSide: BorderSide(
                color: cs.primary.withOpacity(0.5), width: 1.5),
          ),
        ),
        onChanged: (value) {
          _searchDebounce?.cancel();
          _searchDebounce = Timer(
            const Duration(milliseconds: 600),
                () {
              if (mounted) setState(() => _searchKeyword = value);
            },
          );
        },
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // CART - SCROLL TỰ DO (Không header "Giỏ hàng (n)")
  // ═══════════════════════════════════════════════════════════════
  Widget _buildCart(ColorScheme cs, double scale) {
    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        boxShadow: [
          BoxShadow(
            color: cs.shadow.withOpacity(0.08),
            blurRadius: 16 * scale,
            offset: Offset(-12 * scale, 0),
          ),
        ],
      ),
      child: Column(
        children: [
          // Danh sách món + Tóm tắt cùng scroll
          Expanded(
            child: SingleChildScrollView(
              controller: _cartScroll,
              padding: EdgeInsets.fromLTRB(8 * scale, 0, 8 * scale, 90 * scale),
              child: Column(
                children: [
                  // Danh sách các món trong giỏ
                  if (_cart.isEmpty)
                    Padding(
                      padding: EdgeInsets.only(top: 240 * scale),
                      child: Column(
                        children: [
                          Icon(Icons.shopping_cart_outlined,
                              size: 70 * scale,
                              color: cs.onSurface.withOpacity(0.3)),
                          SizedBox(height: 16 * scale),
                          Text('Giỏ hàng trống',
                              style: TextStyle(
                                  fontSize: 18 * scale,
                                  color: cs.onSurface.withOpacity(0.6))),
                        ],
                      ),
                    )
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _cart.length,
                      itemBuilder: (_, i) => _CartItemTile(
                        item: _cart[i],
                        formatMoney: _fmt,
                        onQtyChange: (d) => _updateQty(i, d),
                        onRemove: () => _removeFromCart(i),
                        onWeightTap: () => _openWeightSheet(i),
                        scale: scale,
                        isDiscounted: _activeDiscount?.selectedOption != null &&
                            _activeDiscount!.selectedOption!.discountType.isItemType &&
                            _discountItemProductId == _cart[i].product.id,
                        isAppOrder: _isAppOrder,
                        onPriceTap: _isAppOrder
                            ? () async {
                          final result = await showAppItemPriceSheet(
                              context, cartItem: _cart[i]);
                          if (result != null && mounted) {
                            setState(() {
                              _cart[i] = _cart[i].copyWith(
                                selectedPrice: PriceOption(
                                  discountPercent: _cart[i].selectedPrice.discountPercent,
                                  price: result.newPrice,
                                  label: 'Giá tùy chỉnh',
                                ),
                              );
                            });
                          }
                        }
                            : null,
                      ),
                    ),

                  const SizedBox(height: 24),
                  if (_appliedVoucher != null)
                    GestureDetector(
                      onTap: _showVoucherDetail,
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0284C7).withOpacity(0.06),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: const Color(0xFF0284C7).withOpacity(0.3)),
                        ),
                        child: Row(children: [
                          const Icon(Icons.confirmation_num_rounded,
                              color: Color(0xFF0284C7), size: 18),
                          const SizedBox(width: 10),
                          Expanded(child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Đã áp dụng E-Voucher',
                                    style: TextStyle(fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF0284C7))),
                                Text(_appliedVoucher!.displayValue,
                                    style: TextStyle(fontSize: 11,
                                        color: Colors.grey[600])),
                              ])),
                          const Icon(Icons.chevron_right_rounded,
                              color: Color(0xFF0284C7), size: 18),
                          GestureDetector(
                            onTap: () => setState(() => _appliedVoucher = null),
                            child: const Padding(
                              padding: EdgeInsets.only(left: 8),
                              child: Icon(Icons.close_rounded,
                                  color: Color(0xFF0284C7), size: 16),
                            ),
                          ),
                        ]),
                      ),
                    ),

                  // Phần tóm tắt (nằm dưới danh sách món)
                  _CartSummary(
                    eVoucherDiscount: _eVoucherDiscount,
                    eVoucherLabel:    _appliedVoucher?.displayValue,
                    subTotal:        _subTotal,
                    subTotalExVat:  _subTotalExVat,
                    vatBreakdown:    _vatBreakdown,
                    grandTotal:      _grandTotal,
                    discountAmount:  _discountAmount,
                    discountLabel:   _activeDiscount?.programName,
                    orderSource:     _orderSource,
                    canShopee:       _canShopee,
                    canGrab:         _canGrab,
                    paymentMethod:   _paymentMethod,
                    isCreating:      _isCreatingOrder,
                    cartEmpty:       _cart.isEmpty,
                    formatMoney:     _fmt,
                    platformFee:     _platformFee,
                    netRevenue:      _netRevenue,
                    platformRate:    _platformRate,
                    manualDiscountAmount: _manualDiscountAmount, // ← THÊM
                    onManualDiscountTap:  _openManualDiscountSheet, // ← THÊM
                    appOrderCode:           _appOrderCode,           // ← THÊM
                    onAppOrderCodeChanged:  (v) => setState(() => _appOrderCode = v), // ← THÊM
                    onSourceChanged: (s) => setState(() {
                      _orderSource = s;
                      _clearAppDiscount();
                    }),
                    onPaymentChanged: (p) => setState(() => _paymentMethod = p),
                    onCreateOrder:    _createOrder,
                    onClearCart: () {
                      setState(() => _cart.clear());
                      _snack('Đã xóa giỏ hàng');
                    },
                    cartItems:           _cart,
                    onRemoveUnsupported: (platform) {
                      setState(() {
                        if (platform == null) return;
                        _cart.removeWhere((item) {
                          final menu = item.product.appMenus.firstWhere(
                                (m) => m.platform == platform && m.isActive,
                            orElse: () => AppMenuModel(
                                id: 0, platform: platform,
                                price: 0, isActive: false),
                          );
                          return !menu.isActive;
                        });
                      });
                    },
                    onUpdatePrices: (platform) {
                      setState(() {
                        for (int i = 0; i < _cart.length; i++) {
                          final item = _cart[i];
                          final double newPrice;
                          final String newLabel;
                          if (platform == null) {
                            newPrice = item.product.basePrice;
                            newLabel = 'Giá gốc';
                          } else {
                            final menu = item.product.appMenus.firstWhere(
                                  (m) => m.platform == platform && m.isActive,
                              orElse: () => AppMenuModel(
                                  id: 0, platform: platform,
                                  price: item.product.basePrice,
                                  isActive: false),
                            );
                            newPrice = menu.price;
                            newLabel = platform == 'SHOPEE_FOOD'
                                ? 'Giá Shopee' : 'Giá Grab';
                          }
                          _cart[i] = item.copyWith(selectedPrice: PriceOption(
                              discountPercent: 0,
                              price: newPrice,
                              label: newLabel));
                        }
                      });
                    },
                    scale: scale,
                    isAppOrder:           _isAppOrder,
                    appDiscountAmount:    _appDiscountAmount,
                    onAppDiscountTap:     _openAppDiscountSheet,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════
// CART SUMMARY
// ══════════════════════════════════════════════════════════════════

class _CartSummary extends StatelessWidget {
  final double subTotal, grandTotal, discountAmount;
  final String? discountLabel;
  final Map<int, double> vatBreakdown;
  final PosOrderSource orderSource;
  final bool   canShopee, canGrab, isCreating, cartEmpty;
  final String paymentMethod;
  final String Function(double) formatMoney;
  final void Function(PosOrderSource) onSourceChanged;
  final void Function(String) onPaymentChanged;
  final VoidCallback  onCreateOrder;
  final VoidCallback? onClearCart;
  final double subTotalExVat;
  final double scale;
  final List<CartItem> cartItems;
  final void Function(String? platform) onRemoveUnsupported;
  final void Function(String? platform) onUpdatePrices;
  final bool        isAppOrder;
  final double      appDiscountAmount;
  final VoidCallback onAppDiscountTap;
  final double platformFee;
  final double netRevenue;
  final double platformRate;
  final double       manualDiscountAmount;
  final VoidCallback onManualDiscountTap;
  final double eVoucherDiscount;        // ← THÊM
  final String? eVoucherLabel;          // ← THÊM
  final String     appOrderCode;
  final void Function(String) onAppOrderCodeChanged;

  const _CartSummary({
    required this.appOrderCode,
    required this.onAppOrderCodeChanged,
    required this.subTotal,
    required this.vatBreakdown,
    required this.grandTotal,
    required this.discountAmount,
    this.discountLabel,
    required this.orderSource,
    required this.canShopee,
    required this.canGrab,
    required this.paymentMethod,
    required this.isCreating,
    required this.cartEmpty,
    required this.formatMoney,
    required this.subTotalExVat,
    required this.onSourceChanged,
    required this.onPaymentChanged,
    required this.onCreateOrder,
    required this.onClearCart,
    required this.scale,
    required this.cartItems,
    required this.onRemoveUnsupported,
    required this.onUpdatePrices,
    required this.isAppOrder,
    required this.appDiscountAmount,
    required this.manualDiscountAmount,
    required this.onManualDiscountTap,
    required this.onAppDiscountTap, required this.platformFee, required this.netRevenue, required this.platformRate,
    required this.eVoucherDiscount,       // ← THÊM
    this.eVoucherLabel,                   // ← THÊM
  });

  Future<void> _confirmClearCart(
      BuildContext context, PosOrderSource newSource) async {

    if (cartEmpty) {
      onSourceChanged(newSource);
      return;
    }

    final String? platform = switch (newSource) {
      PosOrderSource.shopeeFood => 'SHOPEE_FOOD',
      PosOrderSource.grabFood   => 'GRAB_FOOD',
      _                         => null,
    };

    // ── MỚI: đổi giữa takeAway ↔ dineIn → giữ nguyên giỏ, không làm gì thêm
    final bool isOldOffline = orderSource == PosOrderSource.takeAway ||
        orderSource == PosOrderSource.dineIn;
    final bool isNewOffline = newSource == PosOrderSource.takeAway ||
        newSource == PosOrderSource.dineIn;

    if (isOldOffline && isNewOffline) {
      onSourceChanged(newSource);
      return;
    }

    final willRemove = <String>[];
    final willUpdate = <String>[];

    for (final item in cartItems) {
      if (platform == null) {
        // Đổi từ App → Offline: reset về basePrice nếu khác
        if (item.product.basePrice != item.selectedPrice.price) {
          willUpdate.add(item.product.name);
        }
      } else {
        // Đổi sang App (Shopee hoặc Grab)
        final appMenu = item.product.appMenus.firstWhere(
              (m) => m.platform == platform && m.isActive,
          orElse: () => AppMenuModel(
              id: 0, platform: platform, price: 0, isActive: false),
        );

        if (!appMenu.isActive) {
          willRemove.add(item.product.name);
        } else if (appMenu.price != item.selectedPrice.price) {
          willUpdate.add(item.product.name);
        }
      }
    }

    // Nếu không có thay đổi gì thì cho đổi luôn
    if (willRemove.isEmpty && willUpdate.isEmpty) {
      onSourceChanged(newSource);
      return;
    }

    final message = willRemove.isEmpty
        ? (willUpdate.length <= 3
        ? 'Giá sẽ được cập nhật: ${willUpdate.join(', ')}.'
        : 'Giá các món trong giỏ sẽ được cập nhật theo nguồn mới.')
        : (willRemove.length <= 3
        ? '${willRemove.join(', ')} không bán ở nguồn này và sẽ bị xóa khỏi giỏ.'
        : '${willRemove.length} món không bán ở nguồn này và sẽ bị xóa khỏi giỏ.');

    final confirmed = await showDialog<bool>(
      context: context,
      useRootNavigator: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Đổi nguồn đơn hàng'),
        content: Text(message, style: const TextStyle(fontSize: 14)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              'Xác nhận',
              style: TextStyle(
                color: willRemove.isNotEmpty ? Colors.red : null,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      onSourceChanged(newSource);
      if (willRemove.isNotEmpty) {
        onRemoveUnsupported(platform);
      } else {
        onUpdatePrices(platform);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final sorted = vatBreakdown.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    const teal = Color(0xFF0D9488);

    return Container(
      padding: EdgeInsets.all(10 * scale),
      decoration: BoxDecoration(
        color: cs.surface,
        boxShadow: [BoxShadow(color: cs.shadow.withOpacity(0.1),
            blurRadius: 8 * scale,
            offset: Offset(0, -4 * scale))],
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        // Order Mode Selector
        PosOrderModeSelector(
          current:   orderSource,
          canShopee: canShopee,
          canGrab:   canGrab,
          onChanged: (newSource) {
            if (!cartEmpty && newSource != orderSource) {
              _confirmClearCart(context, newSource);
            } else {
              onSourceChanged(newSource);
            }
          },
        ),

        const SizedBox(height: 8),

        // VAT breakdown
        if (isAppOrder) ...[
          // ── App order: 3 dòng breakdown ──────────────────────────────

          // 1. Tạm tính (giá gốc app)
          _row('Tạm tính', subTotal, cs, scale: scale),

          // 2. Giảm giá (nếu có)
          if (appDiscountAmount > 0)
            Padding(
              padding: EdgeInsets.only(top: 2 * scale),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(children: [
                    Icon(Icons.local_offer_rounded,
                        size: 12 * scale, color: const Color(0xFFEE4D2D)),
                    const SizedBox(width: 4),
                    Text('Khuyến mãi',
                        style: TextStyle(
                            fontSize: 12 * scale,
                            color: const Color(0xFFEE4D2D),
                            fontWeight: FontWeight.w600)),
                  ]),
                  Text('-${formatMoney(appDiscountAmount)}đ',
                      style: TextStyle(
                          fontSize: 12 * scale,
                          color: const Color(0xFFEE4D2D),
                          fontWeight: FontWeight.w700)),
                ],
              ),
            ),

          // 3. Phí App
          Padding(
            padding: EdgeInsets.only(top: 2 * scale),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(children: [
                  Icon(Icons.storefront_rounded,
                      size: 12 * scale,
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5)),
                  const SizedBox(width: 4),
                  Text(
                    'Phí App (${(platformRate * 100).toStringAsFixed(2)}%)',
                    style: TextStyle(
                        fontSize: 12 * scale,
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.55)),
                  ),
                ]),
                Text(
                  '-${formatMoney(platformFee)}đ',
                  style: TextStyle(
                      fontSize: 12 * scale,
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                      fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),

          Divider(height: 12 * scale),

          // 4. Thực nhận (in đậm màu xanh)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Thực nhận',
                  style: TextStyle(
                      fontSize: 15 * scale,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF0D9488))),
              Text('${formatMoney(netRevenue)}đ',
                  style: TextStyle(
                      fontSize: 17 * scale,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF0D9488))),
            ],
          ),

        ] else ...[
          // ── Offline order ─────────────────────────────────────

          // Tạm tính (đã bao gồm VAT)
          _row('Tạm tính', subTotalExVat, cs, scale: scale),

          // Customer discount (loyalty)
          if (discountAmount > 0)
            Padding(
              padding: EdgeInsets.only(top: 2 * scale),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(children: [
                    Icon(Icons.local_offer_rounded,
                        size: 12 * scale, color: const Color(0xFF0D9488)),
                    const SizedBox(width: 4),
                    Text(
                      discountLabel != null
                          ? 'Giảm ($discountLabel)' : 'Giảm giá',
                      style: TextStyle(
                          fontSize: 12 * scale,
                          color: const Color(0xFF0D9488),
                          fontWeight: FontWeight.w600),
                    ),
                  ]),
                  Text('-${formatMoney(discountAmount)}đ',
                      style: TextStyle(
                          fontSize: 12 * scale,
                          color: const Color(0xFF0D9488),
                          fontWeight: FontWeight.w700)),
                ],
              ),
            ),

          // ── Manual discount (MỚI) ─────────────────────────────
          if (manualDiscountAmount > 0)
            Padding(
              padding: EdgeInsets.only(top: 2 * scale),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(children: [
                    Icon(Icons.sell_rounded,
                        size: 12 * scale, color: Colors.orange.shade700),
                    const SizedBox(width: 4),
                    Text('Giảm',
                        style: TextStyle(
                            fontSize: 12 * scale,
                            color: Colors.orange.shade700,
                            fontWeight: FontWeight.w600)),
                  ]),
                  Text('-${formatMoney(manualDiscountAmount)}đ',
                      style: TextStyle(
                          fontSize: 12 * scale,
                          color: Colors.orange.shade700,
                          fontWeight: FontWeight.w700)),
                ],
              ),
            ),

          if (eVoucherDiscount > 0)
            Padding(
              padding: EdgeInsets.only(top: 2 * scale),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(children: [
                    Icon(Icons.confirmation_num_rounded,
                        size: 12 * scale,
                        color: const Color(0xFF0284C7)),
                    const SizedBox(width: 4),
                    Text('E-Voucher',
                        style: TextStyle(
                            fontSize: 12 * scale,
                            color: const Color(0xFF0284C7),
                            fontWeight: FontWeight.w600)),
                  ]),
                  Text('-${formatMoney(eVoucherDiscount)}đ',
                      style: TextStyle(
                          fontSize: 12 * scale,
                          color: const Color(0xFF0284C7),
                          fontWeight: FontWeight.w700)),
                ],
              ),
            ),

          // Tổng VAT + breakdown
          if (vatBreakdown.isNotEmpty) ...[
            // Dòng tổng VAT
            Padding(
              padding: EdgeInsets.only(top: 2 * scale),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Bao gồm VAT',
                      style: TextStyle(
                          fontSize: 12 * scale,
                          color: cs.onSurface.withOpacity(0.55),
                          fontWeight: FontWeight.w600)),
                  Text('+${formatMoney(vatBreakdown.values.fold(0.0, (s, v) => s + v))}đ',
                      style: TextStyle(
                          fontSize: 12 * scale,
                          color: cs.onSurface.withOpacity(0.55),
                          fontWeight: FontWeight.w600)),
                ],
              ),
            ),

            // Breakdown từng mức
            ...sorted.map((e) => Padding(
              padding: EdgeInsets.only(top: 2 * scale),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('  • ${e.key}%',
                      style: TextStyle(
                          fontSize: 11 * scale,
                          color: cs.onSurface.withOpacity(0.4))),
                  Text('+${formatMoney(e.value)}đ',
                      style: TextStyle(
                          fontSize: 11 * scale,
                          color: cs.onSurface.withOpacity(0.4))),
                ],
              ),
            )),
          ],

          Divider(height: 12 * scale),

          _row('Tổng cộng', grandTotal, cs, isTotal: true, scale: scale),
        ],

        const SizedBox(height: 12),

        if (isAppOrder) ...[
          Padding(
            padding: EdgeInsets.only(bottom: 8 * scale),
            child: _AppOrderCodeInput(
              orderSource:  orderSource,
              currentCode:  appOrderCode,
              onChanged:    onAppOrderCodeChanged,
              scale:        scale,
            ),
          ),

          Row(children: [
            _buildAppDiscountButton(context),
            const SizedBox(width: 8),
            Expanded(
              child: PosPaymentSelector(
                current: paymentMethod,
                onChanged: onPaymentChanged,
              ),
            ),
          ]),
        ] else ...[
          // Nút thêm giảm giá thủ công
          GestureDetector(
            onTap: onManualDiscountTap,
            child: Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(
                  horizontal: 12 * scale, vertical: 8 * scale),
              margin: EdgeInsets.only(bottom: 8 * scale),
              decoration: BoxDecoration(
                color: manualDiscountAmount > 0
                    ? Colors.orange.withOpacity(0.1)
                    : Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: manualDiscountAmount > 0
                      ? Colors.orange.shade400
                      : Theme.of(context).colorScheme.outline.withOpacity(0.3),
                ),
              ),
              child: Row(children: [
                Icon(Icons.sell_rounded,
                    size: 14 * scale,
                    color: manualDiscountAmount > 0
                        ? Colors.orange.shade700
                        : Theme.of(context).colorScheme.onSurface.withOpacity(0.5)),
                SizedBox(width: 6 * scale),
                Expanded(child: Text(
                  manualDiscountAmount > 0
                      ? 'Giảm giá: -${formatMoney(manualDiscountAmount)}đ'
                      : 'Thêm giảm giá',
                  style: TextStyle(
                      fontSize: 12 * scale,
                      fontWeight: FontWeight.w600,
                      color: manualDiscountAmount > 0
                          ? Colors.orange.shade700
                          : Theme.of(context).colorScheme.onSurface.withOpacity(0.5)),
                )),
                Icon(Icons.chevron_right_rounded,
                    size: 16 * scale,
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3)),
              ]),
            ),
          ),
          PosPaymentSelector(
            current: paymentMethod,
            onChanged: onPaymentChanged,
          ),
        ],

        const SizedBox(height: 12),

        // === NÚT XÓA (30%) + TẠO ĐƠN (70%) ===
        Row(
          children: [
            // Nút Xóa (30%)
            Expanded(
              flex: 4,
              child: OutlinedButton.icon(
                icon: Icon(Icons.delete_outline_rounded, size: 18 * scale),
                label: Text('Xóa',
                    style: TextStyle(fontSize: 14 * scale, fontWeight: FontWeight.w600)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Colors.red),
                  padding: EdgeInsets.symmetric(vertical: 14 * scale),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12 * scale)),
                ),
                onPressed: cartEmpty ? null : onClearCart,
              ),
            ),

            const SizedBox(width: 8),

            // Nút Tạo đơn (70%)
            Expanded(
              flex: 7,
              child: SizedBox(
                height: 48 * scale,
                child: FilledButton.icon(
                  icon: isCreating
                      ? SizedBox(
                      width: 18 * scale,
                      height: 18 * scale,
                      child: CircularProgressIndicator(
                          strokeWidth: 2.5 * scale, color: Colors.white))
                      : Icon(_orderIcon, size: 18 * scale),
                  label: Text(_orderLabel,
                      style: TextStyle(
                          fontSize: 14 * scale, fontWeight: FontWeight.bold)),
                  style: FilledButton.styleFrom(
                    backgroundColor: cartEmpty || isCreating ? null : _orderColor,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12 * scale)),
                  ),
                  onPressed: (cartEmpty || isCreating) ? null : onCreateOrder,
                ),
              ),
            ),
          ],
        ),
      ]),
    );
  }

  Widget _buildAppDiscountButton(BuildContext context) {
    final hasDiscount = appDiscountAmount > 0;
    const orange = Color(0xFFEE4D2D);
    final cs = Theme.of(context).colorScheme;

    // Format discount text
    String buttonText = 'Giảm';

    return GestureDetector(
      onTap: onAppDiscountTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 10 * scale, vertical: 6 * scale),
        decoration: BoxDecoration(
          color: hasDiscount
              ? orange.withOpacity(0.12)
              : cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: hasDiscount ? orange : cs.outline.withOpacity(0.3),
          ),
        ),
        child: Text(
          buttonText,
          style: TextStyle(
            fontSize: 12 * scale,
            fontWeight: FontWeight.w600,
            color: hasDiscount ? orange : cs.onSurface.withOpacity(0.7),
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  // Helper row
  Widget _row(String label, double value, ColorScheme cs,
      {bool isTotal = false, bool isVat = false, required double scale}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontWeight: isTotal ? FontWeight.bold : FontWeight.w500,
            fontSize: (isTotal ? 15 : 13) * scale,
            color: isVat ? cs.onSurface.withOpacity(0.55) : cs.onSurface,
          ),
        ),
        Text(
          '+${formatMoney(value)}đ',
          style: TextStyle(
            fontWeight: isTotal ? FontWeight.bold : FontWeight.w500,
            fontSize: (isTotal ? 15 : 13) * scale,
            color: isTotal ? cs.primary : cs.onSurface,
          ),
        ),
      ],
    );
  }

  Color get _orderColor => switch (orderSource) {
    PosOrderSource.shopeeFood => const Color(0xFFEE4D2D),
    PosOrderSource.grabFood => const Color(0xFF00B14F),
    _ => Colors.lightBlue,
  };

  IconData get _orderIcon => switch (orderSource) {
    PosOrderSource.shopeeFood => Icons.shopping_bag_outlined,
    PosOrderSource.grabFood => Icons.delivery_dining,
    PosOrderSource.dineIn => Icons.table_restaurant_outlined,
    _ => Icons.storefront_outlined,
  };

  String get _orderLabel => switch (orderSource) {
    PosOrderSource.takeAway => 'Tạo đơn',
    PosOrderSource.dineIn => 'Tạo đơn',
    PosOrderSource.shopeeFood => 'Tạo đơn',
    PosOrderSource.grabFood => 'Tạo đơn',
  };
}

// ══════════════════════════════════════════════════════════════════
// CART ITEM TILE
// ══════════════════════════════════════════════════════════════════

class _CartItemTile extends StatelessWidget {
  final CartItem item;
  final String Function(double) formatMoney;
  final void Function(int) onQtyChange;
  final VoidCallback onRemove;
  final VoidCallback onWeightTap;   // ← MỚI
  final double scale;
  final bool isDiscounted;
  final bool isAppOrder;
  final VoidCallback? onPriceTap; // callback khi tap giá trong App mode

  const _CartItemTile({
    required this.item,
    required this.formatMoney,
    required this.onQtyChange,
    required this.onRemove,
    required this.onWeightTap,       // ← MỚI
    required this.scale,
    this.isDiscounted = false,
    this.isAppOrder = false,          // ← THÊM nếu chưa có
    this.onPriceTap,                  // ← THÊM nếu chưa có
  });

  // Kiểm tra item có ít nhất 1 ingredient non-addon có selectedCount > 0 không
  bool get _hasWeightableIngredients {
    for (final sel in item.variantSelections) {
      if (sel.isAddonGroup) continue;
      if (sel.selectedIngredients.values.any((c) => c > 0)) return true;
    }
    return false;
  }

  // Kiểm tra item đã có unitWeights override chưa
  bool get _hasWeightOverride {
    for (final sel in item.variantSelections) {
      if (sel.unitWeightsMap.isNotEmpty) return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final cs   = Theme.of(context).colorScheme;
    final vUrl = item.product.imageUrl;
    const teal = Color(0xFF0D9488);
    const scaleAccent = Color(0xFF0EA5E9); // sky blue cho icon cân
    const looseAccent = Color(0xFFEA580C); // orange cho hàng xé lẻ

    return Dismissible(
      key:       ValueKey(item.lineId),   // ← id duy nhất từng dòng
      direction: DismissDirection.endToStart,
      background: Container(
          color: cs.error, alignment: Alignment.centerRight,
          padding: EdgeInsets.only(right: 20 * scale),
          child: Icon(Icons.delete_forever_rounded,
              color: Colors.white, size: 32 * scale)),
      onDismissed: (_) => onRemove(),
      child: Card(
        margin:    EdgeInsets.symmetric(vertical: 6 * scale),
        elevation: 2,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16 * scale)),
        child: Container(
          decoration: isDiscounted
              ? BoxDecoration(
              borderRadius: BorderRadius.circular(16 * scale),
              border: Border.all(
                  color: teal.withOpacity(0.4), width: 1.5))
              : null,
          child: Padding(
            padding: EdgeInsets.all(12 * scale),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Ảnh sản phẩm
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12 * scale),
                    child: NetworkImageViewer(imageUrl: vUrl,
                        height: 80 * scale, width: 80 * scale,
                        fit: BoxFit.cover),
                  ),
                  SizedBox(width: 12 * scale),

                  // Nội dung
                  Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Tên + icon discount + icon đã có weight override
                        Row(children: [
                          Expanded(child: Text(item.product.name,
                              style: TextStyle(fontSize: 15 * scale,
                                  fontWeight: FontWeight.w700),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis)),
                          if (isDiscounted)
                            Padding(
                              padding: EdgeInsets.only(left: 4 * scale),
                              child: Icon(Icons.local_offer_rounded,
                                  size: 14 * scale, color: teal),
                            ),
                        ]),
                        SizedBox(height: 4 * scale),

                        // ── Ý 2: badge XÉ LẺ + số lượng & đơn vị ──────────
                        if (item.looseSale) ...[
                          Container(
                            padding: EdgeInsets.symmetric(
                                horizontal: 8 * scale, vertical: 3 * scale),
                            decoration: BoxDecoration(
                              color: looseAccent.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(6 * scale),
                              border: Border.all(
                                  color: looseAccent.withOpacity(0.4)),
                            ),
                            // ở đây
                            child: Row(mainAxisSize: MainAxisSize.min, children: [
                              Text(
                                'Lẻ · ${item.looseLabel ?? ''}',
                                style: TextStyle(
                                  fontSize: 10 * scale,
                                  fontWeight: FontWeight.w700,
                                  color: looseAccent,
                                ),
                              ),
                            ]),
                          ),
                          SizedBox(height: 4 * scale),
                        ],

                        // Ghi chú
                        if (item.note != null && item.note!.isNotEmpty)
                          Padding(
                              padding: EdgeInsets.only(bottom: 4 * scale),
                              child: Text('Ghi chú: ${item.note}',
                                  style: TextStyle(fontSize: 12 * scale,
                                      color: cs.onSurface.withOpacity(0.6),
                                      fontStyle: FontStyle.italic))),

                        // Ingredients & addons
                        ..._buildIngredientAndAddonLines(cs, scale),

                        SizedBox(height: 6 * scale),

                        // Giá + nút cân
                        GestureDetector(
                          onTap: isAppOrder ? onPriceTap : null,
                          child: Container(
                            padding: isAppOrder
                                ? EdgeInsets.symmetric(horizontal: 8 * scale, vertical: 3 * scale)
                                : EdgeInsets.zero,
                            decoration: isAppOrder ? BoxDecoration(
                              color: const Color(0xFF0284C7).withOpacity(0.08),
                              borderRadius: BorderRadius.circular(6 * scale),
                              border: Border.all(color: const Color(0xFF0284C7).withOpacity(0.3)),
                            ) : null,
                            child: Row(mainAxisSize: MainAxisSize.min, children: [
                              Text(
                                formatMoney(item.selectedPrice.price + item.addonPerUnit),
                                style: TextStyle(
                                  fontSize: 16 * scale, fontWeight: FontWeight.bold,
                                  color: isAppOrder
                                      ? const Color(0xFF0284C7)
                                      : cs.primary,
                                ),
                              ),
                              if (isAppOrder) ...[
                                SizedBox(width: 4 * scale),
                                Icon(Icons.edit_rounded, size: 12 * scale,
                                    color: const Color(0xFF0284C7).withOpacity(0.6)),
                              ],
                            ]),
                          ),
                        ),

                        // Nút điều chỉnh định lượng — dòng riêng bên dưới giá
                        // (hàng xé lẻ đã chốt số lượng lúc nhập → không hiện)
                        if (_hasWeightableIngredients && item.canEditWeight) ...[
                          SizedBox(height: 6 * scale),
                          GestureDetector(
                            onTap: onWeightTap,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: EdgeInsets.symmetric(
                                  horizontal: 8 * scale,
                                  vertical: 4 * scale),
                              decoration: BoxDecoration(
                                color: _hasWeightOverride
                                    ? scaleAccent.withOpacity(0.12)
                                    : cs.onSurface.withOpacity(0.06),
                                borderRadius: BorderRadius.circular(8 * scale),
                                border: Border.all(
                                  color: _hasWeightOverride
                                      ? scaleAccent.withOpacity(0.4)
                                      : cs.onSurface.withOpacity(0.12),
                                ),
                              ),
                              child: Row(mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      _hasWeightOverride
                                          ? Icons.scale_rounded
                                          : Icons.scale_outlined,
                                      size: 12 * scale,
                                      color: _hasWeightOverride
                                          ? scaleAccent
                                          : cs.onSurface.withOpacity(0.4),
                                    ),
                                    SizedBox(width: 4 * scale),
                                    Text(
                                      'Định lượng',
                                      style: TextStyle(
                                        fontSize: 10 * scale,
                                        fontWeight: FontWeight.w600,
                                        color: _hasWeightOverride
                                            ? scaleAccent
                                            : cs.onSurface.withOpacity(0.4),
                                      ),
                                    ),
                                  ]),
                            ),
                          ),
                        ],
                      ])),

                  // ── Ý 2: hàng xé lẻ → KHÔNG có stepper, chỉ có nút xoá ──
                  if (!item.canEditQuantity)
                    Column(mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            item.looseLabel ?? '${item.quantity}',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                fontSize: 13 * scale,
                                fontWeight: FontWeight.bold,
                                color: looseAccent),
                          ),
                          SizedBox(height: 6 * scale),
                          InkWell(
                            onTap: onRemove,
                            borderRadius: BorderRadius.circular(20 * scale),
                            child: Padding(
                              padding: EdgeInsets.all(4 * scale),
                              child: Icon(Icons.delete_outline_rounded,
                                  size: 26 * scale, color: cs.error),
                            ),
                          ),
                        ])
                  else
                  // Stepper qty
                    Column(children: [
                      _qtyButton(Icons.remove_circle_outline_rounded,
                              () => onQtyChange(-1), cs, scale),
                      Padding(
                          padding: EdgeInsets.symmetric(vertical: 4 * scale),
                          child: Text('${item.quantity}',
                              style: TextStyle(fontSize: 16 * scale,
                                  fontWeight: FontWeight.bold))),
                      _qtyButton(Icons.add_circle_rounded,
                              () => onQtyChange(1), cs, scale),
                    ]),
                ]),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildIngredientAndAddonLines(
      ColorScheme cs, double scale) {
    final lines   = <Widget>[];
    final nameMap = <int, String>{};
    for (final v in item.product.variants)
      for (final ing in v.ingredients)
        nameMap[ing.ingredientId] = ing.ingredientName;

    // ── Nguyên liệu chính (non-addon) ──────────────────────────
    const looseAccent = Color(0xFFEA580C);

    for (final sel in item.variantSelections) {
      if (sel.isAddonGroup) continue;
      for (final e in sel.selectedIngredients.entries) {
        if (e.value <= 0) continue;
        final name        = nameMap[e.key] ?? 'NL #${e.key}';
        final weights     = sel.unitWeightsMap[e.key];
        final hasOverride = weights != null && weights.isNotEmpty;

        // Ý 2: đúng nguyên liệu được xé lẻ → hiện "2 Miếng" thay vì "x1"
        final bool isLooseLine = item.looseSale &&
            (item.looseIngredientId == null || item.looseIngredientId == e.key);

        final String label = isLooseLine
            ? '• $name: ${item.looseLabel ?? ''}'
            : '• $name x${e.value}';

        lines.add(Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Row(children: [
            // Tên + số lượng — Flexible để tự cắt khi quá dài
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                    fontSize: 11 * scale,
                    fontWeight:
                    isLooseLine ? FontWeight.w600 : FontWeight.normal,
                    color: isLooseLine
                        ? looseAccent
                        : cs.onSurface.withOpacity(0.7)),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ]),
        ));
      }
    }

    // ── Addons ─────────────────────────────────────────────────
    for (final sel in item.variantSelections) {
      if (!sel.isAddonGroup || sel.addonItems == null) continue;
      for (final a in sel.addonItems!) {
        if (a.quantity <= 0) continue;
        final name = nameMap[a.ingredientId] ?? a.ingredientName;
        lines.add(Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Text(
            '• $name x${a.quantity}',
            style: TextStyle(
                fontSize: 10 * scale,
                color: cs.primary.withOpacity(0.8)),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ));
      }
    }

    return lines;
  }

  /// Format weight gọn: 0.200 → 0.2, 0.310 → 0.31
  String _fmtW(double v) {
    return v.toStringAsFixed(3)
        .replaceAll(RegExp(r'0+$'), '')
        .replaceAll(RegExp(r'\.$'), '');
  }

  Widget _qtyButton(IconData icon, VoidCallback onTap,
      ColorScheme cs, double scale) =>
      InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20 * scale),
          child: Padding(padding: EdgeInsets.all(4 * scale),
              child: Icon(icon, size: 28 * scale, color: cs.primary)));
}


// ══════════════════════════════════════════════════════════════════
// CLOCK WIDGET
// ══════════════════════════════════════════════════════════════════

class _ClockWidget extends StatefulWidget {
  final ColorScheme cs;
  final double scale;
  const _ClockWidget({required this.cs, required this.scale});
  @override State<_ClockWidget> createState() => _ClockWidgetState();
}

class _ClockWidgetState extends State<_ClockWidget> {
  late Timer    _timer;
  late DateTime _now;
  @override
  void initState() {
    super.initState();
    _now   = DateTime.now();
    _timer = Timer.periodic(const Duration(seconds: 1),
            (_) { if (mounted) setState(() => _now = DateTime.now()); });
  }
  @override void dispose() { _timer.cancel(); super.dispose(); }
  @override
  Widget build(BuildContext context) => Text(
    DateFormat('HH:mm:ss  dd/MM/yyyy').format(_now),
    style: TextStyle(
        fontSize: 13 * widget.scale,
        color: widget.cs.onSurface.withOpacity(0.6),
        fontFeatures: const [FontFeature.tabularFigures()]),
  );
}

// ══════════════════════════════════════════════════════════════════
// QUICK ADD HELPERS
// ══════════════════════════════════════════════════════════════════

List<VariantGroupSelection> buildQuickAddSelections(PosProductModel p) {
  final regular = p.variants.where((v) => !v.isAddonGroup).toList();
  final result  = <VariantGroupSelection>[];
  for (final v in regular.where((v) => v.minSelect > 0))
    result.add(VariantGroupSelection(
        variantId: v.id, groupName: v.groupName,
        isAddonGroup: false,
        selectedIngredients: _autoAllocateByOrder(v)));
  if (result.isEmpty && regular.isNotEmpty) {
    final first = regular.first;
    result.add(VariantGroupSelection(
        variantId: first.id, groupName: first.groupName,
        isAddonGroup: false,
        selectedIngredients: _autoFill(first)));
  }
  return result;
}

bool canQuickAdd(PosProductModel p) {
  final regular = p.variants.where((v) => !v.isAddonGroup).toList();
  return regular.isEmpty || _getDefaultVariant(p) != null;
}

PosVariantModel? _getDefaultVariant(PosProductModel p) {
  final regular = p.variants.where((v) => !v.isAddonGroup).toList();
  if (regular.isEmpty) return null;
  if (regular.length == 1) return regular.first;
  return regular.where(_isFullAuto).firstOrNull;
}

bool _isFullAuto(PosVariantModel v) {
  if (v.isAddonGroup || v.ingredients.isEmpty) return false;
  final total = v.ingredients.fold(
      0, (s, i) => s + (i.maxSelectableCount ?? 0));
  return v.minSelect > 0 &&
      v.minSelect == v.maxSelect &&
      v.minSelect == total;
}

/// Trả về danh sách nguyên liệu của biến thể theo ĐÚNG thứ tự displayOrder.
List<PosVariantIngredientModel> _ingredientsByOrder(PosVariantModel v) =>
    [...v.ingredients]..sort((a, b) => a.displayOrder.compareTo(b.displayOrder));

/// Phân bổ số lượng CẦN CHỌN của nhóm bắt buộc cho các nguyên liệu theo
/// THỨ TỰ (displayOrder): dồn tối đa vào nguyên liệu đầu tiên (giới hạn bởi
/// maxSelectableCount), hết mới sang nguyên liệu tiếp theo — KHÔNG chia đều.
///
/// VD: nhóm cần chọn 5, mỗi NL tối đa 5 → NL đầu tiên nhận 5.
///     nhóm "chọn tất cả" (minSelect == tổng cap) → mỗi NL nhận đúng cap của nó.
Map<int, int> _autoAllocateByOrder(PosVariantModel v) {
  final result = <int, int>{};
  if (v.ingredients.isEmpty) return result;

  // Số lượng cần chọn: minSelect (bằng maxSelect khi cố định).
  int remaining = v.minSelect > 0 ? v.minSelect : v.maxSelect;
  if (remaining <= 0) return result;

  for (final ing in _ingredientsByOrder(v)) {
    if (remaining <= 0) break;
    final cap  = ing.maxSelectableCount ?? 1;
    final give = remaining < cap ? remaining : cap;
    if (give > 0) result[ing.ingredientId] = give;
    remaining -= give;
  }
  return result;
}

/// Dùng cho nhóm KHÔNG bắt buộc (fallback): dồn tới maxSelect theo thứ tự.
Map<int, int> _autoFill(PosVariantModel v) {
  final result    = <int, int>{};
  int   remaining = v.maxSelect;
  for (final ing in _ingredientsByOrder(v)) {
    if (remaining <= 0) break;
    final cap  = ing.maxSelectableCount ?? 1;
    final give = remaining < cap ? remaining : cap;
    if (give > 0) result[ing.ingredientId] = give;
    remaining -= give;
  }
  return result;
}

class _ManualDiscountResult {
  final bool   cleared;
  final String type;   // 'amount' hoặc 'percent'
  final double value;
  const _ManualDiscountResult({
    this.cleared = false,
    this.type    = 'amount',
    this.value   = 0,
  });
}

class _ManualDiscountSheet extends StatefulWidget {
  final double subTotal;     // tổng sau loyalty discount, trước manual
  final String currentType;
  final double currentValue;

  const _ManualDiscountSheet({
    required this.subTotal,
    required this.currentType,
    required this.currentValue,
  });

  @override
  State<_ManualDiscountSheet> createState() => _ManualDiscountSheetState();
}

class _ManualDiscountSheetState extends State<_ManualDiscountSheet> {
  late String _type;
  final _ctrl  = TextEditingController();
  final _focus = FocusNode();

  static final _fmt = NumberFormat('#,###', 'vi_VN');

  double get _inputValue => double.tryParse(_ctrl.text) ?? 0;

  double get _discountAmount {
    if (_type == 'percent') {
      return (widget.subTotal * _inputValue / 100)
          .clamp(0, widget.subTotal);
    }
    return _inputValue.clamp(0, widget.subTotal);
  }

  double get _afterDiscount =>
      (widget.subTotal - _discountAmount).clamp(0.0, double.infinity);

  double get _roundingDiff => _afterDiscount - (widget.subTotal - _discountAmount);

  bool get _isValid {
    if (_inputValue <= 0) return false;
    if (_type == 'percent') return _inputValue >= 1 && _inputValue <= 100;
    return _inputValue < widget.subTotal; // không cho giảm bằng hoặc hơn tổng
  }

  @override
  void initState() {
    super.initState();
    _type = widget.currentType;
    if (widget.currentValue > 0) {
      _ctrl.text = widget.currentValue.toInt().toString();
    }
    WidgetsBinding.instance.addPostFrameCallback(
            (_) => _focus.requestFocus());
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bottomPadding = MediaQuery.of(context).padding.bottom + 16;

    return Container(
      padding: EdgeInsets.fromLTRB(20, 16, 20, bottomPadding),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [

        // Handle
        Center(child: Container(width: 40, height: 4,
            decoration: BoxDecoration(
                color: cs.onSurface.withOpacity(0.2),
                borderRadius: BorderRadius.circular(2)))),
        const SizedBox(height: 12),

        // Header
        Row(children: [
          const Icon(Icons.sell_rounded, color: Colors.orange, size: 20),
          const SizedBox(width: 8),
          Text('Giảm giá',
              style: TextStyle(fontSize: 17,
                  fontWeight: FontWeight.bold, color: cs.onSurface)),
          const Spacer(),
          if (widget.currentValue > 0)
            TextButton(
              onPressed: () => Navigator.pop(context,
                  const _ManualDiscountResult(cleared: true)),
              child: const Text('Xóa',
                  style: TextStyle(color: Colors.red, fontSize: 13)),
            ),
        ]),

        // Toggle type
        Container(
          decoration: BoxDecoration(
              color: cs.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.all(4),
          child: Row(children: [
            Expanded(child: _DiscountTypeBtn(
              label: 'Số tiền (đ)',
              selected: _type == 'amount',
              onTap: () => setState(() {
                _type = 'amount';
                _ctrl.clear();
              }),
            )),
            Expanded(child: _DiscountTypeBtn(
              label: 'Phần trăm (%)',
              selected: _type == 'percent',
              onTap: () => setState(() {
                _type = 'percent';
                _ctrl.clear();
              }),
            )),
          ]),
        ),
        const SizedBox(height: 4),

        // Input
        Column(
          children: [
            TextField(
              controller:   _ctrl,
              focusNode:    _focus,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                if (_type == 'percent') _PercentFormatter(),
              ],
              onChanged: (_) => setState(() {}),
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
              textAlign: TextAlign.center,
              decoration: InputDecoration(
                labelText: _type == 'percent'
                    ? 'Nhập % giảm (1–100)' : 'Nhập số tiền giảm',
                hintText:  _type == 'percent' ? 'VD: 10' : 'VD: 50000',
                suffixText: _type == 'percent' ? '%' : 'đ',
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.orange, width: 2),
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 4),

        // Confirm
        SizedBox(
          width: double.infinity, height: 40,
          child: FilledButton.icon(
            icon:  const Icon(Icons.check_rounded),
            label: const Text('Áp dụng',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.orange.shade700,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: _isValid
                ? () => Navigator.pop(context,
                _ManualDiscountResult(type: _type, value: _inputValue))
                : null,
          ),
        ),
      ]),
    );
  }
}

class _DiscountTypeBtn extends StatelessWidget {
  final String label;
  final bool   selected;
  final VoidCallback onTap;
  const _DiscountTypeBtn({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding:  const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? Colors.orange.shade700 : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
        ),
        child: Text(label,
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.w600,
                color: selected
                    ? Colors.white
                    : Theme.of(context).colorScheme.onSurface.withOpacity(0.6))),
      ),
    );
  }
}

class _PreviewLine extends StatelessWidget {
  final String label, value;
  final ColorScheme cs;
  final bool   isBold;
  final Color? valueColor;
  const _PreviewLine(this.label, this.value, this.cs,
      {this.isBold = false, this.valueColor});
  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(label, style: TextStyle(
          fontSize: isBold ? 14 : 13,
          color: cs.onSurface.withOpacity(isBold ? 1 : 0.7))),
      Text(value, style: TextStyle(
          fontSize: isBold ? 15 : 13,
          fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
          color: valueColor ?? cs.onSurface)),
    ],
  );
}

// Formatter giới hạn 1–100 cho input %
class _PercentFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue old, TextEditingValue value) {
    if (value.text.isEmpty) return value;
    final n = int.tryParse(value.text);
    if (n == null || n < 1 || n > 100) return old;
    return value;
  }
}
class _AppOrderCodeInput extends StatefulWidget {
  final PosOrderSource orderSource;
  final String         currentCode;
  final void Function(String) onChanged;
  final double         scale;

  const _AppOrderCodeInput({
    required this.orderSource,
    required this.currentCode,
    required this.onChanged,
    required this.scale,
  });

  @override
  State<_AppOrderCodeInput> createState() => _AppOrderCodeInputState();
}

class _AppOrderCodeInputState extends State<_AppOrderCodeInput> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.currentCode);
  }

  @override
  void didUpdateWidget(_AppOrderCodeInput old) {
    super.didUpdateWidget(old);
    // Sync lại nếu bị clear từ bên ngoài
    if (widget.currentCode.isEmpty && _ctrl.text.isNotEmpty) {
      _ctrl.clear();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs        = Theme.of(context).colorScheme;
    final isShopee  = widget.orderSource == PosOrderSource.shopeeFood;
    final color     = isShopee ? const Color(0xFFEE4D2D) : const Color(0xFF00B14F);
    final prefix    = isShopee ? 'SF-' : 'GF-';
    final isEmpty   = _ctrl.text.trim().isEmpty;

    return Container(
      decoration: BoxDecoration(
        color:        isEmpty
            ? color.withOpacity(0.06)
            : color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isEmpty ? color.withOpacity(0.4) : color,
          width: isEmpty ? 1.0 : 1.5,
        ),
      ),
      padding: EdgeInsets.symmetric(
          horizontal: 10 * widget.scale, vertical: 4 * widget.scale),
      child: Row(children: [
        // Prefix badge
        Container(
          padding: EdgeInsets.symmetric(
              horizontal: 6 * widget.scale, vertical: 3 * widget.scale),
          decoration: BoxDecoration(
            color:        color.withOpacity(0.15),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            prefix,
            style: TextStyle(
              fontSize:   12 * widget.scale,
              fontWeight: FontWeight.w800,
              color:      color,
            ),
          ),
        ),
        SizedBox(width: 8 * widget.scale),

        // Input
        Expanded(
          child: TextField(
            controller:   _ctrl,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: TextStyle(
              fontSize:   13 * widget.scale,
              fontWeight: FontWeight.w700,
              color:      cs.onSurface,
            ),
            decoration: InputDecoration(
              hintText:        'Nhập mã đơn (bắt buộc)',
              hintStyle: TextStyle(
                fontSize: 12 * widget.scale,
                color:    cs.onSurface.withOpacity(0.4),
              ),
              isDense:         true,
              border:          InputBorder.none,
              contentPadding:  EdgeInsets.zero,
            ),
            onChanged: (v) {
              setState(() {});         // rebuild để update border
              widget.onChanged(v);
            },
          ),
        ),

        // Clear button
        if (_ctrl.text.isNotEmpty)
          GestureDetector(
            onTap: () {
              _ctrl.clear();
              setState(() {});
              widget.onChanged('');
            },
            child: Icon(Icons.close_rounded,
                size: 16 * widget.scale,
                color: cs.onSurface.withOpacity(0.4)),
          ),
      ]),
    );
  }
}

// Thêm class này
class _CartBadge extends StatelessWidget {
  final List<CartItem> cart;
  final int productId;
  final double scale;
  final ColorScheme cs;

  const _CartBadge({
    required this.cart,
    required this.productId,
    required this.scale,
    required this.cs,
  });

  @override
  Widget build(BuildContext context) {
    final qty = cart
        .where((c) => c.product.id == productId)
        .fold(0, (s, c) => s + c.quantity);
    if (qty == 0) return const SizedBox.shrink();
    return Container(
      width: 24 * scale, height: 24 * scale,
      decoration: BoxDecoration(
        color: cs.primary, shape: BoxShape.circle,
        boxShadow: [BoxShadow(
            color: cs.primary.withOpacity(0.45),
            blurRadius: 6 * scale)],
      ),
      child: Center(
        child: Text('$qty',
            style: TextStyle(color: Colors.white,
                fontWeight: FontWeight.bold, fontSize: 10 * scale)),
      ),
    );
  }
}