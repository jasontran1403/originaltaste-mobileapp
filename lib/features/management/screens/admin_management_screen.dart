// lib/features/management/screens/admin_management_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/network/dio_client.dart';
import '../../../core/constants/api_constants.dart';
import '../../../services/admin_service.dart';
import '../../../services/pos_service.dart';
import '../../../data/models/pos/pos_product_model.dart';
import '../../../shared/widgets/network_image_viewer.dart';
import '../../pos/widgets/pos_category_form_sheet.dart';
import '../../pos/widgets/pos_ingredient_form_sheet.dart';
import '../../pos/widgets/pos_product_form_sheet.dart';

class AdminManagementScreen extends ConsumerStatefulWidget {
  const AdminManagementScreen({super.key});

  @override
  ConsumerState<AdminManagementScreen> createState() =>
      _AdminManagementScreenState();
}

class _AdminManagementScreenState extends ConsumerState<AdminManagementScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark  = Theme.of(context).brightness == Brightness.dark;
    final bg      = isDark ? const Color(0xFF0F172A) : const Color(0xFFF4F6FA);
    final surface = isDark ? const Color(0xFF1E293B) : Colors.white;
    final divider = isDark ? const Color(0xFF2D3F55) : const Color(0xFFEAECF0);

    return Scaffold(
      backgroundColor: bg,
      body: Column(children: [
        _AdminHeader(
            tabs: _tabs, surface: surface,
            divider: divider, isDark: isDark),
        Expanded(
          child: TabBarView(
            controller: _tabs,
            children: const [
              _StoreTab(),
              _EVoucherTab(),
              _AdminProductTab(),
              _AdminIngredientTab(),
              _AdminCategoryTab(),
            ],
          ),
        ),
      ]),
    );
  }
}

// ── Header ────────────────────────────────────────────────────────

class _AdminHeader extends StatelessWidget {
  final TabController tabs;
  final Color surface, divider;
  final bool isDark;
  const _AdminHeader({required this.tabs, required this.surface,
    required this.divider, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      color: surface,
      child: SafeArea(
        bottom: false,
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            child: Text('Quản lý Store', style: TextStyle(
              fontSize: 20, fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
              color: isDark ? Colors.white : const Color(0xFF111827),
            )),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Container(
              height: 38,
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF0F172A)
                    : const Color(0xFFF0F2F5),
                borderRadius: BorderRadius.circular(11),
              ),
              child: TabBar(
                controller: tabs,
                padding: const EdgeInsets.all(3),
                indicator: BoxDecoration(
                  color: cs.primary,
                  borderRadius: BorderRadius.circular(9),
                  boxShadow: [BoxShadow(
                    color: cs.primary.withOpacity(0.28),
                    blurRadius: 6, offset: const Offset(0, 2),
                  )],
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                dividerColor: Colors.transparent,
                labelColor: Colors.white,
                unselectedLabelColor: isDark
                    ? const Color(0xFF94A3B8)
                    : const Color(0xFF6B7280),
                labelStyle: const TextStyle(
                    fontSize: 11.5, fontWeight: FontWeight.w700),
                unselectedLabelStyle: const TextStyle(
                    fontSize: 11.5, fontWeight: FontWeight.w500),
                tabs: const [
                  Tab(child: _TabLabel(
                      icon: Icons.store_rounded, label: 'Store')),
                  Tab(child: _TabLabel(
                      icon: Icons.card_giftcard_rounded, label: 'EVoucher')),
                  Tab(child: _TabLabel(
                      icon: Icons.fastfood_rounded, label: 'Menu')),
                  Tab(child: _TabLabel(
                      icon: Icons.blender_rounded, label: 'Nguyên liệu')),
                  Tab(child: _TabLabel(
                      icon: Icons.category_rounded, label: 'Danh mục')),
                ],
              ),
            ),
          ),
          Divider(height: 1, color: divider),
        ]),
      ),
    );
  }
}

class _TabLabel extends StatelessWidget {
  final IconData icon;
  final String label;
  const _TabLabel({required this.icon, required this.label});
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 13),
      const SizedBox(width: 4),
      Text(label),
    ],
  );
}

// ════════════════════════════════════════════════════════════════
// STORE TAB
// ════════════════════════════════════════════════════════════════

class _StoreTab extends StatefulWidget {
  const _StoreTab();
  @override
  State<_StoreTab> createState() => _StoreTabState();
}

class _StoreTabState extends State<_StoreTab> {
  final _formKey     = GlobalKey<FormState>();
  final _nameCtrl    = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _phoneCtrl   = TextEditingController();
  final _printerCtrl = TextEditingController();
  final _shopeeCtrl  = TextEditingController();
  final _grabCtrl    = TextEditingController();
  final _referralRateCtrl = TextEditingController();
  List<Map<String, dynamic>> _typeRates = [];


  bool _isLoading = false;
  bool _isSaving  = false;

  @override
  void initState() { super.initState(); _load(); }

