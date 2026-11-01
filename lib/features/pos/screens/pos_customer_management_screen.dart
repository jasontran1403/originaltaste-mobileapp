// lib/features/pos/screens/pos_customer_management_screen.dart
//
// Màn hình quản lý khách hàng + chương trình khuyến mãi POS
// Design: Minimal-refined, teal accent, dark/light adaptive

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:originaltaste/data/network/dio_client.dart';
import 'package:originaltaste/core/constants/api_constants.dart';
import 'package:originaltaste/features/pos/screens/pos_customer_orders_screen.dart';

// ─── Models ──────────────────────────────────────────────────────

class PosCustomerMgmt {
  final int    id;
  final String phone;
  final String name;
  final double totalSpend;        // Tổng chi tiêu mọi thời điểm
  final double availableCredit;   // Số dư credit khả dụng
  final String createdAt;
  // ── Thêm mới ──
  final String? dateOfBirth;
  final String? deliveryAddress;
  final int?    referredByCustomerId;
  final String? referredByName;
  final String? referredByPhone;
  final String customerType;       // ← THÊM
  final String customerTypeLabel;  // ← THÊM

  const PosCustomerMgmt({
    required this.id,
    required this.phone,
    required this.name,
    required this.totalSpend,
    this.availableCredit = 0,
    required this.createdAt,
    this.dateOfBirth,
    this.deliveryAddress,
    this.referredByCustomerId,
    this.referredByName,
    this.referredByPhone,
    this.customerType      = 'KLE',
    this.customerTypeLabel = 'Khách lẻ',
  });

  factory PosCustomerMgmt.fromJson(Map<String, dynamic> j) => PosCustomerMgmt(
    id:                   (j['id'] as num).toInt(),
    phone:                j['phone'] as String,
    name:                 j['name'] as String,
    totalSpend:           (j['totalSpend'] as num?)?.toDouble() ?? 0,
    availableCredit:      (j['availableCredit'] as num?)?.toDouble() ?? 0,
    createdAt:            j['createdAt']?.toString() ?? '',
    dateOfBirth:          j['dateOfBirth'] as String?,
    deliveryAddress:      j['deliveryAddress'] as String?,
    // ← đổi as int? thành (... as num?)?.toInt()
    referredByCustomerId: (j['referredByCustomerId'] as num?)?.toInt(),
    referredByName:       j['referredByName'] as String?,
    referredByPhone:      j['referredByPhone'] as String?,
    customerType:      j['customerType']      as String? ?? 'KLE',
    customerTypeLabel: j['customerTypeLabel'] as String? ?? 'Khách lẻ',
  );
}

class DiscountOptionMgmt {
  final int?   id;
  String discountType;  // PERCENT_BILL|FIXED_BILL|PERCENT_ITEM|FIXED_ITEM
  double discountValue;
  double? maxPerUse;
  String? label;

  DiscountOptionMgmt({
    this.id,
    required this.discountType,
    required this.discountValue,
    this.maxPerUse,
    this.label,
  });

  Map<String, dynamic> toJson() => {
    'discountType':  discountType,
    'discountValue': discountValue,
    if (maxPerUse != null) 'maxPerUse': maxPerUse,
    if (label != null && label!.isNotEmpty) 'label': label,
  };
}

class DiscountProgramMgmt {
  final int    id;
  final String name;
  final String status;
  final double minSpend;
  final double maxDiscountPerCustomer;
  final int    qualifyFrom;
  final int    qualifyTo;
  final int    applyFrom;
  final int    applyTo;
  final List<Map<String, dynamic>> options;

  const DiscountProgramMgmt({
    required this.id,
    required this.name,
    required this.status,
    required this.minSpend,
    required this.maxDiscountPerCustomer,
    required this.qualifyFrom,
    required this.qualifyTo,
    required this.applyFrom,
    required this.applyTo,
    required this.options,
  });

