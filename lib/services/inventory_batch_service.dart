// lib/services/inventory_batch_service.dart
import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';

import '../data/models/management/inventory_batch_models.dart';
import '../data/network/api_result.dart';
import '../data/network/dio_client.dart';
import '../features/management/screens/ingredient_lot_screen.dart';

class InventoryBatchService {
  InventoryBatchService._();
  static final InventoryBatchService instance = InventoryBatchService._();

  static const _base = '/api/seller/inventory-batches';

  Future<ApiResult<List<SupplierModel>>> getSuppliers() {
    return DioClient.instance.get<List<SupplierModel>>(
      '/api/seller/suppliers',
      fromData: (d) => (d as List)
          .map((e) => SupplierModel.fromJson(e))
          .toList(),
    );
  }

  Future<ApiResult<List<InventoryCostLotModel>>> getCostLots(int ingredientId) {
    return DioClient.instance.get<List<InventoryCostLotModel>>(
      '/api/seller/ingredients/$ingredientId/cost-lots',
      fromData: (d) => (d as List)
          .map((e) => InventoryCostLotModel.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  Future<ApiResult<SupplierModel>> createSupplier({
    required String name,
    String? address,
    String? phone,
  }) {
    return DioClient.instance.post<SupplierModel>(
      '/api/seller/suppliers',
      body: {
        'name': name,
        if (address != null && address.isNotEmpty) 'address': address,
        if (phone   != null && phone.isNotEmpty)   'phone':   phone,
      },
      fromData: (d) => SupplierModel.fromJson(d),
    );
  }

  // ── List batches (tab Phiếu / filter theo action) ─────────────────
  Future<ApiResult<List<InventoryBatchSummary>>> getBatches({
    String? action, // null=tất cả, "IMPORT"|"EXPORT"|"ADJUST"
    int page = 0,
    int size = 30,
  }) {
    return DioClient.instance.get<List<InventoryBatchSummary>>(
      _base,
      queryParams: {
        'page': page,
        'size': size,
        if (action != null) 'action': action,
      },
      fromData: (d) {
        final content = (d is Map ? d['content'] : d) as List? ?? [];
        return content
            .map((e) => InventoryBatchSummary.fromJson(e))
            .toList();
      },
    );
  }

  // ── Detail ─────────────────────────────────────────────────────────
  Future<ApiResult<InventoryBatchDetail>> getBatchDetail(int id) {
    return DioClient.instance.get<InventoryBatchDetail>(
      '$_base/$id',
      fromData: (d) => InventoryBatchDetail.fromJson(d),
    );
  }

  Future<ApiResult<Map<String, dynamic>>> importBatch({
    required List<Map<String, dynamic>> items,
    String? supplierRef,
    int?    supplierId,
    String? supplierName,
    List<File> receiptImages = const [],
  }) async {
    final dataMap = {
      'items': items,
      if (supplierRef  != null && supplierRef.isNotEmpty)  'supplierRef':  supplierRef,
      if (supplierId   != null)                            'supplierId':   supplierId,
      if (supplierName != null && supplierName.isNotEmpty) 'supplierName': supplierName,
    };

    return DioClient.instance.postMultipartFiles<Map<String, dynamic>>(
      '$_base/import',
      fields: {'data': jsonEncode(dataMap)},
      fileList: receiptImages,
      fileFieldName: 'images',
      fromData: (d) => d as Map<String, dynamic>,
    );
  }

  // ── Xuất kho ───────────────────────────────────────────────────────
  Future<ApiResult<Map<String, dynamic>>> exportBatch(ExportRequest req) {
    return DioClient.instance.post<Map<String, dynamic>>(
      '$_base/export',
      body: req.toJson(),
      fromData: (d) => d as Map<String, dynamic>,
    );
  }

  // ── Kiểm kho ───────────────────────────────────────────────────────
  Future<ApiResult<Map<String, dynamic>>> checkBatch(StockCheckRequest req) {
    return DioClient.instance.post<Map<String, dynamic>>(
      '$_base/check',
      body: req.toJson(),
      fromData: (d) => d as Map<String, dynamic>,
    );
  }
}