  @override
  void dispose() {
    _nameCtrl.dispose(); _addressCtrl.dispose(); _phoneCtrl.dispose();
    _printerCtrl.dispose(); _shopeeCtrl.dispose(); _grabCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      // Load store info + referralRate cùng 1 block
      final res = await DioClient.instance.get<Map<String, dynamic>>(
        '${ApiConstants.adminBase}/store/info',
        fromData: (d) => d as Map<String, dynamic>,
      );
      if (res.isSuccess && res.data != null && mounted) {
        final d = res.data!;
        setState(() {
          _nameCtrl.text        = d['name']      as String? ?? '';
          _addressCtrl.text     = d['address']   as String? ?? '';
          _phoneCtrl.text       = d['phone']     as String? ?? '';
          _printerCtrl.text     = d['printerIp'] as String? ?? '';
          _shopeeCtrl.text      = ((d['shopeeRate'] as num?)?.toDouble() ?? 0.0).toString();
          _grabCtrl.text        = ((d['grabRate']   as num?)?.toDouble() ?? 0.0).toString();
          _referralRateCtrl.text = ((d['referralRate'] as num?)?.toDouble() ?? 0.05).toString(); // ← đọc ở đây
        });
      }

      // Load type rates riêng
      final rateRes = await DioClient.instance.get<List<dynamic>>(
        '${ApiConstants.adminBase}/store/type-rates',
        fromData: (d) => d as List,
      );
      if (rateRes.isSuccess && rateRes.data != null && mounted) {
        setState(() {
          _typeRates = rateRes.data!
              .map((e) => e as Map<String, dynamic>).toList();
        });
      }
    } catch (e) {
      if (mounted) _snack('Lỗi tải thông tin: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    try {
      await DioClient.instance.put(
        '${ApiConstants.adminBase}/store/info',
        body: {
          'name':       _nameCtrl.text.trim(),
          'address':    _addressCtrl.text.trim(),
          'phone':      _phoneCtrl.text.trim(),
          'printerIp':  _printerCtrl.text.trim(),
          'shopeeRate': double.tryParse(_shopeeCtrl.text) ?? 0.0,
          'grabRate':   double.tryParse(_grabCtrl.text)   ?? 0.0,
          'referralRate': double.tryParse(_referralRateCtrl.text) ?? 0.05
      },
      );
      if (mounted) _snack('Đã lưu thông tin store!');
    } catch (e) {
      if (mounted) _snack('Lỗi lưu: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _snack(String msg, {bool isError = false}) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(msg),
        backgroundColor: isError
            ? Theme.of(context).colorScheme.error : null,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10)),
      ));

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cs     = Theme.of(context).colorScheme;
    final teal   = const Color(0xFF0D9488);
    final bg     = isDark
        ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final border = isDark
        ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

    if (_isLoading) return const Center(child: CircularProgressIndicator());

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Form(
        key: _formKey,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

          // ── Header ──────────────────────────────────────────
          Row(children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: teal.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.store_rounded, color: teal, size: 22),
            ),
            const SizedBox(width: 12),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Thông tin Store', style: TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w800,
                  color: cs.onSurface)),
              Text('Chỉnh sửa thông tin cửa hàng', style: TextStyle(
                  fontSize: 12,
                  color: cs.onSurface.withOpacity(0.5))),
            ]),
          ]),
          const SizedBox(height: 24),

          // ── Thông tin cơ bản ─────────────────────────────────
          _sectionLabel('Thông tin cơ bản', cs),
          const SizedBox(height: 12),
          _field(_nameCtrl, 'Tên cửa hàng *', Icons.storefront_rounded,
              isDark: isDark, cs: cs, teal: teal, bg: bg, border: border,
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'Vui lòng nhập tên' : null),
          const SizedBox(height: 12),
          _field(_addressCtrl, 'Địa chỉ', Icons.location_on_rounded,
              isDark: isDark, cs: cs, teal: teal, bg: bg, border: border,
              maxLines: 2),
          const SizedBox(height: 12),
          _field(_phoneCtrl, 'Số điện thoại', Icons.phone_rounded,
              isDark: isDark, cs: cs, teal: teal, bg: bg, border: border,
              keyboard: TextInputType.phone),
          const SizedBox(height: 24),

          // ── Máy in ───────────────────────────────────────────
          _sectionLabel('Máy in ESC/POS', cs),
          const SizedBox(height: 12),
          _field(_printerCtrl, 'IP máy in', Icons.print_rounded,
              hint: '192.168.1.100',
              isDark: isDark, cs: cs, teal: teal, bg: bg, border: border,
              keyboard: TextInputType.number),
          const SizedBox(height: 24),

          // ── Phí sàn ──────────────────────────────────────────
          _sectionLabel('Phí sàn giao hàng', cs),
          const SizedBox(height: 4),
          Text('Dạng thập phân. VD: 0.3305 = 33.05%',
              style: TextStyle(fontSize: 11,
                  color: cs.onSurface.withOpacity(0.45))),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: _field(
              _shopeeCtrl, 'Phí Shopee Food',
              Icons.shopping_bag_rounded,
              hint: '0.3305', iconColor: const Color(0xFFEE4D2D),
              isDark: isDark, cs: cs, teal: teal, bg: bg, border: border,
              keyboard: const TextInputType.numberWithOptions(decimal: true),
            )),
            const SizedBox(width: 12),
            Expanded(child: _field(
              _grabCtrl, 'Phí Grab Food',
              Icons.delivery_dining_rounded,
              hint: '0.25', iconColor: const Color(0xFF00B14F),
              isDark: isDark, cs: cs, teal: teal, bg: bg, border: border,
              keyboard: const TextInputType.numberWithOptions(decimal: true),
            )),
          ]),

          _sectionLabel('Tỷ lệ chia người giới thiệu', cs),
          const SizedBox(height: 4),
          Text('VD: 0.05 = 5% chi tiêu của người được giới thiệu',
              style: TextStyle(fontSize: 11,
                  color: cs.onSurface.withOpacity(0.45))),
          const SizedBox(height: 12),
          _field(_referralRateCtrl, 'Tỷ lệ referral',
              Icons.people_alt_rounded,
              hint: '0.05',
              isDark: isDark, cs: cs, teal: teal, bg: bg, border: border,
              keyboard: const TextInputType.numberWithOptions(decimal: true)),
          const SizedBox(height: 24),

          _sectionLabel('Tỷ lệ tích lũy theo loại khách', cs),
          const SizedBox(height: 12),
          _TypeRateSection(
            typeRates: _typeRates,
            isDark: isDark, cs: cs, teal: teal, bg: bg, border: border,
            onRefresh: _load,
          ),

          const SizedBox(height: 32),

          // ── Save ─────────────────────────────────────────────
          SizedBox(
            width: double.infinity, height: 50,
            child: FilledButton.icon(
              onPressed: _isSaving ? null : _save,
              icon: _isSaving
                  ? const SizedBox(width: 18, height: 18,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.save_rounded, size: 18),
              label: Text(_isSaving ? 'Đang lưu...' : 'Lưu thay đổi',
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w700)),
              style: FilledButton.styleFrom(
                backgroundColor: teal,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          const SizedBox(height: 90),
        ]),
      ),
    );
  }

  Widget _sectionLabel(String text, ColorScheme cs) => Row(children: [
    Container(width: 3, height: 14,
        decoration: BoxDecoration(color: const Color(0xFF0D9488),
            borderRadius: BorderRadius.circular(2))),
    const SizedBox(width: 7),
    Text(text, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
        color: cs.onSurface.withOpacity(0.6), letterSpacing: 0.3)),
  ]);

  Widget _field(
      TextEditingController ctrl,
      String label,
      IconData icon, {
        String? hint,
        Color? iconColor,
        int maxLines = 1,
        TextInputType keyboard = TextInputType.text,
        String? Function(String?)? validator,
        required bool isDark,
        required ColorScheme cs,
        required Color teal,
        required Color bg,
        required Color border,
      }) =>
      TextFormField(
        controller: ctrl,
        keyboardType: keyboard,
        maxLines: maxLines,
        validator: validator,
        style: TextStyle(fontSize: 14,
            color: isDark ? Colors.white : const Color(0xFF0F172A)),
        decoration: InputDecoration(
          labelText: label, hintText: hint,
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

// ════════════════════════════════════════════════════════════════
// PRODUCT TAB (copy từ PosMenuScreen, bỏ passcode)
// ════════════════════════════════════════════════════════════════

class _AdminProductTab extends StatefulWidget {
  const _AdminProductTab();
  @override
  State<_AdminProductTab> createState() => _AdminProductTabState();
}

class _AdminProductTabState extends State<_AdminProductTab> {
  List<PosCategoryModel> _cats     = [];
  List<PosProductModel>  _products = [];
  PosCategoryModel?      _selCat;
  bool   _loading = true;
  String _search  = '';

  Color get _surface => Theme.of(context).brightness == Brightness.dark
      ? const Color(0xFF1E293B) : Colors.white;
  Color get _divider => Theme.of(context).brightness == Brightness.dark
      ? const Color(0xFF2D3F55) : const Color(0xFFEAECF0);
  bool get _isDark =>
      Theme.of(context).brightness == Brightness.dark;

  @override
  void initState() { super.initState(); _loadCats(); }

  Future<void> _loadCats() async {
    try {
      final list = await AdminService.instance.getCategories(includeDefault: true);
      if (mounted && list.isNotEmpty) {
        setState(() { _cats = list; _selCat = list.first; });
        await _loadProducts(list.first.id);
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadProducts(int catId) async {
    setState(() => _loading = true);
    try {
      final list = await AdminService.instance.getProducts(categoryId: catId);
      if (mounted) setState(() => _products = list);
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<PosProductModel> get _filtered => _search.isEmpty
      ? _products
      : _products.where((p) =>
      p.name.toLowerCase().contains(_search.toLowerCase())).toList();

  @override
  Widget build(BuildContext context) {
    final cs     = Theme.of(context).colorScheme;
    final bottom = MediaQuery.of(context).padding.bottom;

    return Column(children: [
      Container(
        color: _surface,
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        child: Column(children: [
          _SearchBar(hint: 'Tìm sản phẩm...',
              onChanged: (v) => setState(() => _search = v)),
          if (_cats.isNotEmpty) ...[
            const SizedBox(height: 8),
            SizedBox(
              height: 30,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _cats.length,
                separatorBuilder: (_, __) => const SizedBox(width: 6),
                itemBuilder: (_, i) {
                  final cat = _cats[i];
                  final sel = _selCat?.id == cat.id;
                  return GestureDetector(
                    onTap: () {
                      setState(() => _selCat = cat);
                      _loadProducts(cat.id);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 5),
                      decoration: BoxDecoration(
                        color: sel ? cs.primary : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: sel ? cs.primary : _divider),
                      ),
                      child: Text(cat.name, style: TextStyle(
                        fontSize: 12,
                        fontWeight: sel
                            ? FontWeight.w700 : FontWeight.w500,
                        color: sel ? Colors.white
                            : (Theme.of(context).brightness == Brightness.dark
                            ? const Color(0xFF94A3B8)
                            : const Color(0xFF6B7280)),
                      )),
                    ),
                  );
                },
              ),
            ),
          ],
        ]),
      ),
      Divider(height: 1, color: _divider),
      _SectionBar(
        title: _selCat?.name ?? 'Sản phẩm',
        count: _filtered.length,
        onAdd: () => _showAdd(),
      ),
      Expanded(
        child: _loading
            ? Center(child: CircularProgressIndicator(
            strokeWidth: 2, color: cs.primary))
            : _filtered.isEmpty
            ? _EmptyState(
            icon: Icons.fastfood_rounded,
            label: 'Không có sản phẩm')
            : RefreshIndicator(
          onRefresh: _loadCats, color: cs.primary,
          child: ListView.builder(
            padding: EdgeInsets.fromLTRB(16, 8, 16, bottom + 20),
            itemCount: _filtered.length,
            itemBuilder: (_, i) {
              final p = _filtered[i];
              return _ProductCard(
                key: ValueKey(p.id),
                product: p,
                onTap: () => _openDetail(p),
                onDelete: () => _delete(p),
              );
            },
          ),
        ),
      ),
    ]);
  }

  void _showAdd() async {
    List<Map<String, dynamic>> ings = [];
    try { ings = await AdminService.instance.getIngredients(); } catch (_) {}
    if (!mounted) return;
    final saved = await PosProductFormSheet.show(
        context, categories: _cats, ingredients: ings, useAdminApi: true);
    if (saved && _selCat != null) _loadProducts(_selCat!.id);
  }

  void _openDetail(PosProductModel p) async {
    List<Map<String, dynamic>> ings = [];
    try { ings = await AdminService.instance.getIngredients(); } catch (_) {}
    if (!mounted) return;
    final saved = await PosProductFormSheet.show(
        context, product: p, categories: _cats, ingredients: ings, useAdminApi: true);
    if (saved) _loadCats();
  }

  Future<void> _delete(PosProductModel p) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: const Text('Xác nhận xóa'),
        content: Text('Xóa sản phẩm "${p.name}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Hủy')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: FilledButton.styleFrom(
                  backgroundColor: Colors.red),
              child: const Text('Xóa')),
        ],
      ),
    );
    if (ok == true) {
      try {
        await AdminService.instance.deleteProduct(p.id);
        if (_selCat != null) _loadProducts(_selCat!.id);
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Lỗi: $e')));
      }
    }
  }
}

