// lib/features/management/controller/ingredient_controller.dart
// Riverpod Notifier cho Ingredient list + form (create/edit)

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/management/management_models.dart';
import '../../../data/network/api_result.dart';
import '../../../services/seller_service.dart';

// ══════════════════════════════════════════════════════════════════
// LIST STATE
// ══════════════════════════════════════════════════════════════════

class IngredientListState {
  final List<IngredientModel> items;
  final bool isLoading;
  final bool hasMore;
  final int page;
  final String? error;

  const IngredientListState({
    this.items     = const [],
    this.isLoading = false,
    this.hasMore   = true,
    this.page      = 0,
    this.error,
  });

  IngredientListState copyWith({
    List<IngredientModel>? items,
    bool? isLoading, bool? hasMore, int? page,
    String? error, bool clearError = false,
  }) => IngredientListState(
    items:     items     ?? this.items,
    isLoading: isLoading ?? this.isLoading,
    hasMore:   hasMore   ?? this.hasMore,
    page:      page      ?? this.page,
    error:     clearError ? null : (error ?? this.error),
  );
}

class IngredientListNotifier extends Notifier<IngredientListState> {
  static const _pageSize = 20;
  bool _loadingMore = false;  // ← guard ngoài state, sync ngay lập tức

  @override
  IngredientListState build() {
    _loadingMore = false;
    Future.microtask(() => _load(refresh: true));
    return const IngredientListState();
  }

  Future<void> _load({bool refresh = false, int? pageOverride}) async {
    final page = pageOverride ?? (refresh ? 0 : state.page);
    if (refresh) _loadingMore = false;

    state = state.copyWith(
      isLoading: true,
      clearError: true,
      items: refresh ? [] : null,
      page: page,
    );

    final res = await SellerService.instance
        .getIngredients(page: page, size: _pageSize);

    _loadingMore = false;  // reset sau khi xong

    if (res.isSuccess) {
      final newItems = (res.data as List<IngredientModel>?) ?? [];
      state = state.copyWith(
        items:     refresh ? newItems : [...state.items, ...newItems],
        isLoading: false,
        hasMore:   newItems.length == _pageSize,
        page:      page,
      );
    } else {
      state = state.copyWith(
          isLoading: false, error: res.message as String?);
    }
  }

  Future<void> refresh() => _load(refresh: true);

  Future<void> loadMore() async {
    // Double guard: state.isLoading (async) + _loadingMore (sync)
    if (!state.hasMore || state.isLoading || _loadingMore) return;
    _loadingMore = true;  // ← set ngay lập tức, trước khi await
    await _load(pageOverride: state.page + 1);
  }

  Future<bool> delete(int id) async {
    final res = await SellerService.instance.deleteIngredient(id);
    if (res.isSuccess) { await refresh(); return true; }
    return false;
  }
}

final ingredientListProvider =
    NotifierProvider<IngredientListNotifier, IngredientListState>(
        IngredientListNotifier.new);

// ══════════════════════════════════════════════════════════════════
// FORM STATE
// ══════════════════════════════════════════════════════════════════

class IngredientFormState {
  final bool isSaving;
  final bool isLoading;
  final String? error;
  final DateTime? importDate;
  final DateTime? expiryDate;

  const IngredientFormState({
    this.isSaving   = false,
    this.isLoading  = false,
    this.error,
    this.importDate,
    this.expiryDate,
  });

  IngredientFormState copyWith({
    bool? isSaving, bool? isLoading,
    String? error, bool clearError = false,
    DateTime? importDate, bool clearImport = false,
    DateTime? expiryDate, bool clearExpiry = false,
  }) => IngredientFormState(
    isSaving:   isSaving   ?? this.isSaving,
    isLoading:  isLoading  ?? this.isLoading,
    error:      clearError  ? null : (error       ?? this.error),
    importDate: clearImport ? null : (importDate  ?? this.importDate),
    expiryDate: clearExpiry ? null : (expiryDate  ?? this.expiryDate),
  );
}

class IngredientFormNotifier
    extends FamilyNotifier<IngredientFormState, IngredientModel?> {
  final formKey      = GlobalKey<FormState>();
  final nameCtrl     = TextEditingController();
  final unitCtrl     = TextEditingController();
  final stockQtyCtrl = TextEditingController();

  @override
  IngredientFormState build(IngredientModel? arg) {
    ref.onDispose(() {
      nameCtrl.dispose();
      unitCtrl.dispose();
      stockQtyCtrl.dispose();
    });
    if (arg != null) {
      nameCtrl.text     = arg.name;
      unitCtrl.text     = arg.unit;
      stockQtyCtrl.text = arg.stockQuantity.toString();
      return IngredientFormState(
        importDate: arg.importDate != null
            ? DateTime.fromMillisecondsSinceEpoch(arg.importDate!) : null,
        expiryDate: arg.expiryDate != null
            ? DateTime.fromMillisecondsSinceEpoch(arg.expiryDate!) : null,
      );
    }
    unitCtrl.text = 'Kg';
    return const IngredientFormState();
  }

  void setImportDate(DateTime? d) => state = d == null
      ? state.copyWith(clearImport: true) : state.copyWith(importDate: d);

  void setExpiryDate(DateTime? d) => state = d == null
      ? state.copyWith(clearExpiry: true) : state.copyWith(expiryDate: d);

  Future<IngredientModel?> save() async {
    if (!formKey.currentState!.validate()) return null;
    state = state.copyWith(isSaving: true, clearError: true);

    final name  = nameCtrl.text.trim();
    final unit  = unitCtrl.text.trim();
    final qty   = double.tryParse(stockQtyCtrl.text) ?? 0;

    final res = arg == null
        ? await SellerService.instance.createIngredient(
            name: name, unit: unit, stockQuantity: qty,
            importDate: state.importDate?.millisecondsSinceEpoch,
            expiryDate: state.expiryDate?.millisecondsSinceEpoch)
        : await SellerService.instance.updateIngredient(
            id: arg!.id, name: name, unit: unit, stockQuantity: qty,
            importDate: state.importDate?.millisecondsSinceEpoch,
            expiryDate: state.expiryDate?.millisecondsSinceEpoch);

    state = state.copyWith(isSaving: false);
    if (res.isSuccess) {
      if (arg == null) _reset();
      return res.data as IngredientModel?;
    }
    state = state.copyWith(error: res.message?.toString() ?? 'Có lỗi xảy ra');
    return null;
  }

  void _reset() {
    nameCtrl.clear();
    unitCtrl.text = 'Kg';
    stockQtyCtrl.clear();
    state = state.copyWith(clearImport: true, clearExpiry: true);
  }
}

final ingredientFormProvider =
    NotifierProviderFamily<IngredientFormNotifier, IngredientFormState,
        IngredientModel?>(IngredientFormNotifier.new);
