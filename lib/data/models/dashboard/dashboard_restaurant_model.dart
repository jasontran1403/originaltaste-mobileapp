// lib/data/models/dashboard/dashboard_restaurant_model.dart

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

class RestaurantOrderSummaryModel {
  final int totalOrders;
  final int pendingOrders;
  final int confirmedOrders;
  final int preparingOrders;
  final int readyOrders;
  final int deliveringOrders;
  final int completedOrders;
  final int cancelledOrders;
  final int failedOrders;

  const RestaurantOrderSummaryModel({
    this.totalOrders      = 0,
    this.pendingOrders    = 0,
    this.confirmedOrders  = 0,
    this.preparingOrders  = 0,
    this.readyOrders      = 0,
    this.deliveringOrders = 0,
    this.completedOrders  = 0,
    this.cancelledOrders  = 0,
    this.failedOrders     = 0,
  });

  int get activeOrders =>
      pendingOrders + confirmedOrders + preparingOrders + readyOrders + deliveringOrders;

  factory RestaurantOrderSummaryModel.fromJson(Map<String, dynamic> j) =>
      RestaurantOrderSummaryModel(
        totalOrders:      j['totalOrders']      ?? 0,
        pendingOrders:    j['pendingOrders']     ?? 0,
        confirmedOrders:  j['confirmedOrders']   ?? 0,
        preparingOrders:  j['preparingOrders']   ?? 0,
        readyOrders:      j['readyOrders']       ?? 0,
        deliveringOrders: j['deliveringOrders']  ?? 0,
        completedOrders:  j['completedOrders']   ?? 0,
        cancelledOrders:  j['cancelledOrders']   ?? 0,
        failedOrders:     j['failedOrders']      ?? 0,
      );
}

// ── Revenue Summary ───────────────────────────────────────────────────────────

class RestaurantRevenueSummaryModel {
  final double completedRevenue;
  final double pendingRevenue;
  final double totalDiscount;
  final double totalVat;

  const RestaurantRevenueSummaryModel({
    this.completedRevenue = 0,
    this.pendingRevenue   = 0,
    this.totalDiscount    = 0,
    this.totalVat         = 0,
  });

  factory RestaurantRevenueSummaryModel.fromJson(Map<String, dynamic> j) =>
      RestaurantRevenueSummaryModel(
        completedRevenue: _d(j['completedRevenue']),
        pendingRevenue:   _d(j['pendingRevenue']),
        totalDiscount:    _d(j['totalDiscount']),
        totalVat:         _d(j['totalVat']),
      );
}

// ── Customer Summary ──────────────────────────────────────────────────────────

class RestaurantCustomerSummaryModel {
  final int newCustomers;
  final int returningCustomers;

  const RestaurantCustomerSummaryModel({
    this.newCustomers       = 0,
    this.returningCustomers = 0,
  });

  int get total => newCustomers + returningCustomers;

  factory RestaurantCustomerSummaryModel.fromJson(Map<String, dynamic> j) =>
      RestaurantCustomerSummaryModel(
        newCustomers:       j['newCustomers']       ?? 0,
        returningCustomers: j['returningCustomers'] ?? 0,
      );
}

// ── Payment ───────────────────────────────────────────────────────────────────

class RestaurantPaymentMethodItem {
  final String method;
  final String label;
  final double amount;
  final int    count;

  const RestaurantPaymentMethodItem({
    required this.method,
    required this.label,
    this.amount = 0,
    this.count  = 0,
  });

  factory RestaurantPaymentMethodItem.fromJson(Map<String, dynamic> j) =>
      RestaurantPaymentMethodItem(
        method: j['method'] ?? '',
        label:  j['label']  ?? j['method'] ?? '',
        amount: _d(j['amount']),
        count:  j['count']  ?? 0,
      );
}

class RestaurantPaymentBreakdownModel {
  final List<RestaurantPaymentMethodItem> methods;

  const RestaurantPaymentBreakdownModel({this.methods = const []});

  double get totalAmount => methods.fold(0, (s, m) => s + m.amount);
  int    get totalCount  => methods.fold(0, (s, m) => s + m.count);

  factory RestaurantPaymentBreakdownModel.fromJson(Map<String, dynamic> j) =>
      RestaurantPaymentBreakdownModel(
        methods: _list(j['methods'], RestaurantPaymentMethodItem.fromJson),
      );
}

// ── Top Lists ─────────────────────────────────────────────────────────────────

class RestaurantTopProductModel {
  final int     productId;
  final String  productName;
  final String? productImageUrl;
  final double  totalQuantity;
  final double  totalRevenue;
  final int     orderCount;

  const RestaurantTopProductModel({
    required this.productId,
    required this.productName,
    this.productImageUrl,
    this.totalQuantity = 0,
    this.totalRevenue  = 0,
    this.orderCount    = 0,
  });

  factory RestaurantTopProductModel.fromJson(Map<String, dynamic> j) =>
      RestaurantTopProductModel(
        productId:       j['productId']      ?? 0,
        productName:     j['productName']    ?? '',
        productImageUrl: j['productImageUrl'],
        totalQuantity:   _d(j['totalQuantity']),
        totalRevenue:    _d(j['totalRevenue']),
        orderCount:      j['orderCount']     ?? 0,
      );
}

class RestaurantTopCustomerModel {
  final int?    customerId;
  final String  customerName;
  final String? customerPhone;
  final int     orderCount;
  final double  totalSpent;

  const RestaurantTopCustomerModel({
    this.customerId,
    required this.customerName,
    this.customerPhone,
    this.orderCount = 0,
    this.totalSpent = 0,
  });