  factory DiscountProgramMgmt.fromJson(Map<String, dynamic> j) =>
      DiscountProgramMgmt(
        id:                     j['id'] as int,
        name:                   j['name'] as String,
        status:                 j['status'] as String,
        minSpend:               (j['minSpend'] as num).toDouble(),
        maxDiscountPerCustomer: (j['maxDiscountPerCustomer'] as num).toDouble(),
        qualifyFrom:            (j['qualifyFrom'] as num).toInt(),
        qualifyTo:              (j['qualifyTo'] as num).toInt(),
        applyFrom:              (j['applyFrom'] as num).toInt(),
        applyTo:                (j['applyTo'] as num).toInt(),
        options: (j['options'] as List? ?? [])
            .map((e) => e as Map<String, dynamic>).toList(),
      );

  bool get isActive => status == 'ACTIVE';
  bool get isDraft  => status == 'DRAFT';
}

// ─── Main Screen ──────────────────────────────────────────────────

class PosCustomerManagementScreen extends StatefulWidget {
  const PosCustomerManagementScreen({super.key});

  @override
  State<PosCustomerManagementScreen> createState() =>
      _PosCustomerManagementScreenState();
}

class _PosCustomerManagementScreenState
    extends State<PosCustomerManagementScreen> {

  bool _isLoading = false;
  bool _isSearching = false;              // đang gọi API tìm kiếm
  List<PosCustomerMgmt> _customers = [];
  String _customerSearch = '';
  final TextEditingController _searchCtrl = TextEditingController();
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    _loadCustomers();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadCustomers({String? search}) async {
    final q = (search ?? _customerSearch).trim();
    try {
      final res = q.isEmpty
          ? await DioClient.instance.get<List<PosCustomerMgmt>>(
        '${ApiConstants.posBase}/customers',
        fromData: (d) => (d as List)
            .map((e) => PosCustomerMgmt.fromJson(e as Map<String, dynamic>))
            .toList(),
      )
          : await DioClient.instance.get<List<PosCustomerMgmt>>(
        '${ApiConstants.posBase}/customers/search',
        queryParams: {'q': q},          // ← tìm theo SĐT HOẶC tên
        fromData: (d) => (d as List)
            .map((e) => PosCustomerMgmt.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
      if (mounted) setState(() => _customers = res.data ?? []);
    } catch (_) {
      // giữ danh sách cũ nếu lỗi
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  void _onSearchChanged(String v) {
    _customerSearch = v;
    _searchDebounce?.cancel();
    // Ngưng gõ 400ms → hiện loading rồi tải kết quả trùng keyword
    setState(() => _isSearching = true);
    _searchDebounce = Timer(const Duration(milliseconds: 400), () {
      _loadCustomers(search: v);
    });
  }

  void _clearSearch() {
    _searchDebounce?.cancel();
    _searchCtrl.clear();
    _customerSearch = '';
    setState(() => _isSearching = false);
    _loadCustomers(search: '');
  }

  String _fmtMoney(double v) => NumberFormat('#,###', 'vi_VN').format(v);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF0F172A)
          : const Color(0xFFF1F5F9),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(top: 20),
          child: _CustomerTab(
            customers: _customers,
            searchCtrl: _searchCtrl,
            isSearching: _isSearching,
            onSearch: _onSearchChanged,
            onClearSearch: _clearSearch,
            onRefresh: _loadCustomers,
            fmtMoney: _fmtMoney,
            onAdd: () => _showCustomerForm(null),
            onEdit: (c) => _showCustomerForm(c),
          ),
        ),
      ),
    );
  }

  Future<void> _showCustomerForm(PosCustomerMgmt? customer) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      builder: (_) => _CustomerFormSheet(
        customer: customer,
        onSaved: _loadCustomers,
      ),
    );
  }

  void _snack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor:
      isError ? Theme.of(context).colorScheme.error : null,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }
}

// ─── Customer Tab ─────────────────────────────────────────────────

class _CustomerTab extends StatelessWidget {
  final List<PosCustomerMgmt> customers;
  final TextEditingController searchCtrl;
  final bool isSearching;
  final ValueChanged<String> onSearch;
  final VoidCallback onClearSearch;
  final VoidCallback onRefresh;
  final String Function(double) fmtMoney;
  final VoidCallback onAdd;
  final ValueChanged<PosCustomerMgmt> onEdit;

