// lib/features/management/widgets/product_form_sheet.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../data/models/management/management_models.dart';
import '../../../shared/widgets/image_picker_field.dart';
import '../../../shared/widgets/management_shared_widgets.dart';
import '../controller/product_controller.dart';

class ProductFormSheet extends ConsumerStatefulWidget {
  final MgmtProductModel? product;
  const ProductFormSheet({super.key, this.product});

  static Future<bool> show(BuildContext context,
      {MgmtProductModel? product}) async {
    final isMobile = MediaQuery.of(context).size.width < 600;
    final result = await showModalBottomSheet<bool>(
      context:            context,
      isScrollControlled: true,
      useSafeArea:        true,
      backgroundColor:    Colors.transparent,
      isDismissible:      true,
      builder: (_) => Padding(
        padding: EdgeInsets.only(top: isMobile ? 100 : 20),
        child: ProductFormSheet(product: product),
      ),
    );
    return result == true;
  }

  @override
  ConsumerState<ProductFormSheet> createState() => _ProductFormSheetState();
}

class _ProductFormSheetState extends ConsumerState<ProductFormSheet> {
  late final ProductFormNotifier _n;

  @override
  void initState() {
    super.initState();
    _n = ref.read(productFormProvider(widget.product).notifier);
  }

  void _rebuild() => setState(() {});

  Map<int, String> get _tierErrors => _n.validateTiers();

  @override
  Widget build(BuildContext context) {
    final s         = ref.watch(productFormProvider(widget.product));
    final isDark    = Theme.of(context).brightness == Brightness.dark;
    final primary   = isDark ? AppColors.primary : AppColors.primaryDark;
    final cardBg    = isDark ? AppColors.darkCard : AppColors.lightCard;
    final secondary = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final border    = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final bottom    = MediaQuery.of(context).viewInsets.bottom +
        MediaQuery.of(context).padding.bottom + 60;
    final isEdit    = widget.product != null;
    final onBg      = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final fillBg    = isDark
        ? AppColors.darkBg.withOpacity(0.5)
        : AppColors.lightBg.withOpacity(0.6);

    WidgetsBinding.instance
        .addPostFrameCallback((_) => _n.attachListeners(_rebuild));

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Container(
        decoration: BoxDecoration(
          color:        cardBg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: EdgeInsets.fromLTRB(20, 10, 20, bottom + 20),
        child: Form(
          key: _n.formKey,
          child: SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              // Handle bar
              Center(
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color:        secondary.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Title
              Row(children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color:        primary.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    isEdit ? Icons.edit_outlined : Icons.add_rounded,
                    size: 18, color: primary,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  isEdit ? 'Chỉnh sửa sản phẩm' : 'Thêm sản phẩm',
                  style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w800, color: onBg),
                ),
              ]),
              const SizedBox(height: 20),

              // ── 1. Ảnh ──────────────────────────────────────────
              ImagePickerField(
                label:       'Ảnh sản phẩm *',
                imageUrl:    s.imageUrl,
                isUploading: s.isUploading,
                uploadError: s.uploadError,
                onPick:      _n.uploadImage,
                onClear:     _n.clearImage,
                height:      160,
              ),
              if (!s.hasImage && s.error == 'Vui lòng chọn ảnh sản phẩm') ...[
                const SizedBox(height: 6),
                Row(children: [
                  const SizedBox(width: 4),
                  Icon(Icons.error_outline, size: 13, color: AppColors.error),
                  const SizedBox(width: 4),
                  Text('Vui lòng chọn ảnh sản phẩm',
                      style: TextStyle(fontSize: 12, color: AppColors.error)),
                ]),
              ],
              const SizedBox(height: 16),

              // ── 2. Tên ──────────────────────────────────────────
              MgmtTextField(
                controller: _n.nameCtrl,
                label:      'Tên sản phẩm *',
                hint:       'VD: Cà phê sữa đá...',
                prefixIcon: Icons.storefront_outlined,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Vui lòng nhập tên';
                  if (v.trim().length < 2) return 'Tên quá ngắn';
                  return null;
                },
              ),
              const SizedBox(height: 12),

              // ── 3. Giá gốc ──────────────────────────────────────
              MgmtTextField(
                controller:      _n.priceCtrl,
                label:           'Giá gốc (VNĐ) *',
                hint:            'VD: 35000',
                prefixIcon:      Icons.payments_outlined,
                keyboardType:    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                showDoneButton:  true, // ← nút Done trên bàn phím
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Vui lòng nhập giá';
                  if (double.tryParse(
                      v.replaceAll(',', '').replaceAll('.', '')) ==
                      null) return 'Giá không hợp lệ';
                  return null;
                },
              ),
              const SizedBox(height: 12),

