// lib/services/super_admin_service.dart

import 'package:dio/dio.dart';

import '../data/models/customer/customer_data_models.dart';
import '../data/models/dashboard/dashboard_period.dart';
import '../data/models/dashboard/dashboard_pos_model.dart';
import '../data/models/dashboard/dashboard_restaurant_model.dart';
import '../data/models/dashboard/dashboard_vehicle_model.dart';
import '../data/models/dashboard/pos_chart_models.dart';
import '../data/models/dashboard/rolling_performance_model.dart';
import '../data/network/api_result.dart';
import '../data/network/dio_client.dart';
import '../data/models/dashboard/revenue_intelligence_model.dart';

class SuperAdminService {
  SuperAdminService._();
  static final SuperAdminService instance = SuperAdminService._();

  static const _base = '/api/superadmin/dashboard';

  // ── Helper ────────────────────────────────────────────────────
  static String _periodStr(DashboardPeriod p) => switch (p) {
    DashboardPeriod.today   => 'TODAY',
    DashboardPeriod.days7   => '7DAYS',
    DashboardPeriod.days28  => '28DAYS',
    DashboardPeriod.days30  => '30DAYS',
    DashboardPeriod.months3 => '3MONTHS',
    DashboardPeriod.months6 => '6MONTHS',
    DashboardPeriod.year    => 'YEAR',
    DashboardPeriod.custom  => 'CUSTOM',
  };

  Future<ApiResult<PosCustomerPageResult>> getPosCustomers({
    int? storeId,    // null = tất cả stores
    String? search,
    int page = 0,
    int size = 50,
  }) {
    return DioClient.instance.get<PosCustomerPageResult>(
      '/api/superadmin/pos-customers',
      queryParams: {
        'page': page,
        'size': size,
        if (storeId != null) 'storeId': storeId,
        if (search  != null) 'search':  search,
      },
      fromData: (d) {
        // Endpoint trả về List thẳng (không có pagination wrapper)
        // → wrap lại thành PageResult
        if (d is List) {
          final content = d
              .map((e) => PosCustomerData.fromJson(e as Map<String, dynamic>))
              .toList();
          return PosCustomerPageResult(
            content:     content,
            totalItems:  content.length,
            currentPage: 0,
            totalPages:  1,
          );
        }
        return PosCustomerPageResult.fromJson(d as Map<String, dynamic>);
      },
    );
  }



  Future<ApiResult<PosCustomerData>> getPosCustomerById(int id) {
    return DioClient.instance.get<PosCustomerData>(
      '/api/superadmin/pos-customers/$id',
      fromData: (d) => PosCustomerData.fromJson(d as Map<String, dynamic>),
    );
  }

  /// storeId bắt buộc khi superAdmin tạo POS customer
  Future<ApiResult<PosCustomerData>> createPosCustomer(
      Map<String, dynamic> data) {
    return DioClient.instance.post<PosCustomerData>(
      '/api/superadmin/pos-customers',
      body: data,
      fromData: (d) => PosCustomerData.fromJson(d as Map<String, dynamic>),
    );
  }

  Future<ApiResult<PosCustomerData>> updatePosCustomer(
      int id, Map<String, String> data) {
    return DioClient.instance.put<PosCustomerData>(
      '/api/superadmin/pos-customers/$id',
      body: data,
      fromData: (d) => PosCustomerData.fromJson(d as Map<String, dynamic>),
    );
  }

// ══════════════════════════════════════════════════════════════════
// B2B CUSTOMERS — thêm vào class SuperAdminService
// Endpoints: /api/superadmin/b2b-customers
// ══════════════════════════════════════════════════════════════════

  Future<ApiResult<B2bCustomerPageResult>> getB2bCustomers({
    String? type,
    String? search,
    int page = 0,
    int size = 50,
  }) {
    return DioClient.instance.get<B2bCustomerPageResult>(
      '/api/superadmin/b2b-customers',
      queryParams: {
        'page': page,
        'size': size,
        if (type   != null) 'type':   type,
        if (search != null) 'search': search,
      },
      fromData: (d) => B2bCustomerPageResult.fromJson(d as Map<String, dynamic>),
    );
  }