  const _CustomerTab({
    required this.customers,
    required this.searchCtrl,
    required this.isSearching,
    required this.onSearch,
    required this.onClearSearch,
    required this.onRefresh,
    required this.fmtMoney,
    required this.onAdd,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final cs   = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final teal = const Color(0xFF0D9488);

    return Column(children: [
      // Search + Add
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Row(children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: dark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 8)],
              ),
              child: TextField(
                controller: searchCtrl,
                onChanged: onSearch,
                keyboardType: TextInputType.text,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: 'Tìm theo SĐT hoặc tên...',
                  prefixIcon: Icon(Icons.search_rounded,
                      color: cs.onSurface.withOpacity(0.4)),
                  suffixIcon: isSearching
                      ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                      width: 18, height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Color(0xFF0D9488)),
                    ),
                  )
                      : (searchCtrl.text.isNotEmpty
                      ? IconButton(
                    onPressed: onClearSearch,
                    splashRadius: 22,
                    icon: Icon(Icons.cancel_rounded,
                        size: 26,
                        color: cs.onSurface.withOpacity(0.45)),
                    tooltip: 'Xóa',
                  )
                      : null),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                      vertical: 12, horizontal: 4),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          FilledButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.person_add_rounded, size: 18),
            label: const Text('Thêm'),
            style: FilledButton.styleFrom(
              backgroundColor: teal,
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ]),
      ),

      // Stats row
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Row(children: [
          Text('${customers.length} khách hàng',
              style: TextStyle(fontSize: 12,
                  color: cs.onSurface.withOpacity(0.5))),
        ]),
      ),

      // List
      Expanded(
        child: customers.isEmpty
            ? _emptyState('Chưa có khách hàng', Icons.people_outline_rounded)
            : ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
          itemCount: customers.length,
          itemBuilder: (_, i) => _CustomerCard(
            customer: customers[i],
            fmtMoney: fmtMoney,
            onTap: () => onEdit(customers[i]),
          ),
        ),
      ),
    ]);
  }
}

class _CustomerCard extends StatelessWidget {
  final PosCustomerMgmt customer;
  final String Function(double) fmtMoney;
  final VoidCallback onTap;

  const _CustomerCard({
    required this.customer,
    required this.fmtMoney,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs   = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final teal = const Color(0xFF0D9488);

    Color _typeColor(String type) => switch (type) {
      'CTV'  => const Color(0xFF3B82F6),
      'CTVV' => const Color(0xFFF59E0B),
      _      => const Color(0xFF94A3B8),
    };

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: dark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            // Avatar
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                  color: teal.withOpacity(0.12),
                  shape: BoxShape.circle),
              child: Center(child: Text(
                customer.name.isNotEmpty
                    ? customer.name[0].toUpperCase() : '?',
                style: TextStyle(fontSize: 18,
                    fontWeight: FontWeight.w800, color: teal),
              )),
            ),
            const SizedBox(width: 12),

