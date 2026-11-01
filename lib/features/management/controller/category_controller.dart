// lib/features/management/controller/category_controller.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/management/management_models.dart';
import '../../../services/seller_service.dart';

// ══════════════════════════════════════════════════════════════════
// LIST
// ══════════════════════════════════════════════════════════════════

class CategoryListState {
  final List<MgmtCategoryModel> items;
  final bool isLoading;
  final String? error;

  const CategoryListState({
    this.items     = const [],
    this.isLoading = false,
    this.error,
  });

  CategoryListState copyWith({
    List<MgmtCategoryModel>? items,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) =>
      CategoryListState(
        items:     items     ?? this.items,
        isLoading: isLoading ?? this.isLoading,
        error:     clearError ? null : (error ?? this.error),
      );
}

class CategoryListNotifier extends Notifier<CategoryListState> {
  @override
  CategoryListState build() {
    Future.microtask(_load);
    return const CategoryListState();
  }

  Future<void> _load() async {
    state = state.copyWith(isLoading: true, clearError: true);
    final res = await SellerService.instance.getCategories();
    if (res.isSuccess) {
      state = state.copyWith(
          isLoading: false, items: res.data ?? []);
    } else {
      state = state.copyWith(
          isLoading: false, error: res.message?.toString());
    }
  }

  Future<void> refresh() => _load();

  Future<bool> delete(int id) async {
    final res = await SellerService.instance.deleteCategory(id);
    if (res.isSuccess) {
      await _load();
      return true;
    }
    return false;
  }
}

final categoryListProvider =
NotifierProvider<CategoryListNotifier, CategoryListState>(
    CategoryListNotifier.new);

// ══════════════════════════════════════════════════════════════════
// FORM
// ══════════════════════════════════════════════════════════════════

class CategoryFormState {
  final bool isSaving;
  final bool isUploading;
  final String? imageUrl;      // URL sau khi upload thành công
  final String? uploadError;
  final String? error;

  const CategoryFormState({
    this.isSaving     = false,
    this.isUploading  = false,
    this.imageUrl,
    this.uploadError,
    this.error,
  });

  bool get hasImage => imageUrl != null && imageUrl!.isNotEmpty;

  CategoryFormState copyWith({
    bool? isSaving,
    bool? isUploading,
    String? imageUrl,
    bool clearImage       = false,
    String? uploadError,
    bool clearUploadError = false,
    String? error,
    bool clearError       = false,
  }) =>
      CategoryFormState(
        isSaving:    isSaving    ?? this.isSaving,
        isUploading: isUploading ?? this.isUploading,
        imageUrl:    clearImage  ? null : (imageUrl    ?? this.imageUrl),
        uploadError: clearUploadError ? null : (uploadError ?? this.uploadError),
        error:       clearError  ? null : (error       ?? this.error),
      );
}

class CategoryFormNotifier
    extends FamilyNotifier<CategoryFormState, MgmtCategoryModel?> {
  final formKey  = GlobalKey<FormState>();
  final nameCtrl = TextEditingController();

  @override
  CategoryFormState build(MgmtCategoryModel? arg) {
    ref.onDispose(() => nameCtrl.dispose());
    if (arg != null) {
      nameCtrl.text = arg.name;
      return CategoryFormState(imageUrl: arg.imageUrl);
    }
    return const CategoryFormState();
  }

  /// Gọi khi user chọn file — upload ngay và update state
  Future<void> uploadImage(String filePath) async {
    state = state.copyWith(
        isUploading: true, clearImage: true, clearUploadError: true);
    final res = await SellerService.instance.uploadCategoryImage(filePath);
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

  Future<MgmtCategoryModel?> save() async {
    if (!formKey.currentState!.validate()) return null;
    if (state.isUploading) return null;
    if (!state.hasImage) {
      state = state.copyWith(error: 'Vui lòng chọn ảnh danh mục');
      return null;
    }
    state = state.copyWith(isSaving: true, clearError: true);

    final name = nameCtrl.text.trim();
    final res = arg == null
        ? await SellerService.instance
        .createCategory(name: name, imageUrl: state.imageUrl)
        : await SellerService.instance
        .updateCategory(id: arg!.id, name: name, imageUrl: state.imageUrl);

    state = state.copyWith(isSaving: false);
    if (res.isSuccess) {
      if (arg == null) {
        nameCtrl.clear();
        state = state.copyWith(clearImage: true);
      }
      return res.data;
    }
    state = state.copyWith(error: res.message?.toString() ?? 'Có lỗi xảy ra');
    return null;
  }
}

final categoryFormProvider =
NotifierProviderFamily<CategoryFormNotifier, CategoryFormState,
    MgmtCategoryModel?>(CategoryFormNotifier.new);