              // ── 4. Đơn vị tính + VAT ────────────────────────────
              Row(children: [
                Expanded(
                  child: _DropdownField<String>(
                    value:     s.unit,
                    label:     'Đơn vị tính *',
                    icon:      Icons.straighten_outlined,
                    items:     _n.unitOptions
                        .map((u) => DropdownMenuItem(value: u, child: Text(u)))
                        .toList(),
                    onChanged: (v) { if (v != null) _n.setUnit(v); },
                    isDark: isDark, primary: primary,
                    secondary: secondary, border: border, fillBg: fillBg,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _DropdownField<int>(
                    label:     'Thuế VAT',
                    value:     s.vatRate,
                    icon:      Icons.receipt_long_outlined,
                    items:     _n.vatOptions
                        .map((r) => DropdownMenuItem(value: r, child: Text('$r%')))
                        .toList(),
                    onChanged: (v) { if (v != null) _n.setVatRate(v); },
                    isDark: isDark, primary: primary,
                    secondary: secondary, border: border, fillBg: fillBg,
                  ),
                ),
              ]),
              const SizedBox(height: 12),

              // ── 5. Danh mục ──────────────────────────────────────
              s.isLoadingData
                  ? _LoadingField(
                  label: 'Danh mục',
                  secondary: secondary, border: border, fillBg: fillBg)
                  : _DropdownField<int?>(
                label: 'Danh mục',
                value: s.categoryId,
                icon:  Icons.category_outlined,
                hint:  'Không có danh mục',
                items: [
                  const DropdownMenuItem<int?>(
                      value: null,
                      child: Text('Không có danh mục',
                          style: TextStyle(fontSize: 13))),
                  ...s.categories.map((c) => DropdownMenuItem<int?>(
                      value: c.id,
                      child: Text(c.name,
                          style: const TextStyle(fontSize: 13)))),
                ],
                onChanged: (id) {
                  final name = s.categories
                      .where((c) => c.id == id)
                      .map((c) => c.name)
                      .firstOrNull;
                  _n.setCategory(id, name: name);
                },
                isDark: isDark, primary: primary,
                secondary: secondary, border: border, fillBg: fillBg,
              ),
              const SizedBox(height: 12),

              // ── 6. Mô tả ─────────────────────────────────────────
              MgmtTextField(
                controller: _n.descCtrl,
                label:      'Mô tả',
                hint:       'Mô tả ngắn về sản phẩm...',
                prefixIcon: Icons.notes_outlined,
                maxLines:   3,
              ),
              const SizedBox(height: 12),

              // ── 7. Trạng thái bán ────────────────────────────────
              _AvailableToggle(
                value:     s.isAvailable,
                onChanged: _n.setAvailable,
                isDark: isDark, primary: primary,
                secondary: secondary, border: border, fillBg: fillBg,
              ),
              const SizedBox(height: 16),

              // ── 8. Nguyên liệu ───────────────────────────────────
              s.isLoadingData
                  ? _LoadingField(
                  label: 'Nguyên liệu',
                  secondary: secondary, border: border, fillBg: fillBg)
                  : _IngredientSection(
                notifier:       _n,
                allIngredients: s.ingredients,
                onRebuild:      _rebuild,
                isDark: isDark, primary: primary,
                secondary: secondary, border: border,
                fillBg: fillBg, onBg: onBg,
              ),
              const SizedBox(height: 16),

              // ── 9. Khung giá sỉ ──────────────────────────────────
              _TierSection(
                notifier:   _n,
                tierErrors: _tierErrors,
                onRebuild:  _rebuild,
                isDark: isDark, primary: primary,
                secondary: secondary, border: border,
                fillBg: fillBg, onBg: onBg,
              ),

              // ── Error ────────────────────────────────────────────
              if (s.error != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color:  AppColors.error.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.error.withOpacity(0.3)),
                  ),
                  child: Row(children: [
                    Icon(Icons.error_outline, size: 16, color: AppColors.error),
                    const SizedBox(width: 8),
                    Expanded(
                        child: Text(s.error!,
                            style: TextStyle(fontSize: 12, color: AppColors.error))),
                  ]),
                ),
              ],
              const SizedBox(height: 20),

              // ── Buttons ──────────────────────────────────────────
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
                    onPressed: (s.isSaving || s.isUploading || _n.hasTierErrors)
                        ? null
                        : () async {
                      final result = await _n.save();
                      if (!context.mounted) return;
                      if (result != null) {
                        showSuccessSnack(context,
                            isEdit ? 'Đã cập nhật sản phẩm' : 'Đã thêm sản phẩm');
                        Navigator.pop(context, true);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor:         primary,
                      foregroundColor:         Colors.white,
                      padding:                 const EdgeInsets.symmetric(vertical: 14),
                      disabledBackgroundColor: primary.withOpacity(0.45),
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
                        : Text(isEdit ? 'Lưu thay đổi' : 'Thêm sản phẩm',
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

// ══════════════════════════════════════════════════════════════════
// INGREDIENT SECTION
// ══════════════════════════════════════════════════════════════════

class _IngredientSection extends StatelessWidget {
  final ProductFormNotifier notifier;
  final List<IngredientModel> allIngredients;
  final VoidCallback onRebuild;
  final bool isDark;
  final Color primary, secondary, border, fillBg, onBg;

  const _IngredientSection({
    required this.notifier,
    required this.allIngredients,
    required this.onRebuild,
    required this.isDark,
    required this.primary,
    required this.secondary,
    required this.border,
    required this.fillBg,
    required this.onBg,
  });

  @override
  Widget build(BuildContext context) {
    final rows           = notifier.ingredientRows;
    final showEmptyError = rows.isEmpty;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Icon(Icons.science_outlined, size: 16, color: primary),
        const SizedBox(width: 6),
        Text('Nguyên liệu *',
            style: TextStyle(
                fontSize: 14, fontWeight: FontWeight.w700, color: onBg)),
        const Spacer(),
        GestureDetector(
          onTap: () async {
            final selected = await showModalBottomSheet<IngredientModel>(
              context:            context,
              isScrollControlled: true,
              backgroundColor:    Colors.transparent,
              builder: (_) => _IngredientPickerSheet(
                allIngredients: allIngredients,
                selectedIds:    rows.map((r) => r.ingredientId).toSet(),
                isDark:         isDark,
                primary:        primary,
              ),
            );
            if (selected != null) {
              notifier.addIngredientRow(selected, onRebuild);
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color:        primary.withOpacity(0.10),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.add, size: 14, color: primary),
              const SizedBox(width: 4),
              Text('Thêm nguyên liệu',
                  style: TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w600, color: primary)),
            ]),
          ),
        ),
      ]),
      const SizedBox(height: 8),

      if (rows.isEmpty)
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: showEmptyError
                ? AppColors.error.withOpacity(0.05)
                : secondary.withOpacity(0.05),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: showEmptyError
                  ? AppColors.error.withOpacity(0.4)
                  : secondary.withOpacity(0.15),
            ),
          ),
          child: Row(children: [
            Icon(Icons.info_outline,
                size: 15,
                color: showEmptyError
                    ? AppColors.error.withOpacity(0.7)
                    : secondary.withOpacity(0.5)),
            const SizedBox(width: 8),
            Text(
              'Chưa có nguyên liệu — nhấn "Thêm nguyên liệu" để chọn',
              style: TextStyle(
                  fontSize: 12,
                  color: showEmptyError ? AppColors.error : secondary),
            ),
          ]),
        )
      else ...[
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(children: [
            Expanded(
                flex: 4,
                child: Text('Nguyên liệu',
                    style: TextStyle(fontSize: 11, color: secondary))),
            const SizedBox(width: 6),
            SizedBox(
                width: 90,
                child: Text('Số lượng',
                    style: TextStyle(fontSize: 11, color: secondary))),
            const SizedBox(width: 6),
            SizedBox(
                width: 48,
                child: Text('ĐVT',
                    style: TextStyle(fontSize: 11, color: secondary),
                    textAlign: TextAlign.center)),
            const SizedBox(width: 32),
          ]),
        ),
        ...List.generate(
          rows.length,
              (i) => _IngredientRow(
            row:      rows[i],
            onRemove: () => notifier.removeIngredientRow(i, onRebuild),
            isDark:   isDark,
            primary:  primary,
            secondary: secondary,
            border:   border,
            onBg:     onBg,
          ),
        ),
      ],
    ]);
  }
}

