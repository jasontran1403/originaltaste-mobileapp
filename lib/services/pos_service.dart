// lib/services/pos_service.dart

import 'dart:io';

import 'package:dio/dio.dart';
import 'package:file_saver/file_saver.dart';
import 'package:flutter/cupertino.dart';
import 'package:path_provider/path_provider.dart';

import '../core/constants/api_constants.dart';
import '../data/models/pos/pos_product_model.dart';
import '../data/models/pos/pos_shift_model.dart';
import '../data/models/pos/pos_order_model.dart';
import '../data/models/pos/pos_cart_model.dart';
import '../data/network/dio_client.dart';
import '../data/storage/session_storage.dart';
import 'file_helper.dart';

// Helper để cast an toàn
Map<String, dynamic> _asMap(dynamic d) => d as Map<String, dynamic>;
List<dynamic> _asList(dynamic d) => d as List<dynamic>;

class OcrInventoryItem {
  final String  name;
  final int?    packQuantity;
  final double? unitQuantity;
  final int?    matchedIngredientId;
  final String? matchedIngredientName;

  const OcrInventoryItem({
    required this.name,
    this.packQuantity,
    this.unitQuantity,
    this.matchedIngredientId,
    this.matchedIngredientName,
  });

  factory OcrInventoryItem.fromJson(Map<String, dynamic> j) => OcrInventoryItem(
    name:                  j['name'] as String? ?? '',
    packQuantity:          j['packQuantity'] as int?,
    unitQuantity:          (j['unitQuantity'] as num?)?.toDouble(),
    matchedIngredientId:   j['matchedIngredientId'] as int?,
    matchedIngredientName: j['matchedIngredientName'] as String?,
  );
}

class ShiftOcrResult {
  final int?   imageId;
  final String imagePath;
  final String ocrStatus;   // SUCCESS | FAILED | PENDING
  final String? staffName;
  final String? date;
  final String? errorMessage;
  final List<OcrInventoryItem> inventoryList;

  const ShiftOcrResult({
    this.imageId,
    required this.imagePath,
    required this.ocrStatus,
    this.staffName,
    this.date,
    this.errorMessage,
    required this.inventoryList,
  });

  bool get isSuccess => ocrStatus == 'SUCCESS';

  factory ShiftOcrResult.fromJson(Map<String, dynamic> j) => ShiftOcrResult(
    imageId:       j['imageId'] as int?,
    imagePath:     j['imagePath'] as String? ?? '',
    ocrStatus:     j['ocrStatus'] as String? ?? 'FAILED',
    staffName:     j['staffName'] as String?,
    date:          j['date'] as String?,
    errorMessage:  j['errorMessage'] as String?,
    inventoryList: (j['inventoryList'] as List<dynamic>? ?? [])
        .map((e) => OcrInventoryItem.fromJson(e as Map<String, dynamic>))
        .toList(),
  );
}


class PosService {
  PosService._();
  static final PosService instance = PosService._();

  static const _base = ApiConstants.posBase;

  Future<double> getOpeningCash(int shiftId) async {
    try {
      final res = await DioClient.instance.get<double>(
        '$_base/shifts/$shiftId/opening-cash',
        fromData: (data) => (data as num).toDouble(),
      );

      if (res.isSuccess && res.data != null) {
        final amount = res.data as double;
        return amount;
      }
      return 0.0;
    } catch (e, stackTrace) {
      print('❌ Exception khi gọi getOpeningCash shift $shiftId: $e');
      return 0.0;
    }
  }

  Future<void> updateOpenInventory({
    required int    shiftId,
    required int    ingredientId,
    required int    packQuantity,
    required double unitQuantity,   // ← double thay vì int
  }) async {
    final res = await DioClient.instance.patch(
      '$_base/shifts/$shiftId/open-inventory/$ingredientId',
      body: {
        'packQuantity': packQuantity,
        'unitQuantity': unitQuantity,   // gửi double lên server
      },
    );
    if (!res.isSuccess) throw Exception(res.message);
  }

