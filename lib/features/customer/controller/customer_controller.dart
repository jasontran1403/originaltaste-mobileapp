// lib/features/customer/controller/customer_controller.dart
// API routing theo role:
//   seller     → /api/seller/customers/full  (B2B/Sỉ Lẻ, không toggle)
//   admin      → /api/pos/customers          (POS của store, không toggle)
//   superAdmin → toggle B2B + POS:
//                  b2b → /api/seller/customers/full
//                  pos → /api/superadmin/pos-customers

import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:originaltaste/core/enums/user_role.dart';
import 'package:originaltaste/data/network/dio_client.dart';
import 'package:originaltaste/core/constants/api_constants.dart';
import 'package:originaltaste/features/auth/controller/auth_controller.dart';

// ══════════════════════════════════════════════════════════════════
// MODELS
// ══════════════════════════════════════════════════════════════════

enum CustomerMode { b2b, pos }
enum B2bCustomerType { company, retail }

class B2bCustomerModel {
  final int     id;
  final String? customerCode;
  final B2bCustomerType customerType;
  final String? companyName;
  final String? shortName;
  final String? taxCode;
  final String? address;
  final String? deliveryAddress;
  final String? contactName;
  final String? dateOfBirth;
  final String? phone;
  final String? name;
  final String? email;
  final int     discountRate;
  final bool    isActive;
  final int?    createdAt;
  final String? companyPhone;
  final String? companyAddress;

  const B2bCustomerModel({
    required this.id,
    this.customerCode,
    required this.customerType,
    this.companyName,
    this.shortName,
    this.taxCode,
    this.address,
    this.deliveryAddress,
    this.contactName,
    this.dateOfBirth,
    this.phone,
    this.name,
    this.email,
    required this.discountRate,
    required this.isActive,
    this.createdAt, this.companyPhone, this.companyAddress,
  });

  factory B2bCustomerModel.fromJson(Map<String, dynamic> j) =>
      B2bCustomerModel(
        id:              (j['id'] as num).toInt(),
        customerCode:    j['customerCode']    as String?,
        customerType:    (j['customerType'] as String?) == 'COMPANY'
            ? B2bCustomerType.company : B2bCustomerType.retail,
        companyName:     j['companyName']     as String?,
        shortName:       j['shortName']       as String?,
        taxCode:         j['taxCode']         as String?,
        address:         j['address']         as String?,
        deliveryAddress: j['deliveryAddress'] as String?,
        contactName:     j['contactName']     as String?,
        dateOfBirth:     j['dateOfBirth']     as String?,
        phone:           j['phone']           as String?,
        name:            j['name']            as String?,
        email:           j['email']           as String?,
        discountRate: (j['discountRate'] as num?)?.toInt() ?? 0,
        isActive:     (j['isActive'] as bool?) ?? true,
        createdAt:    (j['createdAt'] as num?)?.toInt(),
        companyPhone:   j['companyPhone']   as String?,
        companyAddress: j['companyAddress'] as String?,
      );

  // Tên hiển thị: ưu tiên shortName > companyName > name > customerCode
  String get displayName =>
      shortName ?? companyName ?? name ?? customerCode ?? 'KH #$id';

  bool get isCompany => customerType == B2bCustomerType.company;
}

class PosCustomerModel {
  final int     id;
  final String  phone;
  final String  name;
  final double  totalSpend;
  final int?    storeId;
  final String? dateOfBirth;
  final String? deliveryAddress;
  final int?    referredByCustomerId;
  final String? referredByName;
  final String? referredByPhone;
  final int?    createdAt;
  final String? storeName;
  final String  customerType;       // ← THÊM
  final String  customerTypeLabel;  // ← THÊM

  const PosCustomerModel({
    required this.id,
    required this.phone,
    required this.name,
    required this.totalSpend,
    this.storeId,
    this.dateOfBirth,
    this.deliveryAddress,
    this.referredByCustomerId,
    this.referredByName,
    this.referredByPhone,
    this.createdAt,
    required this.storeName,
    this.customerType      = 'KLE',
    this.customerTypeLabel = 'Khách lẻ',
  });