            // Info
            Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(customer.name, style: TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w700,
                      color: cs.onSurface)),
                  const SizedBox(height: 2),
                  Text(customer.phone, style: TextStyle(
                      fontSize: 12, color: cs.onSurface.withOpacity(0.55),
                      letterSpacing: 0.5)),
                  // Thêm vào _CustomerCard bên dưới phone text
                  const SizedBox(height: 3),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: _typeColor(customer.customerType).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(customer.customerTypeLabel,
                        style: TextStyle(fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: _typeColor(customer.customerType))),
                  ),
                ])),

            // Số dư + Tổng chi tiêu (2 dòng, có nhãn)
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Dòng 1: Số dư credit (số dư thật, dùng được ngay)
                Row(mainAxisSize: MainAxisSize.min, children: [
                  Text('Số dư: ', style: TextStyle(
                      fontSize: 11, color: cs.onSurface.withOpacity(0.55))),
                  Text('${fmtMoney(customer.availableCredit)} credit',
                      style: const TextStyle(fontSize: 13,
                          fontWeight: FontWeight.w800, color: Color(0xFFF59E0B))),
                ]),
                const SizedBox(height: 4),
                // Dòng 2: Tổng chi tiêu (tất cả đơn, không lọc thời gian)
                Row(mainAxisSize: MainAxisSize.min, children: [
                  Text('Tổng chi tiêu: ', style: TextStyle(
                      fontSize: 11, color: cs.onSurface.withOpacity(0.55))),
                  Text('${fmtMoney(customer.totalSpend)} đ',
                      style: TextStyle(fontSize: 14,
                          fontWeight: FontWeight.w800, color: teal)),
                ]),
              ],
            ),

            const SizedBox(width: 12),
            // Nút xem lịch sử đơn (to hơn, bỏ icon > bên phải)
            GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => PosCustomerOrdersScreen(
                    customerPhone: customer.phone,
                    customerName:  customer.name,
                  ),
                ),
              ),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF2563EB).withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.receipt_long_rounded,
                    size: 24, color: Color(0xFF2563EB)),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

// ─── Customer Form Sheet ──────────────────────────────────────────

class _CustomerFormSheet extends StatefulWidget {
  final PosCustomerMgmt? customer;
  final VoidCallback onSaved;

  const _CustomerFormSheet({this.customer, required this.onSaved});

  @override
  State<_CustomerFormSheet> createState() => _CustomerFormSheetState();
}

class _CustomerFormSheetState extends State<_CustomerFormSheet> {
  final _phoneCtrl   = TextEditingController();
  final _nameCtrl    = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _referrerPhoneCtrl = TextEditingController();
  List<Map<String, String>> _customerTypes = [];
  String _selectedType = 'KLE';

  String? _resolvedReferrerPhone; // ← đảm bảo có field này



  DateTime? _selectedDob;
  bool _isSaving = false;

  bool get _isEdit => widget.customer != null;

  // ── DOB helpers ───────────────────────────────────────────────

  String _fmtDob(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/'
          '${d.month.toString().padLeft(2, '0')}/'
          '${d.year}';

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
    _loadTypes();   // ← THÊM dòng này

    if (_isEdit) {
      final c = widget.customer!;
      _phoneCtrl.text   = c.phone;
      _nameCtrl.text    = c.name;
      _addressCtrl.text = c.deliveryAddress ?? '';
      _selectedDob      = _parseDob(c.dateOfBirth);
      _selectedType     = widget.customer!.customerType;
    }
  }

  Future<void> _loadTypes() async {
    try {
      final res = await DioClient.instance
          .get<List<Map<String, String>>>(
        '${ApiConstants.posBase}/customers/types',
        fromData: (d) => (d as List)
            .map((e) => Map<String, String>.from(e as Map))
            .toList(),
      );

      if (mounted && res.data != null) {
        setState(() => _customerTypes = res.data!);
      }
    } catch (_) {
      // fallback hardcode
      _customerTypes = [
        {'value': 'KLE',  'label': 'Khách lẻ'},
        {'value': 'CTV',  'label': 'Cộng tác viên'},
        {'value': 'CTVV', 'label': 'CTV Vàng'},
      ];
    }
  }


  @override
  void dispose() {
    _phoneCtrl.dispose();
    _nameCtrl.dispose();
    _addressCtrl.dispose();
    _referrerPhoneCtrl.dispose(); // ← THÊM
    super.dispose();
  }

  // ── Date picker ───────────────────────────────────────────────

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
            initialDate: _selectedDob ?? DateTime(1990, 1, 1),
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

  // ── Save ─────────────────────────────────────────────────────

