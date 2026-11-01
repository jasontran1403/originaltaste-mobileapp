// lib/features/order/widgets/customer_picker_modal.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../data/models/order/order_models.dart';
import '../../../services/order_service.dart';
import '../controller/order_cart_controller.dart';
import '../../../shared/widgets/order_shared_widgets.dart';

class CustomerPickerModal extends ConsumerStatefulWidget {
  const CustomerPickerModal({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context:            context,
      isScrollControlled: true,
      backgroundColor:    Colors.transparent,
      useRootNavigator:   true,
      builder: (context) => const CustomerPickerModal(),
    );
  }

  @override
  ConsumerState<CustomerPickerModal> createState() =>
      _CustomerPickerModalState();
}

class _CustomerPickerModalState extends ConsumerState<CustomerPickerModal> {
  // ── Retail controllers ────────────────────────────────────────
  final _phoneCtrl    = TextEditingController();
  final _nameCtrl     = TextEditingController();
  final _emailCtrl    = TextEditingController();
  final _addressCtrl  = TextEditingController();
  final _notesCtrl    = TextEditingController();

  // ── Retail search ─────────────────────────────────────────────
  final _retailSearchCtrl = TextEditingController();
  bool _isRetailSearching  = false;
  String? _retailSearchError;
  Map<String, dynamic>? _selectedRetailData;

  // ── Wholesale (B2B) ───────────────────────────────────────────
  final _b2bSearchCtrl = TextEditingController();
  CustomerModel? _found;
  bool _isB2bSearching = false;
  String? _b2bSearchError;
  List<Map<String, dynamic>> _b2bResults    = [];
  Map<String, dynamic>?      _selectedB2bData;

  bool _isSaving = false;

  late final bool _isRetail;

  @override
  void initState() {
    super.initState();
    _isRetail = ref.read(orderCartProvider).orderMode == OrderMode.retail;
    final existing = ref.read(orderCartProvider).selectedCustomer;

    if (_isRetail) {
      _nameCtrl.text    = 'Khách lẻ';
      _phoneCtrl.text   = existing?.phone   ?? '';
      _emailCtrl.text   = existing?.email   ?? '';
      _addressCtrl.text = existing?.address ?? '';
    } else if (existing != null) {
      if (existing.id != null) {
        _found = CustomerModel(
          id:           existing.id!,
          phone:        existing.phone,
          name:         existing.name,
          discountRate: existing.discountRate,
          isActive:     true,
          addresses: existing.address.isEmpty
              ? []
              : [CustomerAddressModel(address: existing.address, isDefault: true)],
        );
      }
    }
  }

  @override
  void dispose() {
    _phoneCtrl.dispose();    _nameCtrl.dispose();
    _emailCtrl.dispose();    _addressCtrl.dispose();
    _notesCtrl.dispose();
    _retailSearchCtrl.dispose();
    _b2bSearchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark    = Theme.of(context).brightness == Brightness.dark;
    final surface   = isDark ? AppColors.darkCard : Colors.white;
    final primary   = isDark ? AppColors.primary : AppColors.primaryDark;
    final secondary = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final border    = isDark ? AppColors.darkBorder : AppColors.lightBorder;

    return DraggableScrollableSheet(
      initialChildSize: 0.88,
      minChildSize:     0.5,
      maxChildSize:     0.95,
      builder: (ctx, scrollCtrl) => Container(
        decoration: BoxDecoration(
          color:        surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.symmetric(vertical: 12),
            width: 40, height: 4,
            decoration: BoxDecoration(
              color:        secondary.withOpacity(0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(children: [
              _ModeBadge(isRetail: _isRetail, primary: primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _isRetail ? 'Thông tin khách lẻ' : 'Thông tin khách sỉ',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
              if (ref.read(orderCartProvider).selectedCustomer != null)
                TextButton(
                  onPressed: () {
                    ref.read(orderCartProvider.notifier).clearCustomer();
                    Navigator.pop(context);
                  },
                  style: TextButton.styleFrom(
                    padding:       const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    minimumSize:   Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text('Xóa KH', style: TextStyle(color: AppColors.error)),
                ),
              const SizedBox(width: 4),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: secondary.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.close, size: 18, color: secondary),
                ),
              ),
            ]),
          ),

          Divider(height: 16, color: border),

          Expanded(
            child: SingleChildScrollView(
              controller: scrollCtrl,
              padding: const EdgeInsets.all(20),
              child: _isRetail
                  ? _buildRetailBody(isDark, primary, secondary, border)
                  : _buildWholesaleBody(isDark, primary, secondary, border),
            ),
          ),
        ]),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════
  // RETAIL BODY
  // ══════════════════════════════════════════════════════════
  Widget _buildRetailBody(bool isDark, Color primary, Color secondary, Color border) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

      Text(
        'Tìm khách theo SĐT hoặc mã KH',
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
        ),
      ),
      const SizedBox(height: 8),

      Row(children: [
        Expanded(
          child: _TextInput(
            controller: _retailSearchCtrl,
            hint: 'Nhập SĐT hoặc mã KH...',
            isDark: isDark,
            primary: primary,
            secondary: secondary,
            onSubmit: (_) => _searchRetail(),
          ),
        ),
        const SizedBox(width: 10),
        GestureDetector(
          onTap: _isRetailSearching ? null : _searchRetail,
          child: Container(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: _isRetailSearching ? secondary.withOpacity(0.3) : primary,
              borderRadius: BorderRadius.circular(8),
            ),
            child: _isRetailSearching
                ? const SizedBox(
              width: 18, height: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            )
                : const Icon(Icons.search, color: Colors.white, size: 20),
          ),
        ),
      ]),