  factory PosCustomerModel.fromJson(Map<String, dynamic> j) =>
      PosCustomerModel(
        id:         (j['id'] as num).toInt(),
        phone:      j['phone'] as String,
        name:       j['name']  as String,
        totalSpend: (j['totalSpend'] as num?)?.toDouble() ?? 0,
        storeId:              (j['storeId'] as num?)?.toInt(),
        dateOfBirth:          j['dateOfBirth']           as String?,
        deliveryAddress:      j['deliveryAddress']       as String?,
        referredByCustomerId: (j['referredByCustomerId'] as num?)?.toInt(),
        referredByName:       j['referredByName']        as String?,
        referredByPhone:      j['referredByPhone']       as String?,
        createdAt:            (j['createdAt'] as num?)?.toInt(),
        storeName: j['storeName']       as String?,
        customerType:      j['customerType']      as String? ?? 'KLE',
        customerTypeLabel: j['customerTypeLabel'] as String? ?? 'Khách lẻ',
      );
}

// ══════════════════════════════════════════════════════════════════
// STATE
// ══════════════════════════════════════════════════════════════════

class CustomerState {
  final CustomerMode mode;
  final bool   b2bLoading;
  final String? b2bError;
  final List<B2bCustomerModel> b2bList;
  final String b2bSearch;
  final String? b2bTypeFilter;
  final bool   posLoading;
  final String? posError;
  final List<PosCustomerModel> posList;
  final String posSearch;
  final bool   isSaving;
  final String? saveError;

  const CustomerState({
    this.mode          = CustomerMode.b2b,
    this.b2bLoading    = false,
    this.b2bError,
    this.b2bList       = const [],
    this.b2bSearch     = '',
    this.b2bTypeFilter,
    this.posLoading    = false,
    this.posError,
    this.posList       = const [],
    this.posSearch     = '',
    this.isSaving      = false,
    this.saveError,
  });

  CustomerState copyWith({
    CustomerMode? mode,
    bool? b2bLoading, String? b2bError,  bool clearB2bError = false,
    List<B2bCustomerModel>? b2bList,
    String? b2bSearch,
    String? b2bTypeFilter,               bool clearB2bTypeFilter = false,
    bool? posLoading, String? posError,  bool clearPosError = false,
    List<PosCustomerModel>? posList,
    String? posSearch,
    bool? isSaving,   String? saveError, bool clearSaveError = false,
  }) =>
      CustomerState(
        mode:          mode          ?? this.mode,
        b2bLoading:    b2bLoading    ?? this.b2bLoading,
        b2bError:      clearB2bError ? null : (b2bError  ?? this.b2bError),
        b2bList:       b2bList       ?? this.b2bList,
        b2bSearch:     b2bSearch     ?? this.b2bSearch,
        b2bTypeFilter: clearB2bTypeFilter
            ? null : (b2bTypeFilter ?? this.b2bTypeFilter),
        posLoading:    posLoading    ?? this.posLoading,
        posError:      clearPosError ? null : (posError  ?? this.posError),
        posList:       posList       ?? this.posList,
        posSearch:     posSearch     ?? this.posSearch,
        isSaving:      isSaving      ?? this.isSaving,
        saveError:     clearSaveError ? null : (saveError ?? this.saveError),
      );

  List<B2bCustomerModel> get filteredB2b {
    var list = b2bList;
    if (b2bTypeFilter != null) {
      final t = b2bTypeFilter == 'COMPANY'
          ? B2bCustomerType.company : B2bCustomerType.retail;
      list = list.where((c) => c.customerType == t).toList();
    }
    if (b2bSearch.isNotEmpty) {
      final q = b2bSearch.toLowerCase();
      list = list.where((c) =>
      (c.customerCode?.toLowerCase().contains(q) ?? false) ||
          (c.shortName?.toLowerCase().contains(q)    ?? false) ||
          (c.companyName?.toLowerCase().contains(q)  ?? false) ||
          (c.name?.toLowerCase().contains(q)         ?? false) ||
          (c.phone?.contains(q)                      ?? false)
      ).toList();
    }
    return list;
  }

  List<PosCustomerModel> get filteredPos {
    if (posSearch.isEmpty) return posList;
    final q = posSearch.toLowerCase();
    return posList.where((c) =>
    c.name.toLowerCase().contains(q) || c.phone.contains(q)
    ).toList();
  }
}