  Future<void> _save() async {
    final phone = _phoneCtrl.text.trim();
    final name  = _nameCtrl.text.trim();
    if (phone.isEmpty || name.isEmpty) return;

    setState(() => _isSaving = true);
    try {
      final body = <String, dynamic>{
        'phone': phone,
        'name':  name,
      };
      body['customerType'] = _selectedType;
      if (_addressCtrl.text.trim().isNotEmpty)
        body['deliveryAddress'] = _addressCtrl.text.trim();
      if (_dobToApi() != null)
        body['dateOfBirth'] = _dobToApi()!;

      // ← DÙNG _resolvedReferrerPhone thay vì _referrerPhoneCtrl
      if (_resolvedReferrerPhone != null && _resolvedReferrerPhone!.isNotEmpty)
        body['referredByPhone'] = _resolvedReferrerPhone!;

      await DioClient.instance.post(
        '${ApiConstants.posBase}/customers',
        body: body,
      );
      widget.onSaved();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) _snack('Lỗi: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _snack(String msg) => ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating));

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cs     = Theme.of(context).colorScheme;
    const teal   = Color(0xFF0D9488);
    final surf   = isDark ? const Color(0xFF1E293B) : Colors.white;
    final bg     = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final border = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final txtSec = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return Container(
      decoration: BoxDecoration(
        color: surf,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 20),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 60),
        child: Column(mainAxisSize: MainAxisSize.min, children: [

          // Handle
          Center(child: Container(
            margin: const EdgeInsets.symmetric(vertical: 12),
            width: 36, height: 4,
            decoration: BoxDecoration(
                color: cs.onSurface.withOpacity(0.2),
                borderRadius: BorderRadius.circular(2)),
          )),

          // Title
          Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                  color: teal.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10)),
              child: Icon(
                _isEdit ? Icons.edit_rounded : Icons.person_add_rounded,
                size: 18, color: teal,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              _isEdit ? 'Cập nhật khách hàng' : 'Thêm khách hàng',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800,
                  color: cs.onSurface),
            ),
          ]),
          const SizedBox(height: 20),

          // ── SĐT (readonly khi edit) ─────────────────────────
          _buildField(
            controller: _phoneCtrl,
            label: 'Số điện thoại *',
            hint: '0938 121 001',
            icon: Icons.phone_rounded,
            readOnly: _isEdit,
            keyboard: TextInputType.phone,
            formatters: [FilteringTextInputFormatter.allow(
                RegExp(r'[\d\s+\-]'))],
            isDark: isDark, cs: cs, bg: bg, border: border, teal: teal,
          ),
          const SizedBox(height: 12),

          // ── Tên ─────────────────────────────────────────────
          _buildField(
            controller: _nameCtrl,
            label: 'Họ và tên *',
            hint: 'Nguyễn Văn A',
            icon: Icons.person_rounded,
            isDark: isDark, cs: cs, bg: bg, border: border, teal: teal,
          ),
          const SizedBox(height: 12),

          // ── Ngày sinh — calendar picker ──────────────────────
          GestureDetector(
            onTap: _pickDob,
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 14),
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _selectedDob != null
                      ? teal.withOpacity(0.5) : border,
                  width: _selectedDob != null ? 1.5 : 1,
                ),
              ),
              child: Row(children: [
                Icon(Icons.cake_rounded, size: 18,
                    color: teal.withOpacity(0.7)),
                const SizedBox(width: 12),
                Expanded(child: Text(
                  _selectedDob != null
                      ? _fmtDob(_selectedDob!)
                      : 'Ngày sinh (tùy chọn)',
                  style: TextStyle(
                    fontSize: 14,
                    color: _selectedDob != null
                        ? (isDark ? Colors.white : const Color(0xFF0F172A))
                        : txtSec.withOpacity(0.6),
                  ),
                )),
                if (_selectedDob != null)
                  GestureDetector(
                    onTap: () => setState(() => _selectedDob = null),
                    child: Icon(Icons.clear_rounded, size: 16,
                        color: txtSec.withOpacity(0.5)),
                  )
                else
                  Icon(Icons.arrow_drop_down_rounded, size: 20,
                      color: txtSec.withOpacity(0.5)),
              ]),
            ),
          ),
          const SizedBox(height: 12),

          // ── Địa chỉ giao hàng ────────────────────────────────
          TextFormField(
            controller: _addressCtrl,
            maxLines: 2,
            keyboardType: TextInputType.multiline,
            style: TextStyle(fontSize: 14,
                color: isDark ? Colors.white : const Color(0xFF0F172A)),
            decoration: InputDecoration(
              labelText: 'Địa chỉ giao hàng (tùy chọn)',
              hintText: '123 Nguyễn Trãi, Q5, TP.HCM',
              prefixIcon: Icon(Icons.location_on_rounded, size: 18,
                  color: teal.withOpacity(0.7)),
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
                  borderSide: const BorderSide(color: teal, width: 1.5)),
              labelStyle: TextStyle(fontSize: 13, color: txtSec),
              hintStyle: TextStyle(fontSize: 13,
                  color: txtSec.withOpacity(0.6)),
            ),
          ),

          // Thêm sau ô địa chỉ, trước referrer field
          const SizedBox(height: 12),

          // ── Loại khách hàng ─────────────────────────────────
          if (_customerTypes.isNotEmpty)
            DropdownButtonFormField<String>(
              value: _selectedType,
              decoration: InputDecoration(
                labelText: 'Loại khách hàng',
                prefixIcon: Icon(Icons.badge_rounded, size: 18,
                    color: teal.withOpacity(0.7)),
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
                    borderSide: const BorderSide(color: teal, width: 1.5)),
                labelStyle: TextStyle(fontSize: 13, color: txtSec),
              ),
              style: TextStyle(fontSize: 14,
                  color: isDark ? Colors.white : const Color(0xFF0F172A)),
              dropdownColor: surf,
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
            ),

          const SizedBox(height: 12),

          // ── Người giới thiệu (chỉ hiện khi thêm mới) ────────
          if (!_isEdit) ...[
            // Thêm mới: dùng _ReferrerField như cũ
            _ReferrerField(
              isDark: isDark, cs: cs, bg: bg,
              border: border, teal: teal, txtSec: txtSec,
              myPhone: _phoneCtrl.text,
              onResolved: (phone) =>
                  setState(() => _resolvedReferrerPhone = phone), // ← callback gán vào state
            ),
          ] else if (widget.customer!.referredByCustomerId != null) ...[
            // Đã có referrer → chỉ hiển thị readonly
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: teal.withOpacity(0.06),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: teal.withOpacity(0.2)),
              ),
              child: Row(children: [
                const Icon(Icons.people_alt_rounded, size: 14, color: Color(0xFF0D9488)),
                const SizedBox(width: 12),
                Expanded(child: Text(
                  'Giới thiệu bởi: ${widget.customer!.referredByName ?? ""}'
                      ' (${widget.customer!.referredByPhone ?? ""})',
                  style: TextStyle(fontSize: 12, color: txtSec),
                )),
                // Lock icon — không thể thay đổi
                Icon(Icons.lock_rounded, size: 13, color: txtSec.withOpacity(0.4)),
              ]),
            ),
          ] else ...[
            // Edit nhưng chưa có referrer → cho phép thêm
            Container(
              padding: const EdgeInsets.all(10),
              margin: const EdgeInsets.only(bottom: 4),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.06),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.orange.withOpacity(0.2)),
              ),
              child: Row(children: [
                Icon(Icons.info_outline_rounded, size: 13,
                    color: Colors.orange.shade700),
                const SizedBox(width: 12),
                Expanded(child: Text(
                  'Chưa có người giới thiệu — có thể thêm 1 lần duy nhất',
                  style: TextStyle(fontSize: 11,
                      color: Colors.orange.shade700),
                )),
              ]),
            ),
            _ReferrerField(
              isDark: isDark, cs: cs, bg: bg,
              border: border, teal: teal, txtSec: txtSec,
              myPhone: _phoneCtrl.text,
              onResolved: (phone) =>
                  setState(() => _resolvedReferrerPhone = phone), // ← callback gán vào state
            ),
          ],

          const SizedBox(height: 20),

          // ── Save button ──────────────────────────────────────
          SizedBox(
            width: double.infinity, height: 48,
            child: FilledButton(
              onPressed: _isSaving ? null : _save,
              style: FilledButton.styleFrom(
                backgroundColor: teal,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: _isSaving
                  ? const SizedBox(width: 18, height: 18,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2))
                  : Text(
                _isEdit ? 'Cập nhật' : 'Thêm khách hàng',
                style: const TextStyle(fontSize: 15,
                    fontWeight: FontWeight.w700),
              ),
            ),
          ),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }

  Widget _typeIcon(String type) {
    final (icon, color) = switch (type) {
      'CTV'  => (Icons.handshake_rounded,   const Color(0xFF3B82F6)),
      'CTVV' => (Icons.workspace_premium_rounded, const Color(0xFFF59E0B)),
      _      => (Icons.person_rounded,      const Color(0xFF94A3B8)),
    };
    return Icon(icon, size: 16, color: color);
  }

}

