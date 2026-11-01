// lib/features/dashboard/controller/dashboard_controller.dart

import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/enums/user_role.dart';
import '../../../data/models/dashboard/dashboard_period.dart';
import '../../../data/models/dashboard/rolling_performance_model.dart';
import '../../../data/models/dashboard/dashboard_pos_model.dart';
import '../../../data/models/dashboard/dashboard_restaurant_model.dart';
import '../../../data/models/dashboard/dashboard_vehicle_model.dart';
import '../../../data/models/dashboard/pos_chart_models.dart';
import '../../../data/network/api_result.dart';
import '../../../data/network/error_handler.dart';
import '../../../features/auth/controller/auth_controller.dart';
import '../../../services/admin_service.dart';
import '../../../services/super_admin_service.dart';
import '../../../data/models/dashboard/revenue_intelligence_model.dart';

enum DashboardMode { pos, wholesale, retail }

class DashboardState {
  final DashboardMode mode;
  final DashboardPeriod period;
  final DateTime? customFrom;
  final DateTime? customTo;
  final List<HeatmapProduct> heatmapProducts;
  final Set<int>             selectedProductIds;

  // Product heatmap
  final List<HeatmapCell>  productHeatmap;
  final Set<int>           selectedProductHeatmapIds;

  // Ingredient heatmap
  final List<HeatmapCell>    ingredientHeatmap;
  final List<HeatmapProduct> heatmapIngredients;
  final Set<int>             selectedIngredientIds;

  // Revenue Intelligence
  final bool riLoading;
  final String? riError;
  final RevenueIntelligenceResponse? riData;

  final bool posLoading;
  final String? posError;
  final PosDashboardModel? posData;
  final int posAnimationKey;

  final bool restaurantLoading;
  final String? restaurantError;
  final RestaurantDashboardModel? restaurantData;

  final bool vehiclesLoading;
  final bool vehicleSearching;
  final List<PosVehicle> vehicles;
  final List<PosVehicle> filteredVehicles;
  final PosVehicle? selectedVehicle;

  final String chartFilterType;
  final bool chartLoading;
  final List<PosOrderByTimeModel> chartOrdersByTime;

  // Rolling Performance (cửa sổ trượt) — chỉ SUPERADMIN
  final int?                     rollingWindow;
  final bool                     rollingLoading;
  final String?                  rollingError;
  final RollingPerformanceModel? rollingData;

  // Advanced Charts
  final bool advancedChartsLoading;
  final String? advancedChartsError;
  final List<CategoryItem>       categories;
  final List<PeriodShiftPoint>   shiftData;
  final List<PeriodStackedPoint> stackedData;
  final List<HeatmapCell>        heatmap;
  final Set<String>              selectedCategories;

  const DashboardState({
    this.mode = DashboardMode.pos,
    this.period = DashboardPeriod.days30,
    this.customFrom,
    this.customTo,
    this.posLoading = false,
    this.posError,
    this.posData,
    this.posAnimationKey = 0,
    this.restaurantLoading = false,
    this.restaurantError,
    this.restaurantData,
    this.vehiclesLoading = false,
    this.vehicleSearching = false,
    this.vehicles = const [],
    this.filteredVehicles = const [],
    this.selectedVehicle,
    this.chartFilterType = 'ALL',
    this.chartLoading = false,
    this.chartOrdersByTime = const [],

    this.rollingWindow,
    this.rollingLoading = false,
    this.rollingError,
    this.rollingData,

    this.advancedChartsLoading = false,
    this.advancedChartsError,
    this.categories = const [],
    this.shiftData = const [],
    this.stackedData = const [],
    this.heatmap = const [],
    this.selectedCategories = const {},

    this.heatmapProducts            = const [],
    this.selectedProductIds         = const {},
    this.productHeatmap             = const [],
    this.selectedProductHeatmapIds  = const {},
    this.ingredientHeatmap          = const [],
    this.heatmapIngredients         = const [],
    this.selectedIngredientIds      = const {},
    this.riLoading = false,
    this.riError,
    this.riData,
  });

