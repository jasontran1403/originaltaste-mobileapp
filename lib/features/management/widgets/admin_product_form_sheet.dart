// lib/features/pos/widgets/admin_product_form_sheet.dart

import 'dart:io';
import 'package:flutter/material.dart';

import 'package:originaltaste/services/pos_service.dart';
import 'package:originaltaste/services/admin_service.dart';
import 'package:originaltaste/data/models/pos/pos_product_model.dart';
import '../../../data/models/pos/pos_draft_models.dart';
import '../../pos/widgets/_pos_form_helpers.dart';
import '../../pos/widgets/pos_variant_picker_sheet.dart';

class AdminProductFormSheet extends StatefulWidget {
  final PosProductModel? product;
  final List<PosCategoryModel> categories;
  final List<Map<String, dynamic>> ingredients;

  const AdminProductFormSheet({
    super.key,
    this.product,
    required this.categories,
    required this.ingredients,
  });

  static Future<bool> show(
      BuildContext context, {
        PosProductModel? product,
        required List<PosCategoryModel> categories,
        required List<Map<String, dynamic>> ingredients,
      }) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      builder: (_) => AdminProductFormSheet(
        product: product,
        categories: categories,
        ingredients: ingredients,
      ),
    );
    return result == true;
  }

  @override
  State<AdminProductFormSheet> createState() => _AdminProductFormSheetState();
}

class _AdminProductFormSheetState extends State<AdminProductFormSheet> {
  final _formKey        = GlobalKey<FormState>();
  final _nameCtrl       = TextEditingController();
  final _descCtrl       = TextEditingController();
  final _priceCtrl      = TextEditingController();
  final _shopeePriceCtrl = TextEditingController();
  final _grabPriceCtrl   = TextEditingController();

  bool    _saving           = false;
  File?   _imgFile;
  String? _existingImageUrl;
  double  _vat              = 0;
  PosCategoryModel? _selCat;
  bool _sellShopee = false;
  bool _sellGrab   = false;

  final List<VariantGroupDraft> _variantGroups = [];
  final List<AddonGroupDraft>   _addonGroups   = [];

  static const _vatOptions = [
    {'label': '0% - Không chịu thuế', 'value': 0.0},
    {'label': '5%',  'value': 5.0},
    {'label': '8%',  'value': 8.0},
    {'label': '10%', 'value': 10.0},
    {'label': '12%', 'value': 12.0},
  ];

  bool get _isEdit => widget.product != null;