// ── 1 dòng nguyên liệu ───────────────────────────────────────────

class _IngredientRow extends StatelessWidget {
  final IngredientFormItem row;
  final VoidCallback onRemove;
  final bool isDark;
  final Color primary, secondary, border, onBg;

  const _IngredientRow({
    required this.row,
    required this.onRemove,
    required this.isDark,
    required this.primary,
    required this.secondary,
    required this.border,
    required this.onBg,
  });

  @override
  Widget build(BuildContext context) {
    final r = row;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        // Tên nguyên liệu
        Expanded(
          flex: 4,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            decoration: BoxDecoration(
              color:        primary.withOpacity(0.05),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: primary.withOpacity(0.2)),
            ),
            child: Text(
              r.ingredientName,
              style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w600, color: onBg),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
        const SizedBox(width: 6),

        // Số lượng
        SizedBox(
          width: 90,
          child: TextField(
            controller:      r.quantityCtrl,
            keyboardType:    const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,3}')),
            ],
            textInputAction: TextInputAction.done,              // ← Done
            onSubmitted:     (_) => FocusScope.of(context).unfocus(),
            style:     TextStyle(fontSize: 13, color: onBg),
            textAlign: TextAlign.center,
            decoration: InputDecoration(
              hintText:  '1',
              hintStyle: TextStyle(fontSize: 12, color: secondary.withOpacity(0.5)),
              isDense:        true,
              isCollapsed:    true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: border)),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: border)),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: primary, width: 1.5)),
            ),
          ),
        ),
        const SizedBox(width: 6),

        // Đơn vị
        Container(
          width: 48,
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: secondary.withOpacity(0.06),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: secondary.withOpacity(0.2)),
          ),
          child: Text(
            r.ingredientUnit,
            style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.w600, color: secondary),
            textAlign: TextAlign.center,
            maxLines:  1,
            overflow:  TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 6),

        // Xóa
        GestureDetector(
          onTap: onRemove,
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color:        AppColors.error.withOpacity(0.10),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.close, size: 15, color: AppColors.error),
          ),
        ),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════════
