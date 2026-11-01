// lib/features/pos/widgets/pos_product_form_sheet.dart
//
// Modal bottom sheet để tạo / chỉnh sửa Product POS
// Fields: ảnh, tên, mô tả, giá gốc, VAT, danh mục,
//         bán trên ứng dụng (ShopeeFood / GrabFood + giá),
//         Variant Groups, Addon Groups

import 'dart:io';
import 'package:flutter/material.dart';

import 'package:originaltaste/services/pos_service.dart';
import 'package:originaltaste/data/models/pos/pos_product_model.dart';

import '../../../data/models/pos/pos_draft_models.dart';
import '../../../services/admin_service.dart';
import '_pos_form_helpers.dart';
import 'pos_variant_picker_sheet.dart';

class PosProductFormSheet extends StatefulWidget {
  /// null = create mode
  final PosProductModel? product;
  final List<PosCategoryModel> categories;
  final List<Map<String, dynamic>> ingredients;
  final bool useAdminApi;

  const PosProductFormSheet({
    super.key,
    this.product,
    required this.categories,
    required this.ingredients,
    this.useAdminApi = false
  });

  static Future<bool> show(
      BuildContext context, {
        PosProductModel? product,
        required List<PosCategoryModel> categories,
        required List<Map<String, dynamic>> ingredients,
        bool useAdminApi = false
      }) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      builder: (_) => PosProductFormSheet(
        product: product,
        categories: categories,
        ingredients: ingredients,
        useAdminApi: useAdminApi,
      ),
    );
    return result == true;
  }

  @override
  State<PosProductFormSheet> createState() => _PosProductFormSheetState();
}

