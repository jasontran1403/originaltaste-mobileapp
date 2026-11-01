import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:originaltaste/services/pos_service.dart';
import 'package:originaltaste/features/pos/components/pos_passcode_dialog.dart';
import 'package:originaltaste/data/models/pos/pos_product_model.dart';
import 'package:originaltaste/shared/widgets/app_input_decimal.dart';
import 'package:originaltaste/features/pos/widgets/pos_category_form_sheet.dart';
import 'package:originaltaste/features/pos/widgets/pos_ingredient_form_sheet.dart';
import 'package:originaltaste/features/pos/widgets/pos_product_form_sheet.dart';

import '../../../shared/widgets/network_image_viewer.dart';

// ═══════════════════════════════════════════════════════════════
// ROOT SCREEN
// ═══════════════════════════════════════════════════════════════

class PosMenuScreen extends StatefulWidget {
  const PosMenuScreen({super.key});

  @override
  State<PosMenuScreen> createState() => _PosMenuScreenState();
}

class _PosMenuScreenState extends State<PosMenuScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  bool _unlocked = false;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkPin());
  }

  Future<void> _checkPin() async {
    final ok = await showPosPasscodeDialog(context);
    if (!mounted) return;
    if (ok) {
      setState(() => _unlocked = true);
    } else {
      context.go('/pos');
    }
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark  = Theme.of(context).brightness == Brightness.dark;
    final cs      = Theme.of(context).colorScheme;
    final bg      = isDark ? const Color(0xFF0F172A) : const Color(0xFFF4F6FA);
    final surface = isDark ? const Color(0xFF1E293B) : Colors.white;
    final divider = isDark ? const Color(0xFF2D3F55) : const Color(0xFFEAECF0);

    if (!_unlocked) {
      return Scaffold(
        backgroundColor: bg,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: bg,
      body: Column(children: [
        // ── Header + pill tab bar ──────────────────────────────
        _Header(tabs: _tabs, surface: surface, divider: divider, isDark: isDark),

        // ── Tab content ────────────────────────────────────────
        Expanded(
          child: TabBarView(
            controller: _tabs,
            children: const [
              _ProductTab(),
              _IngredientTab(),
              _CategoryTab(),
            ],
          ),
        ),
      ]),
    );
  }
}

// ─── Shared design tokens ─────────────────────────────────────
Color _surface(bool isDark) =>
    isDark ? const Color(0xFF1E293B) : Colors.white;
Color _divider(bool isDark) =>
    isDark ? const Color(0xFF2D3F55) : const Color(0xFFEAECF0);
Color _txtPri(bool isDark) =>
    isDark ? Colors.white : const Color(0xFF111827);
Color _txtSec(bool isDark) =>
    isDark ? const Color(0xFF94A3B8) : const Color(0xFF6B7280);

// ─── Header ───────────────────────────────────────────────────
class _Header extends StatelessWidget {
  final TabController tabs;
  final Color surface, divider;
  final bool isDark;
  const _Header({required this.tabs, required this.surface,
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
            child: Text('Quản lý Menu', style: TextStyle(
              fontSize: 20, fontWeight: FontWeight.w800,
              letterSpacing: -0.3, color: _txtPri(isDark),
            )),
          ),
          // Pill tab bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Container(
              height: 38,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF0F2F5),
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
                unselectedLabelColor: _txtSec(isDark),
                labelStyle: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
                unselectedLabelStyle: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500),
                tabs: const [
                  Tab(child: _TabLabel(icon: Icons.fastfood_rounded,     label: 'Sản phẩm')),
                  Tab(child: _TabLabel(icon: Icons.blender_rounded,      label: 'Nguyên liệu')),
                  Tab(child: _TabLabel(icon: Icons.category_rounded,     label: 'Danh mục')),
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
      const SizedBox(width: 5),
      Text(label),
    ],
  );
}

// ═══════════════════════════════════════════════════════════════
// PRODUCT TAB
// ═══════════════════════════════════════════════════════════════

class _ProductTab extends StatefulWidget {
  const _ProductTab();
  @override
  State<_ProductTab> createState() => _ProductTabState();
}

class _ProductTabState extends State<_ProductTab> {
  List<PosCategoryModel> _cats = [];
  List<PosProductModel>  _products = [];
  PosCategoryModel? _selCat;
  bool   _loading = true;
  String _search  = '';

  @override
  void initState() { super.initState(); _loadCats(); }

