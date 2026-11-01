// lib/services/admin_service.dart

import 'package:dio/dio.dart';

import '../data/models/customer/customer_data_models.dart';
import '../data/models/dashboard/dashboard_period.dart';
import '../data/models/dashboard/dashboard_pos_model.dart';
import '../data/models/dashboard/dashboard_restaurant_model.dart';
import '../data/models/dashboard/pos_chart_models.dart';
import '../data/models/pos/pos_order_model.dart';
import '../data/models/pos/pos_product_model.dart';  // ← THÊM
import '../data/models/pos/pos_shift_model.dart';
import '../data/network/api_result.dart';
import '../data/network/dio_client.dart';
import '../data/models/dashboard/revenue_intelligence_model.dart';

class AdminService {
  AdminService._();
  static final AdminService instance = AdminService._();

  static const _base    = '/api/admin/dashboard';
  static const _posBase = '/api/admin';  // ← THÊM

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

  // ════════════════════════════════════════
  // GIỮ NGUYÊN CÁC METHOD CŨ
  // ════════════════════════════════════════

  Future<ApiResult<PosCustomerPageResult>> getPosCustomers({
    String? search, int page = 0, int size = 50,
  }) {
    return DioClient.instance.get<PosCustomerPageResult>(
      '/api/admin/pos-customers',
      queryParams: {
        'page': page, 'size': size,
        if (search != null) 'search': search,
      },
      fromData: (d) =>
          PosCustomerPageResult.fromJson(d as Map<String, dynamic>),
    );
  }

  Future<ApiResult<PosCustomerData>> getPosCustomerById(int id) {
    return DioClient.instance.get<PosCustomerData>(
      '/api/admin/pos-customers/$id',
      fromData: (d) =>
          PosCustomerData.fromJson(d as Map<String, dynamic>),
    );
  }

  Future<ApiResult<PosCustomerData>> createPosCustomer(
      Map<String, String> data) {
    return DioClient.instance.post<PosCustomerData>(
      '/api/admin/pos-customers',
      body: data,
      fromData: (d) =>
          PosCustomerData.fromJson(d as Map<String, dynamic>),
    );
  }

  Future<ApiResult<PosCustomerData>> updatePosCustomer(
      int id, Map<String, String> data) {
    return DioClient.instance.put<PosCustomerData>(
      '/api/admin/pos-customers/$id',
      body: data,
      fromData: (d) =>
          PosCustomerData.fromJson(d as Map<String, dynamic>),
    );
  }