class _PosProductFormSheetState extends State<PosProductFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();

  bool _saving = false;
  File? _imgFile;
  String? _existingImageUrl;

  // VAT
  double _vat = 0;
  static const _vatOptions = [
    {'label': '0% - Không chịu thuế', 'value': 0.0},
    {'label': '5%', 'value': 5.0},
    {'label': '8%', 'value': 8.0},
    {'label': '10%', 'value': 10.0},
    {'label': '12%', 'value': 12.0},
  ];

  // Category
  PosCategoryModel? _selCat;

  // App sales
  bool _sellShopee = false;
  bool _sellGrab = false;
  final _shopeePriceCtrl = TextEditingController();
  final _grabPriceCtrl = TextEditingController();

  // Variant groups & Addon groups — dùng class từ draft models
  final List<VariantGroupDraft> _variantGroups = [];
  final List<AddonGroupDraft> _addonGroups = [];
  final List<int> _deletedVariantIds = [];   // ← THÊM

  bool get _isEdit => widget.product != null;

  @override
  void initState() {
    super.initState();
    if (_isEdit) {
      final p = widget.product!;
      _nameCtrl.text = p.name;
      _priceCtrl.text = p.basePrice.toStringAsFixed(0);
      _existingImageUrl = p.imageUrl;
      _vat = (p.vatPercent ?? 0).toDouble();
      _selCat = widget.categories.where((c) => c.id == p.categoryId).firstOrNull;

      // App sales
      _sellShopee = p.isShopeeFood;
      _sellGrab = p.isGrabFood;
      final shopeeMenu = p.appMenus.where((m) => m.platform == 'SHOPEE_FOOD' && m.isActive).firstOrNull;
      final grabMenu = p.appMenus.where((m) => m.platform == 'GRAB_FOOD' && m.isActive).firstOrNull;
      _shopeePriceCtrl.text = shopeeMenu?.price.toStringAsFixed(0) ?? '';
      _grabPriceCtrl.text = grabMenu?.price.toStringAsFixed(0) ?? '';

      // Load variants & addons
      for (final v in p.variants.where((v) => !v.isAddonGroup)) {
        _variantGroups.add(VariantGroupDraft.fromModel(v));
      }
      for (final v in p.variants.where((v) => v.isAddonGroup)) {
        _addonGroups.add(AddonGroupDraft.fromModel(v));
      }
    } else {
      if (widget.categories.isNotEmpty) _selCat = widget.categories.first;
      _priceCtrl.text = '0';
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _priceCtrl.dispose();
    _shopeePriceCtrl.dispose();
    _grabPriceCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picked = await PosFormHelpers.pickImage();
    if (picked != null && mounted) setState(() => _imgFile = picked);
  }

  // Sửa _save() trong _PosProductFormSheetState
  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_selCat == null) {
      PosFormHelpers.showError(context, 'Vui lòng chọn danh mục');
      return;
    }
    setState(() => _saving = true);
    try {
      String? imageUrl = _existingImageUrl;
      if (_imgFile != null) {
        imageUrl = await PosService.uploadImage(
            filePath: _imgFile!.path, type: 'pos-product');
      }

      final body = <String, dynamic>{
        'name':        _nameCtrl.text.trim(),
        'description': _descCtrl.text.trim(),
        'basePrice':   double.tryParse(_priceCtrl.text) ?? 0,
        'vatPercent':  _vat,
        'categoryId':  _selCat!.id,
        'isShopeeFood': _sellShopee,
        'isGrabFood':   _sellGrab,
        if (_sellShopee)
          'shopeePrice': double.tryParse(_shopeePriceCtrl.text) ?? 0,
        if (_sellGrab)
          'grabPrice': double.tryParse(_grabPriceCtrl.text) ?? 0,
        if (imageUrl != null) 'imageUrl': imageUrl,
      };

      PosProductModel saved;
      if (_isEdit) {
        saved = widget.useAdminApi           // ← THÊM
            ? await AdminService.instance.updateProduct(
            widget.product!.id, body)
            : await PosService.instance.updateProduct(
            widget.product!.id, body);
      } else {
        saved = widget.useAdminApi           // ← THÊM
            ? await AdminService.instance.createProduct(body)
            : await PosService.instance.createProduct(body);
      }

      // Variants — cũng switch service
      for (final vg in _variantGroups) {
        final vBody = vg.toBody(productId: saved.id);
        if (vg.existingId != null) {
          widget.useAdminApi
              ? await AdminService.instance.updateVariant(
              vg.existingId!, vBody)
              : await PosService.instance.updateVariant(
              vg.existingId!, vBody);
        } else {
          widget.useAdminApi
              ? await AdminService.instance.createVariant(vBody)
              : await PosService.instance.createVariant(vBody);
        }
      }

      for (final ag in _addonGroups) {
        final aBody = ag.toBody(productId: saved.id);
        if (ag.existingId != null) {
          widget.useAdminApi
              ? await AdminService.instance.updateVariant(
              ag.existingId!, aBody)
              : await PosService.instance.updateVariant(
              ag.existingId!, aBody);
        } else {
          widget.useAdminApi
              ? await AdminService.instance.createVariant(aBody)
              : await PosService.instance.createVariant(aBody);
        }
      }

      // ← THÊM: xóa những nhóm đã bị gỡ khỏi UI
      for (final id in _deletedVariantIds) {
        widget.useAdminApi
            ? await AdminService.instance.deleteVariant(id)
            : await PosService.instance.deleteVariant(id);
      }

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        PosFormHelpers.showError(context, e.toString());
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cs = Theme.of(context).colorScheme;
    final surface = posSurface(isDark);
    final bottom = MediaQuery.of(context).viewInsets.bottom +
        MediaQuery.of(context).padding.bottom +
        16;

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Container(
        decoration: BoxDecoration(
          color: surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: EdgeInsets.fromLTRB(20, 0, 20, bottom),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                PosFormHelpers.handle(isDark),
                PosFormHelpers.titleRow(
                  isDark: isDark,
                  icon: _isEdit ? Icons.edit_rounded : Icons.add_rounded,
                  label: _isEdit ? 'Chỉnh sửa sản phẩm' : 'Thêm sản phẩm',
                ),
                const SizedBox(height: 20),

                // ── Image ─────────────────────────────────────────
                PosImagePicker(
                  imageFile: _imgFile,
                  existingUrl: _existingImageUrl,
                  onPick: _pickImage,
                  onRemove: () => setState(() {
                    _imgFile = null;
                    _existingImageUrl = null;
                  }),
                ),
                const SizedBox(height: 16),

                // ── Tên ──────────────────────────────────────────
                PosFormField(
                  controller: _nameCtrl,
                  isDark: isDark,
                  label: 'Tên sản phẩm *',
                  hint: 'VD: Hotdog Special...',
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Vui lòng nhập tên' : null,
                ),
                const SizedBox(height: 14),

                // ── Mô tả ─────────────────────────────────────────
                PosFormField(
                  controller: _descCtrl,
                  isDark: isDark,
                  label: 'Mô tả',
                  hint: 'Mô tả ngắn về món...',
                  maxLines: 3,
                ),
                const SizedBox(height: 14),

                // ── Giá gốc ──────────────────────────────────────
                PosFormField(
                  controller: _priceCtrl,
                  isDark: isDark,
                  label: 'Giá gốc *',
                  hint: '0',
                  keyboardType: TextInputType.number,
                  suffixText: 'đ',
                  validator: (v) {
                    final n = double.tryParse(v ?? '');
                    if (n == null || n < 0) return 'Nhập giá hợp lệ';
                    return null;
                  },
                ),
                const SizedBox(height: 14),

                // ── VAT ───────────────────────────────────────────
                _VatDropdown(
                  value: _vat,
                  isDark: isDark,
                  options: _vatOptions,
                  onChanged: (v) => setState(() => _vat = v),
                ),
                const SizedBox(height: 14),

                // ── Category ──────────────────────────────────────
                _CategoryDropdown(
                  categories: widget.categories,
                  selected: _selCat,
                  isDark: isDark,
                  onChanged: (c) => setState(() => _selCat = c),
                ),
                const SizedBox(height: 20),

                // ── Bán trên ứng dụng ─────────────────────────────
                _AppSalesSection(
                  isDark: isDark,
                  sellShopee: _sellShopee,
                  sellGrab: _sellGrab,
                  shopeePriceCtrl: _shopeePriceCtrl,
                  grabPriceCtrl: _grabPriceCtrl,
                  onShopeeChanged: (v) => setState(() => _sellShopee = v),
                  onGrabChanged: (v) => setState(() => _sellGrab = v),
                ),
                const SizedBox(height: 20),

                // ── Variant Groups ────────────────────────────────
                _VariantGroupsSection(
                  groups: _variantGroups,
                  isDark: isDark,
                  ingredients: widget.ingredients,
                  onAdd: () async {
                    final draft = await PosVariantPickerSheet.show(
                      context,
                      ingredients: widget.ingredients,
                      isDark: isDark,
                      isAddon: false,
                    );
                    if (draft != null) setState(() => _variantGroups.add(draft));
                  },
                  onEdit: (i) async {
                    final updated = await PosVariantPickerSheet.show(
                      context,
                      ingredients: widget.ingredients,
                      isDark: isDark,
                      isAddon: false,
                      existing: _variantGroups[i],
                    );
                    if (updated != null) {
                      setState(() => _variantGroups[i] = updated);
                    }
                  },
                  onDelete: (i) => setState(() {
                    final id = _variantGroups[i].existingId;
                    if (id != null) _deletedVariantIds.add(id);
                    _variantGroups.removeAt(i);
                  }),
                ),
                const SizedBox(height: 20),

                // ── Addon Groups ──────────────────────────────────
                _AddonGroupsSection(
                  groups: _addonGroups,
                  isDark: isDark,
                  ingredients: widget.ingredients,
                  onAdd: () async {
                    final draft = await PosVariantPickerSheet.show(
                      context,
                      ingredients: widget.ingredients,
                      isDark: isDark,
                      isAddon: true,
                    );
                    if (draft != null) {
                      setState(() => _addonGroups.add(AddonGroupDraft.fromVariant(draft)));
                    }
                  },
                  onEdit: (i) async {
                    // Dùng toVariantDraft() để KHÔNG mất định lượng và giá
                    // addon riêng đã cấu hình khi mở lại sheet.
                    final vDraft = _addonGroups[i].toVariantDraft();
                    final updated = await PosVariantPickerSheet.show(
                      context,
                      ingredients: widget.ingredients,
                      isDark: isDark,
                      isAddon: true,
                      existing: vDraft,
                    );
                    if (updated != null) {
                      setState(() => _addonGroups[i] = AddonGroupDraft.fromVariant(updated));
                    }
                  },
                  onDelete: (i) => setState(() {
                    final id = _addonGroups[i].existingId;
                    if (id != null) _deletedVariantIds.add(id);
                    _addonGroups.removeAt(i);
                  }),
                ),
                const SizedBox(height: 24),

                // ── Save ──────────────────────────────────────────
                PosFormHelpers.saveButton(
                  label: _isEdit ? 'Lưu thay đổi' : 'Lưu',
                  saving: _saving,
                  onTap: _save,
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ───────────────────────────────────────────────────────────────────────
// Các sub-widget giữ nguyên như code gốc của bạn
// (chỉ cần đảm bảo _VariantGroupsSection và _AddonGroupsSection nhận đúng type List<VariantGroupDraft> và List<AddonGroupDraft>)

class _VatDropdown extends StatelessWidget {
  final double value;
  final bool isDark;
  final List<Map<String, Object>> options;
  final ValueChanged<double> onChanged;

  const _VatDropdown({
    required this.value,
    required this.isDark,
    required this.options,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return DropdownButtonFormField<double>(
      value: value,
      decoration: InputDecoration(
        labelText: 'Thuế VAT (%)',
        filled: true,
        fillColor: posBg(isDark),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: posDivider(isDark)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: posDivider(isDark)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: cs.primary, width: 1.5),
        ),
        labelStyle: TextStyle(fontSize: 13, color: posTxtSec(isDark)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      ),
      style: TextStyle(fontSize: 14, color: posTxtPri(isDark)),
      dropdownColor: posSurface(isDark),
      items: options.map((o) => DropdownMenuItem<double>(
        value: o['value'] as double,
        child: Text(
          o['label'] as String,
          style: TextStyle(fontSize: 14, color: posTxtPri(isDark)),
        ),
      )).toList(),
      onChanged: (v) {
        if (v != null) onChanged(v);
      },
    );
  }
}

class _CategoryDropdown extends StatelessWidget {
  final List<PosCategoryModel> categories;
  final PosCategoryModel? selected;
  final bool isDark;
  final ValueChanged<PosCategoryModel?> onChanged;

  const _CategoryDropdown({
    required this.categories,
    required this.selected,
    required this.isDark,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return DropdownButtonFormField<PosCategoryModel>(
      value: selected,
      decoration: InputDecoration(
        labelText: 'Danh mục *',
        filled: true,
        fillColor: posBg(isDark),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: posDivider(isDark)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: posDivider(isDark)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: cs.primary, width: 1.5),
        ),
        labelStyle: TextStyle(fontSize: 13, color: posTxtSec(isDark)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      ),
      style: TextStyle(fontSize: 14, color: posTxtPri(isDark)),
      dropdownColor: posSurface(isDark),
      items: categories.map((c) => DropdownMenuItem(
        value: c,
        child: Text(c.name, style: TextStyle(fontSize: 14, color: posTxtPri(isDark))),
      )).toList(),
      onChanged: onChanged,
      validator: (v) => v == null ? 'Vui lòng chọn danh mục' : null,
    );
  }
}

// ── App Sales Section ──────────────────────────────────────────
class _AppSalesSection extends StatelessWidget {
  final bool isDark, sellShopee, sellGrab;
  final TextEditingController shopeePriceCtrl, grabPriceCtrl;
  final ValueChanged<bool> onShopeeChanged, onGrabChanged;

  const _AppSalesSection({
    required this.isDark,
    required this.sellShopee,
    required this.sellGrab,
    required this.shopeePriceCtrl,
    required this.grabPriceCtrl,
    required this.onShopeeChanged,
    required this.onGrabChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.storefront_rounded, size: 16, color: const Color(0xFFFF6B2C)),
            const SizedBox(width: 7),
            Text(
              'Bán trên ứng dụng',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: posTxtPri(isDark),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        _AppToggleCard(
          isDark: isDark,
          icon: Icons.shopping_bag_outlined,
          color: const Color(0xFFEE4D2D),
          title: 'ShopeeFood',
          subtitle: sellShopee ? 'Đang bán — nhập giá bên dưới' : 'Không bán trên ShopeeFood',
          value: sellShopee,
          onChanged: onShopeeChanged,
          priceCtrl: sellShopee ? shopeePriceCtrl : null,
          priceLabel: 'Giá ShopeeFood *',
        ),
        const SizedBox(height: 10),

        _AppToggleCard(
          isDark: isDark,
          icon: Icons.delivery_dining_rounded,
          color: const Color(0xFF00B14F),
          title: 'GrabFood',
          subtitle: sellGrab ? 'Đang bán — nhập giá bên dưới' : 'Không bán trên GrabFood',
          value: sellGrab,
          onChanged: onGrabChanged,
          priceCtrl: sellGrab ? grabPriceCtrl : null,
          priceLabel: 'Giá GrabFood *',
        ),
      ],
    );
  }
}

class _AppToggleCard extends StatelessWidget {
  final bool isDark, value;
  final IconData icon;
  final Color color;
  final String title, subtitle;
  final TextEditingController? priceCtrl;
  final String priceLabel;
  final ValueChanged<bool> onChanged;

  const _AppToggleCard({
    required this.isDark,
    required this.value,
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.priceLabel,
    required this.onChanged,
    this.priceCtrl,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: value ? color.withOpacity(0.06) : posBg(isDark),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: value ? color.withOpacity(0.4) : posDivider(isDark),
          width: value ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 16, color: color),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: posTxtPri(isDark),
                      ),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(fontSize: 11, color: value ? color : posTxtSec(isDark)),
                    ),
                  ],
                ),
              ),
              Switch.adaptive(
                value: value,
                activeColor: color,
                onChanged: onChanged,
              ),
            ],
          ),
          if (priceCtrl != null) ...[
            const SizedBox(height: 12),
            PosFormField(
              controller: priceCtrl!,
              label: priceLabel,
              hint: '0',
              isDark: isDark,
              keyboardType: TextInputType.number,
              suffixText: 'đ',
              validator: (v) {
                final n = double.tryParse(v ?? '');
                if (n == null || n < 0) return 'Nhập giá hợp lệ';
                return null;
              },
            ),
          ],
        ],
      ),
    );
  }
}