  DashboardState copyWith({
    DashboardMode? mode,
    DashboardPeriod? period,
    DateTime? customFrom,
    bool clearCustomFrom = false,
    DateTime? customTo,
    bool clearCustomTo = false,
    bool? posLoading,
    String? posError,
    bool clearPosError = false,
    PosDashboardModel? posData,
    int? posAnimationKey,
    bool? restaurantLoading,
    String? restaurantError,
    bool clearRestaurantError = false,
    RestaurantDashboardModel? restaurantData,
    bool clearRestaurantData = false,
    bool? vehiclesLoading,
    bool? vehicleSearching,
    List<PosVehicle>? vehicles,
    List<PosVehicle>? filteredVehicles,
    PosVehicle? selectedVehicle,
    bool clearSelectedVehicle = false,
    String? chartFilterType,
    bool? chartLoading,
    List<PosOrderByTimeModel>? chartOrdersByTime,

    int?  rollingWindow,
    bool  clearRollingWindow = false,
    bool? rollingLoading,
    String? rollingError,
    bool  clearRollingError = false,
    RollingPerformanceModel? rollingData,
    bool  clearRollingData = false,

    bool? advancedChartsLoading,
    String? advancedChartsError,
    bool clearAdvancedChartsError = false,
    List<CategoryItem>? categories,
    List<PeriodShiftPoint>? shiftData,
    List<PeriodStackedPoint>? stackedData,
    List<HeatmapCell>? heatmap,
    Set<String>? selectedCategories,
    List<HeatmapProduct>? heatmapProducts,
    Set<int>?             selectedProductIds,

    List<HeatmapCell>?    productHeatmap,
    Set<int>?             selectedProductHeatmapIds,
    List<HeatmapCell>?    ingredientHeatmap,
    List<HeatmapProduct>? heatmapIngredients,
    Set<int>?             selectedIngredientIds,
    bool? riLoading,
    String? riError,
    bool clearRiError = false,
    RevenueIntelligenceResponse? riData,
    bool clearRiData = false,
  }) =>
      DashboardState(
        mode: mode ?? this.mode,
        period: period ?? this.period,
        customFrom: clearCustomFrom ? null : (customFrom ?? this.customFrom),
        customTo: clearCustomTo ? null : (customTo ?? this.customTo),
        posLoading: posLoading ?? this.posLoading,
        posError: clearPosError ? null : (posError ?? this.posError),
        posData: posData ?? this.posData,
        posAnimationKey: posAnimationKey ?? this.posAnimationKey,
        restaurantLoading: restaurantLoading ?? this.restaurantLoading,
        restaurantError: clearRestaurantError ? null : (restaurantError ?? this.restaurantError),
        restaurantData: clearRestaurantData ? null : (restaurantData ?? this.restaurantData),
        vehiclesLoading: vehiclesLoading ?? this.vehiclesLoading,
        vehicleSearching: vehicleSearching ?? this.vehicleSearching,
        vehicles: vehicles ?? this.vehicles,
        filteredVehicles: filteredVehicles ?? this.filteredVehicles,
        selectedVehicle: clearSelectedVehicle ? null : (selectedVehicle ?? this.selectedVehicle),
        chartFilterType: chartFilterType ?? this.chartFilterType,
        chartLoading: chartLoading ?? this.chartLoading,
        chartOrdersByTime: chartOrdersByTime ?? this.chartOrdersByTime,

        rollingWindow: clearRollingWindow ? null : (rollingWindow ?? this.rollingWindow),
        rollingLoading: rollingLoading ?? this.rollingLoading,
        rollingError: clearRollingError ? null : (rollingError ?? this.rollingError),
        rollingData: clearRollingData ? null : (rollingData ?? this.rollingData),

        advancedChartsLoading: advancedChartsLoading ?? this.advancedChartsLoading,
        advancedChartsError: clearAdvancedChartsError ? null : (advancedChartsError ?? this.advancedChartsError),
        categories: categories ?? this.categories,
        shiftData: shiftData ?? this.shiftData,
        stackedData: stackedData ?? this.stackedData,
        heatmap: heatmap ?? this.heatmap,
        selectedCategories: selectedCategories ?? this.selectedCategories,
        heatmapProducts:    heatmapProducts    ?? this.heatmapProducts,
        selectedProductIds: selectedProductIds ?? this.selectedProductIds,

        productHeatmap:            productHeatmap            ?? this.productHeatmap,
        selectedProductHeatmapIds: selectedProductHeatmapIds ?? this.selectedProductHeatmapIds,
        ingredientHeatmap:         ingredientHeatmap         ?? this.ingredientHeatmap,
        heatmapIngredients:        heatmapIngredients        ?? this.heatmapIngredients,
        selectedIngredientIds:     selectedIngredientIds     ?? this.selectedIngredientIds,
        riLoading: riLoading ?? this.riLoading,
        riError: clearRiError ? null : (riError ?? this.riError),
        riData: clearRiData ? null : (riData ?? this.riData),
      );
}

