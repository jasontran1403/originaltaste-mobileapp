// lib/data/models/dashboard/dashboard_pos_model.dart

// ── Helpers ───────────────────────────────────────────────────────────────────

double _d(dynamic v) {
  if (v == null) return 0.0;
  if (v is double) return v;
  if (v is int) return v.toDouble();
  return double.tryParse(v.toString()) ?? 0.0;
}

Map<String, dynamic> _m(dynamic v) =>
    v is Map<String, dynamic> ? v : <String, dynamic>{};

List<T> _list<T>(dynamic raw, T Function(Map<String, dynamic>) fromJson) {
  if (raw == null) return [];
  return (raw as List).whereType<Map<String, dynamic>>().map(fromJson).toList();
}

// ── Order Summary ─────────────────────────────────────────────────────────────

class PosOrderSummaryModel {
  final int offlineOrders;
  final int shopeeFoodOrders;
  final int grabFoodOrders;
  final int totalOrders;
  final int completedOrders;
  final int cancelledOrders;
  final int pendingOrders;
  final int offlineOrdersCompleted;
  final int offlineOrdersPending;
  final int shopeeFoodOrdersCompleted;
  final int shopeeFoodOrdersPending;
  final int grabFoodOrdersCompleted;
  final int grabFoodOrdersPending;

  const PosOrderSummaryModel({
    this.offlineOrders              = 0,
    this.shopeeFoodOrders           = 0,
    this.grabFoodOrders             = 0,
    this.totalOrders                = 0,
    this.completedOrders            = 0,
    this.cancelledOrders            = 0,
    this.pendingOrders              = 0,
    this.offlineOrdersCompleted     = 0,
    this.offlineOrdersPending       = 0,
    this.shopeeFoodOrdersCompleted  = 0,
    this.shopeeFoodOrdersPending    = 0,
    this.grabFoodOrdersCompleted    = 0,
    this.grabFoodOrdersPending      = 0,
  });

  factory PosOrderSummaryModel.fromJson(Map<String, dynamic> j) =>
      PosOrderSummaryModel(
        offlineOrders:               j['offlineOrders']               ?? 0,
        shopeeFoodOrders:            j['shopeeFoodOrders']            ?? 0,
        grabFoodOrders:              j['grabFoodOrders']              ?? 0,
        totalOrders:                 j['totalOrders']                 ?? 0,
        completedOrders:             j['completedOrders']             ?? 0,
        cancelledOrders:             j['cancelledOrders']             ?? 0,
        pendingOrders:               j['pendingOrders']               ?? 0,
        offlineOrdersCompleted:      j['offlineOrdersCompleted']      ?? 0,
        offlineOrdersPending:        j['offlineOrdersPending']        ?? 0,
        shopeeFoodOrdersCompleted:   j['shopeeFoodOrdersCompleted']   ?? 0,
        shopeeFoodOrdersPending:     j['shopeeFoodOrdersPending']     ?? 0,
        grabFoodOrdersCompleted:     j['grabFoodOrdersCompleted']     ?? 0,
        grabFoodOrdersPending:       j['grabFoodOrdersPending']       ?? 0,
      );
}

// ── Revenue Summary ───────────────────────────────────────────────────────────

class PosRevenueSummaryModel {
  final double totalRevenue;
  final double offlineRevenue;
  final double shopeeFoodRevenue;
  final double grabFoodRevenue;

  const PosRevenueSummaryModel({
    this.totalRevenue      = 0,
    this.offlineRevenue    = 0,
    this.shopeeFoodRevenue = 0,
    this.grabFoodRevenue   = 0,
  });

  factory PosRevenueSummaryModel.fromJson(Map<String, dynamic> j) =>
      PosRevenueSummaryModel(
        totalRevenue:      _d(j['totalRevenue']),
        offlineRevenue:    _d(j['offlineRevenue']),
        shopeeFoodRevenue: _d(j['shopeeFoodRevenue']),
        grabFoodRevenue:   _d(j['grabFoodRevenue']),
      );
}

