// lib/features/management/screens/inventory_screen.dart
import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../../../shared/widgets/management_shared_widgets.dart';
import '../../../app/theme/app_colors.dart';
import '../../../data/models/management/inventory_batch_models.dart';
import '../../../data/models/management/management_models.dart';
import '../../../services/inventory_batch_service.dart';
import '../../../services/seller_service.dart';
import '../../../shared/widgets/network_image_viewer.dart';
import '../../order_scan/widgets/order_scan_button.dart';
// ─── Shared helpers ───────────────────────────────────────────────────────────

class _BatchRow {
  final IngredientModel ingredient;
  double    quantity;
  DateTime? expiryDate;
  double    unitPrice;

  _BatchRow({
    required this.ingredient,
    required this.quantity,
    this.expiryDate,
    this.unitPrice = 0,
  });

  double get lineAmount => quantity * unitPrice;
}

String _fmtQty(double q) =>
    q == q.truncateToDouble() ? q.toInt().toString() : q.toStringAsFixed(2);

double get _safeBottomPad => MediaQueryData.fromView(
    WidgetsBinding.instance.platformDispatcher.views.first).padding.bottom;

// ═══════════════════════════════════════════════════════════════
// InventoryScreen
// ═══════════════════════════════════════════════════════════════

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});
  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  int _tab = 0;

  static const _tabs      = ['Phiếu', 'Nhập', 'Xuất', 'Điều chỉnh'];
  static const _tabColors = [
    Color(0xFF6366F1), Color(0xFF0EA5E9),
    Color(0xFFF97316), Color(0xFFEAB308),
  ];
  static const _tabIcons = [
    Icons.receipt_long_rounded, Icons.download_rounded,
    Icons.upload_rounded,       Icons.tune_rounded,
  ];

  @override
  Widget build(BuildContext context) {
    final isDark    = Theme.of(context).brightness == Brightness.dark;
    final cardBg    = isDark ? AppColors.darkCard  : Colors.white;
    final border    = isDark ? AppColors.darkBorder : const Color(0xFFE5E7EB);
    final onBg      = isDark ? AppColors.darkTextPrimary   : Colors.black87;
    final secondary = isDark ? AppColors.darkTextSecondary : const Color(0xFF6B7280);
    final top       = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : const Color(0xFFF5F6FA),
      body: Column(children: [
        Container(
          color: cardBg,
          padding: EdgeInsets.fromLTRB(4, top + 8, 16, 12),
          child: Row(children: [
            IconButton(
              icon: Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: onBg),
              onPressed: () => Navigator.pop(context),
            ),
            const SizedBox(width: 4),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _tabColors[_tab].withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(_tabIcons[_tab], color: _tabColors[_tab], size: 18),
            ),
            const SizedBox(width: 10),
            Text(_tabs[_tab],
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: onBg)),
          ]),
        ),
        Container(height: 1, color: border),
        Container(
          color: cardBg,
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          child: Row(
            children: List.generate(_tabs.length, (i) {
              final sel = _tab == i;
              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _tab = i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: EdgeInsets.only(right: i < _tabs.length - 1 ? 8 : 0),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: sel
                          ? _tabColors[i].withOpacity(0.12)
                          : (isDark ? AppColors.darkCard : const Color(0xFFF3F4F6)),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: sel ? _tabColors[i] : Colors.transparent,
                        width: 1.5,
                      ),
                    ),
                    child: Center(
                      child: Text(_tabs[i],
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                            color: sel ? _tabColors[i] : secondary,
                          )),
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
        Container(height: 1, color: border),
        Expanded(
          child: IndexedStack(
            index: _tab,
            children: const [
              _BatchListTab(),
              _ImportTab(),
              _ExportTab(),
              _AdjustTab(),
            ],
          ),
        ),
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// SUPPLIER PICKER WIDGET — dùng chung cho Import + Export
// ═══════════════════════════════════════════════════════════════

class _SupplierPickerField extends StatelessWidget {
  final SupplierModel? selected;
  final VoidCallback onTap;    // mở sheet chọn NCC
  final VoidCallback? onClear; // xóa selection hiện tại
  final bool isDark;
  final Color accent;

  const _SupplierPickerField({
    required this.selected,
    required this.onTap,
    this.onClear,
    required this.isDark,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final border    = isDark ? AppColors.darkBorder : const Color(0xFFE5E7EB);
    final secondary = isDark ? AppColors.darkTextSecondary : const Color(0xFF6B7280);
    final onBg      = isDark ? AppColors.darkTextPrimary   : Colors.black87;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        border: Border.all(
          color: selected != null ? accent.withOpacity(0.6) : border,
          width: selected != null ? 1.5 : 1,
        ),
        borderRadius: BorderRadius.circular(10),
        color: selected != null
            ? accent.withOpacity(0.04)
            : (isDark
            ? AppColors.darkBg.withOpacity(0.5)
            : const Color(0xFFF9FAFB)),
      ),
      child: Row(children: [
        // Phần bên trái — bấm để mở picker
        Expanded(
          child: GestureDetector(
            onTap: onTap,
            behavior: HitTestBehavior.opaque,
            child: Row(children: [
              Icon(Icons.business_outlined, size: 18,
                  color: selected != null ? accent : secondary),
              const SizedBox(width: 10),
              Expanded(
                child: selected == null
                    ? Text('Chọn nhà cung cấp...',
                    style: TextStyle(fontSize: 13, color: secondary))
                    : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(selected!.name,
                      style: TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w600, color: onBg)),
                  if (selected!.phone?.isNotEmpty == true)
                    Text(selected!.phone!,
                        style: TextStyle(fontSize: 11, color: secondary)),
                ]),
              ),
            ]),
          ),
        ),
        // Nút X — tách hoàn toàn khỏi onTap
        if (selected != null && onClear != null)
          GestureDetector(
            onTap: onClear,
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Icon(Icons.close_rounded, size: 16, color: secondary),
            ),
          )
        else
          GestureDetector(
            onTap: onTap,
            child: Icon(Icons.search_rounded, size: 16, color: secondary),
          ),
      ]),
    );

  }
}


// ═══════════════════════════════════════════════════════════════
// SUPPLIER PICKER SHEET
// ═══════════════════════════════════════════════════════════════

class _SupplierPickerSheet extends StatefulWidget {
  final List<SupplierModel> suppliers;
  final SupplierModel? selected;
  final bool isDark;
  final Color accent;
  final Future<SupplierModel?> Function(String name, String? address, String? phone)
  onCreateNew;
  final Future<List<SupplierModel>> Function() onReload; // ← THÊM MỚI

  const _SupplierPickerSheet({
    required this.suppliers,
    required this.selected,
    required this.isDark,
    required this.accent,
    required this.onCreateNew,
    required this.onReload,   // ← THÊM MỚI
  });

  @override
  State<_SupplierPickerSheet> createState() => _SupplierPickerSheetState();
}

class _SupplierPickerSheetState extends State<_SupplierPickerSheet> {
  final _searchCtrl = TextEditingController();
  late List<SupplierModel> _allSuppliers;
  List<SupplierModel> _filtered = [];
  bool _showCreate = false;
  bool _reloading  = false; // ← THÊM MỚI

  final _nameCtrl    = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _phoneCtrl   = TextEditingController();
  bool    _creating    = false;
  String? _createError;

  @override
  void initState() {
    super.initState();
    _allSuppliers = List.from(widget.suppliers);
    _filtered     = _allSuppliers;
    _searchCtrl.addListener(_onSearch);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _nameCtrl.dispose();
    _addressCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  void _onSearch() {
    final q = _searchCtrl.text.toLowerCase().trim();
    setState(() {
      _filtered = q.isEmpty
          ? _allSuppliers
          : _allSuppliers
          .where((s) =>
      s.name.toLowerCase().contains(q) ||
          (s.phone?.contains(q) ?? false))
          .toList();
    });
  }

  // ── Reload từ server ──────────────────────────────────────────
  Future<void> _reload() async {
    setState(() => _reloading = true);
    try {
      final list = await widget.onReload();
      if (!mounted) return;
      setState(() {
        _allSuppliers = list;
        _onSearch(); // áp lại filter hiện tại
      });
    } finally {
      if (mounted) setState(() => _reloading = false);
    }
  }

  Future<void> _doCreate() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      setState(() => _createError = 'Vui lòng nhập tên nhà cung cấp');
      return;
    }
    setState(() { _creating = true; _createError = null; });
    final result = await widget.onCreateNew(
      name,
      _addressCtrl.text.trim().isEmpty ? null : _addressCtrl.text.trim(),
      _phoneCtrl.text.trim().isEmpty   ? null : _phoneCtrl.text.trim(),
    );
    if (!mounted) return;
    if (result != null) {
      // Thêm vào local list ngay lập tức rồi return
      setState(() {
        _allSuppliers = [..._allSuppliers, result];
        _filtered     = _allSuppliers;
        _showCreate   = false;
        _nameCtrl.clear(); _addressCtrl.clear(); _phoneCtrl.clear();
      });
      Navigator.pop(context, result);
    } else {
      setState(() { _creating = false; _createError = 'Tạo thất bại, thử lại'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark    = widget.isDark;
    final accent    = widget.accent;
    final cardBg    = isDark ? AppColors.darkCard  : Colors.white;
    final border    = isDark ? AppColors.darkBorder : const Color(0xFFE5E7EB);
    final onBg      = isDark ? AppColors.darkTextPrimary   : Colors.black87;
    final secondary = isDark ? AppColors.darkTextSecondary : const Color(0xFF6B7280);
    final bottom    = MediaQuery.of(context).padding.bottom;

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      constraints:
      BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
      child: Column(children: [
        // Handle
        Center(child: Container(
          margin: const EdgeInsets.only(top: 12, bottom: 4),
          width: 40, height: 4,
          decoration:
          BoxDecoration(color: border, borderRadius: BorderRadius.circular(2)),
        )),

        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                  color: accent.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10)),
              child: Icon(Icons.business_outlined, color: accent, size: 18),
            ),
            const SizedBox(width: 10),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Chọn nhà cung cấp',
                  style: TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w800, color: onBg)),
              Text('${_allSuppliers.length} nhà cung cấp',
                  style: TextStyle(fontSize: 11, color: secondary)),
            ]),
            const Spacer(),

            // ── Nút reload ──────────────────────────────────────
            if (_reloading)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: SizedBox(
                  width: 16, height: 16,
                  child: CircularProgressIndicator(strokeWidth: 1.5, color: accent),
                ),
              )
            else
              IconButton(
                onPressed: _reload,
                icon: Icon(Icons.refresh_rounded, size: 18, color: accent),
                padding: const EdgeInsets.all(6),
                style: IconButton.styleFrom(
                  backgroundColor: accent.withOpacity(0.08),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                tooltip: 'Tải lại danh sách',
              ),
            const SizedBox(width: 6),

            // Nút thêm mới
            TextButton.icon(
              onPressed: () => setState(() => _showCreate = !_showCreate),
              icon: Icon(_showCreate ? Icons.close : Icons.add,
                  size: 16, color: accent),
              label: Text(_showCreate ? 'Hủy' : 'Thêm mới',
                  style: TextStyle(
                      fontSize: 12, color: accent, fontWeight: FontWeight.w600)),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                backgroundColor: accent.withOpacity(0.08),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ]),
        ),

        // Create form (collapsible)
        AnimatedSize(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          child: _showCreate
              ? Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: accent.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: accent.withOpacity(0.25)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Thêm nhà cung cấp mới',
                    style: TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w700, color: onBg)),
                const SizedBox(height: 10),
                _createField(_nameCtrl, 'Tên nhà cung cấp *',
                    Icons.business_outlined, onBg, secondary, border, accent),
                const SizedBox(height: 8),
                _createField(_addressCtrl, 'Địa chỉ',
                    Icons.location_on_outlined, onBg, secondary, border, accent),
                const SizedBox(height: 8),
                _createField(_phoneCtrl, 'Số điện thoại',
                    Icons.phone_outlined, onBg, secondary, border, accent,
                    inputType: TextInputType.phone),
                if (_createError != null) ...[
                  const SizedBox(height: 6),
                  Text(_createError!,
                      style: const TextStyle(fontSize: 12, color: Colors.red)),
                ],
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _creating ? null : _doCreate,
                    icon: _creating
                        ? const SizedBox(
                        width: 14, height: 14,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.save_outlined, size: 16),
                    label: Text(_creating ? 'Đang lưu...' : 'Lưu nhà cung cấp'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accent, foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                      elevation: 0,
                    ),
                  ),
                ),
              ],
            ),
          )
              : const SizedBox.shrink(),
        ),

        // Search
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
          child: TextField(
            controller: _searchCtrl,
            style: TextStyle(fontSize: 14, color: onBg),
            decoration: InputDecoration(
              hintText: 'Tìm nhà cung cấp...',
              hintStyle: TextStyle(color: secondary, fontSize: 14),
              prefixIcon: Icon(Icons.search, color: secondary, size: 20),
              suffixIcon: _searchCtrl.text.isNotEmpty
                  ? IconButton(
                  icon: Icon(Icons.clear, size: 16, color: secondary),
                  onPressed: _searchCtrl.clear)
                  : null,
              filled: true,
              fillColor: secondary.withOpacity(0.06),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: border)),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: border)),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: accent, width: 1.5)),
              contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
          ),
        ),

        Divider(height: 0, color: border),

        // List
        Expanded(
          child: _filtered.isEmpty
              ? Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.search_off_rounded,
                    size: 36, color: secondary.withOpacity(0.3)),
                const SizedBox(height: 8),
                Text('Không tìm thấy', style: TextStyle(color: secondary)),
              ]))
              : ListView.separated(
            padding: EdgeInsets.only(bottom: bottom + 16),
            itemCount: _filtered.length,
            separatorBuilder: (_, __) => Divider(height: 0, color: border),
            itemBuilder: (_, i) {
              final s     = _filtered[i];
              final isSel = s.id == widget.selected?.id;
              return InkWell(
                onTap: () => Navigator.pop(context, s),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 12),
                  color: isSel
                      ? accent.withOpacity(0.06) : Colors.transparent,
                  child: Row(children: [
                    Container(
                      width: 38, height: 38,
                      decoration: BoxDecoration(
                        color: isSel
                            ? accent.withOpacity(0.12)
                            : secondary.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        isSel
                            ? Icons.check_circle_rounded
                            : Icons.business_outlined,
                        color: isSel ? accent : secondary,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(s.name,
                                style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: isSel ? accent : onBg)),
                            if (s.phone?.isNotEmpty == true ||
                                s.address?.isNotEmpty == true)
                              Text(
                                [
                                  if (s.phone?.isNotEmpty == true) s.phone!,
                                  if (s.address?.isNotEmpty == true) s.address!,
                                ].join(' · '),
                                style: TextStyle(fontSize: 11, color: secondary),
                                overflow: TextOverflow.ellipsis,
                              ),
                          ]),
                    ),
                    if (isSel)
                      Icon(Icons.check_rounded, color: accent, size: 18),
                  ]),
                ),
              );
            },
          ),
        ),

        // Không chọn
        Padding(
          padding: EdgeInsets.fromLTRB(16, 8, 16, bottom + 12),
          child: OutlinedButton.icon(
            onPressed: () => Navigator.pop(context, const _ClearSupplier()),
            icon: Icon(Icons.close_rounded, size: 16, color: secondary),
            label: Text('Không chọn nhà cung cấp',
                style: TextStyle(fontSize: 13, color: secondary)),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: border),
              padding: const EdgeInsets.symmetric(vertical: 12),
              minimumSize: const Size(double.infinity, 0),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _createField(
      TextEditingController ctrl, String hint, IconData icon,
      Color onBg, Color secondary, Color border, Color accent, {
        TextInputType inputType = TextInputType.text,
      }) =>
      TextField(
        controller: ctrl,
        keyboardType: inputType,
        style: TextStyle(fontSize: 13, color: onBg),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: secondary, fontSize: 13),
          prefixIcon: Icon(icon, size: 16, color: secondary),
          filled: true,
          fillColor: secondary.withOpacity(0.04),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: border)),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: border)),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: accent, width: 1.5)),
          contentPadding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          isDense: true,
        ),
      );
}