final dashboardControllerProvider = NotifierProvider<DashboardController, DashboardState>(
  DashboardController.new,
);

class DashboardController extends Notifier<DashboardState> {
  int _loadGeneration = 0;
  Timer? _reloadDebounce;
  Timer? _vehicleDebounce;

  CancelToken? _cancelToken;

  CancelToken _freshCancelToken() {
    _cancelToken?.cancel('User changed selection');
    _cancelToken = CancelToken();
    return _cancelToken!;
  }

  UserRole get _role => ref.read(authControllerProvider).role ?? UserRole.admin;
  bool get _isSuperAdmin => _role == UserRole.superAdmin;

  // ── Product Heatmap ─────────────────────────────────────────
  Future<void> loadProductHeatmap({int periodMinutes = 60}) async {
    state = state.copyWith(advancedChartsLoading: true);
    try {
      final isSuper    = _isSuperAdmin;
      final storeId    = state.selectedVehicle?.id;
      final fromTs     = _resolveFromTs();
      final toTs       = _resolveToTs();
      final productIds = state.selectedProductHeatmapIds.toList();

      final result = isSuper && storeId != null
          ? await SuperAdminService.instance.getProductHeatmap(
          storeId: storeId, periodMinutes: periodMinutes,
          fromTs: fromTs, toTs: toTs, productIds: productIds)
          : await AdminService.instance.getProductHeatmap(
          periodMinutes: periodMinutes,
          fromTs: fromTs, toTs: toTs, productIds: productIds);

      if (result.isSuccess && result.data != null) {
        state = state.copyWith(
          advancedChartsLoading: false,
          productHeatmap: result.data as List<HeatmapCell>,
        );
      } else {
        state = state.copyWith(advancedChartsLoading: false);
      }
    } catch (_) {
      state = state.copyWith(advancedChartsLoading: false);
    }
  }

  Future<void> applyProductHeatmapFilter(Set<int> ids) async {
    state = state.copyWith(selectedProductHeatmapIds: ids);
    await loadProductHeatmap();
  }

  // ── Ingredient Heatmap ──────────────────────────────────────
  Future<void> loadIngredientHeatmap({int periodMinutes = 60}) async {
    state = state.copyWith(advancedChartsLoading: true);
    try {
      final isSuper       = _isSuperAdmin;
      final storeId       = state.selectedVehicle?.id;
      final fromTs        = _resolveFromTs();
      final toTs          = _resolveToTs();
      final ingredientIds = state.selectedIngredientIds.toList();

      final result = isSuper && storeId != null
          ? await SuperAdminService.instance.getIngredientHeatmap(
          storeId: storeId, periodMinutes: periodMinutes,
          fromTs: fromTs, toTs: toTs, ingredientIds: ingredientIds)
          : await AdminService.instance.getIngredientHeatmap(
          periodMinutes: periodMinutes,
          fromTs: fromTs, toTs: toTs, ingredientIds: ingredientIds);

      if (result.isSuccess && result.data != null) {
        state = state.copyWith(
          advancedChartsLoading: false,
          ingredientHeatmap: result.data as List<HeatmapCell>,
        );
      } else {
        state = state.copyWith(advancedChartsLoading: false);
      }
    } catch (_) {
      state = state.copyWith(advancedChartsLoading: false);
    }
  }

  Future<void> applyIngredientHeatmapFilter(Set<int> ids) async {
    state = state.copyWith(selectedIngredientIds: ids);
    await loadIngredientHeatmap();
  }

  // ── Order Heatmap (giữ nguyên) ─────────────────────────────
  Future<void> loadHeatmapProducts() async {
    try {
      final isSuper = _isSuperAdmin;
      final storeId = state.selectedVehicle?.id;
      final cancelToken = _freshCancelToken();
      final result = isSuper && storeId != null
          ? await SuperAdminService.instance.getHeatmapProducts(
        storeId: storeId,
        cancelToken: cancelToken,
      )
          : await AdminService.instance.getHeatmapProducts(
        cancelToken: cancelToken,
      );
      if (result.isSuccess && result.data != null) {
        final sorted = List<HeatmapProduct>.from(result.data!)
          ..sort((a, b) => a.name.compareTo(b.name));
        state = state.copyWith(heatmapProducts: sorted);
      }
    } catch (_) {}
  }