// ══════════════════════════════════════════════════════════════════
// PROVIDER
// ══════════════════════════════════════════════════════════════════

final customerControllerProvider =
NotifierProvider<CustomerController, CustomerState>(
  CustomerController.new,
);

// ══════════════════════════════════════════════════════════════════
// CONTROLLER
// ══════════════════════════════════════════════════════════════════

class CustomerController extends Notifier<CustomerState> {
  Timer? _searchDebounce;

  UserRole get _role =>
      ref.read(authControllerProvider).role ?? UserRole.seller;

  bool get _isSuperAdmin => _role == UserRole.superAdmin;
  bool get _isAdmin      => _role == UserRole.admin;
  bool get _isSeller     => _role == UserRole.seller;

  // Mode mặc định:
  //   admin     → chỉ pos
  //   seller    → chỉ b2b
  //   superAdmin → b2b (có toggle)
  CustomerMode get _defaultMode =>
      _isAdmin ? CustomerMode.pos : CustomerMode.b2b;

  bool get canToggleMode => _isSuperAdmin;

  // ── API endpoint routing ──────────────────────────────────────

  String get _b2bListUrl   => '${ApiConstants.sellerBase}/customers/b2b';
  String get _b2bCreateUrl => '${ApiConstants.sellerBase}/customers/b2b';
  String _b2bUpdateUrl(int id) => '${ApiConstants.sellerBase}/customers/b2b/$id';

  String get _b2bDeleteUrl => '${ApiConstants.sellerBase}/customers';

  String get _posListUrl {
    if (_isSuperAdmin) return '${ApiConstants.superAdminBase}/pos-customers';
    if (_isAdmin)      return '${ApiConstants.adminBase}/pos-customers';
    return '${ApiConstants.posBase}/customers';
  }

  String get _posCreateUrl {
    if (_isSuperAdmin) return '${ApiConstants.superAdminBase}/pos-customers';
    if (_isAdmin)      return '${ApiConstants.adminBase}/pos-customers';
    return '${ApiConstants.posBase}/customers';
  }

  String _posUpdateUrl(int id) {
    if (_isSuperAdmin) return '${ApiConstants.superAdminBase}/pos-customers/$id';
    if (_isAdmin)      return '${ApiConstants.adminBase}/pos-customers/$id';
    return '${ApiConstants.posBase}/customers/$id';
  }

  String get posTypesUrl {
    if (_isSuperAdmin) return '${ApiConstants.superAdminBase}/customers/types';
    if (_isAdmin)      return '${ApiConstants.adminBase}/customers/types';
    return '${ApiConstants.posBase}/customers/types';
  }

  @override
  CustomerState build() {
    ref.onDispose(() => _searchDebounce?.cancel());

    // Watch auth state — khi role thay đổi (từ null → admin) sẽ tự rebuild
    final authState = ref.watch(authControllerProvider);
    final role = authState.role;

    // Chỉ load khi đã có role
    if (role != null) {
      Future.microtask(() {
        final mode = role == UserRole.admin ? CustomerMode.pos : CustomerMode.b2b;
        if (state.mode != mode || (state.b2bList.isEmpty && state.posList.isEmpty)) {
          state = state.copyWith(mode: mode);
          _loadCurrent();
        }
      });
    }

    return const CustomerState();
  }

  void setMode(CustomerMode mode) {
    if (!canToggleMode && mode != _defaultMode) return;
    if (state.mode == mode) return;
    state = state.copyWith(mode: mode);
    _loadCurrent();
  }

  void _loadCurrent() {
    if (state.mode == CustomerMode.b2b) loadB2b();
    else loadPos();
  }

  void refresh() => _loadCurrent();

  // ── B2B ───────────────────────────────────────────────────────

  Future<void> loadB2b() async {
    state = state.copyWith(b2bLoading: true, clearB2bError: true);
    try {
      final url = _b2bListUrl;

      final res = await DioClient.instance.get<List<B2bCustomerModel>>(
        url,
        fromData: (d) {
          final list = d is Map ? (d['content'] as List? ?? []) : (d as List);
          return list
              .map((e) => B2bCustomerModel.fromJson(e as Map<String, dynamic>))
              .toList();
        },
      );

      state = state.copyWith(
        b2bLoading: false,
        b2bList:    res.isSuccess ? (res.data ?? []) : [],
        b2bError:   res.isSuccess ? null : res.message,
      );

    } catch (e, st) {
      debugPrint('[CustomerCtrl] loadB2b ERROR: $e');
      debugPrint('[CustomerCtrl] stacktrace: $st');
      state = state.copyWith(b2bLoading: false, b2bError: '$e');
    }
  }