// Sentinel để biết user bấm "Không chọn"
class _ClearSupplier extends SupplierModel {
  const _ClearSupplier() : super(id: -1, name: '');
}

// ═══════════════════════════════════════════════════════════════
// Tab 0 — Danh sách phiếu (giữ nguyên)
// ═══════════════════════════════════════════════════════════════

class _BatchListTab extends StatefulWidget {
  const _BatchListTab();
  @override State<_BatchListTab> createState() => _BatchListTabState();
}

class _BatchListTabState extends State<_BatchListTab> {
  List<InventoryBatchSummary> _items = [];
  bool _loading = true;
  String? _error;

  @override void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    final r = await InventoryBatchService.instance.getBatches();
    if (!mounted) return;
    if (r.isSuccess && r.data != null) setState(() { _items = r.data!; _loading = false; });
    else setState(() { _error = r.message ?? 'Lỗi tải dữ liệu'; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return _ErrorView(msg: _error!, onRetry: _load);

    final sub = Theme.of(context).brightness == Brightness.dark
        ? AppColors.darkTextSecondary : const Color(0xFF6B7280);

    return RefreshIndicator(
      onRefresh: _load,
      child: _items.isEmpty
          ? CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [SliverFillRemaining(
          child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.receipt_long_outlined, size: 52, color: sub.withOpacity(0.3)),
            const SizedBox(height: 10),
            Text('Chưa có phiếu nào', style: TextStyle(color: sub, fontSize: 14)),
          ])),
        )],
      )
          : ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _items.length,
        itemBuilder: (_, i) => _BatchCard(
            batch: _items[i],
            onTap: () => _showDetail(_items[i].id)),
      ),
    );
  }

  void _showDetail(int id) => showModalBottomSheet(
    context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
    builder: (_) => _BatchDetailSheet(batchId: id),
  );
}

class _BatchCard extends StatelessWidget {
  final InventoryBatchSummary batch;
  final VoidCallback onTap;
  const _BatchCard({required this.batch, required this.onTap});

  static const _colors = {'IMPORT': Color(0xFF0EA5E9), 'EXPORT': Color(0xFFF97316), 'ADJUST': Color(0xFFEAB308)};
  static const _labels = {'IMPORT': 'Nhập', 'EXPORT': 'Xuất', 'ADJUST': 'Điều chỉnh'};
  static const _icons  = {'IMPORT': Icons.download_rounded, 'EXPORT': Icons.upload_rounded, 'ADJUST': Icons.tune_rounded};

  @override
  Widget build(BuildContext context) {
    final isDark    = Theme.of(context).brightness == Brightness.dark;
    final cardBg    = isDark ? AppColors.darkCard : Colors.white;
    final onBg      = isDark ? AppColors.darkTextPrimary   : Colors.black87;
    final secondary = isDark ? AppColors.darkTextSecondary : const Color(0xFF6B7280);
    final color     = _colors[batch.action] ?? const Color(0xFF6366F1);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: cardBg, borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.5), width: 1.5),
        ),
        child: Row(children: [
          Container(width: 42, height: 42,
              decoration: BoxDecoration(
                  color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
              child: Icon(_icons[batch.action] ?? Icons.receipt_long_rounded,
                  color: color, size: 20)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                    color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                child: Text(_labels[batch.action] ?? batch.action,
                    style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w700)),
              ),
              const SizedBox(width: 6),
              Expanded(child: Text(batch.batchCode,
                  style: TextStyle(fontSize: 12, color: onBg, fontWeight: FontWeight.w700),
                  overflow: TextOverflow.ellipsis)),
            ]),
            const SizedBox(height: 4),
            Text(DateFormat('dd/MM/yyyy HH:mm')
                .format(DateTime.fromMillisecondsSinceEpoch(batch.createdAt)),
                style: TextStyle(fontSize: 11, color: secondary)),
            if (batch.supplierRef?.isNotEmpty == true)
              Text('Ref: ${batch.supplierRef}',
                  style: TextStyle(fontSize: 11, color: secondary),
                  overflow: TextOverflow.ellipsis),
          ])),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('${batch.totalItems} mục',
                style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(batch.createdByName, style: TextStyle(fontSize: 11, color: secondary)),
            if (batch.action == 'IMPORT' &&
                batch.totalImportAmount != null &&
                batch.totalImportAmount! > 0)
              Text(
                NumberFormat('#,###', 'vi_VN').format(batch.totalImportAmount),
                style: const TextStyle(
                    fontSize: 11,
                    color: Colors.green,
                    fontWeight: FontWeight.w700),
              ),
          ]),
        ]),
      ),
    );
  }
}

class _BatchDetailSheet extends StatefulWidget {
  final int batchId;
  const _BatchDetailSheet({required this.batchId});
  @override State<_BatchDetailSheet> createState() => _BatchDetailSheetState();
}

class _BatchDetailSheetState extends State<_BatchDetailSheet> {
  InventoryBatchDetail? _detail;
  bool _loading = true;

  @override void initState() { super.initState(); _load(); }
  Future<void> _load() async {
    final r = await InventoryBatchService.instance.getBatchDetail(widget.batchId);
    if (!mounted) return;
    setState(() { _detail = r.data; _loading = false; });
  }

  void _showImages(List<String> urls) => showModalBottomSheet(
    context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
    builder: (_) => _ImageGallerySheet(urls: urls),
  );

  static const _actionColors = {'IMPORT': Color(0xFF0EA5E9), 'EXPORT': Color(0xFFF97316), 'ADJUST': Color(0xFFEAB308)};
  static const _actionLabels = {'IMPORT': 'Nhập kho', 'EXPORT': 'Xuất kho', 'ADJUST': 'Kiểm kho'};

  @override
  Widget build(BuildContext context) {
    final isDark    = Theme.of(context).brightness == Brightness.dark;
    final cardBg    = isDark ? AppColors.darkCard  : Colors.white;
    final border    = isDark ? AppColors.darkBorder : const Color(0xFFE5E7EB);
    final onBg      = isDark ? AppColors.darkTextPrimary   : Colors.black87;
    final secondary = isDark ? AppColors.darkTextSecondary : const Color(0xFF6B7280);

    return Container(
      decoration: BoxDecoration(color: cardBg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.88),
      child: _loading
          ? const Center(child: Padding(padding: EdgeInsets.all(40),
          child: CircularProgressIndicator()))
          : _detail == null
          ? const Center(child: Text('Không tìm thấy phiếu'))
          : _buildContent(border, onBg, secondary),
    );
  }