// INGREDIENT PICKER SHEET
// ══════════════════════════════════════════════════════════════════

class _IngredientPickerSheet extends StatefulWidget {
  final List<IngredientModel> allIngredients;
  final Set<int> selectedIds;
  final bool isDark;
  final Color primary;

  const _IngredientPickerSheet({
    required this.allIngredients,
    required this.selectedIds,
    required this.isDark,
    required this.primary,
  });

  @override
  State<_IngredientPickerSheet> createState() => _IngredientPickerSheetState();
}

class _IngredientPickerSheetState extends State<_IngredientPickerSheet> {
  final _searchCtrl  = TextEditingController();
  final _searchFocus = FocusNode();
  List<IngredientModel> _filtered = [];

  @override
  void initState() {
    super.initState();
    _filtered = widget.allIngredients;
    _searchCtrl.addListener(_onSearch);
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _searchFocus.requestFocus());
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  void _onSearch() {
    final q = _searchCtrl.text.toLowerCase().trim();
    setState(() {
      _filtered = q.isEmpty
          ? widget.allIngredients
          : widget.allIngredients
          .where((i) => i.name.toLowerCase().contains(q))
          .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark    = widget.isDark;
    final primary   = widget.primary;
    final cardBg    = isDark ? AppColors.darkCard : Colors.white;
    final border    = isDark ? AppColors.darkBorder : const Color(0xFFE5E7EB);
    final onBg      = isDark ? AppColors.darkTextPrimary : Colors.black87;
    final secondary = isDark ? AppColors.darkTextSecondary : const Color(0xFF6B7280);
    final bottom    = MediaQuery.of(context).padding.bottom;

    return Container(
      decoration: BoxDecoration(
        color:        cardBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      constraints:
      BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.80),
      child: Column(children: [
        Center(
          child: Container(
            margin: const EdgeInsets.only(top: 12, bottom: 4),
            width: 40, height: 4,
            decoration: BoxDecoration(
                color: border, borderRadius: BorderRadius.circular(2)),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                  color: primary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10)),
              child: Icon(Icons.science_outlined, color: primary, size: 18),
            ),
            const SizedBox(width: 10),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Chọn nguyên liệu',
                  style: TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w800, color: onBg)),
              Text('${widget.allIngredients.length} nguyên liệu',
                  style: TextStyle(fontSize: 11, color: secondary)),
            ]),
            const Spacer(),
            IconButton(
              onPressed:   () => Navigator.pop(context),
              icon:        Icon(Icons.close_rounded, color: secondary),
              padding:     EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
          child: TextField(
            controller: _searchCtrl,
            focusNode:  _searchFocus,
            style: TextStyle(fontSize: 14, color: onBg),
            decoration: InputDecoration(
              hintText:   'Tìm nguyên liệu...',
              hintStyle:  TextStyle(color: secondary, fontSize: 14),
              prefixIcon: Icon(Icons.search, color: secondary, size: 20),
              suffixIcon: _searchCtrl.text.isNotEmpty
                  ? IconButton(
                  icon: Icon(Icons.clear, size: 16, color: secondary),
                  onPressed: () {
                    _searchCtrl.clear();
                    _searchFocus.requestFocus();
                  })
                  : null,
              filled:    true,
              fillColor: secondary.withOpacity(0.06),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: border)),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: border)),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: primary, width: 1.5)),
              contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
          ),
        ),
        Divider(height: 0, color: border),
        Expanded(
          child: _filtered.isEmpty
              ? Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.search_off_rounded,
                    size: 40, color: secondary.withOpacity(0.3)),
                const SizedBox(height: 8),
                Text('Không tìm thấy nguyên liệu',
                    style: TextStyle(color: secondary)),
              ]))
              : ListView.separated(
            padding:      EdgeInsets.only(bottom: bottom + 16),
            itemCount:    _filtered.length,
            separatorBuilder: (_, __) => Divider(height: 0, color: border),
            itemBuilder: (_, i) {
              final ing            = _filtered[i];
              final isAlreadyAdded = widget.selectedIds.contains(ing.id);
              return InkWell(
                onTap: isAlreadyAdded ? null : () => Navigator.pop(context, ing),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 12),
                  color: isAlreadyAdded
                      ? primary.withOpacity(0.06)
                      : Colors.transparent,
                  child: Row(children: [
                    Container(
                      width: 38, height: 38,
                      decoration: BoxDecoration(
                        color: isAlreadyAdded
                            ? primary.withOpacity(0.12)
                            : secondary.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        isAlreadyAdded
                            ? Icons.check_circle_rounded
                            : Icons.science_outlined,
                        color: isAlreadyAdded ? primary : secondary,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(ing.name,
                                style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: isAlreadyAdded ? primary : onBg)),
                            Text(
                              'Tồn: ${ing.stockQuantity.toStringAsFixed(1)} ${ing.unit}',
                              style: TextStyle(fontSize: 11, color: secondary),
                            ),
                          ]),
                    ),
                    if (isAlreadyAdded)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color:        primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text('Đã thêm',
                            style: TextStyle(
                                fontSize: 11,
                                color: primary,
                                fontWeight: FontWeight.w600)),
                      ),
                  ]),
                ),
              );
            },
          ),
        ),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════════
