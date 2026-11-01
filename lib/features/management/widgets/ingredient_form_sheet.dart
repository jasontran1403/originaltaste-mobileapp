// lib/features/management/widgets/ingredient_form_sheet.dart
// Bottom sheet form để tạo / chỉnh sửa Ingredient

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../data/models/management/management_models.dart';
import '../../../shared/widgets/management_shared_widgets.dart';
import '../controller/ingredient_controller.dart';

class IngredientFormSheet extends ConsumerWidget {
  /// null = create mode, model = edit mode
  final IngredientModel? ingredient;

  const IngredientFormSheet({super.key, this.ingredient});

  static Future<bool> show(BuildContext context,
      {IngredientModel? ingredient}) async {
    final result = await showModalBottomSheet<bool>(
      context:         context,
      isScrollControlled: true,
      useSafeArea:     true,
      backgroundColor: Colors.transparent,
      builder: (_) => IngredientFormSheet(ingredient: ingredient),
    );
    return result == true;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final formState = ref.watch(ingredientFormProvider(ingredient));
    final notifier  = ref.read(ingredientFormProvider(ingredient).notifier);
    final isDark    = Theme.of(context).brightness == Brightness.dark;
    final primary   = isDark ? AppColors.primary : AppColors.primaryDark;
    final cardBg    = isDark ? AppColors.darkCard : AppColors.lightCard;
    final secondary = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final border    = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final bottom    = MediaQuery.of(context).viewInsets.bottom
        + MediaQuery.of(context).padding.bottom
        + 80; // extra cho custom nav bar
    final isEdit    = ingredient != null;

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Container(
        decoration: BoxDecoration(
          color:        cardBg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: EdgeInsets.fromLTRB(20, 0, 20, bottom + 20),
        child: Form(
          key: notifier.formKey,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            // Handle
            Center(
              child: Container(
                margin:       const EdgeInsets.symmetric(vertical: 12),
                width:        40, height: 4,
                decoration:   BoxDecoration(
                  color:        secondary.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Title row
            Row(children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color:        primary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  isEdit ? Icons.edit_outlined : Icons.add_rounded,
                  size: 18, color: primary),
              ),
              const SizedBox(width: 10),
              Text(
                isEdit ? 'Chỉnh sửa nguyên liệu' : 'Thêm nguyên liệu',
                style: TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w800,
                  color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                ),
              ),
            ]),
            const SizedBox(height: 20),

            // Tên nguyên liệu
            MgmtTextField(
              controller:  notifier.nameCtrl,
              label:       'Tên nguyên liệu *',
              hint:        'VD: Bột mì, Đường, Muối...',
              prefixIcon:  Icons.inventory_2_outlined,
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Vui lòng nhập tên';
                if (v.trim().length < 2) return 'Tên quá ngắn';
                return null;
              },
            ),
            const SizedBox(height: 12),

            // Đơn vị + Số lượng (2 cột)
            Row(children: [
              Expanded(
                flex: 2,
                child: MgmtTextField(
                  controller:  notifier.unitCtrl,
                  label:       'Đơn vị *',
                  hint:        'Kg, lít, hộp...',
                  prefixIcon:  Icons.straighten_outlined,
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Nhập đơn vị' : null,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 3,
                child: MgmtTextField(
                  controller:   notifier.stockQtyCtrl,
                  label:        'Tồn kho *',
                  hint:         '0',
                  prefixIcon:   Icons.numbers_outlined,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Nhập số lượng';
                    if (double.tryParse(v) == null) return 'Số không hợp lệ';
                    return null;
                  },
                ),
              ),
            ]),
            const SizedBox(height: 12),

            // Error banner
            if (formState.error != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color:        AppColors.error.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                  border:       Border.all(color: AppColors.error.withOpacity(0.3)),
                ),
                child: Row(children: [
                  Icon(Icons.error_outline, size: 16, color: AppColors.error),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(formState.error!,
                        style: TextStyle(fontSize: 12, color: AppColors.error)),
                  ),
                ]),
              ),
            ],

            const SizedBox(height: 20),

            // Action buttons
            Row(children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: formState.isSaving
                      ? null : () => Navigator.pop(context, false),
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
                  onPressed: formState.isSaving ? null : () async {
                    final result = await notifier.save();
                    if (!context.mounted) return;
                    if (result != null) {
                      showSuccessSnack(context,
                          isEdit ? 'Đã cập nhật nguyên liệu' : 'Đã thêm nguyên liệu');
                      Navigator.pop(context, true);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    elevation:       formState.isSaving ? 0 : 2,
                    shadowColor:     primary.withOpacity(0.4),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  child: formState.isSaving
                      ? const SizedBox(
                          width: 18, height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : Text(isEdit ? 'Lưu thay đổi' : 'Thêm nguyên liệu',
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 14)),
                ),
              ),
            ]),
          ]),
        ),
      ),
    );
  }
}
