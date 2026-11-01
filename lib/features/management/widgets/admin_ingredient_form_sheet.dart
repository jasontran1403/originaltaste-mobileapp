// lib/features/pos/widgets/admin_ingredient_form_sheet.dart

import 'package:flutter/material.dart';
import 'package:originaltaste/services/admin_service.dart';

import '../../pos/widgets/_pos_form_helpers.dart';

class AdminIngredientFormSheet extends StatefulWidget {
  final Map<String, dynamic>? ingredient;
  const AdminIngredientFormSheet({super.key, this.ingredient});

  static Future<bool> show(BuildContext context,
      {Map<String, dynamic>? ingredient}) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) =>
          AdminIngredientFormSheet(ingredient: ingredient),
    );
    return result == true;
  }

  @override
  State<AdminIngredientFormSheet> createState() =>
      _AdminIngredientFormSheetState();
}

class _AdminIngredientFormSheetState
    extends State<AdminIngredientFormSheet> {
  final _formKey        = GlobalKey<FormState>();
  final _nameCtrl       = TextEditingController();
  final _unitCtrl       = TextEditingController();
  final _perPackCtrl    = TextEditingController();
  final _addonPriceCtrl = TextEditingController();

  int  _typeIdx = 0;
  bool _saving  = false;

  bool get _isEdit => widget.ingredient != null;

  static const _unitOptions = [
    'Cái', 'Cây', 'Miếng', 'Lát', 'Viên',
    'Kg', 'Gr', 'Lít', 'Ml',
    'Bịch', 'Túi', 'Hộp', 'Chai', 'Gói', 'Lọ', 'Khác...',
  ];
  bool _isCustomUnit = false;

  @override
  void initState() {
    super.initState();
    if (_isEdit) {
      final ing        = widget.ingredient!;
      _nameCtrl.text       = ing['name'] as String? ?? '';
      _unitCtrl.text       = ing['unit'] as String? ?? 'Cái';
      final _upp = (ing['unitPerPack'] as num?) ?? 1;
      _perPackCtrl.text = _upp == _upp.toInt() ? '${_upp.toInt()}' : '$_upp';
      _addonPriceCtrl.text = (ing['addonPrice'] as num? ?? 0).toString();
      _typeIdx             =
      (ing['ingredientType'] as String? ?? 'MAIN') == 'SUB' ? 1 : 0;
      _isCustomUnit = _unitCtrl.text.isNotEmpty &&
          !_unitOptions.contains(_unitCtrl.text);
    } else {
      _unitCtrl.text       = 'Cái';
      _perPackCtrl.text    = '1';
      _addonPriceCtrl.text = '0';
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose(); _unitCtrl.dispose();
    _perPackCtrl.dispose(); _addonPriceCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    try {
      final body = <String, dynamic>{
        'name':           _nameCtrl.text.trim(),
        'unit':           _unitCtrl.text.trim().isEmpty
            ? 'Cái' : _unitCtrl.text.trim(),
        'unitPerPack':    double.tryParse(_perPackCtrl.text.replaceAll(',', '.')) ?? 1,
        'ingredientType': _typeIdx == 0 ? 'MAIN' : 'SUB',
        'addonPrice':     double.tryParse(_addonPriceCtrl.text) ?? 0,
      };

      // ← THAY: dùng AdminService
      if (_isEdit) {
        await AdminService.instance.updateIngredient(
            widget.ingredient!['id'] as int, body);
      } else {
        await AdminService.instance.createIngredient(body);
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
    final cs      = Theme.of(context).colorScheme;
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
                label: _isEdit
                    ? 'Chỉnh sửa nguyên liệu'
                    : 'Thêm nguyên liệu',
              ),
              const SizedBox(height: 20),

              PosFormField(
                controller: _nameCtrl, isDark: isDark,
                label: 'Tên nguyên liệu *',
                hint: 'VD: Hotdog, Mozzarella...',
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Vui lòng nhập tên' : null,
              ),
              const SizedBox(height: 14),

              PosFormHelpers.sectionLabel('Đơn vị tính', isDark),
              const SizedBox(height: 8),

              // ── Unit dropdown / tự nhập ────────────────────
              if (_isCustomUnit)
                Row(children: [
                  Expanded(child: TextFormField(
                    controller: _unitCtrl,
                    autofocus: true,
                    style: TextStyle(fontSize: 14,
                        color: posTxtPri(isDark)),
                    decoration: InputDecoration(
                      labelText: 'Nhập đơn vị *',
                      hintText: 'VD: Muỗng, Tô...',
                      filled: true, fillColor: posBg(isDark),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 13),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                          BorderSide(color: posDivider(isDark))),
                      enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                          BorderSide(color: posDivider(isDark))),
                      focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                              color: cs.primary, width: 1.5)),
                      labelStyle: TextStyle(
                          fontSize: 13, color: posTxtSec(isDark)),
                      suffixIcon: IconButton(
                        icon: Icon(Icons.list_rounded,
                            size: 18, color: cs.primary),
                        onPressed: () => setState(() {
                          _isCustomUnit = false;
                          _unitCtrl.text = _unitOptions.first;
                        }),
                      ),
                    ),
                    validator: (v) =>
                    (v == null || v.trim().isEmpty)
                        ? 'Vui lòng nhập đơn vị' : null,
                  )),
                ])
              else
                DropdownButtonFormField<String>(
                  value: _unitOptions.contains(_unitCtrl.text)
                      ? _unitCtrl.text : _unitOptions.first,
                  decoration: InputDecoration(
                    labelText: 'Đơn vị tính *',
                    filled: true, fillColor: posBg(isDark),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 13),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                        BorderSide(color: posDivider(isDark))),
                    enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                        BorderSide(color: posDivider(isDark))),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                            color: cs.primary, width: 1.5)),
                    labelStyle: TextStyle(
                        fontSize: 13, color: posTxtSec(isDark)),
                  ),
                  style: TextStyle(
                      fontSize: 14, color: posTxtPri(isDark)),
                  dropdownColor: posSurface(isDark),
                  isExpanded: true,
                  items: _unitOptions
                      .map((u) => DropdownMenuItem(
                    value: u,
                    child: Text(u,
                        style: TextStyle(
                          fontSize: 14,
                          color: u == 'Khác...'
                              ? cs.primary
                              : posTxtPri(isDark),
                          fontWeight: u == 'Khác...'
                              ? FontWeight.w600
                              : FontWeight.normal,
                        )),
                  ))
                      .toList(),
                  onChanged: (v) {
                    if (v == null) return;
                    if (v == 'Khác...') {
                      setState(() {
                        _isCustomUnit = true;
                        _unitCtrl.text = '';
                      });
                    } else {
                      setState(() => _unitCtrl.text = v);
                    }
                  },
                ),
              const SizedBox(height: 14),

              PosFormField(
                controller: _perPackCtrl, isDark: isDark,
                label:
                '1 bịch/túi/kg = ? ${_unitCtrl.text.trim().isEmpty ? "đơn vị" : _unitCtrl.text.trim()} *',
                hint: '1',
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (v) {
                  final n = double.tryParse((v ?? '').replaceAll(',', '.'));
                  if (n == null || n <= 0) return 'Nhập số > 0';
                  return null;
                },
              ),
              const SizedBox(height: 14),

              PosFormHelpers.sectionLabel('Loại nguyên liệu', isDark),
              PosSegmentControl(
                options: const ['Chính', 'Phụ'],
                icons: const [
                  Icons.star_rounded,
                  Icons.star_border_rounded
                ],
                selected: _typeIdx,
                isDark: isDark,
                onChanged: (i) => setState(() => _typeIdx = i),
              ),
              const SizedBox(height: 14),

              PosFormHelpers.sectionLabel(
                  'Giá Addon (khi dùng trong nhóm thêm món)', isDark),
              PosFormField(
                controller: _addonPriceCtrl, isDark: isDark,
                label: 'Giá Addon', hint: '0',
                keyboardType: const TextInputType.numberWithOptions(
                    decimal: false),
                suffixText: 'đ',
                validator: (v) {
                  final n = double.tryParse(v ?? '');
                  if (n == null || n < 0) return 'Nhập giá ≥ 0';
                  return null;
                },
              ),
              PosFormHelpers.infoBox(
                  '0 = không tính tiền thêm khi chọn nguyên liệu này',
                  isDark),
              const SizedBox(height: 20),

              PosFormHelpers.saveButton(
                label: _isEdit ? 'Lưu thay đổi' : 'Lưu',
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