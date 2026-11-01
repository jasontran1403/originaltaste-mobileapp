// lib/features/customer/screens/pos_customer_form_sheet.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/network/dio_client.dart';
import '../controller/customer_controller.dart';
import '../widgets/customer_widgets.dart';

const _blue = Color(0xFF0284C7);
Future<bool> showPosCustomerForm(
    BuildContext context, {
      PosCustomerModel? customer,
    }) async {
  final result = await showModalBottomSheet<bool>(
    context:            context,
    isScrollControlled: true,
    backgroundColor:    Colors.transparent,
    builder: (_) => _PosCustomerFormSheet(customer: customer),
  );
  return result ?? false;
}

class _PosCustomerFormSheet extends ConsumerStatefulWidget {
  final PosCustomerModel? customer;
  const _PosCustomerFormSheet({this.customer});

  @override
  ConsumerState<_PosCustomerFormSheet> createState() =>
      _PosCustomerFormSheetState();
}

class _PosCustomerFormSheetState
    extends ConsumerState<_PosCustomerFormSheet> {

  final _phoneCtrl   = TextEditingController();
  final _nameCtrl    = TextEditingController();
  final _addressCtrl = TextEditingController();

  DateTime? _selectedDob;
  List<Map<String, String>> _customerTypes = [];  // ← THÊM
  String _selectedType = 'KLE';

  bool get _isEdit => widget.customer != null;

  DateTime? _parseDob(String? s) {
    if (s == null || s.isEmpty) return null;
    try { return DateTime.parse(s); } catch (_) { return null; }
  }

  String? _dobToApi() {
    if (_selectedDob == null) return null;
    return '${_selectedDob!.year}-'
        '${_selectedDob!.month.toString().padLeft(2, '0')}-'
        '${_selectedDob!.day.toString().padLeft(2, '0')}';
  }

  @override
  void initState() {
    super.initState();
    _loadTypes();  // ← THÊM
    if (_isEdit) {
      final c = widget.customer!;
      _phoneCtrl.text   = c.phone;
      _nameCtrl.text    = c.name;
      _addressCtrl.text = c.deliveryAddress ?? '';
      _selectedDob      = _parseDob(c.dateOfBirth);
      _selectedType     = c.customerType;  // ← THÊM
    }
  }

  Future<void> _loadTypes() async {
    final fallback = [
      {'value': 'KLE',  'label': 'Khách lẻ'},
      {'value': 'CTV',  'label': 'Cộng tác viên'},
      {'value': 'CTVV', 'label': 'CTV Vàng'},
    ];
    try {
      final ctrl = ref.read(customerControllerProvider.notifier);
      final res = await DioClient.instance
          .get<List<Map<String, String>>>(
        ctrl.posTypesUrl,
        fromData: (d) => (d as List)
            .map((e) => Map<String, String>.from(e as Map))
            .toList(),
      );
      if (mounted) {
        setState(() => _customerTypes =
        (res.isSuccess && res.data != null && res.data!.isNotEmpty)
            ? res.data! : fallback);
      }
    } catch (_) {
      if (mounted) setState(() => _customerTypes = fallback);
    }
  }

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _nameCtrl.dispose();
    _addressCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDob() async {
    final cs = Theme.of(context).colorScheme;
    DateTime? picked;
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        title: const Text('Chọn ngày sinh',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        content: SizedBox(
          width: 300,
          child: CalendarDatePicker(
            initialDate: _selectedDob ?? DateTime(1990),
            firstDate:   DateTime(1920),
            lastDate:    DateTime.now(),
            onDateChanged: (d) => picked = d,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              setState(() => _selectedDob = null);
            },
            child: Text('Xóa', style: TextStyle(color: cs.error)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              if (picked != null) setState(() => _selectedDob = picked);
            },
            child: const Text('Chọn'),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    final phone = _phoneCtrl.text.trim();
    final name  = _nameCtrl.text.trim();
    if (phone.isEmpty) { _snack('Vui lòng nhập số điện thoại'); return; }
    if (name.isEmpty)  { _snack('Vui lòng nhập tên khách hàng'); return; }

    final data = <String, dynamic>{
      'phone': phone,
      'name':  name,
      'customerType': _selectedType,
    };
    if (_addressCtrl.text.isNotEmpty)
      data['deliveryAddress'] = _addressCtrl.text.trim();
    if (_dobToApi() != null)
      data['dateOfBirth'] = _dobToApi()!;

    final ok = await ref.read(customerControllerProvider.notifier)
        .savePosCustomer(data, id: widget.customer?.id);

    if (ok && mounted) Navigator.pop(context, true);
    else if (!ok && mounted) {
      final err = ref.read(customerControllerProvider).saveError;
      _snack(err ?? 'Lỗi lưu dữ liệu');
    }
  }

  void _snack(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ));

  @override
  Widget build(BuildContext context) {
    final isSaving = ref.watch(customerControllerProvider).isSaving;
    final isDark   = Theme.of(context).brightness == Brightness.dark;
    final cs       = Theme.of(context).colorScheme;
    final surf     = isDark ? const Color(0xFF1E293B) : Colors.white;
    const blue     = Color(0xFF0284C7);

    return Container(
      decoration: BoxDecoration(
        color: surf,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 90),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
        child: Column(mainAxisSize: MainAxisSize.min, children: [

          Center(child: Container(
            margin: const EdgeInsets.symmetric(vertical: 12),
            width: 36, height: 4,
            decoration: BoxDecoration(
                color: cs.onSurface.withOpacity(0.2),
                borderRadius: BorderRadius.circular(2)),
          )),

          Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                  color: blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10)),
              child: Icon(_isEdit ? Icons.edit_rounded
                  : Icons.person_add_rounded, size: 18, color: blue),
            ),
            const SizedBox(width: 10),
            Text(_isEdit ? 'Cập nhật khách POS'
                : 'Thêm khách hàng POS',
                style: TextStyle(fontSize: 16,
                    fontWeight: FontWeight.w800, color: cs.onSurface)),
          ]),
          const SizedBox(height: 20),

          // SĐT (readonly khi edit)
          CustomerFormField(
            controller: _phoneCtrl,
            label: 'Số điện thoại',
            hint:  '0938 121 001',
            icon:  Icons.phone_rounded,
            required: true,
            readOnly: _isEdit,
            keyboard:   TextInputType.phone,
            formatters: [FilteringTextInputFormatter.allow(
                RegExp(r'[\d\s+\-]'))],
            accentColor: blue,
          ),
          const SizedBox(height: 10),

          CustomerFormField(
            controller: _nameCtrl,
            label: 'Họ và tên',
            hint:  'Nguyễn Văn A',
            icon:  Icons.person_rounded,
            required: true,
            accentColor: blue,
          ),
          const SizedBox(height: 10),

          DobPickerButton(
            value:       _selectedDob,
            onTap:       _pickDob,
            onClear:     () => setState(() => _selectedDob = null),
            accentColor: blue,
          ),
          const SizedBox(height: 10),

          CustomerFormField(
            controller: _addressCtrl,
            label: 'Địa chỉ giao hàng (tùy chọn)',
            hint:  '123 Nguyễn Trãi, Q5, HCM',
            icon:  Icons.location_on_rounded,
            maxLines: 2,
            accentColor: blue,
          ),
          const SizedBox(height: 10),
          if (_customerTypes.isNotEmpty)
            _buildTypeDropdown(),
          const SizedBox(height: 10),
          if (_isEdit &&
              widget.customer!.referredByCustomerId != null) ...[
            const SizedBox(height: 10),
            TextFormField(
              initialValue:
              '${widget.customer!.referredByName ?? ''}'
                  '${widget.customer!.referredByPhone != null
                  ? ' · ${widget.customer!.referredByPhone}' : ''}',
              readOnly: true,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              decoration: InputDecoration(
                labelText: 'Người giới thiệu',
                prefixIcon: Icon(Icons.people_alt_rounded,
                    size: 18, color: _blue.withOpacity(0.7)),
                filled:    true,
                fillColor: _blue.withOpacity(0.04),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 13),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: _blue.withOpacity(0.3))),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: _blue.withOpacity(0.3))),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: _blue.withOpacity(0.3))),
                labelStyle: TextStyle(fontSize: 13,
                    color: _blue.withOpacity(0.7)),
              ),
            ),
          ],

          const SizedBox(height: 24),

          SizedBox(
            width: double.infinity, height: 40,
            child: FilledButton(
              onPressed: isSaving ? null : _save,
              style: FilledButton.styleFrom(
                backgroundColor: blue,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: isSaving
                  ? const SizedBox(width: 18, height: 18,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2))
                  : Text(_isEdit ? 'Cập nhật' : 'Thêm khách hàng',
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w700)),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _buildTypeDropdown() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cs     = Theme.of(context).colorScheme;
    const blue   = Color(0xFF0284C7);
    final bg     = isDark
        ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final border = isDark
        ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

    return DropdownButtonFormField<String>(
      value: _selectedType,
      decoration: InputDecoration(
        labelText: 'Loại khách hàng',
        prefixIcon: Icon(Icons.badge_rounded, size: 18,
            color: blue.withOpacity(0.7)),
        filled: true, fillColor: bg,
        contentPadding: const EdgeInsets.symmetric(
            horizontal: 14, vertical: 13),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: border)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: border)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: blue, width: 1.5)),
        labelStyle: TextStyle(fontSize: 13,
            color: cs.onSurface.withOpacity(0.5)),
      ),
      style: TextStyle(fontSize: 14,
          color: isDark ? Colors.white : const Color(0xFF0F172A)),
      dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      items: _customerTypes.map((t) => DropdownMenuItem(
        value: t['value'],
        child: Row(children: [
          _typeIcon(t['value']!),
          const SizedBox(width: 8),
          Text(t['label']!),
        ]),
      )).toList(),
      onChanged: (v) {
        if (v != null) setState(() => _selectedType = v);
      },
    );
  }

  Widget _typeIcon(String type) {
    final (icon, color) = switch (type) {
      'CTV'  => (Icons.handshake_rounded,        const Color(0xFF3B82F6)),
      'CTVV' => (Icons.workspace_premium_rounded, const Color(0xFFF59E0B)),
      _      => (Icons.person_rounded,            const Color(0xFF94A3B8)),
    };
    return Icon(icon, size: 16, color: color);
  }
}