  Future<void> applyHeatmapProductFilter(Set<int> productIds) async {
    state = state.copyWith(selectedProductIds: productIds);
    await loadHeatmap();
  }

  Future<void> loadHeatmap({int periodMinutes = 60}) async {
    state = state.copyWith(advancedChartsLoading: true);
    try {
      final isSuper    = _isSuperAdmin;
      final storeId    = state.selectedVehicle?.id;
      final fromTs     = _resolveFromTs();
      final toTs       = _resolveToTs();
      final productIds = state.selectedProductIds.toList();

      final result = isSuper && storeId != null
          ? await SuperAdminService.instance.getHeatmap(
          storeId: storeId, periodMinutes: periodMinutes,
          fromTs: fromTs, toTs: toTs, productIds: productIds)
          : await AdminService.instance.getHeatmap(
          periodMinutes: periodMinutes,
          fromTs: fromTs, toTs: toTs, productIds: productIds);

      if (result.isSuccess && result.data != null) {
        state = state.copyWith(
          advancedChartsLoading: false,
          heatmap: result.data as List<HeatmapCell>,
        );
      } else {
        state = state.copyWith(advancedChartsLoading: false);
      }
    } catch (e) {
      state = state.copyWith(advancedChartsLoading: false);
    }
  }

  Future<void> toggleCategory(String name) async {
    final current = Set<String>.from(state.selectedCategories);
    if (current.contains(name)) {
      current.clear();
    } else {
      current.clear();
      current.add(name);
    }
    state = state.copyWith(selectedCategories: current);
    await loadAdvancedCharts();
  }

  String _periodUnit() => switch (state.period) {
    DashboardPeriod.today   => 'INTRADAY',
    DashboardPeriod.days7   => 'DAY',
    DashboardPeriod.days28  => 'MONTH_30',
    DashboardPeriod.days30  => 'MONTH_30',
    DashboardPeriod.months3 => 'MONTH_3',
    DashboardPeriod.months6 => 'MONTH_6',
    DashboardPeriod.year    => 'YEAR',
    DashboardPeriod.custom  => 'CUSTOM',
  };

  @override
  DashboardState build() {
    ref.watch(authControllerProvider.select((s) => s.userId));

    ref.onDispose(() {
      _reloadDebounce?.cancel();
      _vehicleDebounce?.cancel();
      _cancelToken?.cancel('Disposed');
    });

    Future.microtask(_init);
    return const DashboardState();
  }

  Future<void> _init() async {
    if (!ref.read(authControllerProvider).isLoggedIn) return;

    if (_isSuperAdmin) {
      state = state.copyWith(rollingWindow: 7);
      await loadVehicles();
    } else {
      await _loadPos();
    }
  }

  // ==================== LOAD POS ====================
  Future<void> _loadPos() async {
    final generation = ++_loadGeneration;
    final cancelToken = _freshCancelToken();

    state = state.copyWith(
      posLoading: true,
      clearPosError: true,
      chartLoading: false,
      chartOrdersByTime: [],
    );

    try {
      final filterType =
      state.chartFilterType == 'ALL'
          ? null
          : state.chartFilterType;

      final result = _isSuperAdmin
          ? await SuperAdminService.instance.getPosDashboard(
        period: state.period,
        fromDate: state.customFrom,
        toDate: state.customTo,
        vehicleId: state.selectedVehicle?.id,
        filterType: filterType,
        cancelToken: cancelToken,
      )
          : await AdminService.instance.getPosDashboard(
        period: state.period,
        fromDate: state.customFrom,
        toDate: state.customTo,
        filterType: filterType,
        cancelToken: cancelToken,
      );

      // Request này không còn hợp lệ
      if (generation != _loadGeneration) return;

      if (result.isTokenExpired) return;

      if (result.isSuccess && result.data != null) {
        final data = result.data!;

        state = state.copyWith(
          posLoading: false,
          posData: data,
          posAnimationKey: state.posAnimationKey + 1,
          chartLoading: false,
          chartOrdersByTime: data.ordersByTime,
        );

        // Advanced charts phải dùng state mới nhất
        await loadAdvancedCharts();

        // Load rolling data ngay sau khi load xong advanced charts
        // KHÔNG cần kiểm tra generation vì đây là request mới nhất
        if (state.rollingWindow != null) {
          await _loadRolling(); // ← Đổi từ unawaited thành await
        }

        // Load Revenue Intelligence
        await loadRevenueIntelligence();
      } else {
        state = state.copyWith(
          posLoading: false,
          chartLoading: false,
          posError: ErrorHandler.message(
            result.code,
            result.message,
          ),
        );
      }
    } on DioException catch (e) {
      if (e.type == DioExceptionType.cancel) return;
      if (generation != _loadGeneration) return;
      state = state.copyWith(
        posLoading: false,
        chartLoading: false,
        posError: e.message,
      );
    } catch (e) {
      if (generation != _loadGeneration) return;
      state = state.copyWith(
        posLoading: false,
        chartLoading: false,
        posError: e.toString(),
      );
    }
  }