      if (_retailSearchError != null && _selectedRetailData == null) ...[
        const SizedBox(height: 12),
        _InfoBanner(text: _retailSearchError!, color: Colors.red.shade700),
      ],

      if (_selectedRetailData != null) ...[
        const SizedBox(height: 16),
        _SelectedRetailCard(
          data: _selectedRetailData!,
          primary: primary,
          secondary: secondary,
          onDeselect: _clearRetailSelection,
        ),
        const SizedBox(height: 24),
        _SubmitButton(
          label: 'Xác nhận & Tạo đơn',
          icon: Icons.check_circle_outline,
          loading: _isSaving,
          color: Colors.orange.shade700,
          onTap: _isSaving ? null : _applyRetail,
        ),
      ] else ...[
        const SizedBox(height: 40),
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.person_search_outlined, size: 60, color: secondary.withOpacity(0.25)),
              const SizedBox(height: 16),
              Text(
                'Nhập SĐT hoặc mã KH để tìm khách hàng',
                style: TextStyle(fontSize: 14, color: secondary),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ],

      const SizedBox(height: 20),
    ]);
  }

  // ══════════════════════════════════════════════════════════
  // WHOLESALE BODY
  // ══════════════════════════════════════════════════════════
  Widget _buildWholesaleBody(bool isDark, Color primary, Color secondary, Color border) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Tìm theo mã KH hoặc MST',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
              color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary)),
      const SizedBox(height: 8),
      Row(children: [
        Expanded(
          child: _TextInput(
            controller: _b2bSearchCtrl,
            hint:       'VD: NOK, ABC, 0312345678...',
            isDark: isDark, primary: primary, secondary: secondary,
            onSubmit: (_) => _searchB2b(),
          ),
        ),
        const SizedBox(width: 10),
        GestureDetector(
          onTap: _isB2bSearching ? null : _searchB2b,
          child: Container(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color:        _isB2bSearching ? secondary.withOpacity(0.3) : primary,
              borderRadius: BorderRadius.circular(8),
            ),
            child: _isB2bSearching
                ? SizedBox(width: 18, height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.search, color: Colors.white, size: 20),
          ),
        ),
      ]),

      if (_b2bResults.isNotEmpty && _found == null) ...[
        const SizedBox(height: 10),
        ..._b2bResults.map((r) => _B2bResultCard(
          data: r, primary: primary, secondary: secondary,
          onSelect: () => _selectB2bCustomer(r),
        )),
      ],

      if (_b2bSearchError != null && _b2bResults.isEmpty && _found == null) ...[
        const SizedBox(height: 10),
        _InfoBanner(text: _b2bSearchError!, color: Colors.orange),
      ],

      if (_found != null && _selectedB2bData != null) ...[
        const SizedBox(height: 16),
        _SelectedB2bCard(
          data: _selectedB2bData!, primary: primary, secondary: secondary,
          onDeselect: _clearB2bSelection,
        ),
        const SizedBox(height: 24),
        _SubmitButton(
          label: 'Xác nhận', icon: Icons.check_circle_outline,
          loading: false, color: primary, onTap: _applyB2bCustomer,
        ),
        const SizedBox(height: 80),
      ],

      if (_found == null && _b2bResults.isEmpty && _b2bSearchError == null)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 40),
          child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.person_search_outlined, size: 52, color: secondary.withOpacity(0.2)),
            const SizedBox(height: 10),
            Text('Nhập mã KH hoặc MST để tìm', style: TextStyle(color: secondary)),
          ])),
        ),
    ]);
  }

  // ══════════════════════════════════════════════════════════
  // ACTIONS — RETAIL SEARCH
  // ══════════════════════════════════════════════════════════
  Future<void> _searchRetail() async {
    final q = _retailSearchCtrl.text.trim();
    if (q.isEmpty) return;

    setState(() {
      _isRetailSearching  = true;
      _retailSearchError  = null;
      _selectedRetailData = null;
    });

    try {
      final res = await OrderService.instance.searchB2bCustomers(q);
      setState(() {
        _isRetailSearching = false;
        if (res.isSuccess && (res.data ?? []).isNotEmpty) {
          final results = List<Map<String, dynamic>>.from(res.data!);
          if (results.isNotEmpty) {
            final d = results.first;
            _selectedRetailData = d;
            _phoneCtrl.text   = d['phone']   ?? '';
            _emailCtrl.text   = d['email']   ?? '';
            _addressCtrl.text = d['address'] ?? d['deliveryAddress'] ?? '';
          } else {
            _retailSearchError = 'Không tìm thấy khách hàng';
          }
        } else {
          _retailSearchError = 'Không tìm thấy khách hàng';
        }
      });
    } catch (_) {
      setState(() {
        _isRetailSearching = false;
        _retailSearchError = 'Lỗi tìm kiếm';
      });
    }
  }

  void _clearRetailSelection() {
    setState(() {
      _selectedRetailData = null;
      _retailSearchError  = null;
      _retailSearchCtrl.clear();
      _phoneCtrl.clear();
      _emailCtrl.clear();
      _addressCtrl.clear();
    });
  }

  // ══════════════════════════════════════════════════════════
  // ACTIONS — RETAIL APPLY
  // ══════════════════════════════════════════════════════════
  void _applyRetail() {
    if (_selectedRetailData == null) {
      _showSnack('Vui lòng tìm khách hàng trước', Colors.orange);
      return;
    }

    final d = _selectedRetailData!;

    final customer = SelectedCustomer(
      id:           (d['id'] as num?)?.toInt(),
      name:         d['companyName'] ?? d['name'] ?? d['contactName'] ?? 'Khách lẻ',
      phone:        d['phone'] ?? '',
      email:        d['email'] ?? '',
      address:      d['address'] ?? d['deliveryAddress'] ?? '',
      discountRate: (d['discountRate'] as num?)?.toInt() ?? 0,
    );

    ref.read(orderCartProvider.notifier).setCustomer(customer);

    if (mounted) Navigator.pop(context);
  }

  // ══════════════════════════════════════════════════════════
  // ACTIONS — WHOLESALE
  // ══════════════════════════════════════════════════════════
  Future<void> _searchB2b() async {
    final q = _b2bSearchCtrl.text.trim();
    if (q.isEmpty) return;
    setState(() {
      _isB2bSearching = true; _b2bSearchError = null;
      _b2bResults = []; _found = null; _selectedB2bData = null;
    });
    try {
      final res = await OrderService.instance.searchB2bCustomers(q);
      setState(() {
        _isB2bSearching = false;
        if (res.isSuccess && (res.data ?? []).isNotEmpty) {
          _b2bResults = List<Map<String, dynamic>>.from(res.data!);
        } else {
          _b2bSearchError = 'Không tìm thấy khách hàng';
        }
      });
    } catch (_) {
      setState(() { _isB2bSearching = false; _b2bSearchError = 'Lỗi tìm kiếm'; });
    }
  }

  void _selectB2bCustomer(Map<String, dynamic> data) {
    setState(() {
      _selectedB2bData = data;
      _b2bResults      = [];
      _found = CustomerModel(
        id:           (data['id'] as num).toInt(),
        phone:        data['phone'] ?? '',
        name:         data['shortName'] ?? data['companyName'] ?? data['name'] ?? '',
        discountRate: (data['discountRate'] as num?)?.toInt() ?? 0,
        isActive:     true,
        addresses:    [],
      );
    });
  }

  void _clearB2bSelection() => setState(() {
    _found = null; _selectedB2bData = null; _b2bSearchError = null; _b2bResults = [];
  });

  void _applyB2bCustomer() {
    if (_found == null || _selectedB2bData == null) return;
    final d = _selectedB2bData!;
    _applyCustomer(
      id:       _found!.id,
      name:     d['shortName'] ?? d['companyName'] ?? d['name'] ?? '',
      phone:    d['phone']    ?? '',
      email:    d['email']    ?? '',
      address:  d['deliveryAddress'] ?? d['companyAddress'] ?? d['address'] ?? '',
      discount: (d['discountRate'] as num?)?.toInt() ?? 0,
    );
  }

  void _applyCustomer({
    int? id, required String name, required String phone,
    required String email, required String address, required int discount,
  }) {
    ref.read(orderCartProvider.notifier).setCustomer(SelectedCustomer(
      id: id, name: name, phone: phone,
      email: email, address: address, discountRate: discount,
    ));
    if (mounted) Navigator.pop(context);
  }

  void _showSnack(String msg, Color bg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg), backgroundColor: bg, behavior: SnackBarBehavior.floating,
    ));
  }
}