  Future<void> _loadCats() async {
    try {
      final list = await PosService.instance.getCategories(includeDefault: true); // ← thêm
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
      final list = await PosService.instance.getProducts(categoryId: catId);
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
    final isDark  = Theme.of(context).brightness == Brightness.dark;
    final cs      = Theme.of(context).colorScheme;
    final bottom  = MediaQuery.of(context).padding.bottom;

    return Column(children: [
      // Search + chips
      Container(
        color: _surface(isDark),
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        child: Column(children: [
          _SearchBar(isDark: isDark,
              hint: 'Tìm sản phẩm...', onChanged: (v) => setState(() => _search = v)),
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
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                      decoration: BoxDecoration(
                        color: sel ? cs.primary : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: sel ? cs.primary : _divider(isDark)),
                      ),
                      child: Text(cat.name, style: TextStyle(
                        fontSize: 12,
                        fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                        color: sel ? Colors.white : _txtSec(isDark),
                      )),
                    ),
                  );
                },
              ),
            ),
          ],
        ]),
      ),
      Divider(height: 1, color: _divider(isDark)),
      _SectionBar(title: _selCat?.name ?? 'Sản phẩm',
          count: _filtered.length, onAdd: () => _showAddDialog(context),
          isDark: isDark),
      Expanded(
        child: _loading
            ? Center(child: CircularProgressIndicator(strokeWidth: 2, color: cs.primary))
            : _filtered.isEmpty
            ? _EmptyState(icon: Icons.fastfood_rounded,
            label: 'Không có sản phẩm', isDark: isDark)
            : RefreshIndicator(
          onRefresh: _loadCats, color: cs.primary,
          child: _search.isEmpty
              ? ReorderableListView.builder(
                  padding: EdgeInsets.fromLTRB(16, 8, 16, bottom + 20),
                  itemCount: _filtered.length,
                  onReorder: _onReorderProducts,
                  itemBuilder: (_, i) {
                    final p = _filtered[i];
                    return _ProductCard(key: ValueKey(p.id),
                        product: p, isDark: isDark,
                        onTap: () => _openDetail(p),
                        onDelete: () => _deleteProduct(p));
                  },
                )
              : ListView.builder(
                  padding: EdgeInsets.fromLTRB(16, 8, 16, bottom + 20),
                  itemCount: _filtered.length,
                  itemBuilder: (_, i) {
                    final p = _filtered[i];
                    return _ProductCard(key: ValueKey(p.id),
                        product: p, isDark: isDark,
                        onTap: () => _openDetail(p),
                        onDelete: () => _deleteProduct(p));
                  },
                ),
        ),
      ),
    ]);
  }

  void _onReorderProducts(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex--;
      final item = _products.removeAt(oldIndex);
      _products.insert(newIndex.clamp(0, _products.length), item);
    });
    _persistProductOrder();
  }

  Future<void> _persistProductOrder() async {
    final payload = [
      for (var i = 0; i < _products.length; i++)
        {'id': _products[i].id, 'displayOrder': i},
    ];
    if (payload.isEmpty) return;
    try {
      await PosService.instance.reorderProducts(payload);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi lưu thứ tự: $e')));
      if (_selCat != null) _loadProducts(_selCat!.id); // khôi phục từ server
    }
  }

  void _openDetail(PosProductModel p) async {
    List<Map<String, dynamic>> ings = [];
    try { ings = await PosService.instance.getIngredients(); } catch (_) {}
    if (!mounted) return;
    final saved = await PosProductFormSheet.show(
      context, product: p, categories: _cats, ingredients: ings,
    );
    if (saved) _loadCats();
  }

  void _showAddDialog(BuildContext ctx2) async {
    List<Map<String, dynamic>> ings = [];
    try { ings = await PosService.instance.getIngredients(); } catch (_) {}
    if (!mounted) return;
    final saved = await PosProductFormSheet.show(
      context, categories: _cats, ingredients: ings,
    );
    if (saved && _selCat != null) _loadProducts(_selCat!.id);
  }

  Future<void> _deleteProduct(PosProductModel p) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Xác nhận xóa'),
        content: Text('Xóa sản phẩm "${p.name}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Hủy')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true),
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Xóa')),
        ],
      ),
    );
    if (confirm == true) {
      try {
        await PosService.instance.deleteProduct(p.id);
        if (_selCat != null) _loadProducts(_selCat!.id);
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Lỗi: $e')));
      }
    }
  }
}

class _ProductCard extends StatelessWidget {
  final PosProductModel product;
  final bool isDark;
  final VoidCallback onTap;
  final VoidCallback? onDelete;
  const _ProductCard({super.key, required this.product,
    required this.isDark, required this.onTap, this.onDelete});