  // ==================== ADVANCED CHARTS ====================
  Future<void> loadAdvancedCharts() async {
    _loadGeneration++;
    final myGeneration = _loadGeneration;
    final cancelToken = _cancelToken ?? CancelToken();

    state = state.copyWith(
      advancedChartsLoading: true,
      clearAdvancedChartsError: true,
    );

    try {
      final isSuper   = _isSuperAdmin;
      final storeId   = state.selectedVehicle?.id;
      final fromTs    = _resolveFromTs();
      final toTs      = _resolveToTs();
      final pUnit     = _periodUnit();
      final cats      = state.selectedCategories.isEmpty
          ? <String>[] : state.selectedCategories.toList();
      final productIds = state.selectedProductIds.toList();

      final catFuture = isSuper && storeId != null
          ? SuperAdminService.instance.getChartCategories(
          storeId: storeId, cancelToken: cancelToken)
          : AdminService.instance.getChartCategories(
          cancelToken: cancelToken);

      final shiftFuture = isSuper && storeId != null
          ? SuperAdminService.instance.getPeriodShift(
          storeId: storeId, fromTs: fromTs, toTs: toTs,
          periodUnit: pUnit, categories: cats,
          cancelToken: cancelToken)
          : AdminService.instance.getPeriodShift(
          fromTs: fromTs, toTs: toTs, periodUnit: pUnit,
          categories: cats, cancelToken: cancelToken);

      final stackedFuture = isSuper && storeId != null
          ? SuperAdminService.instance.getPeriodStacked(
          storeId: storeId, fromTs: fromTs, toTs: toTs,
          periodUnit: pUnit, categories: cats,
          cancelToken: cancelToken)
          : AdminService.instance.getPeriodStacked(
          fromTs: fromTs, toTs: toTs, periodUnit: pUnit,
          categories: cats, cancelToken: cancelToken);

      final heatmapFuture = isSuper && storeId != null
          ? SuperAdminService.instance.getHeatmap(
          storeId: storeId, periodMinutes: 60,
          fromTs: fromTs, toTs: toTs, productIds: productIds,
          cancelToken: cancelToken)
          : AdminService.instance.getHeatmap(
          periodMinutes: 60, fromTs: fromTs, toTs: toTs,
          productIds: productIds, cancelToken: cancelToken);

      final productsFuture = isSuper && storeId != null
          ? SuperAdminService.instance.getHeatmapProducts(
          storeId: storeId, cancelToken: cancelToken)
          : AdminService.instance.getHeatmapProducts(
          cancelToken: cancelToken);

      final productHeatmapFuture = isSuper && storeId != null
          ? SuperAdminService.instance.getProductHeatmap(
          storeId: storeId, periodMinutes: 60,
          fromTs: fromTs, toTs: toTs,
          productIds: state.selectedProductHeatmapIds.toList(),
          cancelToken: cancelToken)
          : AdminService.instance.getProductHeatmap(
          periodMinutes: 60, fromTs: fromTs, toTs: toTs,
          productIds: state.selectedProductHeatmapIds.toList(),
          cancelToken: cancelToken);

      final ingredientHeatmapFuture = isSuper && storeId != null
          ? SuperAdminService.instance.getIngredientHeatmap(
          storeId: storeId, periodMinutes: 60,
          fromTs: fromTs, toTs: toTs,
          ingredientIds: state.selectedIngredientIds.toList(),
          cancelToken: cancelToken)
          : AdminService.instance.getIngredientHeatmap(
          periodMinutes: 60, fromTs: fromTs, toTs: toTs,
          ingredientIds: state.selectedIngredientIds.toList(),
          cancelToken: cancelToken);

      final ingredientsFuture = isSuper && storeId != null
          ? SuperAdminService.instance.getMainIngredients(
          storeId: storeId, cancelToken: cancelToken)
          : AdminService.instance.getMainIngredients(
          cancelToken: cancelToken);

      // ── Gọi tất cả song song ──────────────────────────────
      final results = await Future.wait([
        catFuture.catchError((e) { return ApiResult<List<CategoryItem>>.localError('$e'); }),
        shiftFuture.catchError((e) {  return ApiResult<List<PeriodShiftPoint>>.localError('$e'); }),
        stackedFuture.catchError((e) { return ApiResult<List<PeriodStackedPoint>>.localError('$e'); }),
        heatmapFuture.catchError((e) { return ApiResult<List<HeatmapCell>>.localError('$e'); }),
        productsFuture.catchError((e) { return ApiResult<List<HeatmapProduct>>.localError('$e'); }),
        productHeatmapFuture.catchError((e) { return ApiResult<List<HeatmapCell>>.localError('$e'); }),
        ingredientHeatmapFuture.catchError((e) { return ApiResult<List<HeatmapCell>>.localError('$e'); }),
        ingredientsFuture.catchError((e) { return ApiResult<List<HeatmapProduct>>.localError('$e'); }),
      ]);

      if (myGeneration != _loadGeneration) return;

      state = state.copyWith(
        advancedChartsLoading: false,
        categories: results[0].isSuccess && results[0].data != null
            ? results[0].data as List<CategoryItem> : [],
        shiftData: results[1].isSuccess && results[1].data != null
            ? results[1].data as List<PeriodShiftPoint> : [],
        stackedData: results[2].isSuccess && results[2].data != null
            ? results[2].data as List<PeriodStackedPoint> : [],
        heatmap: results[3].isSuccess && results[3].data != null
            ? results[3].data as List<HeatmapCell> : [],
        heatmapProducts: results[4].isSuccess && results[4].data != null
            ? (List<HeatmapProduct>.from(results[4].data as List<HeatmapProduct>)
          ..sort((a, b) => a.name.compareTo(b.name)))
            : state.heatmapProducts,
        productHeatmap: results[5].isSuccess && results[5].data != null
            ? results[5].data as List<HeatmapCell> : [],
        ingredientHeatmap: results[6].isSuccess && results[6].data != null
            ? results[6].data as List<HeatmapCell> : [],
        heatmapIngredients: results[7].isSuccess && results[7].data != null
            ? (List<HeatmapProduct>.from(results[7].data as List<HeatmapProduct>)
          ..sort((a, b) => a.name.compareTo(b.name)))
            : state.heatmapIngredients,
      );
    } on DioException catch (e) {
      if (e.type == DioExceptionType.cancel) return;
      if (myGeneration != _loadGeneration) return;
      state = state.copyWith(
        advancedChartsLoading: false,
        advancedChartsError: 'Lỗi tải biểu đồ: $e',
      );
    } catch (e, stack) {
      if (myGeneration != _loadGeneration) return;
      state = state.copyWith(
        advancedChartsLoading: false,
        advancedChartsError: 'Lỗi tải biểu đồ: $e',
      );
    }
  }