// ════════════════════════════════════════════════════════════════
// INGREDIENT TAB
// ════════════════════════════════════════════════════════════════

class _AdminIngredientTab extends StatefulWidget {
  const _AdminIngredientTab();
  @override
  State<_AdminIngredientTab> createState() => _AdminIngredientTabState();
}

class _AdminIngredientTabState extends State<_AdminIngredientTab> {
  List<Map<String, dynamic>> _ingredients = [];
  bool   _loading = true;
  String _search  = '';

  bool get _isDark =>
      Theme.of(context).brightness == Brightness.dark;
  Color get _divider => _isDark
      ? const Color(0xFF2D3F55) : const Color(0xFFEAECF0);

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final list = await AdminService.instance.getIngredients();
      if (mounted) setState(() { _ingredients = list; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Map<String, dynamic>> get _filtered => _search.isEmpty
      ? _ingredients
      : _ingredients.where((i) =>
      (i['name'] as String).toLowerCase()
          .contains(_search.toLowerCase())).toList();

  @override
  Widget build(BuildContext context) {
    final cs     = Theme.of(context).colorScheme;
    final bottom = MediaQuery.of(context).padding.bottom;

    return Column(children: [
      Container(
        color: _isDark ? const Color(0xFF1E293B) : Colors.white,
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        child: _SearchBar(hint: 'Tìm nguyên liệu...',
            onChanged: (v) => setState(() => _search = v)),
      ),
      Divider(height: 1, color: _divider),
      _SectionBar(
          title: 'Nguyên liệu',
          count: _filtered.length,
          onAdd: () => _showAdd()),
      Expanded(
        child: _loading
            ? Center(child: CircularProgressIndicator(
            strokeWidth: 2, color: cs.primary))
            : _filtered.isEmpty
            ? _EmptyState(
            icon: Icons.blender_rounded,
            label: 'Không có nguyên liệu')
            : RefreshIndicator(
          onRefresh: _load, color: cs.primary,
          child: ListView(
            padding: EdgeInsets.fromLTRB(16, 8, 16, bottom + 20),
            children: _buildList(),
          ),
        ),
      ),
    ]);
  }

  List<Widget> _buildList() {
    final mainItems = _filtered.where((i) =>
    (i['ingredientType'] as String? ?? 'MAIN') == 'MAIN').toList();
    final subItems = _filtered.where((i) =>
    (i['ingredientType'] as String? ?? 'MAIN') == 'SUB').toList();

    Widget group({
      required String label,
      required Color headerColor,
      required Color bgColor,
      required Color borderColor,
      required IconData icon,
      required List<Map<String, dynamic>> items,
    }) =>
        Container(
          margin: const EdgeInsets.only(bottom: 14),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: borderColor),
          ),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
                  child: Row(children: [
                    Icon(icon, size: 16, color: headerColor),
                    const SizedBox(width: 6),
                    Text('$label (${items.length})',
                        style: TextStyle(fontWeight: FontWeight.w700,
                            fontSize: 14, color: headerColor)),
                  ]),
                ),
                if (items.isEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                    child: Text('Chưa có nguyên liệu',
                        style: TextStyle(fontSize: 12,
                            color: headerColor.withOpacity(0.5),
                            fontStyle: FontStyle.italic)),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
                    child: Column(
                      children: items.map((i) => _IngCard(
                        key: ValueKey('ing_${i['id']}'),
                        ing: i,
                        onEdit: () => _openEdit(i),
                        onDelete: () => _delete(i),
                      )).toList(),
                    ),
                  ),
              ]),
        );

    return [
      group(
        label: 'Nguyên liệu Chính',
        headerColor: const Color(0xFF1976D2),
        bgColor: _isDark
            ? const Color(0xFF0F1F35) : const Color(0xFFE3F2FD),
        borderColor: _isDark
            ? const Color(0xFF1A3A5C) : const Color(0xFF90CAF9),
        icon: Icons.star_outline_rounded,
        items: mainItems,
      ),
      group(
        label: 'Nguyên liệu Phụ / Addon',
        headerColor: const Color(0xFFE65100),
        bgColor: _isDark
            ? const Color(0xFF1F1200) : const Color(0xFFFFF3E0),
        borderColor: _isDark
            ? const Color(0xFF3D2200) : const Color(0xFFFFCC80),
        icon: Icons.add_circle_outline_rounded,
        items: subItems,
      ),
    ];
  }

  void _showAdd() async {
    final saved = await PosIngredientFormSheet.show(context, useAdminApi: true);
    if (saved) _load();
  }

  void _openEdit(Map<String, dynamic> ing) async {
    final saved = await PosIngredientFormSheet.show(
        context, ingredient: ing, useAdminApi: true);
    if (saved) _load();
  }

  Future<void> _delete(Map<String, dynamic> ing) async {
    final id = ing['id'] as int?;
    if (id == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: const Text('Xác nhận xóa'),
        content: Text('Xóa nguyên liệu "${ing['name']}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Hủy')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: FilledButton.styleFrom(
                  backgroundColor: Colors.red),
              child: const Text('Xóa')),
        ],
      ),
    );
    if (ok == true) {
      try {
        await AdminService.instance.deleteIngredient(id);
        _load();
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Lỗi: $e')));
      }
    }
  }
}