class _ReferrerField extends StatefulWidget {
  final bool isDark;
  final ColorScheme cs;
  final Color bg, border, teal, txtSec;
  final String myPhone;
  final ValueChanged<String?>? onResolved;

  const _ReferrerField({
    required this.isDark, required this.cs,
    required this.bg, required this.border,
    required this.teal, required this.txtSec,
    required this.myPhone,
    this.onResolved,
  });

  @override
  State<_ReferrerField> createState() => _ReferrerFieldState();
}

class _ReferrerFieldState extends State<_ReferrerField> {
  final _ctrl = TextEditingController();
  Timer? _debounce;
  bool _isSearching = false;
  bool _searched = false;
  String? _foundName;
  bool _notFound = false;
  String? _resolvedPhone; // phone đã normalize để gửi lên

  @override
  void dispose() {
    _debounce?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  void _onChanged(String v) {
    if (_foundName != null || _notFound) {
      setState(() {
        _foundName = null; _notFound = false;
        _searched = false; _resolvedPhone = null;
      });
      widget.onResolved?.call(null);
    }
    _debounce?.cancel();
    final trimmed = v.replaceAll(RegExp(r'\s+'), '');
    if (trimmed.length < 9) {
      if (_searched) setState(() { _searched = false; });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 600),
            () => _search(trimmed));
  }