  Future<ApiResult<B2bCustomerData>> getB2bCustomerById(int id) {
    return DioClient.instance.get<B2bCustomerData>(
      '/api/superadmin/b2b-customers/$id',
      fromData: (d) => B2bCustomerData.fromJson(d as Map<String, dynamic>),
    );
  }

  Future<ApiResult<B2bCustomerData>> createB2bCustomer(
      Map<String, dynamic> data) {
    return DioClient.instance.post<B2bCustomerData>(
      '/api/superadmin/b2b-customers',
      body: data,
      fromData: (d) => B2bCustomerData.fromJson(d as Map<String, dynamic>),
    );
  }

  Future<ApiResult<B2bCustomerData>> updateB2bCustomer(
      int id, Map<String, dynamic> data) {
    return DioClient.instance.put<B2bCustomerData>(
      '/api/superadmin/b2b-customers/$id',
      body: data,
      fromData: (d) => B2bCustomerData.fromJson(d as Map<String, dynamic>),
    );
  }

  // ── POS Vehicles ──────────────────────────────────────────────
  Future<ApiResult<List<PosVehicle>>> getVehicles() {
    return DioClient.instance.get<List<PosVehicle>>(
      '$_base/pos/vehicles',
      fromData: (d) => d != null
          ? (d as List)
          .whereType<Map<String, dynamic>>()
          .map(PosVehicle.fromJson)
          .toList()
          : <PosVehicle>[],
    );
  }

  // ── POS Dashboard (full) ──────────────────────────────────────
  Future<ApiResult<PosDashboardModel>> getPosDashboard({
    required DashboardPeriod period,
    DateTime? fromDate,
    DateTime? toDate,
    int?      vehicleId,
    String?   filterType,
    CancelToken? cancelToken,
  }) async {
    final params = <String, dynamic>{
      'period': _periodStr(period),
      if (period == DashboardPeriod.custom && fromDate != null)
        'fromTs': fromDate.millisecondsSinceEpoch,
      if (period == DashboardPeriod.custom && toDate != null)
        'toTs': toDate.millisecondsSinceEpoch,
      if (vehicleId  != null) 'vehicleId':  vehicleId,
      if (filterType != null) 'filterType': filterType,
    };
    return DioClient.instance.get<PosDashboardModel>(
      '$_base/pos',
      queryParams: params,
      cancelToken: cancelToken,
      fromData: (d) => d != null
          ? PosDashboardModel.fromJson(d as Map<String, dynamic>)
          : null,
    );
  }

  // ── POS Chart only (ordersByTime) ────────────────────────────
  Future<ApiResult<List<PosOrderByTimeModel>>> getPosChart({
    required DashboardPeriod period,
    DateTime? fromDate,
    DateTime? toDate,
    int?      vehicleId,
    String?   filterType,
  }) async {
    final params = <String, dynamic>{
      'period': _periodStr(period),
      if (period == DashboardPeriod.custom && fromDate != null)
        'fromTs': fromDate.millisecondsSinceEpoch,
      if (period == DashboardPeriod.custom && toDate != null)
        'toTs': toDate.millisecondsSinceEpoch,
      if (vehicleId  != null) 'vehicleId':  vehicleId,
      if (filterType != null) 'filterType': filterType,
    };
    return DioClient.instance.get<List<PosOrderByTimeModel>>(
      '$_base/pos/chart',
      queryParams: params,
      fromData: (d) => d != null
          ? (d as List)
          .whereType<Map<String, dynamic>>()
          .map(PosOrderByTimeModel.fromJson)
          .toList()
          : <PosOrderByTimeModel>[],
    );
  }

  // ── Restaurant Dashboard ──────────────────────────────────────
  // ── Rolling Performance (cửa sổ trượt 7 / 28 / 30 ngày) ───────────
  Future<ApiResult<RollingPerformanceModel>> getPosRolling({
    required int window,          // 7 | 28 | 30
    int?      vehicleId,
    String?   filterType,         // ALL / TAKE_AWAY / DINE_IN / SHOPEE_FOOD / GRAB_FOOD
    DateTime? anchor,             // mặc định = hiện tại (BE tự lấy now)
  }) async {
    final params = <String, dynamic>{
      'window': window,
      if (anchor    != null) 'anchorTs':   anchor.millisecondsSinceEpoch,
      if (vehicleId != null) 'vehicleId':  vehicleId,
      if (filterType != null) 'filterType': filterType,
    };
    return DioClient.instance.get<RollingPerformanceModel>(
      '$_base/pos/rolling',
      queryParams: params,
      fromData: (d) => d != null
          ? RollingPerformanceModel.fromJson(d as Map<String, dynamic>)
          : null,
    );
  }