  String _fmt(double v) => v
      .toStringAsFixed(0)
      .replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    String? vUrl;
    if (product.imageUrl != null && product.imageUrl!.isNotEmpty) {
      vUrl = '${PosService.buildPosImageUrl(product.imageUrl)}?v=${product.imageUrl.hashCode}';
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: _surface(isDark),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap, borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _divider(isDark)),
            ),
            child: Row(children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: vUrl != null
                    ?
                NetworkImageViewer(
                  imageUrl: vUrl ?? '',  // Đảm bảo không null
                  width: 56,
                  height: 56,
                  fit: BoxFit.cover,
                  placeholder: _thumb(cs),  // Widget hiển thị khi đang load
                  errorWidget: _thumb(cs),  // Widget hiển thị khi lỗi
                )
                    : _thumb(cs),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(product.name, style: TextStyle(
                    fontWeight: FontWeight.w700, fontSize: 14,
                    color: _txtPri(isDark))),
                const SizedBox(height: 3),
                Text('${_fmt(product.basePrice)}đ', style: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w700, color: cs.primary)),
                if (product.variants.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text('${product.variants.length} nhóm biến thể',
                      style: TextStyle(fontSize: 11, color: _txtSec(isDark))),
                ],
              ])),
              Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF4F6FA),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.edit_outlined, size: 14, color: _txtSec(isDark)),
                ),
                if (onDelete != null) ...[
                  const SizedBox(height: 6),
                  GestureDetector(
                    onTap: onDelete,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.delete_outline_rounded,
                          size: 14, color: Colors.red),
                    ),
                  ),
                ],
                const SizedBox(height: 6),
                Icon(Icons.drag_handle_rounded, size: 18,
                    color: isDark ? const Color(0xFF3D5068) : const Color(0xFFD1D5DB)),
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
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(Icons.fastfood_rounded,
          color: cs.primary.withOpacity(0.3), size: 24));
}

// ═══════════════════════════════════════════════════════════════
// INGREDIENT TAB
// ═══════════════════════════════════════════════════════════════

class _IngredientTab extends StatefulWidget {
  const _IngredientTab();
  @override
  State<_IngredientTab> createState() => _IngredientTabState();
}

class _IngredientTabState extends State<_IngredientTab> {
  List<Map<String, dynamic>> _ingredients = [];
  bool   _loading = true;
  String _search  = '';

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final list = await PosService.instance.getIngredients();
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

  List<Map<String, dynamic>> get _main =>
      _filtered.where((i) => (i['type'] as String? ?? 'MAIN') == 'MAIN').toList();
  List<Map<String, dynamic>> get _sub =>
      _filtered.where((i) => (i['type'] as String? ?? 'MAIN') != 'MAIN').toList();

  String _fmtQty(double v) {
    if (v == v.truncateToDouble()) return v.toInt().toString();
    return v.toStringAsFixed(2)
        .replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
  }

  @override
  Widget build(BuildContext context) {
    final isDark  = Theme.of(context).brightness == Brightness.dark;
    final cs      = Theme.of(context).colorScheme;
    final bottom  = MediaQuery.of(context).padding.bottom;

    return Column(children: [
      Container(
        color: _surface(isDark),
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        child: _SearchBar(isDark: isDark,
            hint: 'Tìm nguyên liệu...', onChanged: (v) => setState(() => _search = v)),
      ),
      Divider(height: 1, color: _divider(isDark)),
      _SectionBar(title: 'Nguyên liệu', count: _filtered.length,
          onAdd: () => _showAddDialog(context), isDark: isDark),
      Expanded(
        child: _loading
            ? Center(child: CircularProgressIndicator(strokeWidth: 2, color: cs.primary))
            : _filtered.isEmpty
            ? _EmptyState(icon: Icons.blender_rounded,
            label: 'Không có nguyên liệu', isDark: isDark)
            : RefreshIndicator(
          onRefresh: _load, color: cs.primary,
          child: ListView(
            padding: EdgeInsets.fromLTRB(16, 8, 16, bottom + 20),
            children: _buildGroupedList(isDark),
          ),
        ),
      ),
    ]);
  }

