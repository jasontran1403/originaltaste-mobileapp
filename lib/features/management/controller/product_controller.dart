// lib/features/management/controller/product_controller.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/management/management_models.dart';
import '../../../services/seller_service.dart';

// ══════════════════════════════════════════════════════════════════
// TIER FORM ITEM  (1 dòng khung giá sỉ)
// ══════════════════════════════════════════════════════════════════

class TierFormItem {
  final TextEditingController nameCtrl;
  final TextEditingController minQtyCtrl;
  final TextEditingController maxQtyCtrl;
  final TextEditingController priceCtrl;

  TierFormItem({
    String name   = '',
    String minQty = '0',
    String maxQty = '',
    String price  = '',
  })  : nameCtrl   = TextEditingController(text: name),
        minQtyCtrl = TextEditingController(text: minQty),
        maxQtyCtrl = TextEditingController(text: maxQty),
        priceCtrl  = TextEditingController(text: price);

  void dispose() {
    nameCtrl.dispose();
    minQtyCtrl.dispose();
    maxQtyCtrl.dispose();
    priceCtrl.dispose();
  }

  Map<String, dynamic> toJson(int sortOrder) => {
    'tierName':    nameCtrl.text.trim(),
    'minQuantity': double.tryParse(minQtyCtrl.text.trim()) ?? 0.0,
    'maxQuantity': maxQtyCtrl.text.trim().isEmpty
        ? null
        : double.tryParse(maxQtyCtrl.text.trim()),
    'price':       double.tryParse(priceCtrl.text.trim()) ?? 0.0,
    'sortOrder':   sortOrder,
  };
}

// ══════════════════════════════════════════════════════════════════
// INGREDIENT FORM ITEM  (1 dòng nguyên liệu + số lượng)
// ══════════════════════════════════════════════════════════════════

class IngredientFormItem {
  final int ingredientId;
  final String ingredientName;
  final String ingredientUnit; // đơn vị của nguyên liệu (kg, lít, ...)
  final TextEditingController quantityCtrl;

  IngredientFormItem({
    required this.ingredientId,
    required this.ingredientName,
    required this.ingredientUnit,
    String quantity = '1',
  }) : quantityCtrl = TextEditingController(text: quantity);

  void dispose() => quantityCtrl.dispose();

  Map<String, dynamic> toJson() => {
    'ingredientId': ingredientId,
    'quantity':     double.tryParse(quantityCtrl.text.trim()) ?? 1.0,
  };

  bool get isValid {
    final v = double.tryParse(quantityCtrl.text.trim());
    return v != null && v > 0;
  }
}

// ══════════════════════════════════════════════════════════════════
// LIST
// ══════════════════════════════════════════════════════════════════

class ProductListState {
  final List<MgmtProductModel> items;
  final bool isLoading;
  final bool hasMore;
  final int page;
  final String? error;

  const ProductListState({
    this.items     = const [],
    this.isLoading = false,
    this.hasMore   = true,
    this.page      = 0,
    this.error,
  });

  ProductListState copyWith({
    List<MgmtProductModel>? items,
    bool? isLoading,
    bool? hasMore,
    int? page,
    String? error,
    bool clearError = false,
  }) =>
      ProductListState(
        items:     items     ?? this.items,
        isLoading: isLoading ?? this.isLoading,
        hasMore:   hasMore   ?? this.hasMore,
        page:      page      ?? this.page,
        error:     clearError ? null : (error ?? this.error),
      );
}

class ProductListNotifier extends Notifier<ProductListState> {
  static const _pageSize = 10;

  @override
  ProductListState build() {
    Future.microtask(_load);
    return const ProductListState();
  }

