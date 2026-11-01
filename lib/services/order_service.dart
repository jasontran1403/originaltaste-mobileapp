// lib/services/order_service.dart

import 'package:dio/dio.dart';
import 'package:file_saver/file_saver.dart';
import 'package:flutter/cupertino.dart';

import '../../core/constants/api_constants.dart';
import '../data/models/order/order_models.dart';
import '../data/network/api_result.dart';
import '../data/network/dio_client.dart';
import '../data/storage/session_storage.dart';
import 'file_helper.dart';

class OrderService {
  OrderService._();
  static final OrderService instance = OrderService._();

  // ── Image helper ──────────────────────────────────────────────
  static String buildImageUrl(String? path) {
    if (path == null || path.isEmpty) return '';
    if (path.startsWith('http')) return path;
    return '${ApiConstants.baseUrl}${ApiConstants.images}/$path';
  }

  // ══════════════════════════════════════════════════════════════
  // PRODUCTS
  // ══════════════════════════════════════════════════════════════

  Future<OrderHistoryResult> getSaleOrderHistory({
    required int fromTs,
    required int toTs,
    String query = '',
    int page = 0,
    int size = 20,
    // Truyền role để chọn đúng endpoint
    bool isSuperAdmin = false,
  }) async {
    // SuperAdmin dùng endpoint riêng lấy toàn hệ thống
    final endpoint = isSuperAdmin
        ? '/api/superadmin/sale-orders/history'
        : '/api/seller/orders';

    final result = await DioClient.instance.get<Map<String, dynamic>>(
      endpoint,
      queryParams: {
        'fromTs': fromTs,
        'toTs':   toTs,
        if (query.isNotEmpty) 'q': query,
        'page': page,
        'size': size,
      },
      fromData: (d) => d as Map<String, dynamic>,
    );

    if (result.isSuccess && result.data != null) {
      final data    = result.data!;
      final content = (data['content'] as List? ?? []);
      return OrderHistoryResult(
        items:   content
            .map((e) => OrderModel.fromJson(e as Map<String, dynamic>))
            .toList(),
        hasNext: data['hasNext'] == true,
      );
    }
    throw Exception(result.message ?? 'Lỗi tải lịch sử đơn hàng');
  }

  Future<Map<String, dynamic>> getPosOrderHistory({
    required int fromTs,
    required int toTs,
    String query = '',
    int page = 0,
    int size = 20,
    bool isSuperAdmin = false,
  }) async {
    // ADMIN  → /api/admin/pos-orders/history   (theo store của admin)
    // SUPERADMIN → /api/superadmin/pos-orders/history (toàn hệ thống)
    final endpoint = isSuperAdmin
        ? '/api/superadmin/pos-orders/history'
        : '/api/admin/pos-orders/history';

    final result = await DioClient.instance.get<Map<String, dynamic>>(
      endpoint,
      queryParams: {
        'fromTs': fromTs,
        'toTs':   toTs,
        if (query.isNotEmpty) 'q': query,
        'page': page,
        'size': size,
      },
      fromData: (d) => d as Map<String, dynamic>,
    );

    if (result.isSuccess && result.data != null) {
      return result.data!;
    }
    throw Exception(result.message ?? 'Lỗi tải lịch sử POS');
  }

  Future<ApiResult<List<ProductModel>>> getProducts({
    int page = 0,
    int size = 200,
    int? categoryId,
  }) {
    final params = <String, dynamic>{
      'page': page,
      'size': size,
      if (categoryId != null) 'categoryId': categoryId,
    };
    return DioClient.instance.get<List<ProductModel>>(
      '/api/seller/products',
      queryParams: params,
      fromData: (d) {
        if (d is Map && d['content'] is List) {
          return (d['content'] as List)
              .map((e) => ProductModel.fromJson(e))
              .toList();
        }
        if (d is List) return d.map((e) => ProductModel.fromJson(e)).toList();
        return <ProductModel>[];
      },
    );
  }

  // ══════════════════════════════════════════════════════════════
  // CATEGORIES
  // ══════════════════════════════════════════════════════════════

  Future<ApiResult<List<CategoryModel>>> getCategories() {
    return DioClient.instance.get<List<CategoryModel>>(
      '/api/seller/categories',
      fromData: (d) {
        if (d is List) return d.map((e) => CategoryModel.fromJson(e)).toList();
        return <CategoryModel>[];
      },
    );
  }

  // ══════════════════════════════════════════════════════════════
  // CUSTOMERS
  // ══════════════════════════════════════════════════════════════