// TIER SECTION
// ══════════════════════════════════════════════════════════════════

class _TierSection extends StatelessWidget {
  final ProductFormNotifier notifier;
  final Map<int, String> tierErrors;
  final VoidCallback onRebuild;
  final bool isDark;
  final Color primary, secondary, border, fillBg, onBg;

  const _TierSection({
    required this.notifier,
    required this.tierErrors,
    required this.onRebuild,
    required this.isDark,
    required this.primary,
    required this.secondary,
    required this.border,
    required this.fillBg,
    required this.onBg,
  });

  @override
  Widget build(BuildContext context) {
    final tiers = notifier.tiers;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Icon(Icons.layers_outlined, size: 16, color: primary),
        const SizedBox(width: 6),
        Text('Khung giá sỉ',
            style: TextStyle(
                fontSize: 14, fontWeight: FontWeight.w700, color: onBg)),
        const Spacer(),
        GestureDetector(
          onTap: () => notifier.addTier(onRebuild),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color:        primary.withOpacity(0.10),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.add, size: 14, color: primary),
              const SizedBox(width: 4),
              Text('Thêm khung',
                  style: TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w600, color: primary)),
            ]),
          ),
        ),
      ]),
      const SizedBox(height: 8),

      if (tiers.isEmpty)
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color:        secondary.withOpacity(0.05),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: secondary.withOpacity(0.15)),
          ),
          child: Row(children: [
            Icon(Icons.info_outline, size: 15, color: secondary.withOpacity(0.5)),
            const SizedBox(width: 8),
            Text('Không có khung giá — dùng giá gốc cho tất cả đơn',
                style: TextStyle(fontSize: 12, color: secondary)),
          ]),
        )
      else ...[
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(children: [
            const SizedBox(width: 72),
            const SizedBox(width: 8),
            Expanded(
                flex: 2,
                child: Text('Từ (SL)',
                    style: TextStyle(fontSize: 11, color: secondary))),
            const SizedBox(width: 6),
            Expanded(
                flex: 2,
                child: Text('Đến (SL)',
                    style: TextStyle(fontSize: 11, color: secondary))),
            const SizedBox(width: 6),
            Expanded(
                flex: 2,
                child: Text('Giá (đ)',
                    style: TextStyle(fontSize: 11, color: secondary))),
            const SizedBox(width: 32),
          ]),
        ),
        ...List.generate(
          tiers.length,
              (i) => _TierRow(
            tier:     tiers[i],
            index:    i,
            hasError: tierErrors.containsKey(i),
            onRemove: () => notifier.removeTier(i, onRebuild),
            isDark:   isDark,
            primary:  primary,
            secondary: secondary,
            border:   border,
            fillBg:   fillBg,
          ),
        ),
        Text('* "Đến" để trống = không giới hạn trên',
            style: TextStyle(fontSize: 11, color: secondary)),
        if (tierErrors.isNotEmpty) ...[
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color:        AppColors.error.withOpacity(0.06),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.error.withOpacity(0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Icon(Icons.warning_amber_rounded, size: 14, color: AppColors.error),
                  const SizedBox(width: 6),
                  Text('Khung giá phải nối tiếp nhau',
                      style: TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w700,
                          color: AppColors.error)),
                ]),
                ...tierErrors.entries.map((e) => Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: Text('• ${e.value}',
                      style: TextStyle(fontSize: 11, color: AppColors.error)),
                )),
              ],
            ),
          ),
        ],
      ],
    ]);
  }
}