// ── Pie Item ──────────────────────────────────────────────────────────────────

class PosPieItemModel {
  final String key;
  final String label;
  final int    count;
  final double amount;
  final int itemCount;

  const PosPieItemModel({
    required this.key,
    required this.label,
    this.count  = 0,
    this.amount = 0,
    required this.itemCount
  });

  factory PosPieItemModel.fromJson(Map<String, dynamic> j) => PosPieItemModel(
    key:    j['key']   ?? '',
    label:  j['label'] ?? '',
    count:  j['count'] ?? 0,
    amount: _d(j['amount']),
    itemCount: j['itemCount'] ?? 0,
  );
}

// ── Payment Method Item ───────────────────────────────────────────────────────

class PosPaymentMethodItem {
  final String method;
  final String label;
  final double amount;
  final int    count;

  const PosPaymentMethodItem({
    required this.method,
    required this.label,
    this.amount = 0,
    this.count  = 0,
  });

  factory PosPaymentMethodItem.fromJson(Map<String, dynamic> j) =>
      PosPaymentMethodItem(
        method: j['method'] ?? '',
        label:  j['label']  ?? j['method'] ?? '',
        amount: _d(j['amount']),
        count:  j['count']  ?? 0,
      );
}

// ── Payment Breakdown ─────────────────────────────────────────────────────────

class PosPaymentBreakdownModel {
  final List<PosPaymentMethodItem> methods;
  final List<PosPieItemModel>      sourcePieItems;
  final List<PosPieItemModel>      categoryPieItems;

  const PosPaymentBreakdownModel({
    this.methods          = const [],
    this.sourcePieItems   = const [],
    this.categoryPieItems = const [],
  });

  double get totalAmount => methods.fold(0, (s, m) => s + m.amount);
  int    get totalCount  => methods.fold(0, (s, m) => s + m.count);

  factory PosPaymentBreakdownModel.fromJson(Map<String, dynamic> j) =>
      PosPaymentBreakdownModel(
        methods:          _list(j['methods'],          PosPaymentMethodItem.fromJson),
        sourcePieItems:   _list(j['sourcePieItems'],   PosPieItemModel.fromJson),
        categoryPieItems: _list(j['categoryPieItems'], PosPieItemModel.fromJson),
      );
}

// ── Top Product ───────────────────────────────────────────────────────────────

class PosTopProductModel {
  final int     productId;
  final String  productName;
  final String? productImageUrl;
  final double  totalQuantity;
  final double  totalRevenue;
  final int     orderCount;

  const PosTopProductModel({
    required this.productId,
    required this.productName,
    this.productImageUrl,
    this.totalQuantity = 0,
    this.totalRevenue  = 0,
    this.orderCount    = 0,
  });

  factory PosTopProductModel.fromJson(Map<String, dynamic> j) =>
      PosTopProductModel(
        productId:       j['productId']      ?? 0,
        productName:     j['productName']    ?? '',
        productImageUrl: j['productImageUrl'],
        totalQuantity:   _d(j['totalQuantity']),
        totalRevenue:    _d(j['totalRevenue']),
        orderCount:      j['orderCount']     ?? 0,
      );
}

// ── Order By Time ─────────────────────────────────────────────────────────────

class PosOrderByTimeModel {
  final String timeBucket;
  final int    orderCount;
  final double revenue;
  final double aov;
  final int    itemCount;

  const PosOrderByTimeModel({
    required this.timeBucket,
    this.orderCount = 0,
    this.revenue    = 0,
    this.aov        = 0,
    this.itemCount = 0,
  });

  factory PosOrderByTimeModel.fromJson(Map<String, dynamic> j) =>
      PosOrderByTimeModel(
        timeBucket: j['timeBucket'] ?? '',
        orderCount: j['orderCount'] ?? 0,
        revenue:    _d(j['revenue']),
        aov:        _d(j['aov']),
        itemCount:  j['itemCount'] ?? 0,
      );
}