  @override
  void initState() {
    super.initState();
    if (_isEdit) {
      final p = widget.product!;
      _nameCtrl.text        = p.name;
      _priceCtrl.text       = p.basePrice.toStringAsFixed(0);
      _existingImageUrl     = p.imageUrl;
      _vat                  = (p.vatPercent ?? 0).toDouble();
      _selCat = widget.categories
          .where((c) => c.id == p.categoryId)
          .firstOrNull;
      _sellShopee = p.isShopeeFood;
      _sellGrab   = p.isGrabFood;
      final shopeeMenu = p.appMenus
          .where((m) => m.platform == 'SHOPEE_FOOD' && m.isActive)
          .firstOrNull;
      final grabMenu = p.appMenus
          .where((m) => m.platform == 'GRAB_FOOD' && m.isActive)
          .firstOrNull;
      _shopeePriceCtrl.text = shopeeMenu?.price.toStringAsFixed(0) ?? '';
      _grabPriceCtrl.text   = grabMenu?.price.toStringAsFixed(0) ?? '';
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
    _nameCtrl.dispose(); _descCtrl.dispose(); _priceCtrl.dispose();
    _shopeePriceCtrl.dispose(); _grabPriceCtrl.dispose();
    super.dispose();
  }

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

      // ← THAY: dùng AdminService
      PosProductModel saved;
      if (_isEdit) {
        await AdminService.instance.updateProduct(
            widget.product!.id, body);
        saved = widget.product!; // refresh sau
      } else {
        final res = await AdminService.instance.createProduct(body);
        // createProduct trả bool, cần reload — dùng getProducts để lấy id mới nhất
        // Tạm thời dùng product id từ response nếu có
        // Nếu AdminService.createProduct trả PosProductModel thì dùng trực tiếp
        saved = widget.product ?? widget.product!;
        // → xem note bên dưới
      }

      // Save variants — dùng AdminService
      for (final vg in _variantGroups) {
        final vBody = vg.toBody(productId: saved.id);
        if (vg.existingId != null) {
          await AdminService.instance.updateVariant(vg.existingId!, vBody);
        } else {
          await AdminService.instance.createVariant(vBody);
        }
      }
      for (final ag in _addonGroups) {
        final aBody = ag.toBody(productId: saved.id);
        if (ag.existingId != null) {
          await AdminService.instance.updateVariant(ag.existingId!, aBody);
        } else {
          await AdminService.instance.createVariant(aBody);
        }
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
    final isDark  = Theme.of(context).brightness == Brightness.dark;
    final surface = posSurface(isDark);
    final bottom  = MediaQuery.of(context).viewInsets.bottom
        + MediaQuery.of(context).padding.bottom + 16;

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Container(
        decoration: BoxDecoration(
          color: surface,
          borderRadius:
          const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: EdgeInsets.fromLTRB(20, 0, 20, bottom),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              PosFormHelpers.handle(isDark),
              PosFormHelpers.titleRow(
                isDark: isDark,
                icon:  _isEdit ? Icons.edit_rounded : Icons.add_rounded,
                label: _isEdit ? 'Chỉnh sửa sản phẩm' : 'Thêm sản phẩm',
              ),
              const SizedBox(height: 20),
              PosImagePicker(
                imageFile:   _imgFile,
                existingUrl: _existingImageUrl,
                onPick: () async {
                  final f = await PosFormHelpers.pickImage();
                  if (f != null && mounted)
                    setState(() => _imgFile = f);
                },
                onRemove: () => setState(() {
                  _imgFile = null; _existingImageUrl = null;
                }),
              ),
              const SizedBox(height: 16),
              PosFormField(
                controller: _nameCtrl, isDark: isDark,
                label: 'Tên sản phẩm *', hint: 'VD: Hotdog Special...',
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Vui lòng nhập tên' : null,
              ),
              const SizedBox(height: 14),
              PosFormField(
                controller: _descCtrl, isDark: isDark,
                label: 'Mô tả', hint: 'Mô tả ngắn...', maxLines: 3,
              ),
              const SizedBox(height: 14),
              PosFormField(
                controller: _priceCtrl, isDark: isDark,
                label: 'Giá gốc *', hint: '0',
                keyboardType: TextInputType.number, suffixText: 'đ',
                validator: (v) {
                  final n = double.tryParse(v ?? '');
                  if (n == null || n < 0) return 'Nhập giá hợp lệ';
                  return null;
                },
              ),
              const SizedBox(height: 14),
              // VAT dropdown
              DropdownButtonFormField<double>(
                value: _vat,
                decoration: InputDecoration(
                  labelText: 'Thuế VAT (%)',
                  filled: true, fillColor: posBg(isDark),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: posDivider(isDark))),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: posDivider(isDark))),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                          color: Theme.of(context).colorScheme.primary,
                          width: 1.5)),
                  labelStyle:
                  TextStyle(fontSize: 13, color: posTxtSec(isDark)),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 13),
                ),
                style: TextStyle(fontSize: 14, color: posTxtPri(isDark)),
                dropdownColor: posSurface(isDark),
                items: _vatOptions
                    .map((o) => DropdownMenuItem<double>(
                  value: o['value'] as double,
                  child: Text(o['label'] as String,
                      style: TextStyle(
                          fontSize: 14,
                          color: posTxtPri(isDark))),
                ))
                    .toList(),
                onChanged: (v) {
                  if (v != null) setState(() => _vat = v);
                },
              ),
              const SizedBox(height: 14),
              // Category dropdown
              DropdownButtonFormField<PosCategoryModel>(
                value: _selCat,
                decoration: InputDecoration(
                  labelText: 'Danh mục *',
                  filled: true, fillColor: posBg(isDark),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: posDivider(isDark))),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: posDivider(isDark))),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                          color: Theme.of(context).colorScheme.primary,
                          width: 1.5)),
                  labelStyle:
                  TextStyle(fontSize: 13, color: posTxtSec(isDark)),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 13),
                ),
                style: TextStyle(fontSize: 14, color: posTxtPri(isDark)),
                dropdownColor: posSurface(isDark),
                items: widget.categories
                    .map((c) => DropdownMenuItem(
                  value: c,
                  child: Text(c.name,
                      style: TextStyle(
                          fontSize: 14,
                          color: posTxtPri(isDark))),
                ))
                    .toList(),
                onChanged: (c) => setState(() => _selCat = c),
                validator: (v) =>
                v == null ? 'Vui lòng chọn danh mục' : null,
              ),
              const SizedBox(height: 20),

              // ── Variant Groups ──────────────────────────────
              _VariantSection(
                groups: _variantGroups,
                isDark: isDark,
                ingredients: widget.ingredients,
                isAddon: false,
                onAdd: () async {
                  final draft = await PosVariantPickerSheet.show(
                    context,
                    ingredients: widget.ingredients,
                    isDark: isDark,
                    isAddon: false,
                  );
                  if (draft != null)
                    setState(() => _variantGroups.add(draft));
                },
                onEdit: (i) async {
                  final updated = await PosVariantPickerSheet.show(
                    context,
                    ingredients: widget.ingredients,
                    isDark: isDark,
                    isAddon: false,
                    existing: _variantGroups[i],
                  );
                  if (updated != null)
                    setState(() => _variantGroups[i] = updated);
                },
                onDelete: (i) =>
                    setState(() => _variantGroups.removeAt(i)),
              ),
              const SizedBox(height: 20),

              // ── Addon Groups ────────────────────────────────
              _VariantSection(
                groups: _addonGroups.map((ag) => ag.toVariantDraft()).toList(),
                isDark: isDark,
                ingredients: widget.ingredients,
                isAddon: true,
                onAdd: () async {
                  final draft = await PosVariantPickerSheet.show(
                    context,
                    ingredients: widget.ingredients,
                    isDark: isDark,
                    isAddon: true,
                  );
                  if (draft != null)
                    setState(() => _addonGroups
                        .add(AddonGroupDraft.fromVariant(draft)));
                },
                onEdit: (i) async {
                  // Giữ nguyên định lượng + giá addon riêng khi mở lại sheet.
                  final vDraft = _addonGroups[i].toVariantDraft();
                  final updated = await PosVariantPickerSheet.show(
                    context,
                    ingredients: widget.ingredients,
                    isDark: isDark,
                    isAddon: true,
                    existing: vDraft,
                  );
                  if (updated != null)
                    setState(() => _addonGroups[i] =
                        AddonGroupDraft.fromVariant(updated));
                },
                onDelete: (i) =>
                    setState(() => _addonGroups.removeAt(i)),
              ),
              const SizedBox(height: 24),

              PosFormHelpers.saveButton(
                label: _isEdit ? 'Lưu thay đổi' : 'Lưu',
                saving: _saving,
                onTap: _save,
              ),
              const SizedBox(height: 8),
            ]),
          ),
        ),
      ),
    );
  }
}