  Future<void> downloadShiftReport(int shiftId, BuildContext context) async {
    final token = await SessionStorage.getAccessToken();
    final dio = Dio(BaseOptions(
      baseUrl: ApiConstants.baseUrl,
      responseType: ResponseType.bytes,
      receiveTimeout: const Duration(seconds: 90),
      headers: {if (token != null) 'Authorization': 'Bearer $token'},
    ));

    final response = await dio.get('/api/pos/reports/shift/$shiftId');

    if (response.statusCode == 200) {
      await saveFile(
        response: response,
        context: context,
        fallbackName: 'shift_report_$shiftId',
      );
    } else {
      throw Exception('Lỗi server: ${response.statusCode}');
    }
  }

  Future<void> downloadRangeReport({
    required String from,
    required String to,
    required BuildContext context,
  }) async {
    final token = await SessionStorage.getAccessToken();
    final dio = Dio(BaseOptions(
      baseUrl: ApiConstants.baseUrl,
      responseType: ResponseType.bytes,
      receiveTimeout: const Duration(seconds: 120),
      headers: {if (token != null) 'Authorization': 'Bearer $token'},
    ));

    final response = await dio.get(
      '/api/pos/reports/range',
      queryParameters: {'from': from, 'to': to},
    );

    if (response.statusCode == 200) {
      await saveFile(
        response: response,
        context: context,
        fallbackName: 'shifts_report_${from}_$to',
      );
    } else {
      throw Exception('Lỗi server: ${response.statusCode}');
    }
  }

  // ── Image URL builder ─────────────────────────────────────────
  static String buildImageUrl(String? dbPath) {
    if (dbPath == null || dbPath.isEmpty) return '';
    final parts = dbPath.split('/');
    if (parts.length < 4) return '';
    return '${ApiConstants.baseUrl}${ApiConstants.images}/${parts[2]}/${parts[3]}';
  }

  static String buildPosImageUrl(String? dbPath) {
    if (dbPath == null || dbPath.isEmpty) return '';
    final parts = dbPath.split('/');
    if (parts.length < 4) return '';
    return '${ApiConstants.baseUrl}${ApiConstants.images}/images/${parts[2]}/${parts[3]}';
  }

  // ── Upload ────────────────────────────────────────────────────
  static Future<String> uploadImage({
    required String filePath,
    required String type,
  }) async {
    // Backend category dùng @RequestParam("file")
    // Các endpoint khác dùng @RequestParam("image")
    final (String endpoint, String fieldName) = switch (type) {
      'category'    => (ApiConstants.uploadCategory,   'file'),
      'product'     => (ApiConstants.uploadProduct,    'image'),
      'pos-product' => (ApiConstants.uploadPosProduct, 'image'),
      'variant'     => (ApiConstants.uploadVariant,    'image'),
      'ingredient'  => (ApiConstants.uploadIngredient, 'image'),
      _             => throw Exception('Loại ảnh không hỗ trợ: $type'),
    };

    final res = await DioClient.instance.upload<String>(
      endpoint,
      filePath:  filePath,
      fieldName: fieldName,
      fromData:  (d) {
        // Category: data là String trực tiếp (imageUrl)
        if (d is String) return d;
        // Các loại khác: data là Map {imageUrl: "..."}
        if (d is Map<String, dynamic>) {
          return d['imageUrl'] as String?
              ?? d['filename'] as String?
              ?? '';
        }
        return '';
      },
    );

    if (res.isSuccess && res.data != null && res.data!.isNotEmpty) {
      return res.data!;
    }
    throw Exception(res.message.isNotEmpty ? res.message : 'Upload ảnh thất bại');
  }

  // ── Categories ────────────────────────────────────────────────
  Future<List<PosCategoryModel>> getCategories({bool includeDefault = false}) async {
    final res = await DioClient.instance.get<List<PosCategoryModel>>(
      '$_base/categories',
      queryParams: {'includeDefault': '$includeDefault'},
      fromData: (d) => _asList(d)
          .map((e) => PosCategoryModel.fromJson(_asMap(e)))
          .toList(),
    );
    if (res.isSuccess && res.data != null) return res.data!;
    throw Exception(res.message);
  }

  Future<PosCategoryModel> createCategory({
    required String name,
    bool    singlePrice  = false,
    int     displayOrder = 0,
    String? imageUrl,
  }) async {
    final body = <String, dynamic>{
      'name': name, 'singlePrice': singlePrice, 'displayOrder': displayOrder,
      if (imageUrl != null) 'imageUrl': imageUrl,
    };
    final res = await DioClient.instance.post<PosCategoryModel>(
      '$_base/categories',
      body: body,
      fromData: (d) => PosCategoryModel.fromJson(_asMap(d)),
    );
    if (res.isSuccess && res.data != null) return res.data!;
    throw Exception(res.message);
  }