class _TierRow extends StatelessWidget {
  final TierFormItem tier;
  final int index;
  final bool hasError;
  final VoidCallback onRemove;
  final bool isDark;
  final Color primary, secondary, border, fillBg;

  const _TierRow({
    required this.tier,
    required this.index,
    required this.hasError,
    required this.onRemove,
    required this.isDark,
    required this.primary,
    required this.secondary,
    required this.border,
    required this.fillBg,
  });

  InputDecoration _deco(String hint, {bool locked = false}) {
    final errorBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(color: AppColors.error.withOpacity(0.8)),
    );
    final normalBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(
          color: locked ? secondary.withOpacity(0.2) : border),
    );
    final b = hasError ? errorBorder : normalBorder;

    return InputDecoration(
      hintText:  hint,
      hintStyle: TextStyle(fontSize: 12, color: secondary.withOpacity(0.5)),
      isDense:        true,
      isCollapsed:    true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      filled:         locked,
      fillColor:      locked ? secondary.withOpacity(0.06) : null,
      border:         b,
      enabledBorder:  b,
      focusedBorder: hasError
          ? errorBorder
          : OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: primary, width: 1.5)),
      disabledBorder: b,
      suffixIcon: locked
          ? Icon(Icons.lock_outline, size: 12, color: secondary.withOpacity(0.4))
          : null,
      suffixIconConstraints: const BoxConstraints(minWidth: 24, maxWidth: 24),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = tier;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        Container(
          width: 72,
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 7),
          decoration: BoxDecoration(
            color: hasError
                ? AppColors.error.withOpacity(0.08)
                : primary.withOpacity(0.10),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
                color: hasError
                    ? AppColors.error.withOpacity(0.35)
                    : primary.withOpacity(0.20)),
          ),
          child: Text('Khung ${index + 1}',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w700,
                  color: hasError ? AppColors.error : primary)),
        ),
        const SizedBox(width: 6),

        // Từ (locked)
        Expanded(
          flex: 2,
          child: TextField(
            controller:               t.minQtyCtrl,
            readOnly:                 true,
            enableInteractiveSelection: false,
            style: TextStyle(fontSize: 13, color: secondary.withOpacity(0.65)),
            decoration: _deco('0', locked: true),
          ),
        ),
        const SizedBox(width: 6),

        // Đến
        Expanded(
          flex: 2,
          child: TextField(
            controller:      t.maxQtyCtrl,
            keyboardType:    const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
            ],
            textInputAction: TextInputAction.done,              // ← Done
            onSubmitted:     (_) => FocusScope.of(context).unfocus(),
            style:           const TextStyle(fontSize: 13),
            decoration:      _deco('∞'),
          ),
        ),
        const SizedBox(width: 6),

        // Giá
        Expanded(
          flex: 2,
          child: TextField(
            controller:      t.priceCtrl,
            keyboardType:    TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            textInputAction: TextInputAction.done,              // ← Done
            onSubmitted:     (_) => FocusScope.of(context).unfocus(),
            style:           const TextStyle(fontSize: 13),
            decoration:      _deco('Giá'),
          ),
        ),
        const SizedBox(width: 6),

        // Xóa
        GestureDetector(
          onTap: onRemove,
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color:        AppColors.error.withOpacity(0.10),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.close, size: 15, color: AppColors.error),
          ),
        ),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════════