  Future<ApiResult<RevenueIntelligenceResponse>> getRevenueIntelligence({
    required int storeId,
    required int fromTs,
    required int toTs,
    int shortWindow = 7,
    int longWindow = 28,
    double alpha = 0.5,
    double normalThreshold = 0.10,
    double alertThreshold = 0.20,
    CancelToken? cancelToken,
  }) {
    return DioClient.instance.get<RevenueIntelligenceResponse>(
      '$_base/pos/revenue-intelligence',
      queryParams: {
        'storeId':          storeId,
        'fromTs':           fromTs,
        'toTs':             toTs,
        'shortWindow':      shortWindow,
        'longWindow':       longWindow,
        'alpha':            alpha,
        'normalThreshold':  normalThreshold,
        'alertThreshold':   alertThreshold,
      },
      cancelToken: cancelToken,
      fromData: (d) => d != null
          ? RevenueIntelligenceResponse.fromJson(d as Map<String, dynamic>)
          : null,
    );
  }

  Future<ApiResult<RestaurantDashboardModel>> getRestaurantDashboard({
    DashboardPeriod period   = DashboardPeriod.days30,
    DateTime?       fromDate,
    DateTime?       toDate,
    required String mode,
  }) {
    final params = <String, dynamic>{
      'period': _periodStr(period),
      'mode':   mode,
    };
    if (period == DashboardPeriod.custom) {
      if (fromDate != null)
        params['fromTs'] = fromDate.millisecondsSinceEpoch.toString();
      if (toDate != null)
        params['toTs'] = toDate.millisecondsSinceEpoch.toString();
    }
    return DioClient.instance.get<RestaurantDashboardModel>(
      '$_base/restaurant',
      queryParams: params,
      fromData: (d) => d != null
          ? RestaurantDashboardModel.fromJson(d as Map<String, dynamic>)
          : null,
    );
  }