// ════════════════════════════════════════════════════════════════
// CATEGORY TAB
// ════════════════════════════════════════════════════════════════

class _AdminCategoryTab extends StatefulWidget {
  const _AdminCategoryTab();
  @override
  State<_AdminCategoryTab> createState() => _AdminCategoryTabState();
}

class _AdminCategoryTabState extends State<_AdminCategoryTab> {
  List<PosCategoryModel> _cats    = [];
  bool                   _loading = true;

  bool get _isDark =>
      Theme.of(context).brightness == Brightness.dark;
  Color get _divider => _isDark
      ? const Color(0xFF2D3F55) : const Color(0xFFEAECF0);

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final list = await AdminService.instance.getCategories();
      if (mounted) setState(() { _cats = list; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs     = Theme.of(context).colorScheme;
    final bottom = MediaQuery.of(context).padding.bottom;

    return Column(children: [
      Divider(height: 1, color: _divider),
      _SectionBar(
          title: 'Danh mục',
          count: _cats.length,
          onAdd: () => _showAdd()),
      Expanded(
        child: _loading
            ? Center(child: CircularProgressIndicator(
            strokeWidth: 2, color: cs.primary))
            : _cats.isEmpty
            ? _EmptyState(
            icon: Icons.category_rounded,
            label: 'Không có danh mục')
            : RefreshIndicator(
          onRefresh: _load, color: cs.primary,
          child: ReorderableListView.builder(
            padding: EdgeInsets.fromLTRB(
                16, 8, 16, bottom + 20),
            itemCount: _cats.length,
            onReorder: (o, n) {
              setState(() {
                if (n > o) n--;
                final item = _cats.removeAt(o);
                _cats.insert(n, item);
              });
            },
            itemBuilder: (_, i) {
              final cat = _cats[i];
              return _CatCard(
                key: ValueKey(cat.id),
                cat: cat,
                onEdit: () => _openEdit(cat),
                onDelete: () => _delete(cat),
              );
            },
          ),
        ),
      ),
    ]);
  }

  void _showAdd() async {
    final saved = await PosCategoryFormSheet.show(context, useAdminApi: true);
    if (saved) _load();
  }

  void _openEdit(PosCategoryModel cat) async {
    final saved =
    await PosCategoryFormSheet.show(context, category: cat, useAdminApi: true);
    if (saved) _load();
  }

  Future<void> _delete(PosCategoryModel cat) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: const Text('Xác nhận xóa'),
        content: Text('Xóa danh mục "${cat.name}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Hủy')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: FilledButton.styleFrom(
                  backgroundColor: Colors.red),
              child: const Text('Xóa')),
        ],
      ),
    );
    if (ok == true) {
      try {
        await AdminService.instance.deleteCategory(cat.id);
        _load();
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Lỗi: $e')));
      }
    }
  }
}