// SHARED SUB-WIDGETS
// ══════════════════════════════════════════════════════════════════

class _DropdownField<T> extends StatelessWidget {
  final String label;
  final T value;
  final IconData icon;
  final String? hint;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;
  final bool isDark;
  final Color primary, secondary, border, fillBg;

  const _DropdownField({
    required this.label,
    required this.value,
    required this.icon,
    this.hint,
    required this.items,
    required this.onChanged,
    required this.isDark,
    required this.primary,
    required this.secondary,
    required this.border,
    required this.fillBg,
  });

  @override
  Widget build(BuildContext context) {
    final textColor =
    isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final safeValue =
    items.any((item) => item.value == value) ? value : null;

    return DropdownButtonFormField<T>(
      value:         safeValue,
      menuMaxHeight: 220,
      hint: hint != null
          ? Text(hint!,
          style: TextStyle(color: secondary.withOpacity(0.6), fontSize: 13))
          : null,
      decoration: InputDecoration(
        labelText:  label,
        labelStyle: TextStyle(fontSize: 13, color: secondary),
        prefixIcon: Icon(icon, size: 18, color: secondary),
        filled:     true,
        fillColor:  fillBg,
        isDense:    true,
        contentPadding:
        const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: border)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: border)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: primary, width: 1.5)),
      ),
      dropdownColor: isDark ? AppColors.darkCard : Colors.white,
      style:         TextStyle(fontSize: 14, color: textColor),
      isExpanded:    true,
      items:         items,
      onChanged:     onChanged,
    );
  }
}

class _LoadingField extends StatelessWidget {
  final String label;
  final Color secondary, border, fillBg;
  const _LoadingField({
    required this.label,
    required this.secondary,
    required this.border,
    required this.fillBg,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color:        fillBg,
        borderRadius: BorderRadius.circular(10),
        border:       Border.all(color: border),
      ),
      child: Row(children: [
        SizedBox(
          width: 14, height: 14,
          child: CircularProgressIndicator(strokeWidth: 1.5, color: secondary),
        ),
        const SizedBox(width: 10),
        Text('Đang tải $label...',
            style: TextStyle(fontSize: 13, color: secondary)),
      ]),
    );
  }
}

class _AvailableToggle extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool isDark;
  final Color primary, secondary, border, fillBg;

  const _AvailableToggle({
    required this.value,
    required this.onChanged,
    required this.isDark,
    required this.primary,
    required this.secondary,
    required this.border,
    required this.fillBg,
  });

  @override
  Widget build(BuildContext context) {
    final onBg =
    isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color:        fillBg,
        borderRadius: BorderRadius.circular(10),
        border:       Border.all(color: border),
      ),
      child: Row(children: [
        Icon(Icons.storefront_outlined, size: 18, color: secondary),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Đang bán',
                  style: TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w600, color: onBg)),
              Text(value ? 'Hiển thị trong menu' : 'Ẩn khỏi menu',
                  style: TextStyle(fontSize: 11, color: secondary)),
            ],
          ),
        ),
        Switch.adaptive(
          value:            value,
          onChanged:        onChanged,
          activeColor:      primary,
          activeTrackColor: primary.withOpacity(0.3),
        ),
      ]),
    );
  }
}