// ── Recent Order ──────────────────────────────────────────────────────────────

class PosRecentOrderModel {
  final int     orderId;
  final String  orderCode;
  final String  orderSource;
  final int?    createdAt;
  final double  totalAmount;
  final double  finalAmount;
  final String  status;
  final String? paymentMethod;
  final String  paymentStatus;

  const PosRecentOrderModel({
    required this.orderId,
    required this.orderCode,
    this.orderSource   = 'OFFLINE',
    this.createdAt,
    this.totalAmount   = 0,
    this.finalAmount   = 0,
    this.status        = '',
    this.paymentMethod,
    this.paymentStatus = '',
  });

  factory PosRecentOrderModel.fromJson(Map<String, dynamic> j) =>
      PosRecentOrderModel(
        orderId:       j['orderId']       ?? 0,
        orderCode:     j['orderCode']     ?? '',
        orderSource:   j['orderSource']   ?? 'OFFLINE',
        createdAt:     j['createdAt'],
        totalAmount:   _d(j['totalAmount']),
        finalAmount:   _d(j['finalAmount']),
        status:        j['status']        ?? '',
        paymentMethod: j['paymentMethod'],
        paymentStatus: j['paymentStatus'] ?? '',
      );
}

// ── Top-level POS Dashboard Model ─────────────────────────────────────────────

class PosSourceStatModel {
  final String source;       // "TAKE_AWAY" | "DINE_IN" | "SHOPEE_FOOD" | "GRAB_FOOD"
  final int    totalItems;   // tổng sản phẩm
  final int    totalOrders;  // tổng số đơn
  final double totalRevenue; // tổng tiền

  const PosSourceStatModel({
    required this.source,
    this.totalItems   = 0,
    this.totalOrders  = 0,
    this.totalRevenue = 0,
  });

  factory PosSourceStatModel.fromJson(Map<String, dynamic> j) =>
      PosSourceStatModel(
        source:       j['source']       ?? '',
        totalItems:   j['totalItems']   ?? 0,
        totalOrders:  j['totalOrders']  ?? 0,
        totalRevenue: _d(j['totalRevenue']),
      );
}

class PosDashboardModel {
  final PosOrderSummaryModel      orderSummary;
  final PosRevenueSummaryModel    revenueSummary;
  final PosPaymentBreakdownModel  paymentBreakdown;
  final List<PosTopProductModel>  topProducts;
  final List<PosOrderByTimeModel> ordersByTime;
  final List<PosRecentOrderModel> recentOrders;
  final List<PosSourceStatModel>  sourceStats;

  const PosDashboardModel({
    required this.orderSummary,
    required this.revenueSummary,
    required this.paymentBreakdown,
    required this.topProducts,
    required this.ordersByTime,
    required this.recentOrders,
    this.sourceStats = const [],
  });

  PosSourceStatModel statFor(String source) =>
      sourceStats.firstWhere(
            (s) => s.source == source,
        orElse: () => PosSourceStatModel(source: source),
      );

  factory PosDashboardModel.fromJson(Map<String, dynamic> j) =>
      PosDashboardModel(
        orderSummary:     PosOrderSummaryModel.fromJson(_m(j['orderSummary'])),
        revenueSummary:   PosRevenueSummaryModel.fromJson(_m(j['revenueSummary'])),
        paymentBreakdown: PosPaymentBreakdownModel.fromJson(_m(j['paymentBreakdown'])),
        topProducts:  _list(j['topProducts'],  PosTopProductModel.fromJson),
        ordersByTime: _list(j['ordersByTime'], PosOrderByTimeModel.fromJson),
        recentOrders: _list(j['recentOrders'], PosRecentOrderModel.fromJson),
        sourceStats:  _list(j['sourceStats'],  PosSourceStatModel.fromJson), // ← THÊM
      );
}