// ════════════════════════════════════════════════════════════════
// SHARED SMALL WIDGETS (private, dùng trong file này)
// ════════════════════════════════════════════════════════════════

class _SearchBar extends StatelessWidget {
  final String hint;
  final ValueChanged<String> onChanged;
  const _SearchBar({required this.hint, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      height: 38,
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF0F172A) : const Color(0xFFF4F6FA),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isDark
            ? const Color(0xFF2D3F55) : const Color(0xFFEAECF0)),
      ),
      child: TextField(
        style: TextStyle(fontSize: 13,
            color: isDark ? Colors.white : const Color(0xFF111827)),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(fontSize: 13,
              color: isDark
                  ? const Color(0xFF94A3B8)
                  : const Color(0xFF6B7280)),
          prefixIcon: Icon(Icons.search_rounded, size: 17,
              color: isDark
                  ? const Color(0xFF94A3B8)
                  : const Color(0xFF6B7280)),
          border: InputBorder.none, isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
        ),
        onChanged: onChanged,
      ),
    );
  }
}

class _SectionBar extends StatelessWidget {
  final String title;
  final int count;
  final VoidCallback onAdd;
  const _SectionBar({
    required this.title, required this.count, required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    final cs     = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
      child: Row(children: [
        Text(title, style: TextStyle(fontSize: 14,
            fontWeight: FontWeight.w800,
            color: isDark ? Colors.white : const Color(0xFF111827))),
        const SizedBox(width: 7),
        Container(
          padding: const EdgeInsets.symmetric(
              horizontal: 7, vertical: 2),
          decoration: BoxDecoration(
            color: cs.primary.withOpacity(0.10),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text('$count', style: TextStyle(fontSize: 11,
              fontWeight: FontWeight.w700, color: cs.primary)),
        ),
        const Spacer(),
        GestureDetector(
          onTap: onAdd,
          child: Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 13, vertical: 7),
            decoration: BoxDecoration(
              color: cs.primary,
              borderRadius: BorderRadius.circular(9),
              boxShadow: [BoxShadow(
                color: cs.primary.withOpacity(0.25),
                blurRadius: 6, offset: const Offset(0, 2),
              )],
            ),
            child: const Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.add_rounded, size: 15, color: Colors.white),
              SizedBox(width: 4),
              Text('Thêm', style: TextStyle(fontSize: 12.5,
                  fontWeight: FontWeight.w700, color: Colors.white)),
            ]),
          ),
        ),
      ]),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String label;
  const _EmptyState({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
            color: cs.primary.withOpacity(0.07),
            shape: BoxShape.circle),
        child: Icon(icon, size: 32,
            color: cs.primary.withOpacity(0.3)),
      ),
      const SizedBox(height: 12),
      Text(label, style: TextStyle(fontSize: 13,
          color: Theme.of(context).brightness == Brightness.dark
              ? const Color(0xFF94A3B8) : const Color(0xFF6B7280),
          fontWeight: FontWeight.w500)),
    ]));
  }
}