  Widget _buildContent(Color border, Color onBg, Color secondary) {
    final d     = _detail!;
    final color = _actionColors[d.action] ?? const Color(0xFF6366F1);
    return Column(children: [
      Container(margin: const EdgeInsets.only(top: 12), width: 40, height: 4,
          decoration: BoxDecoration(color: border, borderRadius: BorderRadius.circular(2))),
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                  color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
              child: Text(_actionLabels[d.action] ?? d.action,
                  style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w700)),
            ),
            const Spacer(),
            Text(DateFormat('dd/MM/yyyy HH:mm')
                .format(DateTime.fromMillisecondsSinceEpoch(d.createdAt)),
                style: TextStyle(fontSize: 12, color: secondary)),
          ]),
          const SizedBox(height: 6),
          Text(d.batchCode,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: onBg)),
          if (d.supplierRef?.isNotEmpty == true)
            Text('Ref: ${d.supplierRef}', style: TextStyle(fontSize: 12, color: secondary)),
          Text('Bởi: ${d.createdByName}', style: TextStyle(fontSize: 12, color: secondary)),
          if (d.action == 'IMPORT' &&
              d.totalImportAmount != null &&
              d.totalImportAmount! > 0) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.07),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.withOpacity(0.25)),
              ),
              child: Row(children: [
                const Icon(Icons.payments_outlined, size: 15, color: Colors.green),
                const SizedBox(width: 8),
                const Text('Tổng tiền nhập:',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                const Spacer(),
                Text(
                  '${NumberFormat('#,###', 'vi_VN').format(d.totalImportAmount!)}đ',
                  style: const TextStyle(fontSize: 13,
                      fontWeight: FontWeight.w800, color: Colors.green),
                ),
              ]),
            ),
          ],
          if (d.imageUrls.isNotEmpty) ...[
            const SizedBox(height: 10),
            GestureDetector(
              onTap: () => _showImages(d.imageUrls),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF0EA5E9).withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF0EA5E9).withOpacity(0.3)),
                ),
                child: Row(children: [
                  const Icon(Icons.photo_library_outlined, size: 16, color: Color(0xFF0EA5E9)),
                  const SizedBox(width: 8),
                  Text('Xem ${d.imageUrls.length} ảnh phiếu',
                      style: const TextStyle(fontSize: 13, color: Color(0xFF0EA5E9),
                          fontWeight: FontWeight.w600)),
                  const Spacer(),
                  const Icon(Icons.chevron_right_rounded, size: 18, color: Color(0xFF0EA5E9)),
                ]),
              ),
            ),
          ],
        ]),
      ),
      const SizedBox(height: 12),
      Divider(height: 0, color: border),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(children: [
          Expanded(flex: 3, child: _th('Nguyên liệu', secondary)),
          Expanded(flex: 2, child: _th(
              d.action == 'ADJUST' ? 'Tồn thực' : 'Số lượng',
              secondary, center: true)),
          if (d.action == 'IMPORT')
            Expanded(flex: 2, child: _th('Giá / Tiền', secondary, center: true)),
          Expanded(flex: 2, child: _th('Tồn cũ', secondary, center: true)),
          Expanded(flex: 2, child: _th('Tồn mới', secondary, center: true)),
          if (d.action == 'ADJUST') const SizedBox(width: 64),
        ]),
      ),
      Divider(height: 0, color: border),
      Expanded(
        child: ListView.separated(
          padding: const EdgeInsets.only(bottom: 24),
          itemCount: d.lines.length,
          separatorBuilder: (_, __) => Divider(height: 0, color: border),
          itemBuilder: (_, i) => _LogLineRow(line: d.lines[i], action: d.action),
        ),
      ),
    ]);
  }

  Widget _th(String t, Color c, {bool center = false}) =>
      Text(t, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: c),
          textAlign: center ? TextAlign.center : TextAlign.left);
}

class _LogLineRow extends StatelessWidget {
  final BatchLogLine line;
  final String action;
  const _LogLineRow({required this.line, required this.action});

  @override
  Widget build(BuildContext context) {
    final isDark    = Theme.of(context).brightness == Brightness.dark;
    final onBg      = isDark ? AppColors.darkTextPrimary   : Colors.black87;
    final secondary = isDark ? AppColors.darkTextSecondary : const Color(0xFF6B7280);
    final Color qtyColor; final String qtyStr;
    if (action == 'ADJUST') {
      qtyStr = _fmtQty(line.quantityAfter); qtyColor = onBg;
    } else {
      qtyStr   = line.quantity >= 0 ? '+${_fmtQty(line.quantity)}' : _fmtQty(line.quantity);
      qtyColor = line.quantity >= 0 ? const Color(0xFF10B981) : const Color(0xFFF97316);
    }
    Widget? badge;
    if (action == 'ADJUST') {
      final s = line.adjustStatus ?? 'MATCH';
      final (bc, bl) = switch (s) {
        'SURPLUS'  => (const Color(0xFF10B981), 'Dư ${_fmtQty(line.quantity)}'),
        'SHORTAGE' => (const Color(0xFFF97316), 'Thiếu ${_fmtQty(line.quantity.abs())}'),
        _          => (const Color(0xFF6B7280), 'Khớp'),
      };
      badge = Container(width: 64,
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          decoration: BoxDecoration(color: bc.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
          child: Text(bl, style: TextStyle(fontSize: 9, color: bc, fontWeight: FontWeight.w700),
              textAlign: TextAlign.center));
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(children: [
        Expanded(flex: 3, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(line.ingredientName,
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: onBg),
              overflow: TextOverflow.ellipsis),
          Text(line.unit, style: TextStyle(fontSize: 11, color: secondary)),
        ])),
        Expanded(flex: 2, child: Text(qtyStr,
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: qtyColor),
            textAlign: TextAlign.center)),
        // ── Cột Giá/Tiền — chỉ IMPORT ──────────────────────────
        if (action == 'IMPORT')
          Expanded(flex: 2, child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if ((line.unitPrice ?? 0) > 0) ...[
                Text(
                  '${NumberFormat('#,###', 'vi_VN').format(line.unitPrice!)}đ',
                  style: TextStyle(fontSize: 10, color: secondary),
                  textAlign: TextAlign.center,
                ),
                Text(
                  '${NumberFormat('#,###', 'vi_VN').format(line.lineAmount ?? 0)}đ',
                  style: const TextStyle(fontSize: 11,
                      color: Colors.green, fontWeight: FontWeight.w700),
                  textAlign: TextAlign.center,
                ),
              ] else
                Text('--', style: TextStyle(fontSize: 11, color: secondary),
                    textAlign: TextAlign.center),
            ],
          )),
        Expanded(flex: 2, child: Text(_fmtQty(line.quantityBefore),
            style: TextStyle(fontSize: 12, color: secondary), textAlign: TextAlign.center)),
        Expanded(flex: 2, child: Text(_fmtQty(line.quantityAfter),
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: onBg),
            textAlign: TextAlign.center)),
        if (badge != null) badge,
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// Tab 1 — Nhập kho
// ═══════════════════════════════════════════════════════════════

class _ImportTab extends StatefulWidget {
  const _ImportTab();
  @override State<_ImportTab> createState() => _ImportTabState();
}

class _ImportTabState extends State<_ImportTab> {
  static const _accent = Color(0xFF0EA5E9);
  final _priceCtrl = TextEditingController();

  List<IngredientModel> _all      = [];
  List<IngredientModel> _filtered = [];
  final List<_BatchRow> _batch    = [];
  bool    _loading    = true;
  bool    _submitting = false;
  String? _error;
  String? _priceError;


  Future<List<SupplierModel>> _reloadSuppliers() async {
    final r = await InventoryBatchService.instance.getSuppliers();
    if (r.isSuccess && r.data != null) {
      if (mounted) setState(() => _suppliers = r.data!);
      return r.data!;
    }
    return _suppliers;
  }


  final _searchCtrl      = TextEditingController();
  final _supplierRefCtrl = TextEditingController();
  final List<File> _receiptImages = [];
  Timer?  _debounce;

  IngredientModel? _selected;
  final _qtyCtrl  = TextEditingController();
  final _qtyFocus = FocusNode();
  DateTime? _popupExpiry;
  String?   _popupError;

  // ── Supplier ──────────────────────────────────────────────────
  List<SupplierModel> _suppliers     = [];
  SupplierModel?      _selectedSupplier;
  bool                _suppliersLoaded = false;

  @override
  void initState() {
    super.initState();
    _fetch();
    _fetchSuppliers();
    _searchCtrl.addListener(_onSearch);
  }

  @override
  void dispose() {
    _searchCtrl.dispose(); _supplierRefCtrl.dispose();
    _qtyCtrl.dispose(); _qtyFocus.dispose(); _debounce?.cancel();
    super.dispose();
    _priceCtrl.dispose();
  }

  Future<void> _fetch() async {
    setState(() { _loading = true; _error = null; });
    final r = await SellerService.instance.getIngredients(page: 0, size: 200);
    if (!mounted) return;
    if (r.isSuccess && r.data != null)
      setState(() { _all = r.data!; _filtered = List.from(_all); _loading = false; });
    else
      setState(() { _error = r.message ?? 'Lỗi'; _loading = false; });
  }

  Future<void> _fetchSuppliers() async {
    final r = await InventoryBatchService.instance.getSuppliers();
    if (!mounted) return;
    if (r.isSuccess && r.data != null)
      setState(() { _suppliers = r.data!; _suppliersLoaded = true; });
  }

  Future<SupplierModel?> _createSupplier(
      String name, String? address, String? phone) async {
    final r = await InventoryBatchService.instance.createSupplier(
        name: name, address: address, phone: phone);
    if (r.isSuccess && r.data != null) {
      setState(() => _suppliers = [..._suppliers, r.data!]);
      return r.data;
    }
    return null;
  }

  void _openSupplierSheet() async {
    final result = await showModalBottomSheet<dynamic>(
      context: context, isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _SupplierPickerSheet(
        suppliers:   _suppliers,
        selected:    _selectedSupplier,
        isDark:      Theme.of(context).brightness == Brightness.dark,
        accent:      _accent,
        onCreateNew: _createSupplier,
        onReload: _reloadSuppliers,
      ),
    );
    if (!mounted) return;
    if (result is _ClearSupplier) {
      setState(() => _selectedSupplier = null);
    } else if (result is SupplierModel) {
      setState(() => _selectedSupplier = result);
    }
  }