  String _normalizePhone(String raw) {
    String s = raw.replaceAll(RegExp(r'[\s\-]'), '');
    if (s.startsWith('+84')) s = '0${s.substring(3)}';
    else if (s.startsWith('84') && s.length == 11) s = '0${s.substring(2)}';
    else if (!s.startsWith('0') && s.length == 9)  s = '0$s';
    return s;
  }

  Future<void> _search(String raw) async {
    if (!mounted) return;
    final normalized = _normalizePhone(raw);
    final myNorm     = _normalizePhone(widget.myPhone);
    if (normalized == myNorm) {
      setState(() {
        _isSearching = false; _searched = true;
        _notFound = true; _foundName = null;
      });
      return;
    }
    setState(() => _isSearching = true);
    try {
      final res = await DioClient.instance.get<List<dynamic>>(
        '${ApiConstants.posBase}/customers/search',
        queryParams: {'phone': normalized},
        fromData: (d) => d as List,
      );
      if (!mounted) return;
      final list = ((res.isSuccess ? res.data ?? [] : []) as List)
          .cast<Map<String, dynamic>>();
      final exact = list.where((e) =>
      (e['phone'] as String? ?? '') == normalized).toList();
      if (exact.isNotEmpty) {
        setState(() {
          _isSearching = false; _searched = true;
          _foundName = exact.first['name'] as String?;
          _notFound  = false;
          _resolvedPhone = normalized;
        });
        widget.onResolved?.call(normalized); // ← THÊM
      } else {
        setState(() {
          _isSearching = false; _searched = true;
          _foundName = null; _notFound = true; _resolvedPhone = null;
        });
        widget.onResolved?.call(null); // ← THÊM
      }
    } catch (_) {
      if (mounted) setState(() {
        _isSearching = false; _searched = true; _notFound = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      TextFormField(
        controller: _ctrl,
        keyboardType: TextInputType.phone,
        inputFormatters: [FilteringTextInputFormatter.allow(
            RegExp(r'[\d\s+\-]'))],
        onChanged: _onChanged,
        style: TextStyle(fontSize: 14,
            color: widget.isDark ? Colors.white : const Color(0xFF0F172A)),
        decoration: InputDecoration(
          labelText: 'SĐT người giới thiệu (tùy chọn)',
          hintText: '0938 xxx xxx',
          prefixIcon: Icon(Icons.people_alt_rounded, size: 18,
              color: widget.teal.withOpacity(0.7)),
          suffixIcon: _isSearching
              ? Padding(padding: const EdgeInsets.all(12),
              child: SizedBox(width: 16, height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: widget.teal)))
              : _foundName != null
              ? const Icon(Icons.check_circle_rounded,
              color: Color(0xFF0D9488), size: 20)
              : null,
          filled: true, fillColor: widget.bg,
          contentPadding: const EdgeInsets.symmetric(
              horizontal: 14, vertical: 13),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: widget.border)),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: _foundName != null
                    ? widget.teal.withOpacity(0.5) : widget.border,
                width: _foundName != null ? 1.5 : 1,
              )),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: widget.teal, width: 1.5)),
          labelStyle: TextStyle(fontSize: 13, color: widget.txtSec),
          hintStyle: TextStyle(fontSize: 13,
              color: widget.txtSec.withOpacity(0.6)),
        ),
      ),
      if (_searched && !_isSearching) ...[
        const SizedBox(height: 4),
        Padding(
          padding: const EdgeInsets.only(left: 4),
          child: Row(children: [
            Icon(
              _foundName != null
                  ? Icons.check_circle_outline_rounded
                  : Icons.info_outline_rounded,
              size: 13,
              color: _foundName != null
                  ? widget.teal
                  : Theme.of(context).colorScheme.error,
            ),
            const SizedBox(width: 5),
            Flexible(child: Text(
              _foundName != null
                  ? 'Người giới thiệu: $_foundName'
                  : _ctrl.text.isNotEmpty
                  ? 'Không tìm thấy số này'
                  : 'Không thể tự giới thiệu chính mình',
              style: TextStyle(
                fontSize: 11,
                color: _foundName != null
                    ? widget.teal
                    : Theme.of(context).colorScheme.error,
                fontWeight: FontWeight.w500,
              ),
            )),
          ]),
        ),
      ],
    ]);
  }
}