  factory RestaurantTopCustomerModel.fromJson(Map<String, dynamic> j) =>
      RestaurantTopCustomerModel(
        customerId:    j['customerId'],
        customerName:  j['customerName']  ?? 'Khách vãng lai',
        customerPhone: j['customerPhone'],
        orderCount:    j['orderCount']    ?? 0,
        totalSpent:    _d(j['totalSpent']),
      );
}

class RestaurantTopUserModel {
  final int    userId;
  final String userName;
  final String fullName;
  final int    orderCount;
  final double totalRevenue;

  const RestaurantTopUserModel({
    required this.userId,
    required this.userName,
    required this.fullName,
    this.orderCount   = 0,
    this.totalRevenue = 0,
  });

  factory RestaurantTopUserModel.fromJson(Map<String, dynamic> j) =>
      RestaurantTopUserModel(
        userId:       j['userId']       ?? 0,
        userName:     j['userName']     ?? '',
        fullName:     j['fullName']     ?? '',
        orderCount:   j['orderCount']   ?? 0,
        totalRevenue: _d(j['totalRevenue']),
      );
}

// ── Time Series & Region ──────────────────────────────────────────────────────

class RestaurantOrderByTimeModel {
  final String timeBucket;
  final int    orderCount;
  final double revenue;

  const RestaurantOrderByTimeModel({
    required this.timeBucket,
    this.orderCount = 0,
    this.revenue    = 0,
  });

  factory RestaurantOrderByTimeModel.fromJson(Map<String, dynamic> j) =>
      RestaurantOrderByTimeModel(
        timeBucket: j['timeBucket'] ?? '',
        orderCount: j['orderCount'] ?? 0,
        revenue:    _d(j['revenue']),
      );
}

class RestaurantRegionBreakdownModel {
  final String region;
  final int    orderCount;
  final double revenue;

  const RestaurantRegionBreakdownModel({
    required this.region,
    this.orderCount = 0,
    this.revenue    = 0,
  });

  factory RestaurantRegionBreakdownModel.fromJson(Map<String, dynamic> j) =>
      RestaurantRegionBreakdownModel(
        region:     j['region']     ?? '',
        orderCount: j['orderCount'] ?? 0,
        revenue:    _d(j['revenue']),
      );
}

// ── Recent Order ──────────────────────────────────────────────────────────────

class RestaurantRecentOrderModel {
  final int     orderId;
  final String  orderCode;
  final String? customerName;
  final int?    createdAt;
  final double  totalAmount;
  final double  discountAmount;
  final double  vatAmount;
  final double  finalAmount;
  final String  status;
  final String  paymentStatus;

  const RestaurantRecentOrderModel({
    required this.orderId,
    required this.orderCode,
    this.customerName,
    this.createdAt,
    this.totalAmount    = 0,
    this.discountAmount = 0,
    this.vatAmount      = 0,
    this.finalAmount    = 0,
    this.status         = '',
    this.paymentStatus  = '',
  });

  factory RestaurantRecentOrderModel.fromJson(Map<String, dynamic> j) =>
      RestaurantRecentOrderModel(
        orderId:        j['orderId']        ?? 0,
        orderCode:      j['orderCode']      ?? '',
        customerName:   j['customerName'],
        createdAt:      j['createdAt'],
        totalAmount:    _d(j['totalAmount']),
        discountAmount: _d(j['discountAmount']),
        vatAmount:      _d(j['vatAmount']),
        finalAmount:    _d(j['finalAmount']),
        status:         j['status']         ?? '',
        paymentStatus:  j['paymentStatus']  ?? '',
      );
}

// ── Top-level Restaurant Dashboard Model ─────────────────────────────────────

class RestaurantDashboardModel {
  final RestaurantOrderSummaryModel               orderSummary;
  final RestaurantRevenueSummaryModel             revenueSummary;
  final RestaurantCustomerSummaryModel            customerSummary;
  final RestaurantPaymentBreakdownModel           paymentBreakdown;
  final List<RestaurantTopProductModel>           topProducts;
  final List<RestaurantTopCustomerModel>          topCustomers;
  final List<RestaurantTopUserModel>              topUsers;
  final List<RestaurantOrderByTimeModel>          ordersByTime;
  final List<RestaurantRegionBreakdownModel>      regionBreakdown;
  final List<RestaurantRecentOrderModel>          recentOrders;

  const RestaurantDashboardModel({
    required this.orderSummary,
    required this.revenueSummary,
    required this.customerSummary,
    required this.paymentBreakdown,
    required this.topProducts,
    required this.topCustomers,
    required this.topUsers,
    required this.ordersByTime,
    required this.regionBreakdown,
    required this.recentOrders,
  });

  factory RestaurantDashboardModel.fromJson(Map<String, dynamic> j) =>
      RestaurantDashboardModel(
        orderSummary:     RestaurantOrderSummaryModel.fromJson(_m(j['orderSummary'])),
        revenueSummary:   RestaurantRevenueSummaryModel.fromJson(_m(j['revenueSummary'])),
        customerSummary:  RestaurantCustomerSummaryModel.fromJson(_m(j['customerSummary'])),
        paymentBreakdown: RestaurantPaymentBreakdownModel.fromJson(_m(j['paymentBreakdown'])),
        topProducts:  _list(j['topProducts'],     RestaurantTopProductModel.fromJson),
        topCustomers: _list(j['topCustomers'],    RestaurantTopCustomerModel.fromJson),
        topUsers:     _list(j['topUsers'],        RestaurantTopUserModel.fromJson),
        ordersByTime: _list(j['ordersByTime'],    RestaurantOrderByTimeModel.fromJson),
        regionBreakdown: _list(j['regionBreakdown'], RestaurantRegionBreakdownModel.fromJson),
        recentOrders: _list(j['recentOrders'],    RestaurantRecentOrderModel.fromJson),
      );
}