  void _onSearch() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () {
      final q = _searchCtrl.text.toLowerCase().trim();
      setState(() {
        _filtered = q.isEmpty ? List.from(_all)
            : _all.where((i) => i.name.toLowerCase().contains(q)).toList();
      });
    });
  }

  void _openPopup(IngredientModel ing) {
    setState(() { _selected = ing; _qtyCtrl.text = ''; _popupExpiry = null; _popupError = null; _priceError = null; });
    _priceCtrl.text = _selected != null
        ? (_batch.where((r) => r.ingredient.id == _selected!.id)
        .firstOrNull?.unitPrice ?? 0) > 0
        ? _batch.where((r) => r.ingredient.id == _selected!.id)
        .first.unitPrice.toStringAsFixed(0)
        : ''
        : '';
    WidgetsBinding.instance.addPostFrameCallback((_) => _qtyFocus.requestFocus());
  }

  void _closePopup() => setState(() {
    FocusScope.of(context).unfocus();
    _priceCtrl.text = '';
    _selected = null; _qtyCtrl.text = ''; _popupExpiry = null;
    _popupError = null; _priceError = null;
  });

  Future<void> _pickExpiryDate() async {
    final now    = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _popupExpiry ?? now.add(const Duration(days: 30)),
      firstDate: now.subtract(const Duration(days: 1)),
      lastDate: DateTime(now.year + 10),
      helpText: 'Chọn hạn dùng',
    );
    if (picked != null) setState(() => _popupExpiry = picked);
  }

  void _confirmAdd() {
    final qty = double.tryParse(_qtyCtrl.text.trim().replaceAll(',', '.'));
    if (qty == null || qty <= 0) {
      setState(() => _popupError = 'Số lượng phải lớn hơn 0'); return;
    }
    final price = double.tryParse(
        _priceCtrl.text.trim().replaceAll(',', '.').replaceAll('.', '')) ?? 0;
    // ── Bắt buộc nhập giá vốn ( > 0 ) ──────────────────────────────
    if (price <= 0) {
      setState(() => _priceError = 'Vui lòng nhập giá vốn (> 0)'); return;
    }

    final ing      = _selected!;
    final existIdx = _batch.indexWhere((r) => r.ingredient.id == ing.id);
    if (existIdx >= 0) {
      setState(() {
        _batch[existIdx].quantity  += qty;
        _batch[existIdx].expiryDate = _popupExpiry;
        _batch[existIdx].unitPrice  = price;  // cập nhật giá mới nhất
      });
    } else {
      setState(() => _batch.add(_BatchRow(
        ingredient: ing,
        quantity:   qty,
        expiryDate: _popupExpiry,
        unitPrice:  price,
      )));
    }
    _closePopup();
  }

  String _displayExpiry(_BatchRow row) {
    final ne = row.expiryDate;
    final oe = row.ingredient.expiryDate != null
        ? DateTime.fromMillisecondsSinceEpoch(row.ingredient.expiryDate!) : null;
    if (ne == null && oe == null) return '--';
    final now = DateTime.now();
    if (ne != null && ne.isAfter(now)) {
      if (oe == null || ne.isBefore(oe)) return DateFormat('dd/MM/yyyy').format(ne);
      return DateFormat('dd/MM/yyyy').format(oe);
    }
    if (oe != null && oe.isAfter(now)) return DateFormat('dd/MM/yyyy').format(oe);
    final fb = ne ?? oe;
    return fb != null ? DateFormat('dd/MM/yyyy').format(fb) : '--';
  }

  @override
  Widget build(BuildContext context) {
    final isDark    = Theme.of(context).brightness == Brightness.dark;
    final cardBg    = isDark ? AppColors.darkCard  : Colors.white;
    final border    = isDark ? AppColors.darkBorder : const Color(0xFFE5E7EB);
    final onBg      = isDark ? AppColors.darkTextPrimary   : Colors.black87;
    final secondary = isDark ? AppColors.darkTextSecondary : const Color(0xFF6B7280);

    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return _ErrorView(msg: _error!, onRetry: _fetch);

    return Stack(children: [
      LayoutBuilder(builder: (_, c) => c.maxWidth > 700
          ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(width: 420, child: _batchPanel(cardBg, border, onBg, secondary)),
        Container(width: 1, color: border),
        Expanded(child: _ingredientPanel(cardBg, border, onBg, secondary)),
      ])
          : Column(children: [
        if (_batch.isNotEmpty) ...[
          _batchPanel(cardBg, border, onBg, secondary),
          Container(height: 1, color: border),
        ],
        Expanded(child: _ingredientPanel(cardBg, border, onBg, secondary)),
      ]),
      ),
      if (_selected != null) _popupOverlay(cardBg, border, onBg, secondary),
      if (_submitting)
        Container(color: Colors.black.withOpacity(0.3),
            child: const Center(child: CircularProgressIndicator(color: Colors.white))),
    ]);
  }

  Widget _batchPanel(Color cardBg, Color border, Color onBg, Color secondary) {
    return Container(
      color: cardBg,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (_batch.isNotEmpty) ...[
          Container(
            color: const Color(0xFFF8F9FA),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(children: [
              Expanded(flex: 4, child: _thCell('Nguyên liệu', secondary)),
              Expanded(flex: 2, child: _thCell('Số lượng', secondary, center: true)),
              Expanded(flex: 3, child: _thCell('Giá / Thành tiền', secondary, center: true)),
              Expanded(flex: 2, child: _thCell('Hạn dùng', secondary, center: true)),
              const SizedBox(width: 32),
            ]),
          ),
          Divider(height: 0, color: border),
        ],
        Expanded(
          child: _batch.isEmpty
              ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.inbox_outlined, size: 48, color: secondary.withOpacity(0.3)),
            const SizedBox(height: 8),
            Text('Chưa có nguyên liệu nào', style: TextStyle(color: secondary, fontSize: 13)),
            const SizedBox(height: 4),
            Text('Chọn từ danh sách bên dưới', style: TextStyle(color: secondary, fontSize: 12)),
          ]))
              : ListView.separated(
            itemCount: _batch.length,
            separatorBuilder: (_, __) => Divider(height: 0, color: border),
            itemBuilder: (_, i) => _batchRow(i, cardBg, secondary),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: cardBg, border: Border(top: BorderSide(color: border)),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 8, offset: const Offset(0, -3))],
          ),
          padding: EdgeInsets.fromLTRB(16, 12, 16, 90 + _safeBottomPad),
          child: Row(children: [
            Expanded(child: OutlinedButton.icon(
              onPressed: _batch.isEmpty ? null : () => setState(() => _batch.clear()),
              icon: const Icon(Icons.delete_sweep_outlined, size: 16),
              label: const Text('Xóa tất cả'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red, side: const BorderSide(color: Colors.red),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            )),
            const SizedBox(width: 12),
            Expanded(flex: 2, child: ElevatedButton.icon(
              onPressed: (_batch.isEmpty || _submitting) ? null : _submit,
              icon: _submitting
                  ? const SizedBox(width: 18, height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.check_circle_outline, size: 18),
              label: Text(_submitting ? 'Đang nhập...' : 'Nhập kho'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _accent, foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
            )),
          ]),
        ),
      ]),
    );
  }

  Widget _thCell(String t, Color c, {bool center = false}) =>
      Text(t, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: c),
          textAlign: center ? TextAlign.center : TextAlign.left);

  Widget _batchRow(int i, Color cardBg, Color secondary) {
    final row       = _batch[i];
    final expiryStr = _displayExpiry(row);
    final isNear    = row.expiryDate != null &&
        row.expiryDate!.isBefore(DateTime.now().add(const Duration(days: 30)));
    final fmt = NumberFormat('#,###', 'vi_VN');

    return Container(
      color: cardBg,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(children: [
        // Cột tên
        Expanded(flex: 4, child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(row.ingredient.name,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                overflow: TextOverflow.ellipsis),
            Text(row.ingredient.unit, style: TextStyle(fontSize: 11, color: secondary)),
          ],
        )),
        // Cột số lượng
        Expanded(flex: 2, child: Text(
          '${_fmtQty(row.quantity)} ${row.ingredient.unit}',
          style: const TextStyle(fontWeight: FontWeight.w600, color: _accent, fontSize: 13),
          textAlign: TextAlign.center,
        )),
        // Cột giá / thành tiền
        Expanded(flex: 3, child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (row.unitPrice > 0) ...[
              Text(
                '${fmt.format(row.unitPrice)}đ',
                style: TextStyle(fontSize: 10, color: secondary),
                textAlign: TextAlign.center,
              ),
              Text(
                '= ${fmt.format(row.lineAmount)}đ',
                style: const TextStyle(
                    fontSize: 11, color: Colors.green,
                    fontWeight: FontWeight.w700),
                textAlign: TextAlign.center,
              ),
            ] else
              Text('--', style: TextStyle(fontSize: 11, color: secondary),
                  textAlign: TextAlign.center),
          ],
        )),
        // Cột hạn dùng
        Expanded(flex: 2, child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          decoration: BoxDecoration(
            color: isNear ? Colors.orange.withOpacity(0.1) : Colors.grey.shade50,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(expiryStr,
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                  color: isNear ? Colors.orange.shade700 : Colors.grey.shade700),
              textAlign: TextAlign.center),
        )),
        const SizedBox(width: 4),
        InkWell(
          onTap: () => setState(() => _batch.removeAt(i)),
          borderRadius: BorderRadius.circular(6),
          child: Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.08),
                borderRadius: BorderRadius.circular(6)),
            child: const Icon(Icons.remove_circle_outline, size: 16, color: Colors.red),
          ),
        ),
      ]),
    );
  }

  Widget _ingredientPanel(Color cardBg, Color border, Color onBg, Color secondary) {
    return Column(children: [
      Container(
        color: cardBg,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: const OrderScanButton(accent: _accent),
      ),
      Container(
        color: cardBg, padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: TextField(
          controller: _searchCtrl, style: TextStyle(fontSize: 14, color: onBg),
          decoration: InputDecoration(
            hintText: 'Tìm nguyên liệu...',
            hintStyle: TextStyle(color: secondary, fontSize: 14),
            prefixIcon: Icon(Icons.search, color: secondary, size: 20),
            suffixIcon: _searchCtrl.text.isNotEmpty
                ? IconButton(
                icon: Icon(Icons.clear, size: 16, color: secondary),
                onPressed: _searchCtrl.clear)
                : null,
            filled: true, fillColor: secondary.withOpacity(0.06),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: border)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: border)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: _accent, width: 1.5)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
        ),
      ),
      Divider(height: 0, color: border),
      Expanded(
        child: _filtered.isEmpty
            ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.search_off_rounded, size: 40, color: secondary.withOpacity(0.3)),
          const SizedBox(height: 8),
          Text('Không tìm thấy', style: TextStyle(color: secondary)),
        ]))
            : ListView.builder(
          itemCount: _filtered.length,
          itemBuilder: (_, i) =>
              _ingredientTile(_filtered[i], cardBg, border, onBg, secondary),
        ),
      ),
    ]);
  }

  Widget _ingredientTile(IngredientModel ing, Color cardBg, Color border, Color onBg, Color secondary) {
    final row     = _batch.where((r) => r.ingredient.id == ing.id).firstOrNull;
    final inBatch = row != null;
    return InkWell(
      onTap: () => _openPopup(ing),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: inBatch ? _accent.withOpacity(0.04) : cardBg,
          border: Border(bottom: BorderSide(color: border.withOpacity(0.5))),
        ),
        child: Row(children: [
          Container(width: 38, height: 38,
              decoration: BoxDecoration(
                color: inBatch ? _accent.withOpacity(0.12) : secondary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(inBatch ? Icons.check_circle_rounded : Icons.inventory_2_outlined,
                  color: inBatch ? _accent : secondary, size: 18)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(ing.name, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14,
                color: inBatch ? _accent : onBg)),
            Row(children: [
              Text('Tồn: ${_fmtQty(ing.stockQuantity)} ${ing.unit}',
                  style: TextStyle(fontSize: 11, color: secondary)),
              if (inBatch) ...[
                Text(' · ', style: TextStyle(color: secondary, fontSize: 11)),
                Text('Nhập: +${_fmtQty(row.quantity)} ${ing.unit}',
                    style: const TextStyle(fontSize: 11, color: _accent, fontWeight: FontWeight.w600)),
              ],
            ]),
          ])),
          Icon(Icons.add_circle_outline_rounded, color: inBatch ? _accent : secondary, size: 20),
        ]),
      ),
    );
  }

  Widget _popupOverlay(Color cardBg, Color border, Color onBg, Color secondary) =>
      GestureDetector(
        onTap: _closePopup,
        child: Container(
          color: Colors.black.withOpacity(0.45),
          child: Center(child: GestureDetector(onTap: () {},
              child: _popupCard(cardBg, border, onBg, secondary))),
        ),
      );

  Widget _popupCard(Color cardBg, Color border, Color onBg, Color secondary) {
    final ing      = _selected!;
    final existRow = _batch.where((r) => r.ingredient.id == ing.id).firstOrNull;
    final hasExist = existRow != null;
    return Container(
      width: 380, margin: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.18), blurRadius: 30, offset: const Offset(0, 8))]),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          padding: const EdgeInsets.fromLTRB(20, 16, 12, 16),
          decoration: BoxDecoration(color: _accent.withOpacity(0.06),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20))),
          child: Row(children: [
            Container(padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: _accent.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.inventory_2_outlined, color: _accent, size: 20)),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(ing.name, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: onBg)),
              Row(children: [
                Text('Tồn: ${_fmtQty(ing.stockQuantity)} ${ing.unit}',
                    style: TextStyle(fontSize: 11, color: secondary)),
                if (hasExist) ...[
                  Text(' · ', style: TextStyle(color: secondary, fontSize: 11)),
                  Text('Đang nhập: ${_fmtQty(existRow.quantity)} ${ing.unit}',
                      style: const TextStyle(fontSize: 11, color: _accent, fontWeight: FontWeight.w600)),
                ],
              ]),
            ])),
            IconButton(onPressed: _closePopup,
                icon: Icon(Icons.close_rounded, size: 20, color: secondary), padding: EdgeInsets.zero),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.all(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (hasExist)
              Container(
                margin: const EdgeInsets.only(bottom: 14),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(color: _accent.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _accent.withOpacity(0.2))),
                child: Row(children: [
                  const Icon(Icons.add_circle_outline, size: 14, color: _accent),
                  const SizedBox(width: 6),
                  Expanded(child: Text(
                    'Số lượng sẽ cộng thêm vào ${_fmtQty(existRow.quantity)} ${ing.unit} hiện có',
                    style: const TextStyle(fontSize: 12, color: _accent),
                  )),
                ]),
              ),
            Text('Số lượng thêm *', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: onBg)),
            const SizedBox(height: 6),
            NumericField(
              controller:  _qtyCtrl,
              focusNode:   _qtyFocus,
              hint:        '0.00',
              suffixText:  ing.unit,
              decimal:     true,
              focusColor:  _accent,
              onChanged:   (_) => setState(() => _popupError = null),
              onSubmitted: () => _qtyFocus.unfocus(),
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: onBg),
              decoration: InputDecoration(
                hintText:    '0.00',
                hintStyle:   TextStyle(color: secondary),
                suffixText:  ing.unit,
                suffixStyle: const TextStyle(
                    color: _accent, fontWeight: FontWeight.w700, fontSize: 14),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: _accent, width: 1.5)),
                errorText:      _popupError,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
            ),
            const SizedBox(height: 16),
            Text('Hạn dùng', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: onBg)),
            const SizedBox(height: 16),
            Text('Giá vốn (1 ${ing.unit}) *',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: onBg)),
            const SizedBox(height: 6),
            NumericField(
              controller:  _priceCtrl,
              hint:        '0',
              suffixText:  'đ',
              decimal:     false,
              focusColor:  _accent,
              onChanged:   (_) => setState(() => _priceError = null),
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: onBg),
              decoration: InputDecoration(
                hintText:    '0',
                hintStyle:   TextStyle(color: secondary),
                suffixText:  'đ',
                suffixStyle: const TextStyle(
                    color: Colors.green, fontWeight: FontWeight.w700, fontSize: 14),
                errorText:   _priceError,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: _accent, width: 1.5)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
            ),
            // Hiển thị thành tiền realtime
            if (_priceCtrl.text.isNotEmpty && _qtyCtrl.text.isNotEmpty) ...[
              const SizedBox(height: 8),
              Builder(builder: (_) {
                final qty   = double.tryParse(_qtyCtrl.text.replaceAll(',', '.')) ?? 0;
                final price = double.tryParse(_priceCtrl.text) ?? 0;
                final total = qty * price;
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green.withOpacity(0.2)),
                  ),
                  child: Row(children: [
                    const Icon(Icons.calculate_outlined, size: 14, color: Colors.green),
                    const SizedBox(width: 6),
                    Text('Thành tiền: ',
                        style: TextStyle(fontSize: 12, color: secondary)),
                    Text(
                      '${NumberFormat('#,###', 'vi_VN').format(total)}đ',
                      style: const TextStyle(fontSize: 13,
                          fontWeight: FontWeight.w700, color: Colors.green),
                    ),
                  ]),
                );
              }),
            ],

            const SizedBox(height: 6),
            InkWell(
              onTap: _pickExpiryDate,
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  border: Border.all(color: _popupExpiry != null ? _accent : border),
                  borderRadius: BorderRadius.circular(10),
                  color: _popupExpiry != null ? _accent.withOpacity(0.04) : Colors.transparent,
                ),
                child: Row(children: [
                  Icon(Icons.calendar_month_outlined, size: 18,
                      color: _popupExpiry != null ? _accent : secondary),
                  const SizedBox(width: 10),
                  Text(
                    _popupExpiry != null
                        ? DateFormat('dd/MM/yyyy').format(_popupExpiry!)
                        : 'Chọn ngày hết hạn',
                    style: TextStyle(fontSize: 14,
                        color: _popupExpiry != null ? onBg : secondary,
                        fontWeight: _popupExpiry != null ? FontWeight.w600 : FontWeight.normal),
                  ),
                  const Spacer(),
                  if (_popupExpiry != null)
                    GestureDetector(
                        onTap: () => setState(() => _popupExpiry = null),
                        child: Icon(Icons.clear, size: 16, color: secondary))
                  else
                    Icon(Icons.chevron_right, size: 18, color: secondary),
                ]),
              ),
            ),
            const SizedBox(height: 20),
            Row(children: [
              Expanded(child: OutlinedButton(
                onPressed: _closePopup,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  side: BorderSide(color: border),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: Text('Hủy', style: TextStyle(color: secondary)),
              )),
              const SizedBox(width: 12),
              Expanded(flex: 2, child: ElevatedButton.icon(
                onPressed: _confirmAdd,
                icon: Icon(hasExist ? Icons.add : Icons.add_circle_outline, size: 16),
                label: Text(hasExist ? 'Cộng thêm' : 'Thêm vào phiếu'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _accent, foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  elevation: 0,
                ),
              )),
            ]),
          ]),
        ),
      ]),
    );
  }

  void _submit() {
    _supplierRefCtrl.clear();
    _showConfirmSheet();
  }

  void _showConfirmSheet() {
    final isDark    = Theme.of(context).brightness == Brightness.dark;
    final cardBg    = isDark ? AppColors.darkCard  : Colors.white;
    final border    = isDark ? AppColors.darkBorder : const Color(0xFFE5E7EB);
    final onBg      = isDark ? AppColors.darkTextPrimary   : Colors.black87;
    final secondary = isDark ? AppColors.darkTextSecondary : const Color(0xFF6B7280);

    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (sheetCtx) => StatefulBuilder(
        builder: (ctx, setSS) => Container(
          decoration: BoxDecoration(color: cardBg,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
          padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom + MediaQuery.of(ctx).padding.bottom),
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Center(child: Container(margin: const EdgeInsets.only(top: 12, bottom: 4),
                  width: 40, height: 4,
                  decoration: BoxDecoration(color: border, borderRadius: BorderRadius.circular(2)))),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: Row(children: [
                  Container(padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                          color: _accent.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                      child: const Icon(Icons.check_circle_outline_rounded, color: _accent, size: 20)),
                  const SizedBox(width: 10),
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Xác nhận nhập kho',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: onBg)),
                    Text('${_batch.length} nguyên liệu',
                        style: TextStyle(fontSize: 12, color: secondary)),
                  ]),
                ]),
              ),
              const SizedBox(height: 16),
              Divider(height: 0, color: border),
              Padding(padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                  child: Text('Danh sách nhập',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: secondary))),
              ..._batch.map((r) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
                child: Row(children: [
                  Container(width: 6, height: 6,
                      decoration: const BoxDecoration(color: _accent, shape: BoxShape.circle)),
                  const SizedBox(width: 10),
                  Expanded(child: Text(r.ingredient.name,
                      style: TextStyle(fontSize: 13, color: onBg, fontWeight: FontWeight.w500))),
                  Text('+${_fmtQty(r.quantity)} ${r.ingredient.unit}',
                      style: const TextStyle(
                          fontSize: 13, color: _accent, fontWeight: FontWeight.w600)),
                ]),
              )),
              Builder(builder: (_) {
                final totalAmount = _batch.fold<double>(
                    0, (sum, r) => sum + r.lineAmount);
                if (totalAmount <= 0) return const SizedBox.shrink();
                return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.07),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.green.withOpacity(0.25)),
                      ),
                      child: Row(children: [
                        const Icon(Icons.payments_outlined, size: 16, color: Colors.green),
                        const SizedBox(width: 8),
                        const Text('Tổng tiền nhập hàng:',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                        const Spacer(),
                        Text(
                          '${NumberFormat('#,###', 'vi_VN').format(totalAmount)}đ',
                          style: const TextStyle(fontSize: 14,
                              fontWeight: FontWeight.w800, color: Colors.green),
                        ),
                      ]),
                    ),
                  ),
                ]);
              }),
              const SizedBox(height: 16),
              Divider(height: 0, color: border),

              // ── Nhà cung cấp ─────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                child: Row(children: [
                  Text('Nhà cung cấp',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: onBg)),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                        color: secondary.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                    child: Text('Tùy chọn',
                        style: TextStyle(fontSize: 10, color: secondary, fontWeight: FontWeight.w600)),
                  ),
                ]),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                child: _SupplierPickerField(
                  selected: _selectedSupplier,
                  isDark:   isDark,
                  accent:   _accent,
                  onClear: () {
                    setState(() => _selectedSupplier = null);
                    setSS(() {});   // ← rebuild sheet
                  },
                  onTap: () async {
                    // Đóng sheet tạm, mở supplier sheet
                    Navigator.pop(ctx);
                    await Future.delayed(const Duration(milliseconds: 100));
                    if (!mounted) return;
                    final result = await showModalBottomSheet<dynamic>(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (_) => _SupplierPickerSheet(
                        suppliers:   _suppliers,
                        selected:    _selectedSupplier,
                        isDark:      isDark,
                        accent:      _accent,
                        onCreateNew: _createSupplier,
                        onReload: _reloadSuppliers,
                      ),
                    );
                    if (!mounted) return;
                    if (result is _ClearSupplier)
                      setState(() => _selectedSupplier = null);
                    else if (result is SupplierModel)
                      setState(() => _selectedSupplier = result);
                    // Mở lại confirm sheet
                    _showConfirmSheet();
                  },
                ),
              ),

              // ── Mã phiếu NCC ─────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: Text('Mã phiếu nhà cung cấp *',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: onBg)),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                child: TextField(
                  controller: _supplierRefCtrl,
                  style: TextStyle(fontSize: 14, color: onBg),
                  decoration: InputDecoration(
                    hintText: 'VD: NCC-2026-00123',
                    hintStyle: TextStyle(color: secondary, fontSize: 13),
                    prefixIcon: Icon(Icons.receipt_outlined, color: secondary, size: 18),
                    filled: true, fillColor: secondary.withOpacity(0.05),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: border)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: border)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: _accent, width: 1.5)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                ),
              ),

              // ── Ảnh phiếu ────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                child: Row(children: [
                  Text('Ảnh phiếu giao hàng',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: onBg)),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: secondary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4)),
                    child: Text('Tùy chọn',
                        style: TextStyle(fontSize: 10, color: secondary, fontWeight: FontWeight.w600)),
                  ),
                ]),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  if (_receiptImages.isNotEmpty)
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3, crossAxisSpacing: 8,
                          mainAxisSpacing: 8, childAspectRatio: 1),
                      itemCount: _receiptImages.length,
                      itemBuilder: (_, i) => Stack(children: [
                        ClipRRect(borderRadius: BorderRadius.circular(8),
                            child: Image.file(_receiptImages[i], fit: BoxFit.cover,
                                width: double.infinity, height: double.infinity)),
                        Positioned(top: 4, right: 4,
                          child: GestureDetector(
                            onTap: () {
                              setState(() => _receiptImages.removeAt(i));
                              setSS(() {});
                            },
                            child: Container(
                              padding: const EdgeInsets.all(3),
                              decoration: BoxDecoration(
                                  color: Colors.red.withOpacity(0.85),
                                  shape: BoxShape.circle),
                              child: const Icon(Icons.close, size: 12, color: Colors.white),
                            ),
                          ),
                        ),
                      ]),
                    ),
                  if (_receiptImages.isNotEmpty) const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () => _addPhoto(setSS),
                    child: Container(
                      height: 52,
                      decoration: BoxDecoration(
                        border: Border.all(color: border, width: 1.5),
                        borderRadius: BorderRadius.circular(10),
                        color: secondary.withOpacity(0.04),
                      ),
                      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Icon(Icons.camera_alt_outlined, size: 18, color: secondary.withOpacity(0.6)),
                        const SizedBox(width: 8),
                        Text(
                          _receiptImages.isEmpty
                              ? 'Chụp ảnh phiếu'
                              : 'Chụp thêm (${_receiptImages.length} ảnh)',
                          style: TextStyle(fontSize: 13, color: secondary),
                        ),
                      ]),
                    ),
                  ),
                ]),
              ),

              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                child: Row(children: [
                  Expanded(child: OutlinedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: BorderSide(color: border),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text('Hủy', style: TextStyle(color: secondary)),
                  )),
                  const SizedBox(width: 12),
                  Expanded(flex: 2, child: ElevatedButton.icon(
                    onPressed: _submitting ? null : () {
                      if (_selectedSupplier == null) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text('Vui lòng chọn nhà cung cấp'),
                          backgroundColor: Colors.red,
                          behavior: SnackBarBehavior.floating,
                          margin: EdgeInsets.all(16),
                        ));
                        return;
                      }
                      // Validate mã phiếu NCC bắt buộc
                      if (_supplierRefCtrl.text.trim().isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text('Vui lòng nhập mã phiếu nhà cung cấp'),
                          backgroundColor: Colors.red,
                          behavior: SnackBarBehavior.floating,
                          margin: EdgeInsets.all(16),
                        ));
                        return;
                      }

                      Navigator.pop(ctx);
                      _doSubmit(
                        supplierRef: _supplierRefCtrl.text.trim().isEmpty
                            ? null : _supplierRefCtrl.text.trim(),
                      );
                    },
                    icon: const Icon(Icons.check_circle_outline, size: 18),
                    label: const Text('Xác nhận nhập kho'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _accent, foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                  )),
                ]),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  Future<void> _addPhoto(StateSetter setSS) async {
    try {
      final picked = await ImagePicker().pickImage(
          source: ImageSource.camera, imageQuality: 80, maxWidth: 1920);
      if (picked == null) return;
      setState(() => _receiptImages.add(File(picked.path)));
      setSS(() {});
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Không thể mở camera: $e'),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  Future<void> _doSubmit({String? supplierRef}) async {
    setState(() => _submitting = true);
    try {
      final result = await InventoryBatchService.instance.importBatch(
        items: _batch.map((r) => {
          'ingredientId': r.ingredient.id,
          'quantity':     r.quantity,
          if (r.expiryDate != null)
            'expiryDate': r.expiryDate!.millisecondsSinceEpoch,
          if (r.unitPrice > 0)
            'unitPrice': r.unitPrice,   // ← THÊM
        }).toList(),
        supplierRef:    supplierRef,
        supplierId:     _selectedSupplier?.id,
        supplierName:   _selectedSupplier?.name,
        receiptImages:  _receiptImages,
      );
      if (!mounted) return;
      if (result.isSuccess) {
        setState(() { _batch.clear(); _receiptImages.clear(); _selectedSupplier = null; });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('Nhập kho thành công!'),
          backgroundColor: _accent,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(result.message ?? 'Nhập kho thất bại'),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
        ));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }
}