  // ── CHARTS ────────────────────────────────────────────────────────
  // Get categories
  Future<ApiResult<List<CategoryItem>>> getChartCategories({
    required int storeId, CancelToken? cancelToken,
  }) {
    return DioClient.instance.get<List<CategoryItem>>(
      '$_base/charts/categories',
      queryParams: {'storeId': storeId},
      cancelToken: cancelToken,
      fromData: (d) => (d as List)
          .map((e) => CategoryItem.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  // Monthly Shift Chart
  Future<ApiResult<List<PeriodShiftPoint>>> getPeriodShift({
    required int storeId,
    required int fromTs,
    required int toTs,
    required String periodUnit,
    List<String>? categories,
    CancelToken? cancelToken,
  }) async {
    final params = <String, dynamic>{
      'storeId':    storeId,
      'fromTs':     fromTs,
      'toTs':       toTs,
      'periodUnit': periodUnit,
    };
    if (categories != null && categories.isNotEmpty) {
      params['categories'] = categories;
    }
    return DioClient.instance.get<List<PeriodShiftPoint>>(
      '$_base/charts/period-shift',
      queryParams: params,
      cancelToken: cancelToken,
      fromData: (d) => (d as List)
          .map((e) => PeriodShiftPoint.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  // Monthly Stacked Chart
  Future<ApiResult<List<PeriodStackedPoint>>> getPeriodStacked({
    required int storeId,
    required int fromTs,
    required int toTs,
    required String periodUnit,
    List<String>? categories,
    CancelToken? cancelToken,
  }) async {
    final params = <String, dynamic>{
      'storeId':    storeId,
      'fromTs':     fromTs,
      'toTs':       toTs,
      'periodUnit': periodUnit,
    };
    if (categories != null && categories.isNotEmpty) {
      params['categories'] = categories;
    }
    return DioClient.instance.get<List<PeriodStackedPoint>>(
      '$_base/charts/period-stacked',
      queryParams: params,
      cancelToken: cancelToken,
      fromData: (d) => (d as List)
          .map((e) => PeriodStackedPoint.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  // Heatmap
  Future<ApiResult<List<HeatmapProduct>>> getHeatmapProducts({
    required int storeId, CancelToken? cancelToken,
  }) {
    return DioClient.instance.get<List<HeatmapProduct>>(
      '$_base/charts/products',  // hoặc endpoint products của superadmin
      queryParams: {'storeId': storeId},
      cancelToken: cancelToken,
      fromData: (d) => d != null
          ? (d as List)
          .whereType<Map<String, dynamic>>()
          .map((e) => HeatmapProduct.fromJson(e))
          .toList()
          : <HeatmapProduct>[],
    );
  }

  Future<ApiResult<List<HeatmapCell>>> getHeatmap({
    required int storeId, CancelToken? cancelToken,
    int periodMinutes = 60,
    int fromTs = 0,
    int toTs   = 0,
    List<int> productIds = const [],
  }) {
    return DioClient.instance.get<List<HeatmapCell>>(
      '$_base/charts/heatmap',
      queryParams: {
        'storeId':       storeId,
        'periodMinutes': periodMinutes,
        'fromTs':        fromTs,
        'toTs':          toTs,
        if (productIds.isNotEmpty) 'productIds': productIds,
      },
      cancelToken: cancelToken,
      fromData: (d) => d != null
          ? (d as List)
          .whereType<Map<String, dynamic>>()
          .map((e) => HeatmapCell.fromJson(e))
          .toList()
          : <HeatmapCell>[],
    );
  }

  Future<ApiResult<List<HeatmapCell>>> getProductHeatmap({
    required int storeId,
    int periodMinutes = 60,
    int fromTs = 0,
    int toTs   = 0,
    List<int> productIds = const [],
    CancelToken? cancelToken,
  }) {
    return DioClient.instance.get<List<HeatmapCell>>(
      '$_base/charts/product-heatmap',
      queryParams: {
        'storeId':       storeId,
        'periodMinutes': periodMinutes,
        'fromTs':        fromTs,
        'toTs':          toTs,
        if (productIds.isNotEmpty) 'productIds': productIds,
      },
      cancelToken: cancelToken,
      fromData: (d) => d != null
          ? (d as List)
          .whereType<Map<String, dynamic>>()
          .map((e) => HeatmapCell.fromJson(e))
          .toList()
          : <HeatmapCell>[],
    );
  }

  // ── Ingredient Heatmap ────────────────────────────────────────
  Future<ApiResult<List<HeatmapCell>>> getIngredientHeatmap({
    required int storeId,
    int periodMinutes = 60,
    int fromTs = 0,
    int toTs   = 0,
    List<int> ingredientIds = const [],
    CancelToken? cancelToken,
  }) {
    return DioClient.instance.get<List<HeatmapCell>>(
      '$_base/charts/ingredient-heatmap',
      queryParams: {
        'storeId':       storeId,
        'periodMinutes': periodMinutes,
        'fromTs':        fromTs,
        'toTs':          toTs,
        if (ingredientIds.isNotEmpty) 'ingredientIds': ingredientIds,
      },
      cancelToken: cancelToken,
      fromData: (d) => d != null
          ? (d as List)
          .whereType<Map<String, dynamic>>()
          .map((e) => HeatmapCell.fromJson(e))
          .toList()
          : <HeatmapCell>[],
    );
  }

  // ── Main Ingredients list (for filter dropdown) ───────────────
  Future<ApiResult<List<HeatmapProduct>>> getMainIngredients({
    required int storeId, CancelToken? cancelToken,
  }) {
    return DioClient.instance.get<List<HeatmapProduct>>(
      '$_base/charts/main-ingredients',
      queryParams: {'storeId': storeId},
      cancelToken: cancelToken,
      fromData: (d) => d != null
          ? (d as List)
          .whereType<Map<String, dynamic>>()
          .map((e) => HeatmapProduct.fromJson(e))
          .toList()
          : <HeatmapProduct>[],
    );
  }
}