class _ProductCard extends StatelessWidget {
  final PosProductModel product;
  final VoidCallback onTap;
  final VoidCallback? onDelete;
  const _ProductCard({super.key, required this.product,
    required this.onTap, this.onDelete});

  String _fmt(double v) => v.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');

  @override
  Widget build(BuildContext context) {
    final cs     = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surf   = isDark ? const Color(0xFF1E293B) : Colors.white;
    final div    = isDark
        ? const Color(0xFF2D3F55) : const Color(0xFFEAECF0);
    final txtSec = isDark
        ? const Color(0xFF94A3B8) : const Color(0xFF6B7280);

    String? vUrl;
    if (product.imageUrl != null && product.imageUrl!.isNotEmpty) {
      vUrl =
      '${PosService.buildPosImageUrl(product.imageUrl)}?v=${product.imageUrl.hashCode}';
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: surf,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: div),
            ),
            child: Row(children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: vUrl != null
                    ? NetworkImageViewer(
                    imageUrl: vUrl,
                    width: 56, height: 56,
                    fit: BoxFit.cover,
                    errorWidget: _thumb(cs))
                    : _thumb(cs),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(product.name, style: TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 14,
                        color: isDark ? Colors.white
                            : const Color(0xFF111827))),
                    const SizedBox(height: 3),
                    Text('${_fmt(product.basePrice)}đ',
                        style: TextStyle(fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: cs.primary)),
                    if (product.variants.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text('${product.variants.length} nhóm biến thể',
                          style: TextStyle(
                              fontSize: 11, color: txtSec)),
                    ],
                  ])),
              Column(mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _iconBtn(Icons.edit_outlined,
                        isDark ? const Color(0xFF0F172A)
                            : const Color(0xFFF4F6FA),
                        txtSec, onTap),
                    if (onDelete != null) ...[
                      const SizedBox(height: 6),
                      _iconBtn(Icons.delete_outline_rounded,
                          Colors.red.withOpacity(0.08),
                          Colors.red, onDelete!),
                    ],
                  ]),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _thumb(ColorScheme cs) => Container(
      width: 56, height: 56,
      decoration: BoxDecoration(
          color: cs.primary.withOpacity(0.07),
          borderRadius: BorderRadius.circular(10)),
      child: Icon(Icons.fastfood_rounded,
          color: cs.primary.withOpacity(0.3), size: 24));

  Widget _iconBtn(IconData icon, Color bg, Color fg, VoidCallback onTap) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
              color: bg, borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, size: 14, color: fg),
        ),
      );
}

class _IngCard extends StatelessWidget {
  final Map<String, dynamic> ing;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  const _IngCard({super.key, required this.ing,
    this.onEdit, this.onDelete});

  @override
  Widget build(BuildContext context) {
    final cs     = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surf   = isDark ? const Color(0xFF1E293B) : Colors.white;
    final div    = isDark
        ? const Color(0xFF2D3F55) : const Color(0xFFEAECF0);
    final txtSec = isDark
        ? const Color(0xFF94A3B8) : const Color(0xFF6B7280);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: surf,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: div),
        ),
        child: Row(children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
                color: cs.primary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10)),
            child: Icon(Icons.blender_rounded,
                size: 20, color: cs.primary),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(ing['name'] as String? ?? '',
                    style: TextStyle(fontWeight: FontWeight.w700,
                        fontSize: 13.5,
                        color: isDark ? Colors.white
                            : const Color(0xFF111827))),
                const SizedBox(height: 3),
                Text('${ing['unit'] ?? 'đơn vị'} • '
                    '${ing['unitPerPack'] ?? 1} cái/bịch',
                    style: TextStyle(
                        fontSize: 11, color: txtSec)),
              ])),
          Column(mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (onEdit != null)
                  GestureDetector(
                    onTap: onEdit,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF0F172A)
                              : const Color(0xFFF4F6FA),
                          borderRadius: BorderRadius.circular(8)),
                      child: Icon(Icons.edit_outlined,
                          size: 14, color: txtSec),
                    ),
                  ),
                if (onDelete != null) ...[
                  const SizedBox(height: 6),
                  GestureDetector(
                    onTap: onDelete,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(8)),
                      child: const Icon(
                          Icons.delete_outline_rounded,
                          size: 14, color: Colors.red),
                    ),
                  ),
                ],
              ]),
        ]),
      ),
    );
  }
}

class _CatCard extends StatelessWidget {
  final PosCategoryModel cat;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  const _CatCard({super.key, required this.cat,
    this.onEdit, this.onDelete});