// ═══════════════════════════════════════════════════════════════
// Tab 2 — Xuất kho
// ═══════════════════════════════════════════════════════════════

class _ExportTab extends StatefulWidget {
  const _ExportTab();
  @override State<_ExportTab> createState() => _ExportTabState();
}

class _ExportTabState extends State<_ExportTab> {
  static const _accent = Color(0xFFF97316);

  Future<List<SupplierModel>> _reloadSuppliers() async {
    final r = await InventoryBatchService.instance.getSuppliers();
    if (r.isSuccess && r.data != null) {
      if (mounted) setState(() => _suppliers = r.data!);
      return r.data!;
    }
    return _suppliers;
  }

  List<IngredientModel> _all      = [];
  List<IngredientModel> _filtered = [];
  final List<_BatchRow> _batch    = [];
  bool    _loading    = true;
  bool    _submitting = false;
  String? _error;

  final _searchCtrl = TextEditingController();
  final _reasonCtrl = TextEditingController();
  Timer?  _debounce;

  IngredientModel? _selected;
  final _qtyCtrl  = TextEditingController();
  final _qtyFocus = FocusNode();
  String? _popupError;

  // ── Supplier ──────────────────────────────────────────────────
  List<SupplierModel> _suppliers     = [];
  SupplierModel?      _selectedSupplier;