  // ── Revenue Intelligence ────────────────────────────────────────
  Future<void> loadRevenueIntelligence() async {
    if (state.mode != DashboardMode.pos) return;

    state = state.copyWith(riLoading: true, clearRiError: true);
    try {
      final isSuper = _isSuperAdmin;
      final storeId = state.selectedVehicle?.id;
      final fromTs  = _resolveFromTs();
      final toTs    = _resolveToTs();
      final cancelToken = _cancelToken ?? CancelToken();

      final result = isSuper && storeId != null
          ? await SuperAdminService.instance.getRevenueIntelligence(
          storeId: storeId, fromTs: fromTs, toTs: toTs,
          cancelToken: cancelToken)
          : await AdminService.instance.getRevenueIntelligence(
          fromTs: fromTs, toTs: toTs,
          cancelToken: cancelToken);

      if (result.isTokenExpired) return;

      if (result.isSuccess && result.data != null) {
        state = state.copyWith(riLoading: false, riData: result.data);
      } else {
        state = state.copyWith(
          riLoading: false,
          riError: 'Không thể tải Revenue Intelligence',
        );
      }
    } on DioException catch (e) {
      if (e.type == DioExceptionType.cancel) return;
      state = state.copyWith(riLoading: false, riError: 'Lỗi kết nối');
    } catch (e) {
      state = state.copyWith(riLoading: false, riError: 'Lỗi: $e');
    }
  }