  @override
  Widget build(BuildContext context) {
    final cs     = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surf   = isDark ? const Color(0xFF1E293B) : Colors.white;
    final div    = isDark
        ? const Color(0xFF2D3F55) : const Color(0xFFEAECF0);
    final txtSec = isDark
        ? const Color(0xFF94A3B8) : const Color(0xFF6B7280);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: surf,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: div),
        ),
        child: Row(children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: cat.imageUrl != null && cat.imageUrl!.isNotEmpty
                ? NetworkImageViewer(
                imageUrl: cat.imageUrl,
                width: 48, height: 48,
                fit: BoxFit.cover,
                errorWidget: _thumb(cs))
                : _thumb(cs),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(cat.name, style: TextStyle(
                    fontWeight: FontWeight.w700, fontSize: 14,
                    color: isDark ? Colors.white
                        : const Color(0xFF111827))),
                if (cat.productCount > 0) ...[
                  const SizedBox(height: 3),
                  Text('${cat.productCount} sản phẩm',
                      style: TextStyle(
                          fontSize: 11, color: txtSec)),
                ],
              ])),
          Column(mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (onEdit != null)
                  GestureDetector(
                    onTap: onEdit,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF0F172A)
                              : const Color(0xFFF4F6FA),
                          borderRadius: BorderRadius.circular(8)),
                      child: Icon(Icons.edit_outlined,
                          size: 14, color: txtSec),
                    ),
                  ),
                if (onDelete != null) ...[
                  const SizedBox(height: 6),
                  GestureDetector(
                    onTap: onDelete,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(8)),
                      child: const Icon(
                          Icons.delete_outline_rounded,
                          size: 14, color: Colors.red),
                    ),
                  ),
                ],
              ]),
        ]),
      ),
    );
  }

  Widget _thumb(ColorScheme cs) => Container(
      width: 48, height: 48,
      decoration: BoxDecoration(
          color: cs.primary.withOpacity(0.07),
          borderRadius: BorderRadius.circular(10)),
      child: Icon(Icons.category_rounded,
          color: cs.primary.withOpacity(0.3), size: 20));
}

class _TypeRateSection extends StatelessWidget {
  final List<Map<String, dynamic>> typeRates;
  final bool isDark;
  final ColorScheme cs;
  final Color teal, bg, border;
  final VoidCallback onRefresh;