  @override
  void initState() {
    super.initState();
    _fetch();
    _fetchSuppliers();
    _searchCtrl.addListener(_onSearch);
  }

  @override
  void dispose() {
    _searchCtrl.dispose(); _reasonCtrl.dispose();
    _qtyCtrl.dispose(); _qtyFocus.dispose(); _debounce?.cancel();
    super.dispose();
  }

  Future<void> _fetch() async {
    setState(() { _loading = true; _error = null; });
    final r = await SellerService.instance.getIngredients(page: 0, size: 200);
    if (!mounted) return;
    if (r.isSuccess && r.data != null)
      setState(() { _all = r.data!; _filtered = List.from(_all); _loading = false; });
    else
      setState(() { _error = r.message ?? 'Lỗi'; _loading = false; });
  }

  Future<void> _fetchSuppliers() async {
    final r = await InventoryBatchService.instance.getSuppliers();
    if (!mounted) return;
    if (r.isSuccess && r.data != null)
      setState(() => _suppliers = r.data!);
  }

  Future<SupplierModel?> _createSupplier(
      String name, String? address, String? phone) async {
    final r = await InventoryBatchService.instance.createSupplier(
        name: name, address: address, phone: phone);
    if (r.isSuccess && r.data != null) {
      setState(() => _suppliers = [..._suppliers, r.data!]);
      return r.data;
    }
    return null;
  }