  Future<PosCategoryModel> updateCategory(int id, Map<String, dynamic> fields) async {
    final res = await DioClient.instance.put<PosCategoryModel>(
      '$_base/categories/$id',
      body: fields,
      fromData: (d) => PosCategoryModel.fromJson(_asMap(d)),
    );
    if (res.isSuccess && res.data != null) return res.data!;
    throw Exception(res.message);
  }

  Future<void> deleteCategory(int id) async {
    final res = await DioClient.instance.delete('$_base/categories/$id');
    if (!res.isSuccess) throw Exception(res.message);
  }

  // ── Products ──────────────────────────────────────────────────
  Future<List<PosProductModel>> getProducts({int? categoryId}) async {
    final res = await DioClient.instance.get<List<PosProductModel>>(
      '$_base/products',
      queryParams: categoryId != null ? {'categoryId': '$categoryId'} : null,
      fromData: (d) => _asList(d)
          .map((e) => PosProductModel.fromJson(_asMap(e)))
          .toList(),
    );
    if (res.isSuccess && res.data != null) return res.data!;
    throw Exception(res.message);
  }

  Future<PosProductModel> getProductById(int id) async {
    final res = await DioClient.instance.get<PosProductModel>(
      '$_base/products/$id',
      fromData: (d) => PosProductModel.fromJson(_asMap(d)),
    );
    if (res.isSuccess && res.data != null) return res.data!;
    throw Exception(res.message);
  }

  Future<PosProductModel> createProduct(Map<String, dynamic> body) async {
    final res = await DioClient.instance.post<PosProductModel>(
      '$_base/products',
      body: body,
      fromData: (d) => PosProductModel.fromJson(_asMap(d)),
    );
    if (res.isSuccess && res.data != null) return res.data!;
    throw Exception(res.message);
  }

  Future<PosProductModel> updateProduct(int id, Map<String, dynamic> body) async {
    final res = await DioClient.instance.put<PosProductModel>(
      '$_base/products/$id',
      body: body,
      fromData: (d) => PosProductModel.fromJson(_asMap(d)),
    );
    if (res.isSuccess && res.data != null) return res.data!;
    throw Exception(res.message);
  }

  Future<void> deleteProduct(int id) async {
    final res = await DioClient.instance.delete('$_base/products/$id');
    if (!res.isSuccess) throw Exception(res.message);
  }