class _VariantSection extends StatelessWidget {
  final List<VariantGroupDraft> groups;
  final bool isDark, isAddon;
  final List<Map<String, dynamic>> ingredients;
  final VoidCallback onAdd;
  final ValueChanged<int> onEdit, onDelete;

  const _VariantSection({
    required this.groups, required this.isDark,
    required this.ingredients, required this.isAddon,
    required this.onAdd, required this.onEdit, required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final cs    = Theme.of(context).colorScheme;
    final color = isAddon ? const Color(0xFF8B5CF6) : const Color(0xFFFF6B2C);
    final icon  = isAddon
        ? Icons.shopping_cart_outlined : Icons.tune_rounded;
    final label = isAddon ? 'Món thêm (Addon)' : 'Nhóm lựa chọn';
    final addLabel = isAddon ? 'Thêm addon' : 'Thêm nhóm';

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 7),
        Expanded(child: Text(label, style: TextStyle(
            fontSize: 14, fontWeight: FontWeight.w800,
            color: posTxtPri(isDark)))),
        GestureDetector(
          onTap: onAdd,
          child: Row(children: [
            Icon(Icons.add_circle_outline_rounded, size: 15, color: color),
            const SizedBox(width: 4),
            Text(addLabel, style: TextStyle(
                fontSize: 12.5, fontWeight: FontWeight.w700, color: color)),
          ]),
        ),
      ]),
      const SizedBox(height: 10),
      ...groups.asMap().entries.map((e) => _GroupCard(
        group: e.value, isDark: isDark,
        ingredients: ingredients, color: color,
        onEdit: () => onEdit(e.key),
        onDelete: () => onDelete(e.key),
      )),
    ]);
  }
}

class _GroupCard extends StatelessWidget {
  final VariantGroupDraft group;
  final bool isDark;
  final List<Map<String, dynamic>> ingredients;
  final Color color;
  final VoidCallback onEdit, onDelete;

  const _GroupCard({
    required this.group, required this.isDark,
    required this.ingredients, required this.color,
    required this.onEdit, required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final cs    = Theme.of(context).colorScheme;
    final names = group.ingredientIds.map((id) {
      final ing =
          ingredients.where((i) => i['id'] == id).firstOrNull;
      return ing?['name'] as String? ?? '#$id';
    }).join(', ');

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8)),
            child: Icon(Icons.tune_rounded, size: 14, color: color),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(group.name, style: TextStyle(
              fontSize: 14, fontWeight: FontWeight.w700,
              color: posTxtPri(isDark)))),
          GestureDetector(onTap: onEdit,
              child: Icon(Icons.edit_outlined, size: 18,
                  color: posTxtSec(isDark))),
          const SizedBox(width: 8),
          GestureDetector(onTap: onDelete,
              child: Icon(Icons.delete_outline_rounded, size: 18,
                  color: cs.error)),
        ]),
        if (names.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(names, style: TextStyle(fontSize: 12,
              color: posTxtSec(isDark)),
              maxLines: 2, overflow: TextOverflow.ellipsis),
        ],
      ]),
    );
  }
}