  Future<void> _deleteIngredient(Map<String, dynamic> ing) async {
    final id = ing['id'] as int?;
    if (id == null) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Xác nhận xóa'),
        content: Text('Xóa nguyên liệu "${ing['name']}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Hủy')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true),
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Xóa')),
        ],
      ),
    );
    if (confirm == true) {
      try {
        await PosService.instance.deleteIngredient(id);
        _load();
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Lỗi: $e')));
      }
    }
  }

  // ── Kéo-thả đổi thứ tự ────────────────────────────────────────
  // Chỉ cho kéo-thả khi KHÔNG tìm kiếm (để index khớp danh sách đầy đủ).
  bool get _reorderEnabled => _search.isEmpty;

  String _typeOf(Map<String, dynamic> i) =>
      ((i['ingredientType'] as String? ?? 'MAIN') == 'SUB') ? 'SUB' : 'MAIN';

  void _reorder(String type, int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex--;
      final main = _ingredients.where((i) => _typeOf(i) == 'MAIN').toList();
      final sub  = _ingredients.where((i) => _typeOf(i) == 'SUB').toList();
      final group = (type == 'SUB') ? sub : main;
      if (oldIndex < 0 || oldIndex >= group.length) return;
      final moved = group.removeAt(oldIndex);
      group.insert(newIndex.clamp(0, group.length), moved);
      // Ghép lại [Chính..., Phụ...] và đánh số displayOrder tuần tự.
      _ingredients = [...main, ...sub];
      for (var k = 0; k < _ingredients.length; k++) {
        _ingredients[k]['displayOrder'] = k;
      }
    });
    _persistOrder();
  }

  Future<void> _persistOrder() async {
    final payload = [
      for (final i in _ingredients)
        if (i['id'] != null)
          {'id': i['id'], 'displayOrder': i['displayOrder']},
    ];
    if (payload.isEmpty) return;
    try {
      await PosService.instance.reorderIngredients(payload);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi lưu thứ tự: $e')));
      _load(); // khôi phục thứ tự đúng từ server nếu lưu lỗi
    }
  }

  List<Widget> _buildGroupedList(bool isDark) {
    final cs = Theme.of(context).colorScheme;

    Widget ingGroupContainer({
      required String label,
      required String type,
      required Color headerColor,
      required Color bgColor,
      required Color borderColor,
      required IconData icon,
      required List<Map<String, dynamic>> items,
    }) {
      return Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
            child: Row(children: [
              Icon(icon, size: 16, color: headerColor),
              const SizedBox(width: 6),
              Text('$label (${items.length})', style: TextStyle(
                  fontWeight: FontWeight.w700, fontSize: 14, color: headerColor)),
            ]),
          ),
          if (items.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: Text('Chưa có nguyên liệu',
                  style: TextStyle(fontSize: 12, color: headerColor.withOpacity(0.5),
                      fontStyle: FontStyle.italic)),
            )
          else
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
              child: _reorderEnabled
                  ? ReorderableListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      buildDefaultDragHandles: true,
                      itemCount: items.length,
                      onReorder: (o, n) => _reorder(type, o, n),
                      itemBuilder: (_, idx) {
                        final i = items[idx];
                        return _IngCard(
                          key: ValueKey('ing_${i['id'] ?? i.hashCode}'),
                          ing: i, isDark: isDark, fmtQty: _fmtQty,
                          onEdit: () => _openEdit(i),
                          onDelete: () => _deleteIngredient(i),
                        );
                      },
                    )
                  : Column(children: items.map((i) => _IngCard(
                      key: ValueKey('ing_${i['id'] ?? i.hashCode}'),
                      ing: i, isDark: isDark, fmtQty: _fmtQty,
                      onEdit: () => _openEdit(i),
                      onDelete: () => _deleteIngredient(i),
                    )).toList()),
            ),
        ]),
      );
    }

    final mainItems = _filtered.where((i) =>
    (i['ingredientType'] as String? ?? 'MAIN') == 'MAIN').toList();
    final subItems  = _filtered.where((i) =>
    (i['ingredientType'] as String? ?? 'MAIN') == 'SUB').toList();

    return [
      ingGroupContainer(
        label: 'Nguyên liệu Chính',
        type: 'MAIN',
        headerColor: const Color(0xFF1976D2),
        bgColor: isDark ? const Color(0xFF0F1F35) : const Color(0xFFE3F2FD),
        borderColor: isDark ? const Color(0xFF1A3A5C) : const Color(0xFF90CAF9),
        icon: Icons.star_outline_rounded,
        items: mainItems,
      ),
      ingGroupContainer(
        label: 'Nguyên liệu Phụ / Addon',
        type: 'SUB',
        headerColor: const Color(0xFFE65100),
        bgColor: isDark ? const Color(0xFF1F1200) : const Color(0xFFFFF3E0),
        borderColor: isDark ? const Color(0xFF3D2200) : const Color(0xFFFFCC80),
        icon: Icons.add_circle_outline_rounded,
        items: subItems,
      ),
    ];
  }

  void _showAddDialog(BuildContext ctx2) async {
    final saved = await PosIngredientFormSheet.show(context);
    if (saved) _load();
  }

  void _openEdit(Map<String, dynamic> ing) async {
    final saved = await PosIngredientFormSheet.show(context, ingredient: ing);
    if (saved) _load();
  }
}