  void _onSearch() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () {
      final q = _searchCtrl.text.toLowerCase().trim();
      setState(() {
        _filtered = q.isEmpty ? List.from(_all)
            : _all.where((i) => i.name.toLowerCase().contains(q)).toList();
      });
    });
  }

  void _openPopup(IngredientModel ing) {
    setState(() { _selected = ing; _qtyCtrl.text = ''; _popupError = null; });
    WidgetsBinding.instance.addPostFrameCallback((_) => _qtyFocus.requestFocus());
  }

  void _closePopup() =>
      setState(() { FocusScope.of(context).unfocus(); _selected = null; _qtyCtrl.text = ''; _popupError = null; });

  void _confirmAdd() {
    final qty = double.tryParse(_qtyCtrl.text.trim().replaceAll(',', '.'));
    if (qty == null || qty <= 0) {
      setState(() => _popupError = 'Số lượng phải lớn hơn 0'); return;
    }
    if (qty > _selected!.stockQuantity) {
      setState(() => _popupError =
      'Vượt tồn kho (còn ${_fmtQty(_selected!.stockQuantity)} ${_selected!.unit})');
      return;
    }
    final existIdx = _batch.indexWhere((r) => r.ingredient.id == _selected!.id);
    if (existIdx >= 0) setState(() => _batch[existIdx].quantity += qty);
    else setState(() => _batch.add(_BatchRow(ingredient: _selected!, quantity: qty)));
    _closePopup();
  }

  @override
  Widget build(BuildContext context) {
    final isDark    = Theme.of(context).brightness == Brightness.dark;
    final cardBg    = isDark ? AppColors.darkCard  : Colors.white;
    final border    = isDark ? AppColors.darkBorder : const Color(0xFFE5E7EB);
    final onBg      = isDark ? AppColors.darkTextPrimary   : Colors.black87;
    final secondary = isDark ? AppColors.darkTextSecondary : const Color(0xFF6B7280);

    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return _ErrorView(msg: _error!, onRetry: _fetch);

    return Stack(children: [
      LayoutBuilder(builder: (_, c) => c.maxWidth > 700
          ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(width: 420, child: _batchPanel(cardBg, border, onBg, secondary)),
        Container(width: 1, color: border),
        Expanded(child: _ingredientPanel(cardBg, border, onBg, secondary)),
      ])
          : Column(children: [
        if (_batch.isNotEmpty) ...[
          _batchPanel(cardBg, border, onBg, secondary),
          Container(height: 1, color: border),
        ],
        Expanded(child: _ingredientPanel(cardBg, border, onBg, secondary)),
      ]),
      ),
      if (_selected != null) _popupOverlay(cardBg, border, onBg, secondary),
      if (_submitting)
        Container(color: Colors.black.withOpacity(0.3),
            child: const Center(child: CircularProgressIndicator(color: Colors.white))),
    ]);
  }

  Widget _batchPanel(Color cardBg, Color border, Color onBg, Color secondary) {
    return Container(
      color: cardBg,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (_batch.isNotEmpty) ...[
          Container(
            color: const Color(0xFFF8F9FA),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(children: [
              Expanded(flex: 3, child: _thCell('Nguyên liệu', secondary)),
              Expanded(flex: 2, child: _thCell('Số lượng', secondary, center: true)),
              const SizedBox(width: 32),
            ]),
          ),
          Divider(height: 0, color: border),
        ],
        Expanded(
          child: _batch.isEmpty
              ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.inbox_outlined, size: 48, color: secondary.withOpacity(0.3)),
            const SizedBox(height: 8),
            Text('Chưa có nguyên liệu nào',
                style: TextStyle(color: secondary, fontSize: 13)),
            const SizedBox(height: 4),
            Text('Chọn từ danh sách bên dưới',
                style: TextStyle(color: secondary, fontSize: 12)),
          ]))
              : ListView.separated(
            itemCount: _batch.length,
            separatorBuilder: (_, __) => Divider(height: 0, color: border),
            itemBuilder: (_, i) {
              final row = _batch[i];
              return Container(
                color: cardBg,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(children: [
                  Expanded(flex: 3, child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(row.ingredient.name,
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                        overflow: TextOverflow.ellipsis),
                    Text(row.ingredient.unit,
                        style: TextStyle(fontSize: 11, color: secondary)),
                  ])),
                  Expanded(flex: 2,
                      child: Text('${_fmtQty(row.quantity)} ${row.ingredient.unit}',
                          style: const TextStyle(fontWeight: FontWeight.w600,
                              color: _accent, fontSize: 13),
                          textAlign: TextAlign.center)),
                  const SizedBox(width: 4),
                  InkWell(
                    onTap: () => setState(() => _batch.removeAt(i)),
                    borderRadius: BorderRadius.circular(6),
                    child: Container(padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(6)),
                        child: const Icon(Icons.remove_circle_outline,
                            size: 16, color: Colors.red)),
                  ),
                ]),
              );
            },
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: cardBg, border: Border(top: BorderSide(color: border)),
            boxShadow: [BoxShadow(
                color: Colors.black.withOpacity(0.08), blurRadius: 8,
                offset: const Offset(0, -3))],
          ),
          padding: EdgeInsets.fromLTRB(16, 12, 16, 90 + _safeBottomPad),
          child: Row(children: [
            Expanded(child: OutlinedButton.icon(
              onPressed: _batch.isEmpty ? null : () => setState(() => _batch.clear()),
              icon: const Icon(Icons.delete_sweep_outlined, size: 16),
              label: const Text('Xóa tất cả'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red, side: const BorderSide(color: Colors.red),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            )),
            const SizedBox(width: 12),
            Expanded(flex: 2, child: ElevatedButton.icon(
              onPressed: (_batch.isEmpty || _submitting) ? null : _submit,
              icon: _submitting
                  ? const SizedBox(width: 18, height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.check_circle_outline, size: 18),
              label: Text(_submitting ? 'Đang xuất...' : 'Xuất kho'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _accent, foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
            )),
          ]),
        ),
      ]),
    );
  }

  Widget _thCell(String t, Color c, {bool center = false}) =>
      Text(t, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: c),
          textAlign: center ? TextAlign.center : TextAlign.left);

  Widget _ingredientPanel(Color cardBg, Color border, Color onBg, Color secondary) {
    return Column(children: [
      Container(
        color: cardBg, padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: TextField(
          controller: _searchCtrl, style: TextStyle(fontSize: 14, color: onBg),
          decoration: InputDecoration(
            hintText: 'Tìm nguyên liệu...',
            hintStyle: TextStyle(color: secondary, fontSize: 14),
            prefixIcon: Icon(Icons.search, color: secondary, size: 20),
            suffixIcon: _searchCtrl.text.isNotEmpty
                ? IconButton(icon: Icon(Icons.clear, size: 16, color: secondary),
                onPressed: _searchCtrl.clear)
                : null,
            filled: true, fillColor: secondary.withOpacity(0.06),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: border)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: border)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: _accent, width: 1.5)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
        ),
      ),
      Divider(height: 0, color: border),
      Expanded(
        child: _filtered.isEmpty
            ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.search_off_rounded, size: 40, color: secondary.withOpacity(0.3)),
          const SizedBox(height: 8),
          Text('Không tìm thấy', style: TextStyle(color: secondary)),
        ]))
            : ListView.builder(
          itemCount: _filtered.length,
          itemBuilder: (_, i) {
            final ing     = _filtered[i];
            final row     = _batch.where((r) => r.ingredient.id == ing.id).firstOrNull;
            final inBatch = row != null;
            return InkWell(
              onTap: () => _openPopup(ing),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  color: inBatch ? _accent.withOpacity(0.04) : cardBg,
                  border: Border(bottom: BorderSide(color: border.withOpacity(0.5))),
                ),
                child: Row(children: [
                  Container(width: 38, height: 38,
                      decoration: BoxDecoration(
                        color: inBatch ? _accent.withOpacity(0.12) : secondary.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(inBatch ? Icons.check_circle_rounded : Icons.inventory_2_outlined,
                          color: inBatch ? _accent : secondary, size: 18)),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(ing.name, style: TextStyle(fontWeight: FontWeight.w600,
                        fontSize: 14, color: inBatch ? _accent : onBg)),
                    Row(children: [
                      Text('Tồn: ${_fmtQty(ing.stockQuantity)} ${ing.unit}',
                          style: TextStyle(fontSize: 11, color: secondary)),
                      if (inBatch) ...[
                        Text(' · ', style: TextStyle(color: secondary, fontSize: 11)),
                        Text('Xuất: ${_fmtQty(row.quantity)} ${ing.unit}',
                            style: const TextStyle(fontSize: 11,
                                color: _accent, fontWeight: FontWeight.w600)),
                      ],
                    ]),
                  ])),
                  Icon(Icons.add_circle_outline_rounded,
                      color: inBatch ? _accent : secondary, size: 20),
                ]),
              ),
            );
          },
        ),
      ),
    ]);
  }

  Widget _popupOverlay(Color cardBg, Color border, Color onBg, Color secondary) =>
      GestureDetector(
        onTap: _closePopup,
        child: Container(
          color: Colors.black.withOpacity(0.45),
          child: Center(child: GestureDetector(onTap: () {},
              child: _popupCard(cardBg, border, onBg, secondary))),
        ),
      );

  Widget _popupCard(Color cardBg, Color border, Color onBg, Color secondary) {
    final ing      = _selected!;
    final existRow = _batch.where((r) => r.ingredient.id == ing.id).firstOrNull;
    final hasExist = existRow != null;
    return Container(
      width: 380, margin: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(
              color: Colors.black.withOpacity(0.18), blurRadius: 30,
              offset: const Offset(0, 8))]),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          padding: const EdgeInsets.fromLTRB(20, 16, 12, 16),
          decoration: BoxDecoration(color: _accent.withOpacity(0.06),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20))),
          child: Row(children: [
            Container(padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: _accent.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.inventory_2_outlined, color: _accent, size: 20)),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(ing.name,
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: onBg)),
              Row(children: [
                Text('Tồn: ${_fmtQty(ing.stockQuantity)} ${ing.unit}',
                    style: TextStyle(fontSize: 11, color: secondary)),
                if (hasExist) ...[
                  Text(' · ', style: TextStyle(color: secondary, fontSize: 11)),
                  Text('Đang xuất: ${_fmtQty(existRow.quantity)} ${ing.unit}',
                      style: const TextStyle(fontSize: 11,
                          color: _accent, fontWeight: FontWeight.w600)),
                ],
              ]),
            ])),
            IconButton(onPressed: _closePopup,
                icon: Icon(Icons.close_rounded, size: 20, color: secondary),
                padding: EdgeInsets.zero),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.all(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Số lượng xuất *',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: onBg)),
            const SizedBox(height: 6),
            NumericField(
              controller:  _qtyCtrl,
              focusNode:   _qtyFocus,
              hint:        '0.00',
              suffixText:  ing.unit,
              decimal:     true,
              focusColor:  _accent,
              onChanged:   (_) => setState(() => _popupError = null),
              onSubmitted: () => _qtyFocus.unfocus(),
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: onBg),
              decoration: InputDecoration(
                hintText:    '0.00',
                hintStyle:   TextStyle(color: secondary),
                suffixText:  ing.unit,
                suffixStyle: const TextStyle(
                    color: _accent, fontWeight: FontWeight.w700, fontSize: 14),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: _accent, width: 1.5)),
                errorText:      _popupError,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
            ),
            const SizedBox(height: 8),
            Text('Tồn hiện tại: ${_fmtQty(ing.stockQuantity)} ${ing.unit}',
                style: TextStyle(fontSize: 12, color: secondary)),
            const SizedBox(height: 20),
            Row(children: [
              Expanded(child: OutlinedButton(
                onPressed: _closePopup,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  side: BorderSide(color: border),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: Text('Hủy', style: TextStyle(color: secondary)),
              )),
              const SizedBox(width: 12),
              Expanded(flex: 2, child: ElevatedButton.icon(
                onPressed: _confirmAdd,
                icon: Icon(hasExist ? Icons.add : Icons.add_circle_outline, size: 16),
                label: Text(hasExist ? 'Cộng thêm' : 'Thêm vào phiếu'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _accent, foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  elevation: 0,
                ),
              )),
            ]),
          ]),
        ),
      ]),
    );
  }

  void _submit() { _reasonCtrl.clear(); _showConfirmSheet(); }

  void _showConfirmSheet() {
    final isDark    = Theme.of(context).brightness == Brightness.dark;
    final cardBg    = isDark ? AppColors.darkCard  : Colors.white;
    final border    = isDark ? AppColors.darkBorder : const Color(0xFFE5E7EB);
    final onBg      = isDark ? AppColors.darkTextPrimary   : Colors.black87;
    final secondary = isDark ? AppColors.darkTextSecondary : const Color(0xFF6B7280);

    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSS) => Container(
          decoration: BoxDecoration(color: cardBg,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
          padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom + MediaQuery.of(ctx).padding.bottom),
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Center(child: Container(margin: const EdgeInsets.only(top: 12, bottom: 4),
                      width: 40, height: 4,
                      decoration: BoxDecoration(color: border, borderRadius: BorderRadius.circular(2)))),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                    child: Row(children: [
                      Container(padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                              color: _accent.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10)),
                          child: const Icon(Icons.upload_rounded, color: _accent, size: 20)),
                      const SizedBox(width: 10),
                      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Xác nhận xuất kho',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: onBg)),
                        Text('${_batch.length} nguyên liệu',
                            style: TextStyle(fontSize: 12, color: secondary)),
                      ]),
                    ]),
                  ),
                  const SizedBox(height: 16),
                  Divider(height: 0, color: border),
                  Padding(padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                      child: Text('Danh sách xuất',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: secondary))),
                  ..._batch.map((r) => Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
                    child: Row(children: [
                      Container(width: 6, height: 6,
                          decoration: const BoxDecoration(color: _accent, shape: BoxShape.circle)),
                      const SizedBox(width: 10),
                      Expanded(child: Text(r.ingredient.name,
                          style: TextStyle(fontSize: 13, color: onBg, fontWeight: FontWeight.w500))),
                      Text('-${_fmtQty(r.quantity)} ${r.ingredient.unit}',
                          style: const TextStyle(
                              fontSize: 13, color: _accent, fontWeight: FontWeight.w600)),
                    ]),
                  )),
                  const SizedBox(height: 16),
                  Divider(height: 0, color: border),

                  // ── Nhà cung cấp ─────────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                    child: Row(children: [
                      Text('Nhà cung cấp',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: onBg)),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                            color: secondary.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                        child: Text('Tùy chọn',
                            style: TextStyle(fontSize: 10, color: secondary, fontWeight: FontWeight.w600)),
                      ),
                    ]),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                    child: _SupplierPickerField(
                      selected: _selectedSupplier,
                      isDark:   isDark,
                      accent:   _accent,
                      onClear: () {
                        setState(() => _selectedSupplier = null);
                        setSS(() {}); // ← rebuild sheet
                      },
                      onTap: () async {
                        Navigator.pop(ctx);
                        await Future.delayed(const Duration(milliseconds: 100));
                        if (!mounted) return;
                        final result = await showModalBottomSheet<dynamic>(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          builder: (_) => _SupplierPickerSheet(
                            suppliers:   _suppliers,
                            selected:    _selectedSupplier,
                            isDark:      isDark,
                            accent:      _accent,
                            onCreateNew: _createSupplier,
                            onReload: _reloadSuppliers,
                          ),
                        );
                        if (!mounted) return;
                        if (result is _ClearSupplier)
                          setState(() => _selectedSupplier = null);
                        else if (result is SupplierModel)
                          setState(() => _selectedSupplier = result);
                        _showConfirmSheet();
                      },
                    ),
                  ),

                  // ── Lý do xuất kho ───────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                    child: Row(children: [
                      Text('Lý do xuất kho *',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: onBg)),
                      const SizedBox(width: 6),
                    ]),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                    child: TextField(
                      controller: _reasonCtrl,
                      style: TextStyle(fontSize: 14, color: onBg),
                      decoration: InputDecoration(
                        hintText: 'VD: Cho đơn hàng khách A, Hỏng hóc...',
                        hintStyle: TextStyle(color: secondary, fontSize: 13),
                        prefixIcon: Icon(Icons.edit_note_rounded, color: secondary, size: 18),
                        filled: true, fillColor: secondary.withOpacity(0.05),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: border)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: border)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: _accent, width: 1.5)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                    child: Row(children: [
                      Expanded(child: OutlinedButton(
                        onPressed: () => Navigator.pop(ctx),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side: BorderSide(color: border),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Text('Hủy', style: TextStyle(color: secondary)),
                      )),
                      const SizedBox(width: 12),
                      Expanded(flex: 2, child: ElevatedButton.icon(
                        onPressed: _submitting ? null : () {
                          if (_reasonCtrl.text.trim().isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                              content: Text('Vui lòng nhập lý do xuất kho'),
                              backgroundColor: Colors.red,
                              behavior: SnackBarBehavior.floating,
                              margin: EdgeInsets.all(16),
                            ));
                            return;
                          }
                          Navigator.pop(ctx);
                          _doSubmit();
                        },
                        icon: const Icon(Icons.check_circle_outline, size: 18),
                        label: const Text('Xác nhận xuất kho'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _accent, foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                      )),
                    ]),
                  ),
                ]),
          ),
        ),
      ),
    );
  }

  Future<void> _doSubmit() async {
    setState(() => _submitting = true);
    try {
      final result = await InventoryBatchService.instance.exportBatch(
        ExportRequest(
          reason:       _reasonCtrl.text.trim().isEmpty ? null : _reasonCtrl.text.trim(),
          supplierId:   _selectedSupplier?.id,
          supplierName: _selectedSupplier?.name,
          items: _batch.map((r) =>
              ExportItem(ingredientId: r.ingredient.id, quantity: r.quantity)).toList(),
        ),
      );
      if (!mounted) return;
      if (result.isSuccess) {
        setState(() { _batch.clear(); _selectedSupplier = null; });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('Xuất kho thành công!'), backgroundColor: _accent,
          behavior: SnackBarBehavior.floating, margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(result.message ?? 'Xuất kho thất bại'),
          backgroundColor: Colors.red.shade700, behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
        ));
      }
    } finally { if (mounted) setState(() => _submitting = false); }
  }
}

// ═══════════════════════════════════════════════════════════════
// Tab 3 — Điều chỉnh (giữ nguyên, không có supplier)
// ═══════════════════════════════════════════════════════════════