// ══════════════════════════════════════════════════════════════════
// HELPER WIDGETS
// ══════════════════════════════════════════════════════════════════

class _ModeBadge extends StatelessWidget {
  final bool isRetail; final Color primary;
  const _ModeBadge({required this.isRetail, required this.primary});
  @override
  Widget build(BuildContext context) {
    final c = isRetail ? Colors.orange : primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: c.withOpacity(0.1), borderRadius: BorderRadius.circular(6),
        border: Border.all(color: c.withOpacity(0.4)),
      ),
      child: Text(isRetail ? 'Khách lẻ' : 'Khách sỉ',
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: c)),
    );
  }
}

class _TextInput extends StatelessWidget {
  final TextEditingController    controller;
  final String                   hint;
  final TextInputType?            keyboard;
  final List<TextInputFormatter>? formatters;
  final bool                     readOnly;
  final int?                     maxLines;
  final String?                  suffix;
  final Function(String)?        onSubmit;
  final bool isDark; final Color primary; final Color secondary;

  const _TextInput({
    required this.controller, required this.hint,
    this.keyboard, this.formatters, this.readOnly = false,
    this.maxLines = 1, this.suffix, this.onSubmit,
    required this.isDark, required this.primary, required this.secondary,
  });

  @override
  Widget build(BuildContext context) {
    final bc = secondary.withOpacity(0.4);
    return TextField(
      controller: controller, keyboardType: keyboard,
      inputFormatters: formatters, readOnly: readOnly,
      maxLines: maxLines, onSubmitted: onSubmit,
      style: TextStyle(fontSize: 13,
          color: readOnly ? secondary
              : (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary)),
      decoration: InputDecoration(
        hintText: hint, hintStyle: TextStyle(fontSize: 13, color: secondary),
        suffixText: suffix,
        filled: readOnly, fillColor: readOnly ? secondary.withOpacity(0.06) : null,
        contentPadding: const EdgeInsets.all(13), isDense: true, isCollapsed: true,
        border:        OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: bc)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: bc)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: primary, width: 1.5)),
      ),
    );
  }
}