class _IngCard extends StatelessWidget {
  final Map<String, dynamic> ing;
  final bool isDark;
  final String Function(double) fmtQty;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  const _IngCard({super.key, required this.ing,
    required this.isDark, required this.fmtQty,
    this.onEdit, this.onDelete});

  @override
  Widget build(BuildContext context) {
    final cs    = Theme.of(context).colorScheme;
    final stock    = (ing['currentStock'] as num? ?? 0).toDouble();
    final minStock = (ing['minStock'] as num? ?? 0).toDouble();
    final isLow    = stock < minStock;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _surface(isDark),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isLow ? cs.error.withOpacity(0.35) : _divider(isDark),
            width: isLow ? 1.5 : 1,
          ),
        ),
        child: Row(children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: isLow ? cs.error.withOpacity(0.1) : cs.primary.withOpacity(0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              isLow ? Icons.warning_amber_rounded : Icons.blender_rounded,
              size: 20, color: isLow ? cs.error : cs.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(ing['name'] as String? ?? '',
                  style: TextStyle(fontWeight: FontWeight.w700,
                      fontSize: 13.5, color: _txtPri(isDark)))),
              if (isLow) Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: cs.error.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text('Thấp', style: TextStyle(
                    fontSize: 10, color: cs.error, fontWeight: FontWeight.w700)),
              ),
            ]),
            const SizedBox(height: 3),
            Text('Tồn: ${fmtQty(stock)} ${ing['unit'] as String? ?? 'đơn vị'}',
                style: TextStyle(fontSize: 11,
                    color: isLow ? cs.error : _txtSec(isDark))),
            if (minStock > 0) ...[
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: (stock / minStock).clamp(0.0, 1.0),
                  minHeight: 3,
                  backgroundColor: cs.error.withOpacity(0.1),
                  valueColor: AlwaysStoppedAnimation(isLow ? cs.error : cs.primary),
                ),
              ),
            ],
          ])),
          const SizedBox(width: 8),
          Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            if (onEdit != null)
              GestureDetector(
                onTap: onEdit,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF4F6FA),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.edit_outlined, size: 14,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF6B7280)),
                ),
              ),

            // ← Bật lại nút xóa ở đây
            if (onDelete != null) ...[
              const SizedBox(height: 6),
              GestureDetector(
                onTap: onDelete,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.delete_outline_rounded,
                      size: 14, color: Colors.red),
                ),
              ),
            ],

            const SizedBox(height: 6),
            Icon(Icons.drag_handle_rounded, size: 18,
                color: isDark ? const Color(0xFF3D5068) : const Color(0xFFD1D5DB)),
          ]),
        ]),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// CATEGORY TAB
// ═══════════════════════════════════════════════════════════════

class _CategoryTab extends StatefulWidget {
  const _CategoryTab();
  @override
  State<_CategoryTab> createState() => _CategoryTabState();
}