// ── Variant Groups Section ─────────────────────────────────────
class _VariantGroupsSection extends StatelessWidget {
  final List<VariantGroupDraft> groups;
  final bool isDark;
  final List<Map<String, dynamic>> ingredients;
  final VoidCallback onAdd;
  final ValueChanged<int> onEdit, onDelete;

  const _VariantGroupsSection({
    required this.groups,
    required this.isDark,
    required this.ingredients,
    required this.onAdd,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.tune_rounded, size: 16, color: const Color(0xFFFF6B2C)),
            const SizedBox(width: 7),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Nhóm lựa chọn (Variant Groups)',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: posTxtPri(isDark)),
                  ),
                  Text(
                    'Mỗi nhóm là 1 bộ lựa chọn độc lập — khách phải chọn đủ mỗi nhóm',
                    style: TextStyle(fontSize: 11, color: posTxtSec(isDark)),
                  ),
                ],
              ),
            ),
            GestureDetector(
              onTap: onAdd,
              child: Row(
                children: [
                  Icon(Icons.add_circle_outline_rounded, size: 15, color: cs.primary),
                  const SizedBox(width: 4),
                  Text(
                    'Thêm nhóm',
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: cs.primary),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        PosFormHelpers.infoBox(
          'VD: Sản phẩm "Xúc xích chiên" có 2 nhóm.\n'
              '• Nhóm "Chọn loại xúc xích": chọn 1 từ [Cheddar, Garlic, Thueringer]\n'
              '• Nhóm "Chọn sốt": chọn 1 từ [Sốt cay, Sốt tỏi, Không sốt]\n'
              'Khách phải chọn cả 2 nhóm trước khi add vào giỏ.',
          isDark,
        ),

        ...groups.asMap().entries.map((e) => _VariantGroupCard(
          group: e.value,
          idx: e.key,
          isDark: isDark,
          ingredients: ingredients,
          onEdit: () => onEdit(e.key),
          onDelete: () => onDelete(e.key),
        )),
      ],
    );
  }
}