  Future<ApiResult<CustomerModel?>> getCustomerByPhone(String phone) {
    return DioClient.instance.get<CustomerModel?>(
      '/api/seller/customers/phone/$phone',
      fromData: (d) =>
      d != null ? CustomerModel.fromJson(d as Map<String, dynamic>) : null,
    );
  }

  Future<ApiResult<CustomerModel>> createCustomer({
    required String phone,
    String? name,
    String? email,
    int discountRate = 0,
    List<Map<String, dynamic>>? addresses,
  }) {
    return DioClient.instance.post<CustomerModel>(
      '/api/seller/customers',
      body: {
        'phone': phone,
        if (name != null)      'name':         name,
        if (email != null)     'email':        email,
        'discountRate':        discountRate,
        if (addresses != null) 'addresses':    addresses,
      },
      fromData: (d) =>
      d != null ? CustomerModel.fromJson(d as Map<String, dynamic>) : null,
    );
  }

  Future<ApiResult<CustomerModel>> updateCustomer({
    required int id,
    required String phone,
    String? name,
    String? email,
    int discountRate = 0,
    List<Map<String, dynamic>>? addresses,
  }) {
    return DioClient.instance.put<CustomerModel>(
      '/api/seller/customers/$id',
      body: {
        'phone': phone,
        if (name != null)      'name':         name,
        if (email != null)     'email':        email,
        'discountRate':        discountRate,
        if (addresses != null) 'addresses':    addresses,
      },
      fromData: (d) =>
      d != null ? CustomerModel.fromJson(d as Map<String, dynamic>) : null,
    );
  }

  // ══════════════════════════════════════════════════════════════
  // ORDERS
  // ══════════════════════════════════════════════════════════════

  Future<ApiResult<List<OrderModel>>> getOrders() {
    return DioClient.instance.get<List<OrderModel>>(
      '/api/seller/orders',
      fromData: (d) {
        if (d is List) return d.map((e) => OrderModel.fromJson(e)).toList();
        return <OrderModel>[];
      },
    );
  }

  Future<ApiResult<OrderModel>> getOrderById(int id) {
    return DioClient.instance.get<OrderModel>(
      '/api/seller/orders/$id',
      fromData: (d) =>
      d != null ? OrderModel.fromJson(d as Map<String, dynamic>) : null,
    );
  }

  Future<ApiResult<OrderModel>> createOrder(CreateOrderRequest request) {
    return DioClient.instance.post<OrderModel>(
      '/api/seller/orders',
      body: request.toJson(),
      fromData: (d) =>
      d != null ? OrderModel.fromJson(d as Map<String, dynamic>) : null,
    );
  }

  Future<ApiResult<OrderModel>> cancelOrder(int orderId) {
    return DioClient.instance.post<OrderModel>(
      '/api/seller/orders/$orderId/cancel',
      body: {},
      fromData: (d) =>
      d != null ? OrderModel.fromJson(d as Map<String, dynamic>) : null,
    );
  }

  Future<ApiResult<OrderModel>> cancelSaleOrder(int orderId) {
    return DioClient.instance.post<OrderModel>(
      '/api/superadmin/sale-orders/$orderId/cancel',
      body: {},
      fromData: (d) =>
      d != null ? OrderModel.fromJson(d as Map<String, dynamic>) : null,
    );
  }

  Future<void> generateInvoice(int orderId, BuildContext context) async {
    try {
      final token = await SessionStorage.getAccessToken();

      final dio = Dio(BaseOptions(
        baseUrl: ApiConstants.baseUrl,
        responseType: ResponseType.bytes,           // Quan trọng: nhận bytes
        receiveTimeout: const Duration(seconds: 60),
        connectTimeout: const Duration(seconds: 15),
        headers: {
          if (token != null) 'Authorization': 'Bearer $token',
        },
      ));

      final response = await dio.get('/api/seller/orders/$orderId/invoice');

      if (response.statusCode == 200 && response.data != null) {
        await saveFile(
          response: response,
          context: context,
          fallbackName: 'invoice_$orderId',
        );
      } else {
        throw Exception('Lỗi server: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;   // Để _exportInvoice bắt lỗi và hiển thị SnackBar
    }
  }

  Future<ApiResult<List<dynamic>>> searchB2bCustomers(String query) async {
    return await DioClient.instance.get(
      '${ApiConstants.sellerBase}/customers/b2b/search?code=$query',
      fromData: (d) => d is List ? d : [],
    );
  }
}