  // ── Ingredients ───────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getIngredients() async {
    final res = await DioClient.instance.get<List<Map<String, dynamic>>>(
      '$_base/ingredients',
      fromData: (d) => _asList(d).map((e) => _asMap(e)).toList(),
    );
    if (res.isSuccess && res.data != null) return res.data!;
    throw Exception(res.message);
  }

  Future<Map<String, dynamic>> createIngredient(Map<String, dynamic> body) async {
    final res = await DioClient.instance.post<Map<String, dynamic>>(
      '$_base/ingredients',
      body: body,
      fromData: (d) => _asMap(d),
    );
    if (res.isSuccess && res.data != null) return res.data!;
    throw Exception(res.message);
  }

  Future<Map<String, dynamic>> updateIngredient(int id, Map<String, dynamic> body) async {
    final res = await DioClient.instance.put<Map<String, dynamic>>(
      '$_base/ingredients/$id',
      body: body,
      fromData: (d) => _asMap(d),
    );
    if (res.isSuccess && res.data != null) return res.data!;
    throw Exception(res.message);
  }

  Future<void> deleteIngredient(int id) async {
    final res = await DioClient.instance.delete('$_base/ingredients/$id');
    if (!res.isSuccess) throw Exception(res.message);
  }

  /// Cập nhật thứ tự (displayOrder) nhiều nguyên liệu cùng lúc (kéo-thả).
  /// items: [{ 'id': int, 'displayOrder': int }, ...]
  Future<void> reorderIngredients(List<Map<String, dynamic>> items) async {
    final res = await DioClient.instance.put(
      '$_base/ingredients/reorder',
      body: {'items': items},
    );
    if (!res.isSuccess) throw Exception(res.message);
  }

  /// Cập nhật thứ tự (displayOrder) nhiều sản phẩm cùng lúc (kéo-thả).
  Future<void> reorderProducts(List<Map<String, dynamic>> items) async {
    final res = await DioClient.instance.put(
      '$_base/products/reorder',
      body: {'items': items},
    );
    if (!res.isSuccess) throw Exception(res.message);
  }

  /// Cập nhật thứ tự (displayOrder) nhiều danh mục cùng lúc (kéo-thả).
  Future<void> reorderCategories(List<Map<String, dynamic>> items) async {
    final res = await DioClient.instance.put(
      '$_base/categories/reorder',
      body: {'items': items},
    );
    if (!res.isSuccess) throw Exception(res.message);
  }

  // ── Variants ──────────────────────────────────────────────────
  Future<void> createVariant(Map<String, dynamic> body) async {
    final res = await DioClient.instance.post('$_base/variants', body: body);
    if (!res.isSuccess) throw Exception(res.message);
  }

  Future<void> updateVariant(int id, Map<String, dynamic> body) async {
    final res = await DioClient.instance.put('$_base/variants/$id', body: body);
    if (!res.isSuccess) throw Exception(res.message);
  }

  Future<void> deleteVariant(int id) async {
    final res = await DioClient.instance.delete('$_base/variants/$id');
    if (!res.isSuccess) throw Exception(res.message);
  }

  // ── Shifts ────────────────────────────────────────────────────
  Future<PosShiftModel?> getCurrentShift() async {
    final res = await DioClient.instance.get<PosShiftModel>(
      '$_base/shifts/current',
      fromData: (d) => PosShiftModel.fromJson(_asMap(d)),
    );
    if (res.isSuccess && res.data != null) return res.data;
    return null;
  }

  Future<PosShiftModel> openShift(Map<String, dynamic> body) async {
    final res = await DioClient.instance.post<PosShiftModel>(
      '$_base/shifts/open',
      body: body,
      fromData: (d) => PosShiftModel.fromJson(_asMap(d)),
    );
    if (res.isSuccess && res.data != null) return res.data!;
    throw Exception(res.message);
  }

  Future<PosShiftModel> closeShift(Map<String, dynamic> body) async {
    final res = await DioClient.instance.post<PosShiftModel>(
      '$_base/shifts/close',
      body: body,
      fromData: (d) => PosShiftModel.fromJson(_asMap(d)),
    );
    if (res.isSuccess && res.data != null) return res.data!;
    throw Exception(res.message.isNotEmpty ? res.message : 'Lỗi khi đóng ca');
  }

  Future<bool> isFirstShiftOfDay() async {
    final res = await DioClient.instance.get<bool>(
      '$_base/shifts/is-first-today',
      fromData: (d) => d is bool ? d : d.toString().toLowerCase() == 'true',
    );
    return res.isSuccess ? (res.data ?? false) : false;
  }

  Future<bool> verifyPosMenuPin(String pin) async {
    final res = await DioClient.instance.post(
      '$_base/verify-menu-pin',
      body: {'pin': pin},
    );
    if (res.code == 900) return true;
    throw Exception(res.message.isNotEmpty ? res.message : 'Mật khẩu không đúng');
  }

  Future<List<PosShiftModel>> getShiftsByDate(String date) async {
    final res = await DioClient.instance.get<List<PosShiftModel>>(
      '$_base/shifts',
      queryParams: {'date': date},
      fromData: (d) => _asList(d)
          .map((e) => PosShiftModel.fromJson(_asMap(e)))
          .toList(),
    );
    if (res.isSuccess && res.data != null) return res.data!;
    throw Exception(res.message);
  }

  Future<Map<String, dynamic>> getShiftReport(int shiftId) async {
    final res = await DioClient.instance.get<Map<String, dynamic>>(
      '$_base/shifts/$shiftId/report',
      fromData: (d) => _asMap(d),
    );
    if (res.isSuccess && res.data != null) return res.data!;
    throw Exception(res.message);
  }

  // ── Orders ────────────────────────────────────────────────────