class _VariantGroupCard extends StatelessWidget {
  final VariantGroupDraft group;
  final int idx;
  final bool isDark;
  final List<Map<String, dynamic>> ingredients;
  final VoidCallback onEdit, onDelete;

  const _VariantGroupCard({
    required this.group,
    required this.idx,
    required this.isDark,
    required this.ingredients,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final names = group.ingredientIds.map((id) {
      final ing = ingredients.where((i) => i['id'] == id).firstOrNull;
      return ing?['name'] as String? ?? '#$id';
    }).join(', ');

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.primary.withOpacity(0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.primary.withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF9C00).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.tune_rounded, size: 14, color: Color(0xFFFF9C00)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  group.name,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: posTxtPri(isDark)),
                ),
              ),
              Text(
                '${group.minSelect}–${group.maxSelect} chọn',
                style: TextStyle(fontSize: 11, color: posTxtSec(isDark)),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: onEdit,
                child: Icon(Icons.expand_less_rounded, size: 20, color: posTxtSec(isDark)),
              ),
              const SizedBox(width: 4),
              GestureDetector(
                onTap: onDelete,
                child: Icon(Icons.delete_outline_rounded, size: 18, color: Theme.of(context).colorScheme.error),
              ),
            ],
          ),
          if (group.ingredientIds.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              names,
              style: TextStyle(fontSize: 12, color: posTxtSec(isDark)),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ] else
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Chưa chọn nguyên liệu...',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.error.withOpacity(0.7),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Addon Groups Section ───────────────────────────────────────
class _AddonGroupsSection extends StatelessWidget {
  final List<AddonGroupDraft> groups;
  final bool isDark;
  final List<Map<String, dynamic>> ingredients;
  final VoidCallback onAdd;
  final ValueChanged<int> onEdit, onDelete;

