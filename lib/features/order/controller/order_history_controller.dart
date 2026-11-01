// lib/features/order/controller/order_history_controller.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/order/order_models.dart';
import '../../../services/order_service.dart';

// ── State ─────────────────────────────────────────────────────────

class OrderHistoryState {
  final List<OrderModel> orders;
  final bool isLoading;
  final String? error;

  const OrderHistoryState({
    this.orders   = const [],
    this.isLoading = false,
    this.error,
  });

  OrderHistoryState copyWith({
    List<OrderModel>? orders,
    bool?             isLoading,
    String?           error,
    bool              clearError = false,
  }) => OrderHistoryState(
    orders:    orders    ?? this.orders,
    isLoading: isLoading ?? this.isLoading,
    error:     clearError ? null : (error ?? this.error),
  );
}

// ── Notifier ──────────────────────────────────────────────────────

final orderHistoryProvider =
NotifierProvider<OrderHistoryNotifier, OrderHistoryState>(
    OrderHistoryNotifier.new);

class OrderHistoryNotifier extends Notifier<OrderHistoryState> {
  @override
  OrderHistoryState build() {
    return const OrderHistoryState();
  }

  Future<void> loadOrders() async {
    state = state.copyWith(isLoading: true, clearError: true);
    final result = await OrderService.instance.getOrders();
    if (result.isSuccess && result.data != null) {
      final sorted = List<OrderModel>.from(result.data!)
        ..sort((a, b) => (b.createdAt ?? 0).compareTo(a.createdAt ?? 0));
      state = state.copyWith(orders: sorted, isLoading: false);
    } else {
      state = state.copyWith(
        isLoading: false,
        error: result.message ?? 'Không thể tải danh sách đơn hàng',
      );
    }
  }
}

// ── Order detail state ────────────────────────────────────────────

class OrderDetailState {
  final OrderModel? order;
  final bool isLoading;
  final bool isExporting;
  final String? error;

  const OrderDetailState({
    this.order,
    this.isLoading   = false,
    this.isExporting = false,
    this.error,
  });

  OrderDetailState copyWith({
    OrderModel? order,
    bool?       isLoading,
    bool?       isExporting,
    String?     error,
    bool        clearError = false,
  }) => OrderDetailState(
    order:       order       ?? this.order,
    isLoading:   isLoading   ?? this.isLoading,
    isExporting: isExporting ?? this.isExporting,
    error:       clearError ? null : (error ?? this.error),
  );
}

final orderDetailProvider = NotifierProvider.family<OrderDetailNotifier,
    OrderDetailState, int>(OrderDetailNotifier.new);

class OrderDetailNotifier extends FamilyNotifier<OrderDetailState, int> {
  @override
  OrderDetailState build(int arg) {
    // KHÔNG gọi _load ở đây nữa → tránh crash uninitialized
    return const OrderDetailState();
  }

  // Public method để màn hình gọi load
  Future<void> loadOrder() async {
    _load(arg);
  }

  Future<void> _load(int id) async {
    state = state.copyWith(isLoading: true, clearError: true);
    final result = await OrderService.instance.getOrderById(id);
    if (result.isSuccess && result.data != null) {
      state = state.copyWith(order: result.data, isLoading: false);
    } else {
      state = state.copyWith(
        isLoading: false,
        error: result.message ?? 'Không thể tải chi tiết đơn hàng',
      );
    }
  }
}