  int _resolveFromTs() {
    final now = DateTime.now();
    return switch (state.period) {
      DashboardPeriod.today   => DateTime(now.year, now.month, now.day)
          .millisecondsSinceEpoch,
      DashboardPeriod.days7   => now.subtract(const Duration(days: 6))
          .millisecondsSinceEpoch,
      DashboardPeriod.days28  => now.subtract(const Duration(days: 27))
          .millisecondsSinceEpoch,
      DashboardPeriod.days30  => now.subtract(const Duration(days: 29))
          .millisecondsSinceEpoch,
      DashboardPeriod.months3 => DateTime(now.year, now.month - 3, 1)
          .millisecondsSinceEpoch,
      DashboardPeriod.months6 => DateTime(now.year, now.month - 6, 1)
          .millisecondsSinceEpoch,
      DashboardPeriod.year    => DateTime(now.year - 1, now.month, now.day)
          .millisecondsSinceEpoch,
      DashboardPeriod.custom  => state.customFrom?.millisecondsSinceEpoch
          ?? DateTime(now.year, now.month, now.day).millisecondsSinceEpoch,
    };
  }

  int _resolveToTs() {
    final now = DateTime.now();
    return switch (state.period) {
      DashboardPeriod.today => DateTime(now.year, now.month, now.day, 23, 59, 59)
          .millisecondsSinceEpoch,
      DashboardPeriod.custom => state.customTo != null
          ? DateTime(state.customTo!.year, state.customTo!.month,
          state.customTo!.day, 23, 59, 59).millisecondsSinceEpoch
          : DateTime(now.year, now.month, now.day, 23, 59, 59)
          .millisecondsSinceEpoch,
      _ => DateTime(now.year, now.month, now.day, 23, 59, 59)
          .millisecondsSinceEpoch,
    };
  }

  // ── Chart filter ──────────────────────────────────────────────
  Future<void> setChartFilterType(String filterType) async {
    if (state.chartFilterType == filterType) return;
    state = state.copyWith(
      chartFilterType:   filterType,
      chartLoading:      true,
      chartOrdersByTime: [],
    );
    await _loadChart();
  }

  Future<void> _loadChart() async {
    try {
      final ft = state.chartFilterType == 'ALL'
          ? null : state.chartFilterType;

      final result = _isSuperAdmin
          ? await SuperAdminService.instance.getPosChart(
          period: state.period, fromDate: state.customFrom,
          toDate: state.customTo, vehicleId: state.selectedVehicle?.id,
          filterType: ft)
          : await AdminService.instance.getPosChart(
          period: state.period, fromDate: state.customFrom,
          toDate: state.customTo, filterType: ft);

      if (result.isTokenExpired) return;

      state = state.copyWith(
        chartLoading:      false,
        chartOrdersByTime: result.isSuccess ? (result.data ?? []) : [],
      );
    } catch (_) {
      state = state.copyWith(chartLoading: false);
    }

    // Load rolling sau khi chart data được cập nhật
    if (state.rollingWindow != null) {
      await _loadRolling(); // ← Đổi từ unawaited thành await
    }
  }

  // ── Rolling Performance ─────────────────────────────────────────
  void setRollingWindow(int? w) {
    if (w == state.rollingWindow) return;
    state = state.copyWith(
      rollingWindow:      w,
      clearRollingWindow: w == null,
      clearRollingData:   w == null,
      clearRollingError:  true,
    );
    if (w != null) unawaited(_loadRolling());
  }

  Future<void> _loadRolling() async {
    final w = state.rollingWindow;
    if (w == null || !_isSuperAdmin || state.mode != DashboardMode.pos) return;

    // Cần lưu generation để tránh race condition
    final generation = _loadGeneration;

    state = state.copyWith(rollingLoading: true, clearRollingError: true);
    try {
      final ft = state.chartFilterType == 'ALL' ? null : state.chartFilterType;
      final result = await SuperAdminService.instance.getPosRolling(
          window: w, vehicleId: state.selectedVehicle?.id, filterType: ft);

      if (result.isTokenExpired) return;

      // Kiểm tra xem request này có còn hợp lệ không
      if (generation != _loadGeneration) return;
      if (w != state.rollingWindow) return;

      if (result.isSuccess && result.data != null) {
        state = state.copyWith(rollingLoading: false, rollingData: result.data);
      } else {
        state = state.copyWith(
          rollingLoading: false,
          rollingError:   ErrorHandler.message(result.code, result.message),
        );
      }
    } catch (_) {
      // Kiểm tra xem request này có còn hợp lệ không
      if (generation != _loadGeneration) return;
      state = state.copyWith(rollingLoading: false, rollingError: 'Lỗi tải rolling');
    }
  }