  void setB2bSearch(String q) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350),
            () => state = state.copyWith(b2bSearch: q));
  }

  void setB2bTypeFilter(String? type) => state = state.copyWith(
    b2bTypeFilter:      type,
    clearB2bTypeFilter: type == null,
  );

  Future<String?> saveB2bCustomer(Map<String, dynamic> data, {int? id}) async {
    state = state.copyWith(isSaving: true, clearSaveError: true);
    try {
      final res = id != null
          ? await DioClient.instance.put(_b2bUpdateUrl(id), body: data)
          : await DioClient.instance.post(_b2bCreateUrl, body: data);

      // Server luôn trả HTTP 200, phân biệt thành công/lỗi qua res.code trong body
      // code 900 = success, code 400/500 = lỗi nghiệp vụ
      if (res.code != 900) {
        final msg = _parseErrorMessage(res.message);
        state = state.copyWith(isSaving: false, saveError: msg);
        return msg;
      }

      state = state.copyWith(isSaving: false);
      await loadB2b();
      return null;
    } catch (e) {
      final msg = _parseErrorMessage('$e');
      state = state.copyWith(isSaving: false, saveError: msg);
      return msg;
    }
  }

  Future<bool> deleteB2bCustomer(int id) async {
    try {
      await DioClient.instance.delete('$_b2bDeleteUrl/$id');
      await loadB2b();
      return true;
    } catch (_) { return false; }
  }

  // ── POS ───────────────────────────────────────────────────────

  Future<void> loadPos() async {
    state = state.copyWith(posLoading: true, clearPosError: true);
    try {
      final res = await DioClient.instance.get<List<PosCustomerModel>>(
        _posListUrl,
        fromData: (d) {
          // Admin endpoint trả về pagination wrapper, POS endpoint trả về List thẳng
          final list = d is Map ? (d['content'] as List? ?? []) : (d as List);
          return list
              .map((e) => PosCustomerModel.fromJson(e as Map<String, dynamic>))
              .toList();
        },
      );

      state = state.copyWith(
        posLoading: false,
        posList:    res.isSuccess ? (res.data ?? []) : [],
        posError:   res.isSuccess ? null : res.message,
      );
    } catch (e, st) {
      debugPrint('[CustomerCtrl] loadPos ERROR: $e\n$st');
      state = state.copyWith(posLoading: false, posError: '$e');
    }
  }

  void setPosSearch(String q) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350),
            () => state = state.copyWith(posSearch: q));
  }

  Future<bool> savePosCustomer(Map<String, dynamic> data, {int? id}) async {
    state = state.copyWith(isSaving: true, clearSaveError: true);
    try {
      if (id != null) {
        await DioClient.instance.put(_posUpdateUrl(id), body: data);
      } else {
        await DioClient.instance.post(_posCreateUrl, body: data);
      }
      state = state.copyWith(isSaving: false);
      await loadPos();
      return true;
    } catch (e) {
      state = state.copyWith(isSaving: false, saveError: '$e');
      return false;
    }
  }

  String _parseErrorMessage(String raw) {
    final lower = raw.toLowerCase();
    if (lower.contains('customercode') || lower.contains('mã kh') || lower.contains('mã khách')) {
      return 'Mã khách hàng đã tồn tại';
    }
    if (lower.contains('phone') || lower.contains('sđt') || lower.contains('số điện thoại')) {
      return 'Số điện thoại đã tồn tại';
    }
    if (lower.contains('taxcode') || lower.contains('mst') || lower.contains('mã số thuế')) {
      return 'Mã số thuế đã tồn tại';
    }
    // Fallback: trích message từ DioException nếu có
    final msgMatch = RegExp(r'"message"\s*:\s*"([^"]+)"').firstMatch(raw);
    if (msgMatch != null) return msgMatch.group(1)!;
    return 'Đã xảy ra lỗi, vui lòng thử lại';
  }
}