  Future<void> _load({bool refresh = false, int? pageOverride}) async {
    final page = pageOverride ?? (refresh ? 0 : state.page);
    state = state.copyWith(
        isLoading: true,
        clearError: true,
        items: refresh ? [] : null,
        page: page);

    final res = await SellerService.instance
        .getProducts(page: page, size: _pageSize);

    if (res.isSuccess) {
      final newItems = res.data ?? <MgmtProductModel>[];
      state = state.copyWith(
        items:     refresh ? newItems : [...state.items, ...newItems],
        isLoading: false,
        hasMore:   newItems.length == _pageSize,
        page:      page,
      );
    } else {
      state = state.copyWith(
          isLoading: false, error: res.message?.toString());
    }
  }

  Future<void> refresh() => _load(refresh: true);

  Future<void> loadMore() async {
    if (!state.hasMore || state.isLoading) return;
    await _load(pageOverride: state.page + 1);
  }

  Future<bool> delete(int id) async {
    final res = await SellerService.instance.deleteProduct(id);
    if (res.isSuccess) {
      await refresh();
      return true;
    }
    return false;
  }
}

final productListProvider =
NotifierProvider<ProductListNotifier, ProductListState>(
    ProductListNotifier.new);

// ══════════════════════════════════════════════════════════════════
// FORM STATE
// ══════════════════════════════════════════════════════════════════

class ProductFormState {
  final bool isSaving;
  final bool isUploading;
  final bool isLoadingData;
  final String? imageUrl;
  final String? uploadError;
  final String? error;
  final int? categoryId;
  final String? categoryName;
  final bool isAvailable;
  final int vatRate;
  final String unit;
  final List<MgmtCategoryModel> categories;
  final List<IngredientModel> ingredients;

  const ProductFormState({
    this.isSaving        = false,
    this.isUploading     = false,
    this.isLoadingData   = false,
    this.imageUrl,
    this.uploadError,
    this.error,
    this.categoryId,
    this.categoryName,
    this.isAvailable     = true,
    this.vatRate         = 0,
    this.unit            = 'kg',
    this.categories      = const [],
    this.ingredients     = const [],
  });

  bool get hasImage => imageUrl != null && imageUrl!.isNotEmpty;

  ProductFormState copyWith({
    bool? isSaving,
    bool? isUploading,
    bool? isLoadingData,
    String? imageUrl,
    bool clearImage          = false,
    String? uploadError,
    bool clearUploadError    = false,
    String? error,
    bool clearError          = false,
    int? categoryId,
    String? categoryName,
    bool clearCategory       = false,
    bool? isAvailable,
    int? vatRate,
    String? unit,
    List<MgmtCategoryModel>? categories,
    List<IngredientModel>? ingredients,
  }) =>
      ProductFormState(
        isSaving:      isSaving       ?? this.isSaving,
        isUploading:   isUploading    ?? this.isUploading,
        isLoadingData: isLoadingData  ?? this.isLoadingData,
        imageUrl:      clearImage     ? null : (imageUrl     ?? this.imageUrl),
        uploadError:   clearUploadError ? null : (uploadError ?? this.uploadError),
        error:         clearError     ? null : (error        ?? this.error),
        categoryId:    clearCategory  ? null : (categoryId   ?? this.categoryId),
        categoryName:  clearCategory  ? null : (categoryName  ?? this.categoryName),
        isAvailable:   isAvailable    ?? this.isAvailable,
        vatRate:       vatRate         ?? this.vatRate,
        unit:          unit            ?? this.unit,
        categories:    categories      ?? this.categories,
        ingredients:   ingredients     ?? this.ingredients,
      );
}

// ══════════════════════════════════════════════════════════════════
// FORM NOTIFIER
// ══════════════════════════════════════════════════════════════════