class _TextInputValidated extends StatefulWidget {
  final TextEditingController    controller;
  final String                   hint;
  final TextInputType?            keyboard;
  final String? Function(String)? validator;
  final bool isDark; final Color primary; final Color secondary;
  const _TextInputValidated({
    required this.controller, required this.hint, this.keyboard, this.validator,
    required this.isDark, required this.primary, required this.secondary,
  });
  @override
  State<_TextInputValidated> createState() => _TextInputValidatedState();
}

class _TextInputValidatedState extends State<_TextInputValidated> {
  String? _error;
  @override
  Widget build(BuildContext context) {
    final bc = widget.secondary.withOpacity(0.4);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      TextField(
        controller: widget.controller, keyboardType: widget.keyboard,
        style: TextStyle(fontSize: 13,
            color: widget.isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
        onChanged: (v) { if (widget.validator != null) setState(() => _error = widget.validator!(v)); },
        decoration: InputDecoration(
          hintText: widget.hint, hintStyle: TextStyle(fontSize: 13, color: widget.secondary),
          contentPadding: const EdgeInsets.all(13), isDense: true, isCollapsed: true,
          border:        OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: bc)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: _error != null ? AppColors.error : bc)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: _error != null ? AppColors.error : widget.primary, width: 1.5)),
        ),
      ),
      if (_error != null)
        Padding(padding: const EdgeInsets.only(top: 4, left: 2),
            child: Text(_error!, style: TextStyle(fontSize: 11, color: AppColors.error))),
    ]);
  }
}