// lib/services/pos_service.dart - Updated createOrder method

  // lib/services/pos_service.dart - Fixed createOrder method

  Future<PosOrderModel> createOrder({
    required String orderSource,
    required List<CartItem> cartItems,
    String? paymentMethod,
    String? note,
    String? customerPhone,
    String? customerName,
    int? customerDiscountId,
    int? discountItemProductId,
    double? appDiscountAmount,
    double? appFinalAmount,
    double? manualDiscountAmount,
    String? voucherCode,
    String? appOrderCode,
  }) async {

    // Convert CartItem to the format expected by backend
    final items = cartItems.map((cartItem) {
      final itemMap = <String, dynamic>{
        'productId': cartItem.product.id,
        'quantity': cartItem.quantity,
        'discountPercent': cartItem.selectedPrice.discountPercent,
      };

      // Add optional fields
      if (cartItem.note != null && cartItem.note!.isNotEmpty) {
        itemMap['note'] = cartItem.note;
      }

      // IMPORTANT: Send overridden price if exists
      final bool isAppSource = orderSource == 'SHOPEE_FOOD' || orderSource == 'GRAB_FOOD';
      if (cartItem.looseSale) {
        // Ý 2: bán xé lẻ → gửi giá tay + cờ looseSale + số lượng/đơn vị xé lẻ.
        // quantity luôn = 1 (1 dòng = 1 lần xé lẻ); số lượng thực nằm ở
        // looseQuantity (theo đơn vị nhỏ nhất) và trong unitWeights của NL.
        itemMap['looseSale'] = true;
        itemMap['finalUnitPrice'] = cartItem.finalUnitPrice;
        if (cartItem.looseQuantity != null) {
          itemMap['looseQuantity'] = cartItem.looseQuantity;
        }
        if (cartItem.looseUnit != null && cartItem.looseUnit!.isNotEmpty) {
          itemMap['looseUnit'] = cartItem.looseUnit;
        }
        if (cartItem.looseMainUnit != null &&
            cartItem.looseMainUnit!.isNotEmpty) {
          itemMap['looseMainUnit'] = cartItem.looseMainUnit;
        }
        if (cartItem.looseIngredientId != null) {
          itemMap['looseIngredientId'] = cartItem.looseIngredientId;
        }
      } else if (isAppSource && cartItem.selectedPrice.label == 'Giá tùy chỉnh') {
        itemMap['finalUnitPrice'] = cartItem.selectedPrice.price;
      } else if (!isAppSource &&
          cartItem.selectedPrice.price != cartItem.product.basePrice) {
        // Giá bị override bởi định lượng (weight sheet)
        itemMap['finalUnitPrice'] = cartItem.selectedPrice.price;
      }


      // Handle variant selections
      if (cartItem.variantSelections.isNotEmpty) {
        itemMap['variantSelections'] = cartItem.variantSelections.map((selection) {
          final variantMap = <String, dynamic>{
            'variantId': selection.variantId,
            'isAddonGroup': selection.isAddonGroup,
          };

          // Handle selected ingredients
          final ingredientsList = selection.selectedIngredients.entries.map((entry) {
            final ingredientId = entry.key;
            final count = entry.value;

            final ingredientMap = <String, dynamic>{
              'ingredientId': ingredientId,
              'selectedCount': count,
            };

            // Add unitWeights if this ingredient has weight overrides
            final weights = selection.unitWeightsMap[ingredientId];
            if (weights != null && weights.isNotEmpty) {
              // Convert to List<num> to accept both int and double
              ingredientMap['unitWeights'] = weights.map((w) => w as num).toList();
            }

            // For addon items, include price information
            if (selection.isAddonGroup && selection.addonItems != null) {
              final addon = selection.addonItems!.firstWhere(
                    (a) => a.ingredientId == ingredientId,
                orElse: () => AddonItem(
                  ingredientId: ingredientId,
                  ingredientName: '',
                  baseAddonPrice: 0,
                  discountedAddonPrice: 0,
                  quantity: 0,
                ),
              );
              if (addon.quantity > 0) {
                ingredientMap['addonPriceSnapshot'] = addon.discountedAddonPrice as num;
                ingredientMap['addonBasePrice'] = addon.baseAddonPrice as num;
                ingredientMap['addonName'] = addon.ingredientName;
                ingredientMap['isAddonIngredient'] = true;
              }
            }

            return ingredientMap;
          }).toList();

          variantMap['selectedIngredients'] = ingredientsList;
          return variantMap;
        }).toList();
      }

      return itemMap;
    }).toList();

    final body = <String, dynamic>{
      'orderSource': orderSource,
      'paymentMethod': paymentMethod ?? 'CASH',
      'items': items,
    };

    // Add optional fields to body
    if (note != null && note.isNotEmpty) body['note'] = note;
    if (customerPhone != null && customerPhone.isNotEmpty) body['customerPhone'] = customerPhone;
    if (customerName != null && customerName.isNotEmpty) body['customerName'] = customerName;
    if (customerDiscountId != null) body['customerDiscountId'] = customerDiscountId;
    if (discountItemProductId != null) body['discountItemProductId'] = discountItemProductId;
    if (appDiscountAmount != null && appDiscountAmount > 0) body['appDiscountAmount'] = appDiscountAmount;
    if (appFinalAmount != null && appFinalAmount > 0) body['appFinalAmount'] = appFinalAmount;
    if (manualDiscountAmount != null && manualDiscountAmount > 0) // ← THÊM
      body['manualDiscountAmount'] = manualDiscountAmount;

    if (voucherCode != null) body['voucherCode'] = voucherCode;
    if (appOrderCode != null && appOrderCode.isNotEmpty)
      body['appOrderCode'] = appOrderCode;

    final res = await DioClient.instance.post<PosOrderModel>(
      '$_base/orders',
      body: body,
      fromData: (d) => PosOrderModel.fromJson(_asMap(d)),
    );

    if (res.isSuccess && res.data != null) return res.data!;
    throw Exception(res.message ?? 'Không thể tạo đơn hàng');
  }

  Future<Map<String, dynamic>> getStoreInfo() async {
    final res = await DioClient.instance.get<Map<String, dynamic>>(
      '$_base/store/info',
      fromData: (d) => _asMap(d),
    );
    if (res.isSuccess && res.data != null) return res.data!;
    throw Exception(res.message.isNotEmpty ? res.message : 'Không lấy được thông tin store');
  }

  /// ADMIN mở lại ca đã đóng (chỉ cho phép trong ngày của ca đó).
  Future<PosShiftModel> reopenShift(int shiftId) async {
    final res = await DioClient.instance.post<PosShiftModel>(
      '$_base/admin/shifts/$shiftId/reopen',
      fromData: (d) => PosShiftModel.fromJson(_asMap(d)),
    );
    if (res.isSuccess && res.data != null) return res.data!;
    throw Exception(res.message.isNotEmpty
        ? res.message
        : 'Không thể mở lại ca');
  }

  Future<void> deleteOrder(int orderId, String passcode) async {
    final res = await DioClient.instance.post(
      '$_base/orders/$orderId/delete',
      body: {'passcode': passcode},
    );
    if (!res.isSuccess) throw Exception(res.message.isNotEmpty ? res.message : 'Không thể xóa đơn hàng');
  }

  Future<PosOrderModel> getOrderById(int id) async {
    final res = await DioClient.instance.get<PosOrderModel>(
      '$_base/orders/$id',
      fromData: (d) => PosOrderModel.fromJson(_asMap(d)),
    );
    if (res.isSuccess && res.data != null) return res.data!;
    throw Exception(res.message);
  }

  Future<List<PosOrderModel>> getOrdersByShift(int shiftId) async {
    final res = await DioClient.instance.get<List<PosOrderModel>>(
      '$_base/shifts/$shiftId/orders',
      fromData: (d) => _asList(d)
          .map((e) => PosOrderModel.fromJson(_asMap(e)))
          .toList(),
    );

    if (res.isSuccess && res.data != null) return res.data!;
    throw Exception(res.message);
  }

  Future<PosOrderModel> cancelOrder(int orderId, String password) async {
    final res = await DioClient.instance.post<PosOrderModel>(
      '$_base/orders/$orderId/cancel',
      body: {'password': password},
      fromData: (d) => PosOrderModel.fromJson(_asMap(d)),
    );
    if (res.isSuccess && res.data != null) return res.data!;
    throw Exception(res.message);
  }

  Future<PosOrderModel> updateOrderPaymentMethod(int orderId, String method) async {
    final res = await DioClient.instance.put<PosOrderModel>(
      '$_base/orders/$orderId/payment-method',
      body: {'paymentMethod': method},
      fromData: (d) => PosOrderModel.fromJson(_asMap(d)),
    );
    if (res.isSuccess && res.data != null) return res.data!;
    throw Exception(res.message);
  }

  // ── Stock Import ──────────────────────────────────────────────
  Future<void> importStock(List<Map<String, dynamic>> items) async {
    final res = await DioClient.instance.post(
      '$_base/shifts/stock-import',
      body: {'items': items},
    );

    if (!res.isSuccess) throw Exception(res.message);
  }

  Future<List<Map<String, dynamic>>> getStockImportHistory() async {
    final res = await DioClient.instance.get<List<Map<String, dynamic>>>(
      '$_base/shifts/stock-import/history',
      fromData: (d) => _asList(d).map((e) => _asMap(e)).toList(),
    );
    if (res.isSuccess && res.data != null) return res.data!;
    return [];
  }

  // ── Reports (Telegram export) ─────────────────────────────────

  /// Export báo cáo 1 ca → server xử lý ngầm, gửi Excel lên Telegram.
  /// Trả về message xác nhận từ server.
  Future<String> triggerShiftReport(int shiftId) async {
    final res = await DioClient.instance.get<String>(
      '$_base/reports/shift/$shiftId',
      fromData: (d) {
        if (d is Map<String, dynamic>) return d['message'] as String? ?? 'Đang xử lý...';
        return d.toString();
      },
    );
    if (res.isSuccess && res.data != null) return res.data!;
    throw Exception(res.message.isNotEmpty ? res.message : 'Không thể gửi báo cáo');
  }

  /// Export báo cáo theo khoảng ngày (chỉ ca đã đóng).
  /// [from] và [to] theo định dạng 'yyyy-MM-dd', vd: '2026-03-01'.
  Future<String> triggerRangeReport({
    required String from,
    required String to,
  }) async {
    final res = await DioClient.instance.get<String>(
      '$_base/reports/range',
      queryParams: {'from': from, 'to': to},
      fromData: (d) {
        if (d is Map<String, dynamic>) return d['message'] as String? ?? 'Đang xử lý...';
        return d.toString();
      },
    );
    if (res.isSuccess && res.data != null) return res.data!;
    throw Exception(res.message.isNotEmpty ? res.message : 'Không thể gửi báo cáo');
  }

  Future<ShiftOcrResult> uploadOpenShiftImages({
    required List<File> files,
    int? shiftId,
  }) async {
    final res = await DioClient.instance.uploadMultipartFileList<ShiftOcrResult>(
      '$_base/shifts/images/open',
      files:           files,
      fileField:       'files',
      extraFields:     shiftId != null ? {'shiftId': '$shiftId'} : {},
      sendTimeout:     const Duration(seconds: 120),
      receiveTimeout:  const Duration(seconds: 300),
      fromData:        (d) => ShiftOcrResult.fromJson(_asMap(d)),
    );
    if (res.isSuccess && res.data != null) return res.data!;
    throw Exception(res.message.isNotEmpty ? res.message : 'Upload thất bại');
  }