class _CategoryTabState extends State<_CategoryTab> {
  List<PosCategoryModel> _cats = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final list = await PosService.instance.getCategories();
      if (mounted) setState(() { _cats = list; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark  = Theme.of(context).brightness == Brightness.dark;
    final cs      = Theme.of(context).colorScheme;
    final bottom  = MediaQuery.of(context).padding.bottom;

    return Column(children: [
      Divider(height: 1, color: _divider(isDark)),
      _SectionBar(title: 'Danh mục', count: _cats.length,
          onAdd: () => _showAddDialog(context), isDark: isDark),
      Expanded(
        child: _loading
            ? Center(child: CircularProgressIndicator(strokeWidth: 2, color: cs.primary))
            : _cats.isEmpty
            ? _EmptyState(icon: Icons.category_rounded,
            label: 'Không có danh mục', isDark: isDark)
            : RefreshIndicator(
          onRefresh: _load, color: cs.primary,
          child: ReorderableListView.builder(
            padding: EdgeInsets.fromLTRB(16, 8, 16, bottom + 20),
            itemCount: _cats.length,
            onReorder: (o, n) {
              setState(() {
                if (n > o) n--;
                final item = _cats.removeAt(o);
                _cats.insert(n.clamp(0, _cats.length), item);
              });
              _persistCategoryOrder();
            },
            itemBuilder: (_, i) {
              final cat = _cats[i];

              return _CatCard(key: ValueKey(cat.id),
                  cat: cat, isDark: isDark,
                  onEdit: () => _openEdit(cat),
                  onDelete: () => _deleteCategory(cat));
            },
          ),
        ),
      ),
    ]);
  }

  Future<void> _persistCategoryOrder() async {
    final payload = [
      for (var i = 0; i < _cats.length; i++)
        {'id': _cats[i].id, 'displayOrder': i},
    ];
    if (payload.isEmpty) return;
    try {
      await PosService.instance.reorderCategories(payload);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi lưu thứ tự: $e')));
      _load(); // khôi phục thứ tự từ server nếu lưu lỗi
    }
  }

  Future<void> _deleteCategory(PosCategoryModel cat) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Xác nhận xóa'),
        content: Text('Xóa danh mục "${cat.name}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Hủy')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true),
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Xóa')),
        ],
      ),
    );
    if (confirm == true) {
      try {
        await PosService.instance.deleteCategory(cat.id);
        _load();
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Lỗi: $e')));
      }
    }
  }

  void _showAddDialog(BuildContext ctx2) async {
    final saved = await PosCategoryFormSheet.show(context);
    if (saved) _load();
  }

  void _openEdit(PosCategoryModel cat) async {
    final saved = await PosCategoryFormSheet.show(context, category: cat);
    if (saved) _load();
  }
}

class _CatCard extends StatelessWidget {
  final PosCategoryModel cat;
  final bool isDark;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  const _CatCard({super.key, required this.cat,
    required this.isDark,
    this.onEdit, this.onDelete});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _surface(isDark),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _divider(isDark)),
        ),
        child: Row(children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: cat.imageUrl != null && cat.imageUrl!.isNotEmpty
                ? NetworkImageViewer(
              imageUrl:    cat.imageUrl,
              width:       48, height: 48,
              fit:         BoxFit.cover,
              forceRefresh: false,
              errorWidget: _thumb(cs),
            )
                : _thumb(cs),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(cat.name, style: TextStyle(
                fontWeight: FontWeight.w700, fontSize: 14, color: _txtPri(isDark))),
            if (cat.productCount > 0) ...[
              const SizedBox(height: 3),
              Text('${cat.productCount} sản phẩm',
                  style: TextStyle(fontSize: 11, color: _txtSec(isDark))),
            ],
          ])),
          Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            if (onEdit != null)
              GestureDetector(
                onTap: onEdit,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF4F6FA),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.edit_outlined, size: 14,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF6B7280)),
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
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.delete_outline_rounded, size: 14,
                      color: Colors.red),
                ),
              ),
            ],
            const SizedBox(height: 6),
            Icon(Icons.drag_handle_rounded, size: 18,
                color: isDark ? const Color(0xFF3D5068) : const Color(0xFFD1D5DB)),
          ]),
        ]),
      ),
    );
  }

  Widget _thumb(ColorScheme cs) => Container(
      width: 48, height: 48,
      decoration: BoxDecoration(
        color: cs.primary.withOpacity(0.07),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(Icons.category_rounded,
          color: cs.primary.withOpacity(0.3), size: 20));
}

// ═══════════════════════════════════════════════════════════════
// SHARED SMALL WIDGETS
// ═══════════════════════════════════════════════════════════════