class ProductFormNotifier
    extends FamilyNotifier<ProductFormState, MgmtProductModel?> {
  final formKey   = GlobalKey<FormState>();
  final nameCtrl  = TextEditingController();
  final priceCtrl = TextEditingController();
  final descCtrl  = TextEditingController();

  // Tier rows — mutable list; UI reads directly
  final List<TierFormItem> tiers = [];
  final Map<int, VoidCallback> _maxListeners = {};

  // ── Ingredient rows — mutable list ──────────────────────────
  final List<IngredientFormItem> ingredientRows = [];

  static const _unitOptions = [
    'kg', 'g', 'lít', 'ml', 'cái', 'hộp', 'túi', 'chai', 'bộ', 'thùng', 'gói',
  ];
  static const _vatOptions  = [0, 5, 8, 10];
  List<String> get unitOptions => _unitOptions;
  List<int>    get vatOptions  => _vatOptions;

  @override
  ProductFormState build(MgmtProductModel? arg) {
    ref.onDispose(() {
      nameCtrl.dispose();
      priceCtrl.dispose();
      descCtrl.dispose();
      _detachAllListeners();
      for (final t in tiers) t.dispose();
      for (final i in ingredientRows) i.dispose();
    });

    if (arg != null) {
      nameCtrl.text  = arg.name;
      priceCtrl.text = arg.price.toStringAsFixed(0);
      descCtrl.text  = arg.description ?? '';

      // Pre-fill tiers
      if (arg.tiers != null) {
        for (final t in arg.tiers!) {
          tiers.add(TierFormItem(
            name:   t['tierName']?.toString() ?? '',
            minQty: _fmtQ(t['minQuantity']),
            maxQty: t['maxQuantity'] == null ? '' : _fmtQ(t['maxQuantity']),
            price:  (t['price'] as num?)?.toInt().toString() ?? '',
          ));
        }
      }

      // Pre-fill ingredient rows từ productIngredients của model
      for (final pi in arg.productIngredients) {
        ingredientRows.add(IngredientFormItem(
          ingredientId:   pi.ingredientId,
          ingredientName: pi.name,
          ingredientUnit: pi.unit,
          quantity:       _fmtQ(pi.quantity),
        ));
      }
    }

    Future.microtask(_loadData);

    return ProductFormState(
      imageUrl:     arg?.imageUrl,
      categoryId:   arg?.categoryId,
      categoryName: arg?.categoryName,
      isAvailable:  arg?.isAvailable ?? true,
      vatRate:      arg?.vatRate ?? 0,
      unit:         arg?.unit ?? 'kg',
    );
  }

  String _fmtQ(dynamic q) {
    final d = (q as num?)?.toDouble() ?? 0.0;
    return d == d.truncateToDouble()
        ? d.toInt().toString()
        : d.toStringAsFixed(3).replaceAll(RegExp(r'0+$'), '');
  }

  Future<void> _loadData() async {
    state = state.copyWith(isLoadingData: true);
    final catRes = await SellerService.instance.getCategories();
    final ingRes = await SellerService.instance.getIngredients(page: 0, size: 200);
    state = state.copyWith(
      isLoadingData: false,
      categories:    catRes.data ?? [],
      ingredients:   ingRes.data ?? [],
    );
  }

  // ── Image ────────────────────────────────────────────────────────

  Future<void> uploadImage(String filePath) async {
    state = state.copyWith(
        isUploading: true, clearImage: true, clearUploadError: true);
    final res = await SellerService.instance.uploadProductImage(filePath);
    if (res.isSuccess && res.data != null && res.data!.isNotEmpty) {
      state = state.copyWith(isUploading: false, imageUrl: res.data);
    } else {
      state = state.copyWith(
          isUploading: false,
          uploadError: res.message?.toString() ?? 'Upload thất bại');
    }
  }

  void clearImage() =>
      state = state.copyWith(clearImage: true, clearUploadError: true);

  // ── Setters ──────────────────────────────────────────────────────

  void setCategory(int? id, {String? name}) => id == null
      ? state = state.copyWith(clearCategory: true)
      : state = state.copyWith(categoryId: id, categoryName: name);

  void setAvailable(bool v) => state = state.copyWith(isAvailable: v);
  void setVatRate(int v)    => state = state.copyWith(vatRate: v);
  void setUnit(String v)    => state = state.copyWith(unit: v);

  Future<void> reloadIngredients() async {
    final ingRes = await SellerService.instance.getIngredients(page: 0, size: 200);
    state = state.copyWith(ingredients: ingRes.data ?? []);
  }

  // ── Ingredient rows ──────────────────────────────────────────────

  /// Thêm 1 nguyên liệu mới vào danh sách
  void addIngredientRow(IngredientModel ing, void Function() onRebuild) {
    // Không cho thêm trùng
    if (ingredientRows.any((r) => r.ingredientId == ing.id)) {
      onRebuild();
      return;
    }
    ingredientRows.add(IngredientFormItem(
      ingredientId:   ing.id,
      ingredientName: ing.name,
      ingredientUnit: ing.unit,
    ));
    onRebuild();
  }

  /// Xóa 1 nguyên liệu khỏi danh sách
  void removeIngredientRow(int index, void Function() onRebuild) {
    ingredientRows[index].dispose();
    ingredientRows.removeAt(index);
    onRebuild();
  }

  /// Validate ingredient rows
  String? validateIngredients() {
    if (ingredientRows.isEmpty) return 'Vui lòng chọn ít nhất 1 nguyên liệu';
    for (int i = 0; i < ingredientRows.length; i++) {
      if (!ingredientRows[i].isValid) {
        return 'Số lượng nguyên liệu "${ingredientRows[i].ingredientName}" không hợp lệ (phải > 0)';
      }
    }
    return null;
  }

  bool get hasIngredientErrors => validateIngredients() != null;

  // ── Tiers ────────────────────────────────────────────────────────

  void addTier(void Function() onRebuild) {
    final autoMin = tiers.isNotEmpty
        ? tiers.last.maxQtyCtrl.text.trim()
        : '0';
    tiers.add(TierFormItem(
      name:   'Khung ${tiers.length + 1}',
      minQty: autoMin.isNotEmpty ? autoMin : '0',
    ));
    attachListeners(onRebuild);
    onRebuild();
  }

  void removeTier(int index, void Function() onRebuild) {
    _detachAllListeners();
    tiers[index].dispose();
    tiers.removeAt(index);
    attachListeners(onRebuild);
    onRebuild();
  }

  void attachListeners(void Function() onRebuild) {
    _detachAllListeners();
    if (tiers.isEmpty) return;

    tiers[0].minQtyCtrl.text = '0';

    for (int i = 0; i < tiers.length - 1; i++) {
      final cur  = i;
      final next = i + 1;
      void cb() {
        final val = tiers[cur].maxQtyCtrl.text;
        if (tiers[next].minQtyCtrl.text != val) {
          tiers[next].minQtyCtrl.text = val;
          tiers[next].minQtyCtrl.selection =
              TextSelection.collapsed(offset: val.length);
        }
        onRebuild();
      }
      _maxListeners[cur] = cb;
      tiers[cur].maxQtyCtrl.addListener(cb);
    }

    final last = tiers.length - 1;
    void lastCb() => onRebuild();
    _maxListeners[last] = lastCb;
    tiers[last].maxQtyCtrl.addListener(lastCb);
  }

  void _detachAllListeners() {
    _maxListeners.forEach((i, cb) {
      if (i < tiers.length) tiers[i].maxQtyCtrl.removeListener(cb);
    });
    _maxListeners.clear();
  }

  Map<int, String> validateTiers() {
    if (tiers.isEmpty) return {};
    final errors = <int, String>{};
    for (int i = 0; i < tiers.length; i++) {
      final minRaw = tiers[i].minQtyCtrl.text.trim();
      final maxRaw = tiers[i].maxQtyCtrl.text.trim();
      final minVal = double.tryParse(minRaw);
      final maxVal = maxRaw.isEmpty ? null : double.tryParse(maxRaw);

      if (i == 0 && (minVal == null || minVal != 0)) {
        errors[i] = 'Khung 1 phải bắt đầu từ 0'; continue;
      }
      if (minVal == null) {
        errors[i] = 'Khung ${i+1}: giá trị "Từ" không hợp lệ'; continue;
      }
      if (maxRaw.isNotEmpty && maxVal == null) {
        errors[i] = 'Khung ${i+1}: giá trị "Đến" không hợp lệ'; continue;
      }
      if (maxVal != null && maxVal <= minVal) {
        errors[i] = 'Khung ${i+1}: "Đến" phải lớn hơn "Từ"'; continue;
      }
      if (i == tiers.length - 1 && maxRaw.isNotEmpty) {
        errors[i] = 'Khung cuối — "Đến" phải để trống (vô cực)'; continue;
      }
      if (i < tiers.length - 1 && maxRaw.isEmpty) {
        errors[i] = 'Khung ${i+1}: "Đến" không được để trống vì còn khung sau';
      }
    }
    return errors;
  }

  bool get hasTierErrors => validateTiers().isNotEmpty;

  // ── Save ─────────────────────────────────────────────────────────

  Future<MgmtProductModel?> save() async {
    if (!formKey.currentState!.validate()) return null;
    if (state.isUploading || hasTierErrors) return null;
    if (!state.hasImage) {
      state = state.copyWith(error: 'Vui lòng chọn ảnh sản phẩm');
      return null;
    }
    final ingError = validateIngredients();
    if (ingError != null) {
      state = state.copyWith(error: ingError);
      return null;
    }
    state = state.copyWith(isSaving: true, clearError: true);

    final name        = nameCtrl.text.trim();
    final price       = double.tryParse(
        priceCtrl.text.replaceAll(',', '').replaceAll('.', '').trim()) ?? 0;
    final desc        = descCtrl.text.trim();
    final tiersJson   = List.generate(tiers.length, (i) => tiers[i].toJson(i));
    final ingJson     = ingredientRows.map((r) => r.toJson()).toList();

    final res = arg == null
        ? await SellerService.instance.createProduct(
      name:         name,
      basePrice:    price,
      unit:         state.unit,
      imageUrl:     state.imageUrl,
      description:  desc.isEmpty ? null : desc,
      categoryId:   state.categoryId,
      categoryName: state.categoryName,
      isAvailable:  state.isAvailable,
      vatRate:      state.vatRate,
      tiers:        tiersJson.isEmpty ? null : tiersJson,
      ingredients:  ingJson,
    )
        : await SellerService.instance.updateProduct(
      id:           arg!.id,
      name:         name,
      basePrice:    price,
      unit:         state.unit,
      imageUrl:     state.imageUrl,
      description:  desc.isEmpty ? null : desc,
      categoryId:   state.categoryId,
      categoryName: state.categoryName,
      isAvailable:  state.isAvailable,
      vatRate:      state.vatRate,
      tiers:        tiersJson.isEmpty ? null : tiersJson,
      ingredients:  ingJson,
    );

    state = state.copyWith(isSaving: false);
    if (res.isSuccess) {
      if (arg == null) _reset();
      return res.data;
    }
    state = state.copyWith(error: res.message?.toString() ?? 'Có lỗi xảy ra');
    return null;
  }

  void _reset() {
    nameCtrl.clear();
    priceCtrl.clear();
    descCtrl.clear();
    _detachAllListeners();
    for (final t in tiers) t.dispose();
    tiers.clear();
    for (final i in ingredientRows) i.dispose();
    ingredientRows.clear();
    state = state.copyWith(
      clearImage: true, clearCategory: true,
      isAvailable: true, vatRate: 0, unit: 'kg',
    );
  }
}

final productFormProvider =
NotifierProviderFamily<ProductFormNotifier, ProductFormState,
    MgmtProductModel?>(ProductFormNotifier.new);