  // ── Vehicle search ─────────────────────────────────────────────
  void cancelVehicleDebounce() => _vehicleDebounce?.cancel();

  void resetVehicleSearch() {
    cancelVehicleDebounce();
    state = state.copyWith(
      vehicleSearching: false,
      filteredVehicles: state.vehicles,
    );
  }

  // ── Public actions ─────────────────────────────────────────────
  void setMode(DashboardMode m) {
    if (state.mode == m) return;
    state = state.copyWith(mode: m);
    reload();
  }

  void setPeriod(DashboardPeriod p, {DateTime? from, DateTime? to}) {
    state = state.copyWith(
      period:          p,
      customFrom:      from,
      clearCustomFrom: from == null,
      customTo:        to,
      clearCustomTo:   to == null,
    );
    reload();
  }

  void reload() {
    _reloadDebounce?.cancel();
    _reloadDebounce = Timer(const Duration(milliseconds: 10), _load);
  }

  void pullRefresh() => reload();

  void selectVehicle(PosVehicle v) {
    if (state.selectedVehicle?.id == v.id) return;
    state = state.copyWith(
      selectedVehicle:  v,
      filteredVehicles: state.vehicles,
    );
    reload();
  }

  void onVehicleSearchChanged(String query) {
    _vehicleDebounce?.cancel();

    if (query.trim().isEmpty) {
      state = state.copyWith(
        vehicleSearching: false,
        filteredVehicles: state.vehicles,
      );
      return;
    }

    state = state.copyWith(vehicleSearching: true);
    _vehicleDebounce = Timer(const Duration(milliseconds: 600), () {
      final q = query.trim().toLowerCase();
      final filtered = state.vehicles
          .where((v) => v.name.toLowerCase().contains(q))
          .toList();
      state = state.copyWith(
        vehicleSearching: false,
        filteredVehicles: filtered,
      );
    });
  }

  // ── Private load ───────────────────────────────────────────────
  Future<void> _load() async {
    if (state.mode == DashboardMode.pos) {
      await _loadPos();
    } else {
      await _loadRestaurant();
    }
  }

  Future<void> _loadRestaurant() async {
    state = state.copyWith(
      restaurantLoading:    true,
      clearRestaurantError: true,
      clearRestaurantData:  true,
    );

    final modeStr = state.mode == DashboardMode.wholesale
        ? 'wholesale' : 'retail';

    try {
      final result = _isSuperAdmin
          ? await SuperAdminService.instance.getRestaurantDashboard(
          period: state.period, fromDate: state.customFrom,
          toDate: state.customTo, mode: modeStr)
          : await AdminService.instance.getRestaurantDashboard(
          period: state.period, fromDate: state.customFrom,
          toDate: state.customTo, mode: modeStr);

      if (result.isTokenExpired) return;

      if (result.isSuccess && result.data != null) {
        state = state.copyWith(
          restaurantLoading: false,
          restaurantData:    result.data,
        );
      } else {
        state = state.copyWith(
          restaurantLoading: false,
          restaurantError:   ErrorHandler.message(result.code, result.message),
        );
      }
    } catch (e) {
      state = state.copyWith(
        restaurantLoading: false,
        restaurantError:   'Lỗi không xác định: $e',
      );
    }
  }

  Future<void> loadVehicles() async {
    if (state.vehiclesLoading) return;

    state = state.copyWith(vehiclesLoading: true);
    try {
      final result = await SuperAdminService.instance.getVehicles();

      if (result.isTokenExpired) {
        state = state.copyWith(vehiclesLoading: false);
        return;
      }

      if (result.isSuccess &&
          result.data != null &&
          result.data!.isNotEmpty) {
        final vehicles = result.data!;
        state = state.copyWith(
          vehiclesLoading:  false,
          vehicles:         vehicles,
          filteredVehicles: vehicles,
          selectedVehicle:  _resolveSelectedAfterLoad(vehicles),
        );
      } else {
        state = state.copyWith(vehiclesLoading: false);
      }
    } catch (_) {
      state = state.copyWith(vehiclesLoading: false);
    }
    await _loadPos();
  }

  PosVehicle _resolveSelectedAfterLoad(List<PosVehicle> vehicles) {
    final current = state.selectedVehicle;
    if (current != null) {
      for (final v in vehicles) {
        if (v.id == current.id) return current;
      }
    }
    return vehicles.first;
  }
}