class _SearchBar extends StatelessWidget {
  final bool isDark;
  final String hint;
  final ValueChanged<String> onChanged;
  const _SearchBar({required this.isDark, required this.hint,
    required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 38,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF4F6FA),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _divider(isDark)),
      ),
      child: TextField(
        style: TextStyle(fontSize: 13, color: _txtPri(isDark)),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(fontSize: 13, color: _txtSec(isDark)),
          prefixIcon: Icon(Icons.search_rounded, size: 17, color: _txtSec(isDark)),
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
  final bool isDark;
  const _SectionBar({required this.title, required this.count,
    required this.onAdd, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
      child: Row(children: [
        Text(title, style: TextStyle(fontSize: 14,
            fontWeight: FontWeight.w800, color: _txtPri(isDark))),
        const SizedBox(width: 7),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
          decoration: BoxDecoration(
            color: cs.primary.withOpacity(0.10),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text('$count', style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.w700, color: cs.primary)),
        ),
        const Spacer(),
        GestureDetector(
          onTap: onAdd,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
            decoration: BoxDecoration(
              color: cs.primary,
              borderRadius: BorderRadius.circular(9),
              boxShadow: [BoxShadow(
                color: cs.primary.withOpacity(0.25),
                blurRadius: 6, offset: const Offset(0, 2),
              )],
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: const [
              Icon(Icons.add_rounded, size: 15, color: Colors.white),
              SizedBox(width: 4),
              Text('Thêm', style: TextStyle(
                  fontSize: 12.5, fontWeight: FontWeight.w700, color: Colors.white)),
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
  final bool isDark;
  const _EmptyState({required this.icon, required this.label, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: cs.primary.withOpacity(0.07), shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 32, color: cs.primary.withOpacity(0.3)),
      ),
      const SizedBox(height: 12),
      Text(label, style: TextStyle(fontSize: 13,
          color: _txtSec(isDark), fontWeight: FontWeight.w500)),
    ]));
  }
}

class _StyledDialog extends StatelessWidget {
  final bool isDark;
  final String title;
  final Widget content;
  final VoidCallback onCancel, onConfirm;
  const _StyledDialog({required this.isDark, required this.title,
    required this.content, required this.onCancel, required this.onConfirm});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: _surface(isDark),
      title: Text(title, style: TextStyle(
          fontWeight: FontWeight.w800, color: _txtPri(isDark))),
      content: content,
      actions: [
        TextButton(onPressed: onCancel,
            child: Text('Hủy', style: TextStyle(color: _txtSec(isDark)))),
        FilledButton(onPressed: onConfirm, child: const Text('Thêm')),
      ],
    );
  }
}

class _DialogField extends StatelessWidget {
  final TextEditingController ctrl;
  final String label;
  final bool isDark;
  const _DialogField({required this.ctrl, required this.label, required this.isDark});

  @override
  Widget build(BuildContext context) => TextField(
    controller: ctrl, autofocus: true,
    style: TextStyle(color: _txtPri(isDark)),
    decoration: InputDecoration(
      labelText: label,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
    ),
  );
}

// ═══════════════════════════════════════════════════════════════
// PRODUCT DETAIL SHEET
// ═══════════════════════════════════════════════════════════════

class _ProductDetailSheet extends StatefulWidget {
  final PosProductModel product;
  final VoidCallback onSaved;
  const _ProductDetailSheet({required this.product, required this.onSaved});
  @override
  State<_ProductDetailSheet> createState() => _ProductDetailSheetState();
}

class _ProductDetailSheetState extends State<_ProductDetailSheet> {
  bool _saving = false;
  late final Map<int, Map<int, _IngData>> _ingData;

  @override
  void initState() {
    super.initState();
    _ingData = {};
    for (final v in widget.product.variants) {
      _ingData[v.id] = {};
      for (final ing in v.ingredients) {
        _ingData[v.id]![ing.ingredientId] = _IngData(
          qty: ing.maxSelectableCount ?? 1,
          stockDeductPerUnit: ing.stockDeductPerUnit,
        );
      }
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      for (final v in widget.product.variants) {
        final payload = v.ingredients.map((ing) {
          final d = _ingData[v.id]![ing.ingredientId]!;
          return {
            'ingredientId': ing.ingredientId,
            'quantity': d.qty,
            'stockDeductPerUnit': d.stockDeductPerUnit,
          };
        }).toList();
        await PosService.instance.updateVariant(v.id, {'ingredients': payload});
      }
      if (mounted) {
        Navigator.pop(context);
        widget.onSaved();
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Đã lưu thay đổi')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Lỗi: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final p      = widget.product;

    return Container(
      constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.9),
      decoration: BoxDecoration(
        color: _surface(isDark),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 16, 8),
          child: Column(children: [
            Center(child: Container(
              width: 36, height: 4,
              decoration: BoxDecoration(
                  color: _txtSec(isDark).withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2)),
            )),
            const SizedBox(height: 14),
            Row(children: [
              Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(p.name, style: TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w800, color: _txtPri(isDark))),
                Text('Chỉnh sửa nguyên liệu & định lượng',
                    style: TextStyle(fontSize: 12, color: _txtSec(isDark))),
              ])),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF4F6FA),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.close_rounded, size: 18, color: _txtSec(isDark)),
                ),
              ),
            ]),
          ]),
        ),
        Divider(height: 1, color: _divider(isDark)),
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              ...p.variants.map((v) => _VariantIngSection(
                variant: v,
                ingData: _ingData[v.id]!,
                onChanged: (ingId, data) =>
                    setState(() => _ingData[v.id]![ingId] = data),
              )),
              const SizedBox(height: 60),
            ]),
          ),
        ),
        Container(
          padding: EdgeInsets.fromLTRB(
              16, 10, 16, MediaQuery.of(context).padding.bottom + 16),
          decoration: BoxDecoration(
            color: _surface(isDark),
            border: Border(top: BorderSide(color: _divider(isDark))),
          ),
          child: SizedBox(
            width: double.infinity, height: 48,
            child: FilledButton.icon(
              icon: _saving
                  ? const SizedBox(width: 16, height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.save_outlined, size: 18),
              label: const Text('Lưu thay đổi',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
              onPressed: _saving ? null : _save,
              style: FilledButton.styleFrom(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12))),
            ),
          ),
        ),
      ]),
    );
  }
}

