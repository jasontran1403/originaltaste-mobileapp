// lib/features/management/widgets/store_info_pane.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/network/dio_client.dart';
import '../../../core/constants/api_constants.dart';

class StoreInfoPane extends ConsumerStatefulWidget {
  const StoreInfoPane({super.key});

  @override
  ConsumerState<StoreInfoPane> createState() => _StoreInfoPaneState();
}

class _StoreInfoPaneState extends ConsumerState<StoreInfoPane> {
  final _formKey      = GlobalKey<FormState>();
  final _nameCtrl     = TextEditingController();
  final _addressCtrl  = TextEditingController();
  final _phoneCtrl    = TextEditingController();
  final _printerCtrl  = TextEditingController();
  final _shopeeCtrl   = TextEditingController();
  final _grabCtrl     = TextEditingController();

  bool _isLoading = false;
  bool _isSaving  = false;
  Map<String, dynamic>? _storeData;

  @override
  void initState() {
    super.initState();
    _loadStore();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _addressCtrl.dispose();
    _phoneCtrl.dispose();
    _printerCtrl.dispose();
    _shopeeCtrl.dispose();
    _grabCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadStore() async {
    setState(() => _isLoading = true);
    try {
      final res = await DioClient.instance.get<Map<String, dynamic>>(
        '${ApiConstants.posBase}/store/info',
        fromData: (d) => d as Map<String, dynamic>,
      );
      if (res.isSuccess && res.data != null && mounted) {
        final d = res.data!;
        setState(() {
          _storeData = d;
          _nameCtrl.text    = d['name']       as String? ?? '';
          _addressCtrl.text = d['address']    as String? ?? '';
          _phoneCtrl.text   = d['phone']      as String? ?? '';
          _printerCtrl.text = d['printerIp']  as String? ?? '';
          _shopeeCtrl.text  =
              ((d['shopeeRate'] as num?)?.toDouble() ?? 0.0).toString();
          _grabCtrl.text    =
              ((d['grabRate']   as num?)?.toDouble() ?? 0.0).toString();
        });
      }
    } catch (e) {
      _snack('Lỗi tải thông tin store: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    try {
      await DioClient.instance.put(
        '${ApiConstants.posBase}/store/info',
        body: {
          'name':       _nameCtrl.text.trim(),
          'address':    _addressCtrl.text.trim(),
          'phone':      _phoneCtrl.text.trim(),
          'printerIp':  _printerCtrl.text.trim(),
          'shopeeRate': double.tryParse(_shopeeCtrl.text) ?? 0.0,
          'grabRate':   double.tryParse(_grabCtrl.text)   ?? 0.0,
        },
      );
      if (mounted) _snack('Đã lưu thông tin store!');
    } catch (e) {
      if (mounted) _snack('Lỗi lưu: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _snack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError
          ? Theme.of(context).colorScheme.error : null,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final cs     = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final teal   = const Color(0xFF0D9488);

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ────────────────────────────────────────
            Row(children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: teal.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.store_rounded, color: teal, size: 22),
              ),
              const SizedBox(width: 12),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Thông tin Store',
                    style: TextStyle(fontSize: 16,
                        fontWeight: FontWeight.w800, color: cs.onSurface)),
                Text('Chỉnh sửa thông tin cửa hàng',
                    style: TextStyle(fontSize: 12,
                        color: cs.onSurface.withOpacity(0.5))),
              ]),
            ]),
            const SizedBox(height: 24),

            // ── Thông tin cơ bản ───────────────────────────────
            _sectionLabel('Thông tin cơ bản', cs),
            const SizedBox(height: 12),
            _buildField(
              controller: _nameCtrl,
              label: 'Tên cửa hàng *',
              icon: Icons.storefront_rounded,
              validator: (v) =>
              (v == null || v.trim().isEmpty) ? 'Vui lòng nhập tên' : null,
              isDark: isDark, cs: cs, teal: teal,
            ),
            const SizedBox(height: 12),
            _buildField(
              controller: _addressCtrl,
              label: 'Địa chỉ',
              icon: Icons.location_on_rounded,
              maxLines: 2,
              isDark: isDark, cs: cs, teal: teal,
            ),
            const SizedBox(height: 12),
            _buildField(
              controller: _phoneCtrl,
              label: 'Số điện thoại',
              icon: Icons.phone_rounded,
              keyboard: TextInputType.phone,
              isDark: isDark, cs: cs, teal: teal,
            ),
            const SizedBox(height: 24),

            // ── Máy in ────────────────────────────────────────
            _sectionLabel('Máy in', cs),
            const SizedBox(height: 12),
            _buildField(
              controller: _printerCtrl,
              label: 'IP máy in (ESC/POS)',
              hint: '192.168.1.100',
              icon: Icons.print_rounded,
              keyboard: TextInputType.number,
              isDark: isDark, cs: cs, teal: teal,
            ),
            const SizedBox(height: 24),

            // ── Phí sàn App ───────────────────────────────────
            _sectionLabel('Phí sàn giao hàng', cs),
            const SizedBox(height: 4),
            Text('Nhập dạng thập phân, VD: 0.3305 = 33.05%',
                style: TextStyle(fontSize: 11,
                    color: cs.onSurface.withOpacity(0.45))),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: _buildField(
                controller: _shopeeCtrl,
                label: 'Phí Shopee Food',
                hint: '0.3305',
                icon: Icons.shopping_bag_rounded,
                keyboard: const TextInputType.numberWithOptions(decimal: true),
                isDark: isDark, cs: cs, teal: teal,
                iconColor: const Color(0xFFEE4D2D),
              )),
              const SizedBox(width: 12),
              Expanded(child: _buildField(
                controller: _grabCtrl,
                label: 'Phí Grab Food',
                hint: '0.25',
                icon: Icons.delivery_dining_rounded,
                keyboard: const TextInputType.numberWithOptions(decimal: true),
                isDark: isDark, cs: cs, teal: teal,
                iconColor: const Color(0xFF00B14F),
              )),
            ]),
            const SizedBox(height: 32),

            // ── Save button ───────────────────────────────────
            SizedBox(
              width: double.infinity,
              height: 50,
              child: FilledButton.icon(
                onPressed: _isSaving ? null : _save,
                icon: _isSaving
                    ? const SizedBox(width: 18, height: 18,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.save_rounded, size: 18),
                label: Text(
                  _isSaving ? 'Đang lưu...' : 'Lưu thay đổi',
                  style: const TextStyle(fontSize: 15,
                      fontWeight: FontWeight.w700),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: teal,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String text, ColorScheme cs) => Row(children: [
    Container(width: 3, height: 14,
        decoration: BoxDecoration(
            color: const Color(0xFF0D9488),
            borderRadius: BorderRadius.circular(2))),
    const SizedBox(width: 7),
    Text(text, style: TextStyle(
        fontSize: 12, fontWeight: FontWeight.w700,
        color: cs.onSurface.withOpacity(0.6), letterSpacing: 0.3)),
  ]);

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    String? hint,
    required IconData icon,
    Color? iconColor,
    int maxLines = 1,
    TextInputType keyboard = TextInputType.text,
    String? Function(String?)? validator,
    required bool isDark,
    required ColorScheme cs,
    required Color teal,
  }) {
    final bg     = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final border = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

    return TextFormField(
      controller: controller,
      keyboardType: keyboard,
      maxLines: maxLines,
      validator: validator,
      style: TextStyle(fontSize: 14,
          color: isDark ? Colors.white : const Color(0xFF0F172A)),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, size: 18,
            color: iconColor ?? teal.withOpacity(0.7)),
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
            borderSide: BorderSide(color: teal, width: 1.5)),
        errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: cs.error)),
        labelStyle: TextStyle(fontSize: 13,
            color: cs.onSurface.withOpacity(0.5)),
        hintStyle: TextStyle(fontSize: 13,
            color: cs.onSurface.withOpacity(0.35)),
      ),
    );
  }
}