class _AdjustTab extends StatefulWidget {
  const _AdjustTab();
  @override State<_AdjustTab> createState() => _AdjustTabState();
}

class _AdjustTabState extends State<_AdjustTab> {
  static const _accent = Color(0xFFEAB308);

  List<IngredientModel> _all      = [];
  List<IngredientModel> _filtered = [];
  final Map<int, TextEditingController> _ctrlMap = {};
  bool    _loading    = true;
  bool    _submitting = false;
  String? _error;

  final _searchCtrl = TextEditingController();
  Timer?  _debounce;

  @override
  void initState() { super.initState(); _fetch(); _searchCtrl.addListener(_onSearch); }

  @override
  void dispose() {
    _searchCtrl.dispose();
    for (final c in _ctrlMap.values) c.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _fetch() async {
    setState(() { _loading = true; _error = null; });
    final r = await SellerService.instance.getIngredients(page: 0, size: 200);
    if (!mounted) return;
    if (r.isSuccess && r.data != null) {
      for (final ing in r.data!) _ctrlMap[ing.id] ??= TextEditingController();
      setState(() { _all = r.data!; _filtered = List.from(_all); _loading = false; });
    } else {
      setState(() { _error = r.message ?? 'Lỗi'; _loading = false; });
    }
  }

  void _onSearch() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () {
      final q = _searchCtrl.text.toLowerCase().trim();
      setState(() {
        _filtered = q.isEmpty ? List.from(_all)
            : _all.where((i) => i.name.toLowerCase().contains(q)).toList();
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark    = Theme.of(context).brightness == Brightness.dark;
    final cardBg    = isDark ? AppColors.darkCard  : Colors.white;
    final border    = isDark ? AppColors.darkBorder : const Color(0xFFE5E7EB);
    final onBg      = isDark ? AppColors.darkTextPrimary   : Colors.black87;
    final secondary = isDark ? AppColors.darkTextSecondary : const Color(0xFF6B7280);

    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return _ErrorView(msg: _error!, onRetry: _fetch);

    return Column(children: [
      Container(
        color: cardBg, padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: TextField(
          controller: _searchCtrl, style: TextStyle(fontSize: 14, color: onBg),
          decoration: InputDecoration(
            hintText: 'Tìm nguyên liệu...',
            hintStyle: TextStyle(color: secondary, fontSize: 14),
            prefixIcon: Icon(Icons.search, color: secondary, size: 20),
            suffixIcon: _searchCtrl.text.isNotEmpty
                ? IconButton(icon: Icon(Icons.clear, size: 16, color: secondary),
                onPressed: _searchCtrl.clear)
                : null,
            filled: true, fillColor: secondary.withOpacity(0.06),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: border)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: border)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: _accent, width: 1.5)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
        ),
      ),
      Divider(height: 0, color: border),
      Expanded(
        child: ListView.separated(
          padding: EdgeInsets.only(bottom: _safeBottomPad + 90),
          itemCount: _filtered.length,
          separatorBuilder: (_, __) => Divider(height: 0, color: border),
          itemBuilder: (_, i) {
            final ing    = _filtered[i];
            final ctrl   = _ctrlMap[ing.id]!;
            final actual = double.tryParse(ctrl.text.replaceAll(',', '.'));
            final diff   = actual != null ? actual - ing.stockQuantity : null;
            Color  diffColor = secondary; String diffStr = '';
            if (diff != null) {
              if (diff > 0.001)       { diffColor = const Color(0xFF10B981); diffStr = '+${_fmtQty(diff)} (Dư)'; }
              else if (diff < -0.001) { diffColor = const Color(0xFFF97316); diffStr = '${_fmtQty(diff)} (Thiếu)'; }
              else                    { diffColor = secondary; diffStr = 'Khớp ✓'; }
            }
            return Container(
              color: cardBg,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(ing.name,
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: onBg)),
                  Text('Tồn hiện tại: ${_fmtQty(ing.stockQuantity)} ${ing.unit}',
                      style: TextStyle(fontSize: 11, color: secondary)),
                  if (diffStr.isNotEmpty)
                    Text(diffStr,
                        style: TextStyle(fontSize: 11, color: diffColor, fontWeight: FontWeight.w600)),
                ])),
                const SizedBox(width: 12),
                SizedBox(width: 110,
                  child:
                  NumericField(
                    controller:  ctrl,
                    width:       110,
                    hint:        '0.00',
                    suffixText:  ing.unit,
                    decimal:     true,
                    focusColor:  _accent,
                    onChanged:   (_) => setState(() {}),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: onBg),
                    decoration: InputDecoration(
                      hintText:    '0.00',
                      hintStyle:   TextStyle(color: secondary, fontSize: 13),
                      suffixText:  ing.unit,
                      suffixStyle: const TextStyle(
                          color: _accent, fontSize: 12, fontWeight: FontWeight.w700),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: _accent, width: 1.5)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                    ),
                  ),
                ),
              ]),
            );
          },
        ),
      ),
      Container(
        decoration: BoxDecoration(
          color: cardBg, border: Border(top: BorderSide(color: border)),
          boxShadow: [BoxShadow(
              color: Colors.black.withOpacity(0.05), blurRadius: 8,
              offset: const Offset(0, -3))],
        ),
        padding: EdgeInsets.fromLTRB(16, 12, 16, _safeBottomPad + 90),
        child: ElevatedButton.icon(
          onPressed: _submitting ? null : _submit,
          icon: _submitting
              ? const SizedBox(width: 18, height: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.check_circle_outline, size: 18),
          label: Text(_submitting ? 'Đang tạo phiếu...' : 'Tạo phiếu kiểm kho'),
          style: ElevatedButton.styleFrom(
            backgroundColor: _accent, foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 50),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 0,
          ),
        ),
      ),
    ]);
  }

  Future<void> _submit() async {
    final items = <StockCheckItem>[];
    for (final ing in _all) {
      final ctrl = _ctrlMap[ing.id];
      if (ctrl == null || ctrl.text.trim().isEmpty) continue;
      final qty = double.tryParse(ctrl.text.trim().replaceAll(',', '.'));
      if (qty == null) continue;
      items.add(StockCheckItem(ingredientId: ing.id, actualQuantity: qty));
    }
    if (items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Vui lòng nhập số lượng thực tế ít nhất 1 nguyên liệu'),
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }
    setState(() => _submitting = true);
    try {
      final result = await InventoryBatchService.instance.checkBatch(
          StockCheckRequest(items: items));
      if (!mounted) return;
      if (result.isSuccess) {
        for (final c in _ctrlMap.values) c.clear();
        await _fetch();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('Kiểm kho thành công!'), backgroundColor: _accent,
          behavior: SnackBarBehavior.floating, margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(result.message ?? 'Lỗi kiểm kho'),
          backgroundColor: Colors.red.shade700, behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
        ));
      }
    } finally { if (mounted) setState(() => _submitting = false); }
  }
}

// ─── Shared UI ────────────────────────────────────────────────────────────────

class _ImageGallerySheet extends StatefulWidget {
  final List<String> urls;
  const _ImageGallerySheet({required this.urls});
  @override State<_ImageGallerySheet> createState() => _ImageGallerySheetState();
}

class _ImageGallerySheetState extends State<_ImageGallerySheet> {
  int _current = 0;
  final _ctrl  = PageController();

  @override void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final isDark    = Theme.of(context).brightness == Brightness.dark;
    final cardBg    = isDark ? AppColors.darkCard : Colors.white;
    final border    = isDark ? AppColors.darkBorder : const Color(0xFFE5E7EB);
    final secondary = isDark ? AppColors.darkTextSecondary : const Color(0xFF6B7280);

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: BoxDecoration(color: cardBg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20))),
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
          child: Column(children: [
            Center(child: Container(width: 36, height: 4,
                decoration: BoxDecoration(color: border, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 12),
            Row(children: [
              Text('Ảnh phiếu giao hàng',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              const Spacer(),
              Text('${_current + 1} / ${widget.urls.length}',
                  style: TextStyle(fontSize: 13, color: secondary)),
            ]),
          ]),
        ),
        Divider(height: 1, color: border),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Text('Nhấn vào ảnh để xem toàn màn hình',
              style: TextStyle(fontSize: 11, color: secondary.withOpacity(0.6)),
              textAlign: TextAlign.center),
        ),
        Expanded(
          child: PageView.builder(
            controller: _ctrl,
            itemCount: widget.urls.length,
            onPageChanged: (i) => setState(() => _current = i),
            itemBuilder: (_, i) => GestureDetector(
              onTap: () => Navigator.push(context, MaterialPageRoute(
                fullscreenDialog: true,
                builder: (_) => _FullScreenImageView(urls: widget.urls, initialIndex: i),
              )),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: ClipRRect(borderRadius: BorderRadius.circular(12),
                    child: NetworkImageViewer(imageUrl: widget.urls[i], fit: BoxFit.contain)),
              ),
            ),
          ),
        ),
        if (widget.urls.length > 1)
          Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(widget.urls.length, (i) =>
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: i == _current ? 18 : 6, height: 6,
                    decoration: BoxDecoration(
                      color: i == _current
                          ? const Color(0xFF0EA5E9) : secondary.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  )),
            ),
          ),
      ]),
    );
  }
}

class _FullScreenImageView extends StatefulWidget {
  final List<String> urls;
  final int initialIndex;
  const _FullScreenImageView({required this.urls, required this.initialIndex});
  @override State<_FullScreenImageView> createState() => _FullScreenImageViewState();
}

class _FullScreenImageViewState extends State<_FullScreenImageView> {
  late int _current;
  late PageController _ctrl;

  @override
  void initState() {
    super.initState();
    _current = widget.initialIndex;
    _ctrl = PageController(initialPage: widget.initialIndex);
  }

  @override void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(children: [
        PageView.builder(
          controller: _ctrl,
          itemCount: widget.urls.length,
          onPageChanged: (i) => setState(() => _current = i),
          itemBuilder: (_, i) => InteractiveViewer(
            minScale: 0.5, maxScale: 4.0,
            child: Center(child: NetworkImageViewer(
              imageUrl: widget.urls[i], fit: BoxFit.contain,
              errorWidget: const Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.broken_image_outlined, size: 64, color: Colors.white38),
                SizedBox(height: 12),
                Text('Không tải được ảnh', style: TextStyle(color: Colors.white54)),
              ]),
            )),
          ),
        ),
        Positioned(
          top: MediaQuery.of(context).padding.top + 8,
          left: 0, right: 0,
          child: Row(children: [
            const SizedBox(width: 8),
            IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.close_rounded, color: Colors.white, size: 26),
              style: IconButton.styleFrom(
                  backgroundColor: Colors.black.withOpacity(0.4), padding: const EdgeInsets.all(8)),
            ),
            const Spacer(),
            if (widget.urls.length > 1)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: Colors.black.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(20)),
                child: Text('${_current + 1} / ${widget.urls.length}',
                    style: const TextStyle(color: Colors.white, fontSize: 14,
                        fontWeight: FontWeight.w600)),
              ),
            const SizedBox(width: 16),
          ]),
        ),
        if (widget.urls.length > 1)
          Positioned(
            bottom: MediaQuery.of(context).padding.bottom + 20,
            left: 0, right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(widget.urls.length, (i) =>
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: i == _current ? 18 : 6, height: 6,
                    decoration: BoxDecoration(
                      color: i == _current ? Colors.white : Colors.white.withOpacity(0.4),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  )),
            ),
          ),
      ]),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String msg;
  final VoidCallback onRetry;
  const _ErrorView({required this.msg, required this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.error_outline, size: 48, color: AppColors.error),
      const SizedBox(height: 12),
      Text(msg, style: TextStyle(color: AppColors.error)),
      const SizedBox(height: 12),
      ElevatedButton(onPressed: onRetry, child: const Text('Thử lại')),
    ]),
  );
}