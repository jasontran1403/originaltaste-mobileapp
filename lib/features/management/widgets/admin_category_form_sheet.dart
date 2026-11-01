// lib/features/pos/widgets/admin_category_form_sheet.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'package:originaltaste/services/pos_service.dart';
import 'package:originaltaste/services/admin_service.dart';
import 'package:originaltaste/data/models/pos/pos_product_model.dart';

import '../../pos/widgets/_pos_form_helpers.dart';

class AdminCategoryFormSheet extends StatefulWidget {
  final PosCategoryModel? category;
  const AdminCategoryFormSheet({super.key, this.category});

  static Future<bool> show(BuildContext context,
      {PosCategoryModel? category}) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AdminCategoryFormSheet(category: category),
    );
    return result == true;
  }

  @override
  State<AdminCategoryFormSheet> createState() =>
      _AdminCategoryFormSheetState();
}

class _AdminCategoryFormSheetState
    extends State<AdminCategoryFormSheet> {
  final _formKey  = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();

  bool    _isSinglePrice  = false;
  bool    _saving         = false;
  bool    _showImageError = false;
  File?   _imgFile;
  String? _existingImageUrl;

  bool get _isEdit   => widget.category != null;
  bool get _hasImage => _imgFile != null || _existingImageUrl != null;

  @override
  void initState() {
    super.initState();
    if (_isEdit) {
      final c           = widget.category!;
      _nameCtrl.text    = c.name;
      _isSinglePrice    = c.singlePrice;
      _existingImageUrl = c.imageUrl;
    }
  }

  @override
  void dispose() { _nameCtrl.dispose(); super.dispose(); }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800, maxHeight: 800, imageQuality: 85);
    if (picked != null && mounted) {
      setState(() {
        _imgFile        = File(picked.path);
        _showImageError = false;
      });
    }
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (!_hasImage) {
      setState(() => _showImageError = true);
      return;
    }
    setState(() => _saving = true);
    try {
      String? imageUrl = _existingImageUrl;
      if (_imgFile != null) {
        imageUrl = await PosService.uploadImage(
            filePath: _imgFile!.path, type: 'category');
      }

      final body = <String, dynamic>{
        'name':        _nameCtrl.text.trim(),
        'singlePrice': _isSinglePrice,
        if (imageUrl != null) 'imageUrl': imageUrl,
      };

      // ← THAY: dùng AdminService
      if (_isEdit) {
        await AdminService.instance
            .updateCategory(widget.category!.id, body);
      } else {
        await AdminService.instance.createCategory(body);
      }

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        PosFormHelpers.showError(context, e);
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark  = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? const Color(0xFF1E293B) : Colors.white;
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
                label: _isEdit
                    ? 'Chỉnh sửa danh mục' : 'Thêm danh mục',
              ),
              const SizedBox(height: 20),

              PosImagePicker(
                imageFile:   _imgFile,
                existingUrl: _existingImageUrl,
                onPick:   _pickImage,
                onRemove: () => setState(() {
                  _imgFile = null;
                  _existingImageUrl = null;
                  _showImageError   = true;
                }),
              ),
              if (_showImageError && !_hasImage) ...[
                const SizedBox(height: 6),
                Row(children: [
                  Icon(Icons.error_outline, size: 14,
                      color: Theme.of(context).colorScheme.error),
                  const SizedBox(width: 4),
                  Text('Vui lòng chọn ảnh cho danh mục',
                      style: TextStyle(fontSize: 12,
                          color: Theme.of(context).colorScheme.error)),
                ]),
              ],
              const SizedBox(height: 16),

              PosFormField(
                controller: _nameCtrl, isDark: isDark,
                label: 'Tên danh mục *', hint: 'VD: Hotdogs, Combo...',
                validator: (v) =>
                (v == null || v.trim().length < 2)
                    ? 'Vui lòng nhập tên (tối thiểu 2 ký tự)' : null,
              ),
              const SizedBox(height: 16),

              // Single price toggle — giữ nguyên UI
              _SinglePriceToggle(
                value: _isSinglePrice, isDark: isDark,
                onChanged: (v) =>
                    setState(() => _isSinglePrice = v),
              ),
              const SizedBox(height: 24),

              PosFormHelpers.saveButton(
                label:  _isEdit ? 'Lưu thay đổi' : 'Lưu',
                saving: _saving, onTap: _save,
              ),
              const SizedBox(height: 8),
            ]),
          ),
        ),
      ),
    );
  }
}

class _SinglePriceToggle extends StatelessWidget {
  final bool value, isDark;
  final ValueChanged<bool> onChanged;
  const _SinglePriceToggle({
    required this.value, required this.isDark,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final cs      = Theme.of(context).colorScheme;
    final surface = isDark
        ? const Color(0xFF0F172A) : const Color(0xFFF4F6FA);
    final border  = isDark
        ? const Color(0xFF2D3F55) : const Color(0xFFEAECF0);
    final txtSec  = isDark
        ? const Color(0xFF94A3B8) : const Color(0xFF6B7280);

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: surface, borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: Row(children: [
        Expanded(child: GestureDetector(
          onTap: () => onChanged(false),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: !value ? cs.primary : Colors.transparent,
              borderRadius: BorderRadius.circular(9),
            ),
            child: Row(mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.wb_sunny_rounded, size: 15,
                      color: !value ? Colors.white : txtSec),
                  const SizedBox(width: 6),
                  Text('Thường', style: TextStyle(fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: !value ? Colors.white : txtSec)),
                ]),
          ),
        )),
        Expanded(child: GestureDetector(
          onTap: () => onChanged(true),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: value
                  ? const Color(0xFF7C3AED) : Colors.transparent,
              borderRadius: BorderRadius.circular(9),
            ),
            child: Row(mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.ac_unit_rounded, size: 15,
                      color: value ? Colors.white : txtSec),
                  const SizedBox(width: 6),
                  Text('Lạnh', style: TextStyle(fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: value ? Colors.white : txtSec)),
                ]),
          ),
        )),
      ]),
    );
  }
}