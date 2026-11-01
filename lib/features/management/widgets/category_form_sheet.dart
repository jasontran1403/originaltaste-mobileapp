// lib/features/management/widgets/category_form_sheet.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../data/models/management/management_models.dart';
import '../../../shared/widgets/image_picker_field.dart';
import '../../../shared/widgets/management_shared_widgets.dart';
import '../controller/category_controller.dart';

class CategoryFormSheet extends ConsumerWidget {
  final MgmtCategoryModel? category;
  const CategoryFormSheet({super.key, this.category});

  static Future<bool> show(BuildContext context,
      {MgmtCategoryModel? category}) async {
    final result = await showModalBottomSheet<bool>(
      context:             context,
      isScrollControlled:  true,
      useSafeArea:         true,
      backgroundColor:     Colors.transparent,
      builder: (_) => CategoryFormSheet(category: category),
    );
    return result == true;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s       = ref.watch(categoryFormProvider(category));
    final n       = ref.read(categoryFormProvider(category).notifier);
    final isDark  = Theme.of(context).brightness == Brightness.dark;
    final primary = isDark ? AppColors.primary : AppColors.primaryDark;
    final cardBg  = isDark ? AppColors.darkCard : AppColors.lightCard;
    final secondary = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final border  = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final bottom  = MediaQuery.of(context).viewInsets.bottom
        + MediaQuery.of(context).padding.bottom
        + 80; // extra cho custom nav bar
    final isEdit  = category != null;

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Container(
        decoration: BoxDecoration(
          color:        cardBg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: EdgeInsets.fromLTRB(20, 0, 20, bottom + 20),
        child: Form(
          key: n.formKey,
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              // Handle
              Center(
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                      color: secondary.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(2)),
                ),
              ),

              // Title
              Row(children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                      color:        primary.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10)),
                  child: Icon(
                      isEdit ? Icons.edit_outlined : Icons.add_rounded,
                      size: 18, color: primary),
                ),
                const SizedBox(width: 10),
                Text(
                  isEdit ? 'Chỉnh sửa danh mục' : 'Thêm danh mục',
                  style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w800,
                      color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
                ),
              ]),
              const SizedBox(height: 20),

              // Tên
              MgmtTextField(
                controller: n.nameCtrl,
                label:      'Tên danh mục *',
                hint:       'VD: Đồ uống, Bánh ngọt...',
                prefixIcon: Icons.category_outlined,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Vui lòng nhập tên';
                  if (v.trim().length < 2) return 'Tên quá ngắn';
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Ảnh
              ImagePickerField(
                label:         'Ảnh danh mục *',
                imageUrl:      s.imageUrl,
                isUploading:   s.isUploading,
                uploadError:   s.uploadError,
                onPick:        n.uploadImage,
                onClear:       n.clearImage,
                height:        150,
              ),
              // Lỗi ảnh bắt buộc
              if (!s.hasImage && s.error == 'Vui lòng chọn ảnh danh mục') ...[
                const SizedBox(height: 6),
                Row(children: [
                  const SizedBox(width: 4),
                  Icon(Icons.error_outline, size: 13, color: AppColors.error),
                  const SizedBox(width: 4),
                  Text('Vui lòng chọn ảnh danh mục',
                      style: TextStyle(fontSize: 12, color: AppColors.error)),
                ]),
              ],

              // Error banner
              if (s.error != null && s.error != 'Vui lòng chọn ảnh danh mục') ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color:        AppColors.error.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: AppColors.error.withOpacity(0.3)),
                  ),
                  child: Row(children: [
                    Icon(Icons.error_outline,
                        size: 16, color: AppColors.error),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(s.error!,
                          style: TextStyle(
                              fontSize: 12, color: AppColors.error)),
                    ),
                  ]),
                ),
              ],
              const SizedBox(height: 20),

              // Buttons
              Row(children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: s.isSaving
                        ? null
                        : () => Navigator.pop(context, false),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      side: BorderSide(color: border),
                    ),
                    child: const Text('Hủy'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: (s.isSaving || s.isUploading) ? null : () async {
                      final result = await n.save();
                      if (!context.mounted) return;
                      if (result != null) {
                        showSuccessSnack(context,
                            isEdit ? 'Đã cập nhật danh mục' : 'Đã thêm danh mục');
                        Navigator.pop(context, true);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      elevation: s.isSaving ? 0 : 2,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    child: s.isSaving
                        ? const SizedBox(
                            width: 18, height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : s.isUploading
                            ? const Text('Đang upload...',
                                style: TextStyle(fontWeight: FontWeight.w700))
                            : Text(isEdit ? 'Lưu thay đổi' : 'Thêm danh mục',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700, fontSize: 14)),
                  ),
                ),
              ]),
            ]),
          ),
        ),
      ),
    );
  }
}