// ── Upload NHIỀU ảnh — đóng ca ───────────────────────────────────────────────
  Future<ShiftOcrResult> uploadCloseShiftImages({
    required List<File> files,
    required int shiftId,
  }) async {
    final res = await DioClient.instance.uploadMultipartFileList<ShiftOcrResult>(
      '$_base/shifts/images/close',
      files:           files,
      fileField:       'files',
      extraFields:     {'shiftId': '$shiftId'},
      sendTimeout:     const Duration(seconds: 120),
      receiveTimeout:  const Duration(seconds: 300),
      fromData:        (d) => ShiftOcrResult.fromJson(_asMap(d)),
    );
    if (res.isSuccess && res.data != null) return res.data!;
    throw Exception(res.message.isNotEmpty ? res.message : 'Upload thất bại');
  }

// ── Convenience wrappers 1 ảnh (giữ tương thích code cũ) ─────────────────────
  Future<ShiftOcrResult> uploadOpenShiftImage({
    required String filePath,
    int? shiftId,
  }) =>
      uploadOpenShiftImages(
        files:   [File(filePath)],
        shiftId: shiftId,
      );

  Future<ShiftOcrResult> uploadCloseShiftImage({
    required String filePath,
    required int shiftId,
  }) =>
      uploadCloseShiftImages(
        files:   [File(filePath)],
        shiftId: shiftId,
      );

}