  Future<ApiResult<PosDashboardModel>> getPosDashboard({
    required DashboardPeriod period,
    DateTime? fromDate, DateTime? toDate, String? filterType,
    CancelToken? cancelToken,
  }) async {
    final params = <String, dynamic>{
      'period': _periodStr(period),
      if (period == DashboardPeriod.custom && fromDate != null)
        'fromTs': fromDate.millisecondsSinceEpoch,
      if (period == DashboardPeriod.custom && toDate != null)
        'toTs': toDate.millisecondsSinceEpoch,
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

  Future<ApiResult<List<PosOrderByTimeModel>>> getPosChart({
    required DashboardPeriod period,
    DateTime? fromDate, DateTime? toDate, String? filterType,
  }) async {
    final params = <String, dynamic>{
      'period': _periodStr(period),
      if (period == DashboardPeriod.custom && fromDate != null)
        'fromTs': fromDate.millisecondsSinceEpoch,
      if (period == DashboardPeriod.custom && toDate != null)
        'toTs': toDate.millisecondsSinceEpoch,
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

  Future<ApiResult<RestaurantDashboardModel>> getRestaurantDashboard({
    DashboardPeriod period = DashboardPeriod.days30,
    DateTime? fromDate, DateTime? toDate,
    required String mode,
  }) {
    final params = <String, dynamic>{
      'period': _periodStr(period), 'mode': mode,
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

  // ════════════════════════════════════════
  // STORE
  // ════════════════════════════════════════

  Future<Map<String, dynamic>?> getStoreInfo() async {
    final res = await DioClient.instance.get<Map<String, dynamic>>(
      '$_posBase/store/info',
      fromData: (d) => d as Map<String, dynamic>,
    );
    return res.data;
  }

  Future<bool> updateStoreInfo(Map<String, dynamic> body) async {
    final res = await DioClient.instance.put(
      '$_posBase/store/info',
      body: body,
    );
    return res.isSuccess;
  }

  // ════════════════════════════════════════
  // CATEGORY
  // ════════════════════════════════════════

  Future<List<PosCategoryModel>> getCategories({
    bool includeDefault = false,
  }) async {
    final res = await DioClient.instance.get<List<PosCategoryModel>>(
      '$_posBase/categories'
          '${includeDefault ? '?includeDefault=true' : ''}',
      fromData: (d) => (d as List)
          .map((e) =>
          PosCategoryModel.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
    return res.data ?? [];
  }

  Future<bool> createCategory(Map<String, dynamic> body) async {
    final res = await DioClient.instance.post(
      '$_posBase/categories',
      body: body,
    );
    return res.isSuccess;
  }

  Future<bool> updateCategory(int id, Map<String, dynamic> body) async {
    final res = await DioClient.instance.put(
      '$_posBase/categories/$id',
      body: body,
    );
    return res.isSuccess;
  }

  Future<void> deleteCategory(int id) async {
    await DioClient.instance.delete('$_posBase/categories/$id');
  }

  // ════════════════════════════════════════
  // INGREDIENT
  // ════════════════════════════════════════

  Future<List<Map<String, dynamic>>> getIngredients() async {
    final res = await DioClient.instance
        .get<List<Map<String, dynamic>>>(
      '$_posBase/ingredients',
      fromData: (d) => (d as List)
          .map((e) => e as Map<String, dynamic>)
          .toList(),
    );
    return res.data ?? [];
  }

  Future<bool> createIngredient(Map<String, dynamic> body) async {
    final res = await DioClient.instance.post(
      '$_posBase/ingredients',
      body: body,
    );
    return res.isSuccess;
  }

  Future<bool> updateIngredient(
      int id, Map<String, dynamic> body) async {
    final res = await DioClient.instance.put(
      '$_posBase/ingredients/$id',
      body: body,
    );
    return res.isSuccess;
  }

  Future<void> deleteIngredient(int id) async {
    await DioClient.instance.delete('$_posBase/ingredients/$id');
  }

  // ════════════════════════════════════════
  // PRODUCT
  // ════════════════════════════════════════

  Future<List<PosProductModel>> getProducts({int? categoryId}) async {
    final query = categoryId != null ? '?categoryId=$categoryId' : '';
    final res = await DioClient.instance.get<List<PosProductModel>>(
      '$_posBase/products$query',
      fromData: (d) => (d as List)
          .map((e) => PosProductModel.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
    return res.data ?? [];
  }

  Future<List<PosShiftModel>> getShifts({String? search}) async {
    final res = await DioClient.instance.get<List<PosShiftModel>>(
      '$_posBase/shifts',
      queryParams: {
        if (search != null && search.isNotEmpty) 'search': search,
      },
      fromData: (d) => (d as List)
          .map((e) => PosShiftModel.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
    if (res.isSuccess && res.data != null) return res.data!;
    throw Exception(res.message);
  }

  Future<List<PosOrderModel>> getOrdersByShift(int shiftId) async {
    final res = await DioClient.instance.get<List<PosOrderModel>>(
      '$_posBase/shifts/$shiftId/orders',
      fromData: (d) => (d as List)
          .map((e) => PosOrderModel.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
    if (res.isSuccess && res.data != null) return res.data!;
    throw Exception(res.message);
  }

  Future<PosProductModel> createProduct(Map<String, dynamic> body) async {
    final res = await DioClient.instance.post<PosProductModel>(
      '$_posBase/products',
      body: body,
      fromData: (d) => PosProductModel.fromJson(_asMap(d)),
    );
    if (res.isSuccess && res.data != null) return res.data!;
    throw Exception(res.message);
  }

  Future<PosProductModel> updateProduct(int id, Map<String, dynamic> body) async {
    final res = await DioClient.instance.put<PosProductModel>(
      '$_posBase/products/$id',
      body: body,
      fromData: (d) => PosProductModel.fromJson(_asMap(d)),
    );
    if (res.isSuccess && res.data != null) return res.data!;
    throw Exception(res.message);
  }

  Future<void> deleteProduct(int id) async {
    final res = await DioClient.instance.delete('$_posBase/products/$id');
    if (!res.isSuccess) throw Exception(res.message);
  }

  static Map<String, dynamic> _asMap(dynamic d) =>
      d as Map<String, dynamic>;

  // ════════════════════════════════════════
  // VARIANT
  // ════════════════════════════════════════

  Future<bool> createVariant(Map<String, dynamic> body) async {
    final res = await DioClient.instance.post(
      '$_posBase/variants',
      body: body,
    );
    return res.isSuccess;
  }

  Future<bool> updateVariant(
      int id, Map<String, dynamic> body) async {
    final res = await DioClient.instance.put(
      '$_posBase/variants/$id',
      body: body,
    );
    return res.isSuccess;
  }

  Future<void> deleteVariant(int id) async {
    await DioClient.instance.delete('$_posBase/variants/$id');
  }

  // ════════════════════════════════════════
  // ADVANCED CHARTS (dành cho Admin)
  // Lưu ý: Không cần truyền storeId vì backend tự resolve từ
  // pos_user_store dựa trên user trong JWT token
  // (xem AdminController#resolveStoreId / posChartService.resolveStoreId)
  // ════════════════════════════════════════

  /// Lấy danh sách danh mục để filter chart
  /// ← FIX: endpoint đúng là /api/admin/dashboard/charts/categories
  /// (trước đây gọi sai sang $_posBase/charts/categories → 404 → rỗng)
  Future<ApiResult<List<CategoryItem>>> getChartCategories({CancelToken? cancelToken}) {
    return DioClient.instance.get<List<CategoryItem>>(
      '$_base/charts/categories',
        cancelToken: cancelToken, fromData: (d) => d != null
          ? (d as List)
          .whereType<Map<String, dynamic>>()
          .map((e) => CategoryItem.fromJson(e))
          .toList()
          : <CategoryItem>[],
    );
  }

  /// Monthly Shift Chart (Doanh thu & Đơn hàng theo ca)
  /// ← FIX: endpoint đúng là /api/admin/dashboard/charts/period-shift
  /// (trước đây gọi sai sang $_posBase/charts/monthly-shift → 404 → rỗng)
  Future<ApiResult<List<PeriodShiftPoint>>> getPeriodShift({
    required int fromTs,
    required int toTs,
    required String periodUnit,
    List<String>? categories, CancelToken? cancelToken,
  }) async {
    final params = <String, dynamic>{
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

  /// Monthly Stacked Chart (Phân bổ theo ca hoặc theo danh mục)
  /// ← FIX: endpoint đúng là /api/admin/dashboard/charts/period-stacked
  /// (trước đây gọi sai sang $_posBase/charts/monthly-stacked → 404 → rỗng)
  Future<ApiResult<List<PeriodStackedPoint>>> getPeriodStacked({
    required int fromTs,
    required int toTs,
    required String periodUnit,
    List<String>? categories, CancelToken? cancelToken,

  }) async {
    final params = <String, dynamic>{
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
      cancelToken: cancelToken ,fromData: (d) => (d as List)
          .map((e) => PeriodStackedPoint.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  /// Danh sách sản phẩm để filter heatmap
  /// Giữ nguyên $_posBase — endpoint backend là /api/admin/charts/products
  /// (route này nằm ngoài nhóm /dashboard trong AdminController)
  Future<ApiResult<List<HeatmapProduct>>> getHeatmapProducts({CancelToken? cancelToken}) {
    return DioClient.instance.get<List<HeatmapProduct>>(
      '$_posBase/charts/products',
      cancelToken: cancelToken, fromData: (d) => d != null
          ? (d as List)
          .whereType<Map<String, dynamic>>()
          .map((e) => HeatmapProduct.fromJson(e))
          .toList()
          : <HeatmapProduct>[],
    );
  }

  /// Heatmap đơn hàng theo giờ/ngày trong tuần
  /// ← FIX: endpoint đúng là /api/admin/dashboard/charts/heatmap
  /// (trước đây gọi sai sang $_posBase/charts/heatmap → 404 → rỗng)
  Future<ApiResult<List<HeatmapCell>>> getHeatmap({
    int periodMinutes = 60,
    int fromTs = 0,
    int toTs   = 0,
    List<int> productIds = const [], CancelToken? cancelToken,
  }) {
    return DioClient.instance.get<List<HeatmapCell>>(
      '$_base/charts/heatmap',
      queryParams: {
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
    int periodMinutes = 60,
    int fromTs = 0,
    int toTs   = 0,
    List<int> productIds = const [], CancelToken? cancelToken,
  }) {
    return DioClient.instance.get<List<HeatmapCell>>(
      '$_base/charts/product-heatmap',
      queryParams: {
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
    int periodMinutes = 60,
    int fromTs = 0,
    int toTs   = 0,
    List<int> ingredientIds = const [],CancelToken? cancelToken,
  }) {
    return DioClient.instance.get<List<HeatmapCell>>(
      '$_base/charts/ingredient-heatmap',
      queryParams: {
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
  Future<ApiResult<List<HeatmapProduct>>> getMainIngredients({CancelToken? cancelToken}) {
    return DioClient.instance.get<List<HeatmapProduct>>(
      '$_base/charts/main-ingredients',
      cancelToken: cancelToken,
      fromData: (d) => d != null
          ? (d as List)
          .whereType<Map<String, dynamic>>()
          .map((e) => HeatmapProduct.fromJson(e))
          .toList()
          : <HeatmapProduct>[],
    );
  }

  Future<ApiResult<RevenueIntelligenceResponse>> getRevenueIntelligence({
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
}