  const _TypeRateSection({
    required this.typeRates, required this.isDark,
    required this.cs, required this.teal,
    required this.bg, required this.border,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      ...typeRates.map((r) => _TypeRateCard(
        rate: r, isDark: isDark, cs: cs, teal: teal, bg: bg, border: border,
        onRefresh: onRefresh,
      )),
      const SizedBox(height: 8),
      OutlinedButton.icon(
        onPressed: () => _showForm(context, null),
        icon: const Icon(Icons.add_rounded, size: 16),
        label: const Text('Thêm loại khách mới'),
        style: OutlinedButton.styleFrom(
          foregroundColor: teal,
          side: BorderSide(color: teal.withOpacity(0.5)),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10)),
        ),
      ),
    ]);
  }

  void _showForm(BuildContext context, Map<String, dynamic>? existing) {
    final typeCodeCtrl  = TextEditingController(
        text: existing?['typeCode'] as String? ?? '');
    final typeLabelCtrl = TextEditingController(
        text: existing?['typeLabel'] as String? ?? '');
    final accumRateCtrl = TextEditingController(
        text: existing?['accumRate']?.toString() ?? '0.05');
    final id = existing?['id'] as int?;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 90),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20)),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Center(child: Container(width: 36, height: 4,
                decoration: BoxDecoration(
                    color: cs.onSurface.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 16),
            Text(id == null ? 'Thêm loại khách' : 'Sửa loại khách',
                style: TextStyle(fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: cs.onSurface)),
            const SizedBox(height: 16),
            if (id == null) ...[
              TextField(
                controller: typeCodeCtrl,
                decoration: InputDecoration(
                  labelText: 'Mã loại (VD: VIP)',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 10),
            ],
            TextField(
              controller: typeLabelCtrl,
              decoration: InputDecoration(
                labelText: 'Tên hiển thị',
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: accumRateCtrl,
              keyboardType: const TextInputType.numberWithOptions(
                  decimal: true),
              decoration: InputDecoration(
                labelText: 'Tỷ lệ tích lũy (VD: 0.05 = 5%)',
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity, height: 46,
              child: FilledButton(
                onPressed: () async {
                  final body = {
                    'typeCode':  typeCodeCtrl.text.trim().toUpperCase(),
                    'typeLabel': typeLabelCtrl.text.trim(),
                    'accumRate': double.tryParse(
                        accumRateCtrl.text) ?? 0.05,
                  };
                  if (id == null) {
                    await DioClient.instance.post(
                        '${ApiConstants.adminBase}/store/type-rates',
                        body: body);
                  } else {
                    await DioClient.instance.put(
                        '${ApiConstants.adminBase}/store/type-rates/$id',
                        body: body);
                  }
                  if (ctx.mounted) Navigator.pop(ctx);
                  onRefresh();
                },
                style: FilledButton.styleFrom(
                  backgroundColor: teal,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Lưu',
                    style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

class _TypeRateCard extends StatelessWidget {
  final Map<String, dynamic> rate;
  final bool isDark;
  final ColorScheme cs;
  final Color teal, bg, border;
  final VoidCallback onRefresh;

  const _TypeRateCard({
    required this.rate, required this.isDark, required this.cs,
    required this.teal, required this.bg, required this.border,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final pct = ((rate['accumRate'] as num).toDouble() * 100)
        .toStringAsFixed(1);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: border),
      ),
      child: Row(children: [
        Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(rate['typeLabel'] as String,
              style: TextStyle(fontWeight: FontWeight.w700,
                  fontSize: 13, color: cs.onSurface)),
          Text('${rate['typeCode']} · Tích lũy $pct%',
              style: TextStyle(fontSize: 11,
                  color: cs.onSurface.withOpacity(0.5))),
        ])),
        IconButton(
          icon: Icon(Icons.edit_rounded, size: 16,
              color: cs.onSurface.withOpacity(0.5)),
          onPressed: () => _TypeRateSection(
            typeRates: const [], isDark: isDark, cs: cs,
            teal: teal, bg: bg, border: border,
            onRefresh: onRefresh,
          )._showForm(context, rate),
        ),
        IconButton(
          icon: const Icon(Icons.delete_outline_rounded,
              size: 16, color: Colors.red),
          onPressed: () async {
            final id = rate['id'] as int;
            await DioClient.instance.delete(
                '${ApiConstants.adminBase}/store/type-rates/$id');
            onRefresh();
          },
        ),
      ]),
    );
  }
}

class _EVoucherTab extends StatefulWidget {
  const _EVoucherTab();
  @override
  State<_EVoucherTab> createState() => _EVoucherTabState();
}

class _EVoucherTabState extends State<_EVoucherTab> {
  List<Map<String, dynamic>> _templates = [];
  bool _loading = true;

  bool get _isDark => Theme.of(context).brightness == Brightness.dark;
  Color get _divider => _isDark
      ? const Color(0xFF2D3F55) : const Color(0xFFEAECF0);
  Color get _teal => const Color(0xFF0D9488);

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await DioClient.instance.get<List<dynamic>>(
        '${ApiConstants.adminBase}/store/voucher-templates',
        fromData: (d) => d as List,
      );
      if (mounted && res.isSuccess && res.data != null) {
        setState(() => _templates = res.data!
            .map((e) => e as Map<String, dynamic>).toList());
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showForm([Map<String, dynamic>? existing]) {
    final isDark   = _isDark;
    final cs       = Theme.of(context).colorScheme;
    final nameCtrl = TextEditingController(
        text: existing?['name'] as String? ?? '');
    final amtCtrl  = TextEditingController(
        text: existing?['discountAmount']?.toString() ?? '');
    final costCtrl = TextEditingController(
        text: existing?['creditCost']?.toString() ?? '');
    final id = existing?['id'] as int?;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 90),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20)),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Center(child: Container(width: 36, height: 4,
                decoration: BoxDecoration(
                    color: cs.onSurface.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 16),
            Text(id == null ? 'Thêm E-Voucher' : 'Sửa E-Voucher',
                style: TextStyle(fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: cs.onSurface)),
            const SizedBox(height: 16),
            TextField(
              controller: nameCtrl,
              decoration: InputDecoration(
                labelText: 'Tên voucher (VD: Giảm 50,000đ)',
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: amtCtrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Số tiền giảm (đ)',
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: costCtrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Số điểm credit cần để đổi',
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity, height: 46,
              child: FilledButton(
                onPressed: () async {
                  final body = {
                    'name':           nameCtrl.text.trim(),
                    'discountAmount': double.tryParse(amtCtrl.text)  ?? 0,
                    'creditCost':     double.tryParse(costCtrl.text) ?? 0,
                  };
                  if (id == null) {
                    await DioClient.instance.post(
                        '${ApiConstants.adminBase}/store/voucher-templates',
                        body: body);
                  } else {
                    await DioClient.instance.put(
                        '${ApiConstants.adminBase}/store/voucher-templates/$id',
                        body: body);
                  }
                  if (ctx.mounted) Navigator.pop(ctx);
                  _load();
                },
                style: FilledButton.styleFrom(
                  backgroundColor: _teal,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Lưu',
                    style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  String _fmt(double v) => v.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');

  @override
  Widget build(BuildContext context) {
    final cs     = Theme.of(context).colorScheme;
    final bottom = MediaQuery.of(context).padding.bottom;

    return Column(children: [
      Divider(height: 1, color: _divider),
      _SectionBar(
        title: 'E-Voucher Templates',
        count: _templates.length,
        onAdd: () => _showForm(),
      ),
      Expanded(
        child: _loading
            ? Center(child: CircularProgressIndicator(
            strokeWidth: 2, color: cs.primary))
            : _templates.isEmpty
            ? const _EmptyState(
            icon: Icons.card_giftcard_rounded,
            label: 'Chưa có E-Voucher')
            : RefreshIndicator(
          onRefresh: _load, color: cs.primary,
          child: ListView.builder(
            padding: EdgeInsets.fromLTRB(
                16, 8, 16, bottom + 20),
            itemCount: _templates.length,
            itemBuilder: (_, i) {
              final t = _templates[i];
              final amt  = (t['discountAmount'] as num).toDouble();
              final cost = (t['creditCost']     as num).toDouble();
              final isDark = _isDark;
              final cs2 = Theme.of(context).colorScheme;

              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _divider),
                ),
                child: Row(children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF59E0B).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.card_giftcard_rounded,
                        color: Color(0xFFF59E0B), size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(t['name'] as String,
                            style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                                color: cs2.onSurface)),
                        const SizedBox(height: 3),
                        Text('Giảm ${_fmt(amt)}đ  ·  '
                            'Cần ${_fmt(cost)} điểm',
                            style: TextStyle(fontSize: 12,
                                color: cs2.onSurface.withOpacity(0.55))),
                      ])),
                  IconButton(
                    icon: Icon(Icons.edit_rounded, size: 16,
                        color: cs2.onSurface.withOpacity(0.5)),
                    onPressed: () => _showForm(t),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded,
                        size: 16, color: Colors.red),
                    onPressed: () async {
                      final id = t['id'] as int;
                      await DioClient.instance.delete(
                          '${ApiConstants.adminBase}/store/voucher-templates/$id');
                      _load();
                    },
                  ),
                ]),
              );
            },
          ),
        ),
      ),
    ]);
  }
}