// ─── Shared helper widgets ────────────────────────────────────────

Widget _buildField({
  required TextEditingController controller,
  required String label,
  String? hint,
  required IconData icon,
  bool readOnly = false,
  TextInputType keyboard = TextInputType.text,
  List<TextInputFormatter>? formatters,
  required bool isDark,
  required ColorScheme cs,
  required Color bg,
  required Color border,
  required Color teal,
}) {
  return TextFormField(
    controller: controller,
    readOnly: readOnly,
    keyboardType: keyboard,
    inputFormatters: formatters,
    style: TextStyle(fontSize: 14,
        color: isDark ? Colors.white : const Color(0xFF0F172A)),
    decoration: InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon, size: 18,
          color: readOnly
              ? cs.onSurface.withOpacity(0.3)
              : teal.withOpacity(0.7)),
      filled: true,
      fillColor: readOnly
          ? cs.onSurface.withOpacity(0.04)
          : bg,
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
      labelStyle: TextStyle(fontSize: 13,
          color: cs.onSurface.withOpacity(0.5)),
      hintStyle: TextStyle(fontSize: 13,
          color: cs.onSurface.withOpacity(0.35)),
    ),
  );
}

Widget _emptyState(String text, IconData icon) =>
    Center(child: Column(mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 56, color: Colors.grey.withOpacity(0.3)),
          const SizedBox(height: 12),
          Text(text, style: TextStyle(fontSize: 15,
              color: Colors.grey.withOpacity(0.5))),
        ]));