  const _AddonGroupsSection({
    required this.groups,
    required this.isDark,
    required this.ingredients,
    required this.onAdd,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final addonColor = const Color(0xFF8B5CF6);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.shopping_cart_outlined, size: 16, color: addonColor),
            const SizedBox(width: 7),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Món thêm (Addon)',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: posTxtPri(isDark)),
                  ),
                  Text(
                    'Tùy chọn — khách chọn thêm món, mỗi lần chọn cộng tiền',
                    style: TextStyle(fontSize: 11, color: posTxtSec(isDark)),
                  ),
                ],
              ),
            ),
            GestureDetector(
              onTap: onAdd,
              child: Row(
                children: [
                  Icon(Icons.add_circle_outline_rounded, size: 15, color: addonColor),
                  const SizedBox(width: 4),
                  Text(
                    'Thêm addon',
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: addonColor),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        ...groups.asMap().entries.map((e) => _AddonGroupCard(
          group: e.value,
          isDark: isDark,
          ingredients: ingredients,
          onEdit: () => onEdit(e.key),
          onDelete: () => onDelete(e.key),
        )),
      ],
    );
  }
}

class _AddonGroupCard extends StatelessWidget {
  final AddonGroupDraft group;
  final bool isDark;
  final List<Map<String, dynamic>> ingredients;
  final VoidCallback onEdit, onDelete;

  const _AddonGroupCard({
    required this.group,
    required this.isDark,
    required this.ingredients,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final addonColor = const Color(0xFF8B5CF6);
    final names = group.ingredientIds.map((id) {
      final ing = ingredients.where((i) => i['id'] == id).firstOrNull;
      return ing?['name'] as String? ?? '#$id';
    }).join(', ');

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: addonColor.withOpacity(0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: addonColor.withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: addonColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.shopping_cart_outlined, size: 14, color: addonColor),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  group.name,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: posTxtPri(isDark)),
                ),
              ),
              GestureDetector(
                onTap: onEdit,
                child: Icon(Icons.expand_less_rounded, size: 20, color: posTxtSec(isDark)),
              ),
              const SizedBox(width: 4),
              GestureDetector(
                onTap: onDelete,
                child: Icon(Icons.delete_outline_rounded, size: 18, color: cs.error),
              ),
            ],
          ),
          if (group.ingredientIds.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              names,
              style: TextStyle(fontSize: 12, color: posTxtSec(isDark)),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ] else
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Chưa chọn món thêm...',
                style: TextStyle(fontSize: 12, color: cs.error.withOpacity(0.7)),
              ),
            ),
        ],
      ),
    );
  }
}