class _Field extends StatelessWidget {
  final String label; final Widget child;
  const _Field({required this.label, required this.child});
  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8), child,
      ]);
}

class _FieldRequired extends StatelessWidget {
  final String label; final Widget child;
  const _FieldRequired({required this.label, required this.child});
  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const SizedBox(height: 8), child,
      ]);
}

class _InfoBanner extends StatelessWidget {
  final String text; final Color color;
  const _InfoBanner({required this.text, required this.color});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(
      color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(10),
      border: Border.all(color: color.withOpacity(0.25)),
    ),
    child: Row(children: [
      Icon(Icons.info_outline, size: 15, color: color),
      const SizedBox(width: 8),
      Expanded(child: Text(text, style: TextStyle(fontSize: 12, color: color))),
    ]),
  );
}

class _SubmitButton extends StatelessWidget {
  final String label; final IconData icon; final bool loading;
  final Color color; final VoidCallback? onTap;
  const _SubmitButton({required this.label, required this.icon,
    required this.loading, required this.color, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 13),
      decoration: BoxDecoration(
        color: onTap == null ? color.withOpacity(0.4) : color,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Center(child: loading
          ? const SizedBox(width: 18, height: 18,
          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
          : Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 16, color: Colors.white), const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
      ])),
    ),
  );
}

// ── Selected Retail Card ─────────────────────────────────────────
class _SelectedRetailCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final Color primary, secondary;
  final VoidCallback onDeselect;
  const _SelectedRetailCard({
    required this.data, required this.primary,
    required this.secondary, required this.onDeselect,
  });
  @override
  Widget build(BuildContext context) {
    final isCompany = (data['customerType'] as String?) == 'COMPANY';
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color:        Colors.green.withOpacity(0.05),
        borderRadius: BorderRadius.circular(10),
        border:       Border.all(color: Colors.green.withOpacity(0.35)),
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.12), shape: BoxShape.circle),
          child: Icon(
            isCompany ? Icons.business_rounded : Icons.person_rounded,
            size: 16, color: Colors.green,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.check_circle, size: 12, color: Colors.green),
            const SizedBox(width: 4),
            Text('Đã tìm thấy khách hàng',
                style: TextStyle(fontSize: 11, color: Colors.green, fontWeight: FontWeight.w600)),
          ]),
          const SizedBox(height: 2),
          Text(
            data['companyName'] ?? data['name'] ?? data['contactName'] ?? '',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          ),
          if (data['phone'] != null)
            Text(data['phone'], style: TextStyle(fontSize: 11, color: secondary)),
          if (data['address'] != null || data['deliveryAddress'] != null)
            Text(
              data['address'] ?? data['deliveryAddress'] ?? '',
              style: TextStyle(fontSize: 11, color: secondary),
            ),
          if (isCompany && data['taxCode'] != null)
            Text('MST: ${data['taxCode']}',
                style: TextStyle(fontSize: 11, color: secondary)),
        ])),
        GestureDetector(
          onTap: onDeselect,
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: Icon(Icons.close, size: 16, color: secondary.withOpacity(0.5)),
          ),
        ),
      ]),
    );
  }
}