class _IngData {
  int qty;
  double stockDeductPerUnit;
  _IngData({required this.qty, required this.stockDeductPerUnit});
}

class _VariantIngSection extends StatelessWidget {
  final PosVariantModel variant;
  final Map<int, _IngData> ingData;
  final void Function(int, _IngData) onChanged;
  const _VariantIngSection({required this.variant,
    required this.ingData, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cs     = Theme.of(context).colorScheme;

    final mainIngs = variant.ingredients
        .where((i) => i.subGroupTag == null || i.subGroupTag!.isEmpty).toList();
    final subGroups = <String, List<PosVariantIngredientModel>>{};
    for (final ing in variant.ingredients
        .where((i) => i.subGroupTag != null && i.subGroupTag!.isNotEmpty)) {
      subGroups.putIfAbsent(ing.subGroupTag!, () => []).add(ing);
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: variant.isAddonGroup
              ? cs.primary.withOpacity(0.07)
              : (isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC)),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: variant.isAddonGroup
                ? cs.primary.withOpacity(0.25)
                : _divider(isDark),
          ),
        ),
        child: Row(children: [
          if (variant.isAddonGroup)
            Container(
              margin: const EdgeInsets.only(right: 7),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                  color: cs.primary.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(5)),
              child: Text('Addon', style: TextStyle(
                  fontSize: 10, fontWeight: FontWeight.w800, color: cs.primary)),
            ),
          Expanded(child: Text(variant.groupName, style: TextStyle(
              fontSize: 14, fontWeight: FontWeight.w700, color: _txtPri(isDark)))),
          Text('${variant.minSelect}–${variant.maxSelect} chọn',
              style: TextStyle(fontSize: 11, color: _txtSec(isDark))),
        ]),
      ),
      if (mainIngs.isNotEmpty) ...[
        _lbl('MAIN', cs),
        ...mainIngs.map((ing) => _IngRow(
          ing: ing, data: ingData[ing.ingredientId]!,
          onChanged: (d) => onChanged(ing.ingredientId, d),
        )),
      ],
      ...subGroups.entries.map((e) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _lbl(e.key, cs),
          ...e.value.map((ing) => _IngRow(
            ing: ing, data: ingData[ing.ingredientId]!,
            onChanged: (d) => onChanged(ing.ingredientId, d),
          )),
        ],
      )),
      const SizedBox(height: 16),
    ]);
  }

  Widget _lbl(String text, ColorScheme cs) => Padding(
    padding: const EdgeInsets.only(bottom: 6, top: 2),
    child: Row(children: [
      Container(width: 3, height: 13,
          decoration: BoxDecoration(color: cs.primary,
              borderRadius: BorderRadius.circular(2))),
      const SizedBox(width: 6),
      Text(text, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
          color: cs.onSurface.withOpacity(0.55), letterSpacing: 0.5)),
    ]),
  );
}

class _IngRow extends StatelessWidget {
  final PosVariantIngredientModel ing;
  final _IngData data;
  final void Function(_IngData) onChanged;
  const _IngRow({required this.ing, required this.data, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _divider(isDark)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(ing.ingredientName, style: TextStyle(
            fontWeight: FontWeight.w600, fontSize: 13, color: _txtPri(isDark))),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: AppInputDecimal(
            label: 'Số lượng', hint: '1', suffixText: 'lần',
            initialValue: data.qty.toDouble(), decimalPlaces: 0, min: 0,
            onChanged: (v) => onChanged(
                _IngData(qty: v.toInt(), stockDeductPerUnit: data.stockDeductPerUnit)),
          )),
          const SizedBox(width: 10),
          Expanded(child: AppInputDecimal(
            label: 'Định lượng', hint: '0.1', suffixText: 'kg',
            helperText: 'min 0.01 (1g)',
            initialValue: data.stockDeductPerUnit, decimalPlaces: 2, min: 0.01,
            onChanged: (v) => onChanged(
                _IngData(qty: data.qty, stockDeductPerUnit: v)),
          )),
        ]),
      ]),
    );
  }
}