// ── B2B Result Card ──────────────────────────────────────────────
class _B2bResultCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final Color primary, secondary; final VoidCallback onSelect;
  const _B2bResultCard({required this.data, required this.primary,
    required this.secondary, required this.onSelect});
  @override
  Widget build(BuildContext context) {
    final isCompany = (data['customerType'] as String?) == 'COMPANY';
    return GestureDetector(
      onTap: onSelect,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: primary.withOpacity(0.04), borderRadius: BorderRadius.circular(10),
          border: Border.all(color: primary.withOpacity(0.25)),
        ),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: (isCompany ? primary : Colors.orange).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(isCompany ? Icons.business_rounded : Icons.person_rounded,
                size: 16, color: isCompany ? primary : Colors.orange),
          ),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(data['shortName'] ?? data['companyName'] ?? data['name'] ?? '',
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
            Text('${data['customerCode'] ?? ''} • ${data['phone'] ?? ''}',
                style: TextStyle(fontSize: 11, color: secondary)),
            if (data['taxCode'] != null)
              Text('MST: ${data['taxCode']}',
                  style: TextStyle(fontSize: 11, color: secondary)),
          ])),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(color: primary, borderRadius: BorderRadius.circular(6)),
            child: const Text('Chọn',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white)),
          ),
        ]),
      ),
    );
  }
}

// ── Selected B2B Card ────────────────────────────────────────────
class _SelectedB2bCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final Color primary, secondary; final VoidCallback onDeselect;
  const _SelectedB2bCard({required this.data, required this.primary,
    required this.secondary, required this.onDeselect});
  @override
  Widget build(BuildContext context) {
    final isCompany = (data['customerType'] as String?) == 'COMPANY';
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.green.withOpacity(0.05), borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.withOpacity(0.35)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.check_circle, size: 14, color: Colors.green),
          const SizedBox(width: 6),
          Text('Đã chọn khách hàng',
              style: TextStyle(fontSize: 11, color: Colors.green, fontWeight: FontWeight.w600)),
          const Spacer(),
          GestureDetector(
            onTap: onDeselect,
            child: Row(children: [
              Icon(Icons.close, size: 13, color: secondary.withOpacity(0.5)),
              const SizedBox(width: 2),
              Text('Bỏ chọn', style: TextStyle(fontSize: 10, color: secondary.withOpacity(0.5))),
            ]),
          ),
        ]),
        const SizedBox(height: 10),
        const Divider(height: 1),
        const SizedBox(height: 10),

        if (isCompany) ...[
          _InfoLine(label: 'Công ty',    value: data['companyName'] ?? '', bold: true),
          if (data['taxCode']        != null) _InfoLine(label: 'MST',        value: data['taxCode']),
          if (data['companyAddress'] != null) _InfoLine(label: 'Địa chỉ CT', value: data['companyAddress']),
          if (data['companyPhone']   != null) _InfoLine(label: 'SĐT CT',     value: data['companyPhone']),
          const SizedBox(height: 8),
          Divider(height: 1, color: Colors.green.withOpacity(0.2)),
          const SizedBox(height: 8),
          if (data['contactName']     != null) _InfoLine(label: 'Người nhận', value: data['contactName']),
          if (data['phone']           != null) _InfoLine(label: 'SĐT nhận',   value: data['phone']),
          if (data['deliveryAddress'] != null) _InfoLine(label: 'Địa chỉ GH', value: data['deliveryAddress']),
        ] else ...[
          _InfoLine(label: 'Người nhận', value: data['contactName'] ?? data['name'] ?? ''),
          if (data['phone']   != null) _InfoLine(label: 'Số điện thoại', value: data['phone']),
          if (data['address'] != null) _InfoLine(label: 'Địa chỉ',       value: data['address']),
        ],

        if ((data['discountRate'] as num?)?.toInt() != 0 && data['discountRate'] != null) ...[
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
                color: primary.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
            child: Text('Chiết khấu: ${data['discountRate']}%',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: primary)),
          ),
        ],
      ]),
    );
  }
}

class _InfoLine extends StatelessWidget {
  final String label, value; final bool bold;
  const _InfoLine({required this.label, required this.value, this.bold = false});
  @override
  Widget build(BuildContext context) {
    final secondary = Theme.of(context).brightness == Brightness.dark
        ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(width: 100,
            child: Text('$label:', style: TextStyle(fontSize: 12, color: secondary))),
        Expanded(child: Text(value, style: TextStyle(
            fontSize: 12, fontWeight: bold ? FontWeight.w700 : FontWeight.w500))),
      ]),
    );
  }
}