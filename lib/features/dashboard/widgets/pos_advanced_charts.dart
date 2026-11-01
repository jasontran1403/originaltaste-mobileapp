// lib/features/dashboard/widgets/pos_advanced_charts.dart

import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../data/models/dashboard/dashboard_period.dart';
import '../../../data/models/dashboard/pos_chart_models.dart';
import '../../../features/dashboard/controller/dashboard_controller.dart';

// ── Color Stops cho 3 heatmap ────────────────────────────────
const _orderColorStops = [
  Color(0xFFF1F5F9),
  Color(0xFFCFE8F8), Color(0xFFB3D8F4), Color(0xFF96C6EE),
  Color(0xFF78B3E8), Color(0xFF5A9FE0), Color(0xFF3D8BD8),
  Color(0xFF2475C8), Color(0xFF1260B0), Color(0xFF064D96),
];

const _productColorStops = [
  Color(0xFFF1F5F9),
  Color(0xFFD1FAE5), Color(0xFFA7F3D0), Color(0xFF6EE7B7),
  Color(0xFF34D399), Color(0xFF10B981), Color(0xFF059669),
  Color(0xFF047857), Color(0xFF065F46), Color(0xFF064E3B),
];

const _ingredientColorStops = [
  Color(0xFFF1F5F9),
  Color(0xFFEDE9FE), Color(0xFFDDD6FE), Color(0xFFC4B5FD),
  Color(0xFFA78BFA), Color(0xFF8B5CF6), Color(0xFF7C3AED),
  Color(0xFF6D28D9), Color(0xFF5B21B6), Color(0xFF4C1D95),
];

class PosAdvancedCharts extends ConsumerStatefulWidget {    // ← đổi thành StatefulWidget
  const PosAdvancedCharts({super.key});

  @override
  ConsumerState<PosAdvancedCharts> createState() => _PosAdvancedChartsState();
}

class _PosAdvancedChartsState extends ConsumerState<PosAdvancedCharts> {
  String _heatmapMode = 'order';  // order | product | ingredient

  @override
  Widget build(BuildContext context) {
    final ctrl = ref.watch(dashboardControllerProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final notifier = ref.read(dashboardControllerProvider.notifier);

    // ── Config theo mode ──────────────────────────────────────
    final heatmapConfig = switch (_heatmapMode) {
      'product' => (
      title:      'Heatmap sản phẩm',
      countLabel: 'sản phẩm',
      colorStops: _productColorStops,
      cells:      ctrl.productHeatmap,
      products:   ctrl.heatmapProducts,
      selectedIds: ctrl.selectedProductHeatmapIds,
      onPeriod:   (int p) => notifier.loadProductHeatmap(periodMinutes: p),
      onFilter:   (Set<int> ids) => notifier.applyProductHeatmapFilter(ids),
      ),
      'ingredient' => (
      title:      'Heatmap nguyên liệu chính',
      countLabel: 'NL chính',
      colorStops: _ingredientColorStops,
      cells:      ctrl.ingredientHeatmap,
      products:   ctrl.heatmapIngredients,
      selectedIds: ctrl.selectedIngredientIds,
      onPeriod:   (int p) => notifier.loadIngredientHeatmap(periodMinutes: p),
      onFilter:   (Set<int> ids) => notifier.applyIngredientHeatmapFilter(ids),
      ),
      _ => (
      title:      'Heatmap đơn hàng',
      countLabel: 'đơn',
      colorStops: _orderColorStops,
      cells:      ctrl.heatmap,
      products:   ctrl.heatmapProducts,
      selectedIds: ctrl.selectedProductIds,
      onPeriod:   (int p) => notifier.loadHeatmap(periodMinutes: p),
      onFilter:   (Set<int> ids) => notifier.applyHeatmapProductFilter(ids),
      ),
    };

    return Column(children: [
      _CategoryFilterBar(
        categories: ctrl.categories,
        selectedCategories: ctrl.selectedCategories,
        isDark: isDark,
        onToggle: (name) => notifier.toggleCategory(name),
      ),
      const SizedBox(height: 12),
      _Chart1(
        data: ctrl.shiftData,
        loading: ctrl.advancedChartsLoading,
        isDark: isDark,
      ),
      const SizedBox(height: 12),
      _Chart2(
        data: ctrl.stackedData,
        loading: ctrl.advancedChartsLoading,
        isDark: isDark,
      ),
      const SizedBox(height: 12),

      // ── Heatmap duy nhất + dropdown chọn mode ──────────────
      _HeatmapChart(
        title:                  heatmapConfig.title,
        countLabel:             heatmapConfig.countLabel,
        colorStops:             heatmapConfig.colorStops,
        cells:                  heatmapConfig.cells,
        loading:                ctrl.advancedChartsLoading,
        isDark:                 isDark,
        products:               heatmapConfig.products,
        selectedProductIds:     heatmapConfig.selectedIds,
        onPeriodChanged:        heatmapConfig.onPeriod,
        onProductFilterChanged: heatmapConfig.onFilter,
        // ← THÊM: dropdown chọn loại heatmap
        heatmapMode:            _heatmapMode,
        onHeatmapModeChanged:   (mode) => setState(() => _heatmapMode = mode),
      ),
    ]);
  }
}
// ══════════════════════════════════════════════════════════════════
// CATEGORY FILTER BAR
// ══════════════════════════════════════════════════════════════════
class _CategoryFilterBar extends StatefulWidget {
  final List<CategoryItem> categories;
  final Set<String> selectedCategories;
  final bool isDark;
  final void Function(String) onToggle;

  const _CategoryFilterBar({
    required this.categories,
    required this.selectedCategories,
    required this.isDark,
    required this.onToggle,
  });

  @override
  State<_CategoryFilterBar> createState() => _CategoryFilterBarState();
}

class _CategoryFilterBarState extends State<_CategoryFilterBar> {
  @override
  Widget build(BuildContext context) {
    final isNarrow = MediaQuery.of(context).size.width < 600;
    final cs     = Theme.of(context).colorScheme;
    final border = widget.isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color:        widget.isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border:       Border.all(color: border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text('Lọc theo Danh mục',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: cs.onSurface.withOpacity(0.7))),
          const Spacer(),
          if (widget.selectedCategories.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: cs.primary,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text('${widget.selectedCategories.length}',
                  style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Colors.white)),
            ),
        ]),
        const SizedBox(height: 10),
        if (widget.categories.isEmpty)
          Text('Chưa có danh mục',
              style: TextStyle(
                  fontSize: 12, color: cs.onSurface.withOpacity(0.4)))
        else if (isNarrow)
          _buildDropdownButton(context, cs)
        else
          _buildWrap(cs),
      ]),
    );
  }

  Widget _buildDropdownButton(BuildContext context, ColorScheme cs) {
    final selectedCategories = widget.selectedCategories;
    final label = selectedCategories.isEmpty
        ? 'Tất cả danh mục'
        : selectedCategories.length == 1
        ? selectedCategories.first
        : '${selectedCategories.length} danh mục';

    return GestureDetector(
      onTap: () => _showCategoryPicker(context, cs),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: selectedCategories.isNotEmpty
              ? cs.primary.withOpacity(0.08)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selectedCategories.isNotEmpty
                ? cs.primary
                : cs.primary.withOpacity(0.35),
            width: 1.5,
          ),
        ),
        child: Row(children: [
          Icon(Icons.category_outlined,
              size: 15,
              color: selectedCategories.isNotEmpty
                  ? cs.primary
                  : cs.onSurface.withOpacity(0.5)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(label,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: selectedCategories.isNotEmpty
                        ? cs.primary
                        : cs.onSurface.withOpacity(0.6))),
          ),
          Icon(Icons.arrow_drop_down_rounded,
              color: cs.primary.withOpacity(0.7)),
        ]),
      ),
    );
  }

  void _showCategoryPicker(BuildContext context, ColorScheme cs) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CategoryPickerSheet(
        categories:          widget.categories,
        selectedCategories:  widget.selectedCategories,
        isDark:              widget.isDark,
        onToggle: (name) {
          widget.onToggle(name);
          setState(() {});
        },
      ),
    );
  }

  Widget _buildWrap(ColorScheme cs) {
    return Wrap(
        spacing: 8,
        runSpacing: 8,
        children: widget.categories.map((cat) {
          final isSel = widget.selectedCategories.contains(cat.name);
          return GestureDetector(
            onTap: () {
              widget.onToggle(cat.name);
              setState(() {});
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: isSel ? cs.primary : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color:
                  isSel ? cs.primary : cs.primary.withOpacity(0.4),
                  width: 1.5,
                ),
              ),
              child: Text(cat.name,
                  style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: isSel ? Colors.white : cs.primary)),
            ),
          );
        }).toList());
  }
}

// ── Sheet tìm kiếm & chọn danh mục ───────────────────────────────

class _CategoryPickerSheet extends StatefulWidget {
  final List<CategoryItem>  categories;
  final Set<String>         selectedCategories;
  final bool                isDark;
  final void Function(String) onToggle;

  const _CategoryPickerSheet({
    required this.categories,
    required this.selectedCategories,
    required this.isDark,
    required this.onToggle,
  });

  @override
  State<_CategoryPickerSheet> createState() => _CategoryPickerSheetState();
}

class _CategoryPickerSheetState extends State<_CategoryPickerSheet> {
  final _searchCtrl = TextEditingController();
  String _query = '';
  late final Set<String> _localSelected;

  @override
  void initState() {
    super.initState();
    _localSelected = Set<String>.from(widget.selectedCategories);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<CategoryItem> get _filtered {
    if (_query.isEmpty) return widget.categories;
    return widget.categories
        .where((c) =>
        c.name.toLowerCase().contains(_query.toLowerCase()))
        .toList();
  }

  void _toggle(String name) {
    setState(() {
      if (_localSelected.contains(name)) {
        _localSelected.remove(name);
      } else {
        _localSelected.add(name);
      }
    });
    widget.onToggle(name);
  }

  @override
  Widget build(BuildContext context) {
    final cs         = Theme.of(context).colorScheme;
    final bgColor    = widget.isDark ? const Color(0xFF1E293B) : Colors.white;
    final border     = widget.isDark
        ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final maxH       = MediaQuery.of(context).size.height * 0.75;

    return Container(
      constraints: BoxConstraints(maxHeight: maxH),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 36, height: 4,
          margin: const EdgeInsets.only(top: 12, bottom: 4),
          decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.3),
              borderRadius: BorderRadius.circular(2)),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Row(children: [
            Text('Chọn danh mục',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: cs.onSurface)),
            const Spacer(),
            if (_localSelected.isNotEmpty)
              GestureDetector(
                onTap: () {
                  final names = List<String>.from(_localSelected);
                  setState(() => _localSelected.clear());
                  for (final name in names) {
                    widget.onToggle(name);
                  }
                },
                child: Text('Bỏ chọn tất cả',
                    style: TextStyle(
                        fontSize: 12,
                        color: cs.error,
                        fontWeight: FontWeight.w600)),
              ),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TextField(
            controller: _searchCtrl,
            onChanged: (v) => setState(() => _query = v),
            decoration: InputDecoration(
              hintText:    'Tìm danh mục...',
              prefixIcon:  const Icon(Icons.search_rounded, size: 18),
              isDense:     true,
              filled:      true,
              fillColor:   cs.surfaceContainerHighest.withOpacity(0.5),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
              contentPadding:
              const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Flexible(
          child: _filtered.isEmpty
              ? Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 90),
            child: Text('Không tìm thấy danh mục',
                style: TextStyle(
                    color: cs.onSurface.withOpacity(0.4))),
          )
              : ListView.builder(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 90),
            itemCount: _filtered.length,
            itemBuilder: (_, i) {
              final cat   = _filtered[i];
              final isSel = _localSelected.contains(cat.name);
              return GestureDetector(
                onTap: () => _toggle(cat.name),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: isSel
                        ? cs.primary.withOpacity(0.1)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isSel ? cs.primary : border,
                      width: isSel ? 1.5 : 1,
                    ),
                  ),
                  child: Row(children: [
                    Expanded(
                      child: Text(cat.name,
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: isSel
                                  ? cs.primary
                                  : cs.onSurface)),
                    ),
                    if (isSel)
                      Icon(Icons.check_circle_rounded,
                          color: cs.primary, size: 20)
                    else
                      Icon(Icons.radio_button_unchecked_rounded,
                          color: cs.onSurface.withOpacity(0.3),
                          size: 20),
                  ]),
                ),
              );
            },
          ),
        ),
      ]),
    );
  }
}


// ══════════════════════════════════════════════════════════════════
// CHART 1 — Dual Line: Revenue (solid) + OrderCount (dashed)
// ══════════════════════════════════════════════════════════════════

class _Chart1 extends StatefulWidget {
  final List<PeriodShiftPoint> data;
  final bool loading;
  final bool isDark;

  const _Chart1(
      {required this.data, required this.loading, required this.isDark});

  @override
  State<_Chart1> createState() => _Chart1State();
}

class _Chart1State extends State<_Chart1> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;
  int? _selectedIdx;
  int _selShift = 0;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800));
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);
    _ctrl.forward();
  }

  @override
  void didUpdateWidget(_Chart1 old) {
    super.didUpdateWidget(old);
    if (old.data != widget.data) _ctrl.forward(from: 0);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  List<_PeriodAgg> get _aggregated {
    final Map<String, _PeriodAgg> map = {};
    for (final p in widget.data) {
      if (_selShift != 0 && p.shift != _selShift) continue;
      if (_selShift == 0 && p.shift == 0) continue;

      if (!map.containsKey(p.periodLabel)) {
        map[p.periodLabel] = _PeriodAgg(
          label: p.periodLabel, fromTs: p.periodFromTs, toTs: p.periodToTs,
          revenue: p.revenue, orderCount: p.orderCount,
        );
      } else {
        final prev = map[p.periodLabel]!;
        map[p.periodLabel] = _PeriodAgg(
          label: prev.label, fromTs: prev.fromTs, toTs: prev.toTs,
          revenue: prev.revenue + p.revenue,
          orderCount: prev.orderCount + p.orderCount,
        );
      }
    }
    return map.values.toList()..sort((a, b) => a.fromTs.compareTo(b.fromTs));
  }

  int? _calculateIndexFromPosition({
    required Offset? position,
    required double width,
    required int dataLength,
  }) {
    if (position == null || dataLength <= 1) return null;
    const padL = 65.0;
    const padR = 55.0;
    final w = width - padL - padR;
    final x = position.dx;
    if (x < padL || x > padL + w) return null;
    final idx = ((x - padL) / (w / (dataLength - 1))).round().clamp(0, dataLength - 1);
    return idx;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final border = widget.isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final fmt = NumberFormat('#,###', 'vi_VN');
    final agg = _aggregated;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: widget.isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Doanh thu & Đơn hàng',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: cs.onSurface)),
            const SizedBox(height: 4),
            const Row(children: [
              _LegendDot(color: Color(0xFF2563EB), label: 'Doanh thu'),
              SizedBox(width: 12),
              _LegendDot(
                  color: Color(0xFF0891B2),
                  label: 'Số đơn (--)',
                  dashed: true),
            ]),
          ]),
          const Spacer(),
          _ShiftFilter(
            selected: _selShift,
            onSelect: (s) => setState(() {
              _selShift = s;
              _selectedIdx = null;
              _ctrl.forward(from: 0);
            }),
            isDark: widget.isDark,
          ),
        ]),
        const SizedBox(height: 12),
        if (widget.loading)
          const SizedBox(
              height: 280,
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)))
        else if (agg.isEmpty)
          const SizedBox(
              height: 200, child: Center(child: Text('Không có dữ liệu')))
        else
          AnimatedBuilder(
            animation: _anim,
            builder: (_, __) => LayoutBuilder(
              builder: (ctx, cst) {
                return GestureDetector(
                  onTapDown: (details) {
                    final idx = _calculateIndexFromPosition(
                      position: details.localPosition,
                      width: cst.maxWidth,
                      dataLength: agg.length,
                    );
                    setState(() {
                      _selectedIdx = _selectedIdx == idx ? null : idx;
                    });
                  },
                  onTap: () {
                    if (_selectedIdx != null) {
                      final idx = _calculateIndexFromPosition(
                        position: null,
                        width: cst.maxWidth,
                        dataLength: agg.length,
                      );
                      if (idx == null) setState(() => _selectedIdx = null);
                    }
                  },
                  child: Stack(children: [
                    CustomPaint(
                      size: Size(cst.maxWidth, 280),
                      painter: _DualLinePainter(
                        periods: agg,
                        progress: _anim.value,
                        isDark: widget.isDark,
                        selectedIdx: _selectedIdx,
                      ),
                    ),
                    if (_selectedIdx != null && _selectedIdx! < agg.length)
                      _buildTooltip(fmt, agg[_selectedIdx!], cst.maxWidth, agg.length),
                  ]),
                );
              },
            ),
          ),
      ]),
    );
  }

  Widget _buildTooltip(NumberFormat fmt, _PeriodAgg p, double maxWidth, int dataLength) {
    final cs = Theme.of(context).colorScheme;
    const padL = 65.0;
    const padR = 55.0;
    final w = maxWidth - padL - padR;
    final x = padL + (_selectedIdx! / (dataLength - 1)) * w;
    final left = (x + 14).clamp(0.0, maxWidth - 230.0);

    return Positioned(
      left: left,
      top: 0,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: widget.isDark ? const Color(0xFF0F172A) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.18), blurRadius: 10)
          ],
          border: Border.all(
              color: widget.isDark
                  ? const Color(0xFF334155)
                  : const Color(0xFFE2E8F0)),
        ),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(p.label,
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: cs.onSurface)),
              const SizedBox(height: 6),
              Row(children: [
                Container(width: 8, height: 8,
                    decoration: const BoxDecoration(
                        color: Color(0xFF2563EB), shape: BoxShape.circle)),
                const SizedBox(width: 6),
                Text('Doanh thu: ${fmt.format(p.revenue)}đ',
                    style: TextStyle(fontSize: 11, color: cs.onSurface)),
              ]),
              const SizedBox(height: 4),
              Row(children: [
                Container(width: 8, height: 8,
                    decoration: const BoxDecoration(
                        color: Color(0xFF0891B2), shape: BoxShape.circle)),
                const SizedBox(width: 6),
                Text('Số đơn: ${p.orderCount.toInt()}',
                    style: TextStyle(fontSize: 11, color: cs.onSurface)),
              ]),
            ]),
      ),
    );
  }
}

class _PeriodAgg {
  final String label;
  final int fromTs, toTs;
  final double revenue, orderCount;
  const _PeriodAgg(
      {required this.label, required this.fromTs, required this.toTs,
        required this.revenue, required this.orderCount});
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  final bool dashed;
  const _LegendDot(
      {required this.color, required this.label, this.dashed = false});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 8, height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 4),
      Text(label,
          style: TextStyle(fontSize: 10, color: cs.onSurface.withOpacity(0.6))),
    ]);
  }
}

class _ShiftFilter extends StatelessWidget {
  final int selected;
  final void Function(int) onSelect;
  final bool isDark;
  const _ShiftFilter(
      {required this.selected, required this.onSelect, required this.isDark});

  static const _opts = [
    (0, 'Tất cả', Color(0xFF6366F1)),
    (1, 'Ca 1',   Color(0xFF2563EB)),
    (2, 'Ca 2',   Color(0xFF7C3AED)),
    (3, 'Ca 3',   Color(0xFFEA580C)),
  ];

  @override
  Widget build(BuildContext context) {
    final isNarrow = MediaQuery.of(context).size.width < 600;
    if (isNarrow) return _buildDropdown(context);
    return _buildChips();
  }

  Widget _buildDropdown(BuildContext context) {
    final current = _opts.firstWhere((o) => o.$1 == selected,
        orElse: () => _opts[0]);
    final color = current.$3;

    return GestureDetector(
      onTap: () => _showPicker(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color, width: 1.5),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(current.$2,
              style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w700, color: color)),
          const SizedBox(width: 4),
          Icon(Icons.arrow_drop_down_rounded, size: 18, color: color),
        ]),
      ),
    );
  }

  void _showPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 90),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 36, height: 4,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2)),
          ),
          ..._opts.map((o) {
            final isSel = selected == o.$1;
            return GestureDetector(
              onTap: () {
                Navigator.pop(context);
                onSelect(o.$1);
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: isSel ? o.$3.withOpacity(0.12) : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSel ? o.$3 : o.$3.withOpacity(0.3),
                    width: isSel ? 1.5 : 1,
                  ),
                ),
                child: Row(children: [
                  Text(o.$2,
                      style: TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w600,
                          color: isSel ? o.$3
                              : (isDark ? Colors.white70 : Colors.black87))),
                  const Spacer(),
                  if (isSel) Icon(Icons.check_rounded, color: o.$3, size: 18),
                ]),
              ),
            );
          }),
        ]),
      ),
    );
  }

  Widget _buildChips() {
    return Row(
        mainAxisSize: MainAxisSize.min,
        children: _opts.map((o) {
          final isSel = selected == o.$1;
          return Padding(
            padding: const EdgeInsets.only(left: 4),
            child: GestureDetector(
              onTap: () => onSelect(o.$1),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isSel ? o.$3 : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: o.$3, width: 1.5),
                ),
                child: Text(o.$2,
                    style: TextStyle(
                        fontSize: 10, fontWeight: FontWeight.w600,
                        color: isSel ? Colors.white : o.$3)),
              ),
            ),
          );
        }).toList());
  }
}

class _DualLinePainter extends CustomPainter {
  final List<_PeriodAgg> periods;
  final double progress;
  final bool isDark;
  final int? selectedIdx;

  static const _colRev = Color(0xFF2563EB);
  static const _colOrd = Color(0xFF0891B2);

  _DualLinePainter({
    required this.periods, required this.progress,
    required this.isDark, this.selectedIdx,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (periods.isEmpty) return;
    const padL = 65.0, padR = 55.0, padT = 20.0, padB = 40.0;
    final w = size.width - padL - padR;
    final h = size.height - padT - padB;
    final n = periods.length;

    double maxRev = periods.map((p) => p.revenue).fold(0.0, (a, b) => a > b ? a : b);
    double maxOrd = periods.map((p) => p.orderCount).fold(0.0, (a, b) => a > b ? a : b);
    if (maxRev == 0) maxRev = 1;
    if (maxOrd == 0) maxOrd = 1;

    final fmtS = TextStyle(fontSize: 9,
        color: (isDark ? Colors.white : Colors.black).withOpacity(0.5));
    final gridP = Paint()
      ..color = (isDark ? Colors.white : Colors.black).withOpacity(0.06)
      ..strokeWidth = 1;
    final fmtC = NumberFormat.compactCurrency(locale: 'vi', symbol: '');

    for (int i = 0; i <= 4; i++) {
      final y = padT + h - (i / 4) * h;
      canvas.drawLine(Offset(padL, y), Offset(padL + w, y), gridP);
      _dt(canvas, fmtC.format(maxRev * i / 4), Offset(0, y - 6), fmtS, TextAlign.right, 60);
      _dt(canvas, (maxOrd * i / 4).toInt().toString(),
          Offset(padL + w + 4, y - 6), fmtS, TextAlign.left, 50);
    }

    final step = (n / 12).ceil().clamp(1, 999);
    for (int i = 0; i < n; i += step) {
      final x = padL + (n == 1 ? w / 2 : i / (n - 1) * w);
      _dtRotated(canvas, periods[i].label,
          Offset(x, size.height - padB + 4), fmtS, -0.52);
    }

    _drawLineSeries(canvas, n, padL, padT, w, h, maxRev, (p) => p.revenue, _colRev, false);
    _drawLineSeries(canvas, n, padL, padT, w, h, maxOrd, (p) => p.orderCount, _colOrd, true);

    if (selectedIdx != null && selectedIdx! < n) {
      final x = padL + (n == 1 ? w / 2 : selectedIdx! / (n - 1) * w);
      canvas.drawLine(Offset(x, padT), Offset(x, padT + h),
          Paint()..color = Colors.grey.withOpacity(0.3)..strokeWidth = 1);
      _hoverDot(canvas, x, padT + h - periods[selectedIdx!].revenue / maxRev * h, _colRev);
      _hoverDot(canvas, x, padT + h - periods[selectedIdx!].orderCount / maxOrd * h, _colOrd);
    }
  }

  void _dtRotated(Canvas canvas, String text, Offset pivot, TextStyle s, double angle) {
    final tp = TextPainter(
        text: TextSpan(text: text, style: s),
        textDirection: ui.TextDirection.ltr)..layout(maxWidth: 60);
    canvas.save();
    canvas.translate(pivot.dx, pivot.dy);
    canvas.rotate(angle);
    tp.paint(canvas, Offset(-tp.width / 2, 0));
    canvas.restore();
  }

  void _drawLineSeries(Canvas canvas, int n, double padL, double padT,
      double w, double h, double maxVal,
      double Function(_PeriodAgg) val, Color color, bool dashed) {
    final pts = List.generate(n, (i) => Offset(
        padL + (n == 1 ? w / 2 : i / (n - 1) * w),
        padT + h - val(periods[i]) / maxVal * h));

    final totalPts = (pts.length * progress).ceil().clamp(1, pts.length);
    final paint = Paint()
      ..color = color..strokeWidth = 2.5
      ..style = PaintingStyle.stroke..strokeCap = StrokeCap.round;

    if (!dashed) {
      final path = Path()..moveTo(pts[0].dx, pts[0].dy);
      for (int i = 1; i < totalPts; i++) path.lineTo(pts[i].dx, pts[i].dy);
      canvas.drawPath(path, paint);
    } else {
      for (int i = 0; i < totalPts - 1; i++) {
        final p1 = pts[i], p2 = pts[i + 1];
        final dist = (p2 - p1).distance;
        final segs = (dist / 10).floor().clamp(1, 999);
        for (int j = 0; j < segs; j++) {
          if (j % 2 == 0) {
            canvas.drawLine(
                Offset.lerp(p1, p2, j / segs)!,
                Offset.lerp(p1, p2, (j + 0.6) / segs)!, paint);
          }
        }
      }
    }

    final dot = Paint()..color = color..style = PaintingStyle.fill;
    for (int i = 0; i < totalPts; i++) canvas.drawCircle(pts[i], 3.5, dot);
  }

  void _hoverDot(Canvas canvas, double x, double y, Color c) {
    canvas.drawCircle(Offset(x, y), 6,
        Paint()..color = c..style = PaintingStyle.fill);
    canvas.drawCircle(Offset(x, y), 9,
        Paint()..color = c.withOpacity(0.2)..style = PaintingStyle.fill);
  }

  void _dt(Canvas canvas, String text, Offset off, TextStyle s, TextAlign a, double mw) {
    final tp = TextPainter(
        text: TextSpan(text: text, style: s),
        textDirection: ui.TextDirection.ltr, textAlign: a)..layout(maxWidth: mw);
    tp.paint(canvas, off);
  }

  @override
  bool shouldRepaint(_DualLinePainter old) =>
      old.progress != progress || old.selectedIdx != selectedIdx || old.periods != periods;
}

// ══════════════════════════════════════════════════════════════════
// CHART 2 — Stacked Area %
// ══════════════════════════════════════════════════════════════════

class _Chart2 extends StatefulWidget {
  final List<PeriodStackedPoint> data;
  final bool loading;
  final bool isDark;

  const _Chart2({required this.data, required this.loading, required this.isDark});

  @override
  State<_Chart2> createState() => _Chart2State();
}

class _Chart2State extends State<_Chart2> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;
  int? _selectedIdx;
  String _metric = 'revenue';

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900));
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);
    _ctrl.forward();
  }

  @override
  void didUpdateWidget(_Chart2 old) {
    super.didUpdateWidget(old);
    if (old.data != widget.data) _ctrl.forward(from: 0);
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  static const _shiftColors = [
    Color(0xFF2563EB), Color(0xFF7C3AED), Color(0xFFEA580C), Color(0xFF6366F1),
  ];

  int? _calculateIndexFromPosition({
    required Offset? position, required double width, required int dataLength,
  }) {
    if (position == null || dataLength <= 1) return null;
    const padL = 55.0; const padR = 20.0;
    final w = width - padL - padR;
    final x = position.dx;
    if (x < padL || x > padL + w) return null;
    return ((x - padL) / (w / (dataLength - 1))).round().clamp(0, dataLength - 1);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final border = widget.isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final fmt = NumberFormat('#,###', 'vi_VN');

    final tmpFromTs = <String, int>{};
    for (final p in widget.data) {
      tmpFromTs.putIfAbsent(p.periodLabel, () => p.periodFromTs);
    }
    final sortedPeriods = tmpFromTs.keys.toList()
      ..sort((a, b) => (tmpFromTs[a] ?? 0).compareTo(tmpFromTs[b] ?? 0));

    final groups = widget.data.map((p) => p.groupKey).toSet().toList()..sort();
    final Map<String, Map<String, double>> byPeriod = {};
    for (final p in widget.data) {
      byPeriod.putIfAbsent(p.periodLabel, () => <String, double>{})[p.groupKey] =
      _metric == 'revenue' ? p.revenue : p.orderCount;
    }

    const colors = _shiftColors;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: widget.isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text('Phân bổ theo Ca',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: cs.onSurface)),
          const Spacer(),
          _MetricToggle(value: _metric, onChange: (m) => setState(() {
            _metric = m; _selectedIdx = null; _ctrl.forward(from: 0);
          }), isDark: widget.isDark),
        ]),
        const SizedBox(height: 8),
        Wrap(spacing: 10, runSpacing: 4,
            children: groups.asMap().entries.map((e) {
              final color = colors[e.key % colors.length];
              return Row(mainAxisSize: MainAxisSize.min, children: [
                Container(width: 10, height: 10,
                    decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
                const SizedBox(width: 4),
                Text(e.value, style: TextStyle(fontSize: 10, color: cs.onSurface.withOpacity(0.7))),
              ]);
            }).toList()),
        const SizedBox(height: 10),
        if (widget.loading)
          const SizedBox(height: 260,
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)))
        else
          AnimatedBuilder(
            animation: _anim,
            builder: (_, __) => LayoutBuilder(
              builder: (ctx, cst) {
                return GestureDetector(
                  onTapDown: (details) {
                    final idx = _calculateIndexFromPosition(
                        position: details.localPosition, width: cst.maxWidth,
                        dataLength: sortedPeriods.length);
                    setState(() { _selectedIdx = _selectedIdx == idx ? null : idx; });
                  },
                  onTap: () {
                    if (_selectedIdx != null) {
                      final idx = _calculateIndexFromPosition(
                          position: null, width: cst.maxWidth,
                          dataLength: sortedPeriods.length);
                      if (idx == null) setState(() => _selectedIdx = null);
                    }
                  },
                  child: Stack(children: [
                    CustomPaint(
                      size: Size(cst.maxWidth, 260),
                      painter: _StackedAreaPainter(
                        byPeriod: byPeriod, periods: sortedPeriods,
                        groups: groups, colors: colors,
                        progress: _anim.value, isDark: widget.isDark,
                        selectedIdx: _selectedIdx,
                      ),
                    ),
                    if (_selectedIdx != null && _selectedIdx! < sortedPeriods.length)
                      _buildTooltip(fmt, sortedPeriods[_selectedIdx!],
                          byPeriod[sortedPeriods[_selectedIdx!]] ?? {},
                          colors, groups, cst.maxWidth, sortedPeriods),
                  ]),
                );
              },
            ),
          ),
      ]),
    );
  }

  Widget _buildTooltip(NumberFormat fmt, String period, Map<String, double> data,
      List<Color> colors, List<String> groups, double maxWidth, List<String> sortedPeriods) {
    final cs = Theme.of(context).colorScheme;
    final total = data.values.fold(0.0, (a, b) => a + b);
    const padL = 55.0; const padR = 20.0;
    final w = maxWidth - padL - padR;
    final x = padL + (_selectedIdx! / (sortedPeriods.length - 1)) * w;
    final left = (x + 14).clamp(0.0, maxWidth - 230.0);

    return Positioned(
      left: left, top: 0,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: widget.isDark ? const Color(0xFF0F172A) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.18), blurRadius: 10)],
          border: Border.all(color: widget.isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min, children: [
              Text(period, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: cs.onSurface)),
              const SizedBox(height: 6),
              ...groups.asMap().entries.map((e) {
                final color = colors[e.key % colors.length];
                final val = data[e.value] ?? 0;
                final pct = total > 0 ? val / total * 100 : 0.0;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Container(width: 8, height: 8,
                        decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                    const SizedBox(width: 6),
                    Text('${e.value}: ${fmt.format(val)}đ (${pct.toStringAsFixed(1)}%)',
                        style: TextStyle(fontSize: 10, color: cs.onSurface)),
                  ]),
                );
              }),
            ]),
      ),
    );
  }
}

class _MetricToggle extends StatelessWidget {
  final String value;
  final void Function(String) onChange;
  final bool isDark;

  const _MetricToggle({required this.value, required this.onChange, required this.isDark, super.key});

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      _buildButton(label: 'Doanh thu', metric: 'revenue',
          isSelected: value == 'revenue', color: const Color(0xFF2563EB)),
      const SizedBox(width: 6),
      _buildButton(label: 'Số đơn', metric: 'orderCount',
          isSelected: value == 'orderCount', color: const Color(0xFF0891B2)),
    ]);
  }

  Widget _buildButton({required String label, required String metric,
    required bool isSelected, required Color color}) {
    return GestureDetector(
      onTap: () => onChange(metric),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? color : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isSelected ? color : color.withOpacity(0.5), width: 1.5),
        ),
        child: Text(label, style: TextStyle(
            fontSize: 11.5, fontWeight: FontWeight.w700,
            color: isSelected ? Colors.white : color)),
      ),
    );
  }
}

class _StackedAreaPainter extends CustomPainter {
  final Map<String, Map<String, double>> byPeriod;
  final List<String> periods;
  final List<String> groups;
  final List<Color> colors;
  final double progress;
  final bool isDark;
  final int? selectedIdx;

  _StackedAreaPainter({
    required this.byPeriod, required this.periods, required this.groups,
    required this.colors, required this.progress, required this.isDark,
    this.selectedIdx,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (periods.isEmpty || groups.isEmpty) return;
    const padL = 55.0, padR = 20.0, padT = 20.0, padB = 40.0;
    final w = size.width - padL - padR;
    final h = size.height - padT - padB;
    final n = periods.length;

    final txtS = TextStyle(fontSize: 9,
        color: (isDark ? Colors.white : Colors.black).withOpacity(0.5));
    final gridP = Paint()
      ..color = (isDark ? Colors.white : Colors.black).withOpacity(0.06)..strokeWidth = 1;

    for (int i = 0; i <= 4; i++) {
      final y = padT + h - (i / 4) * h;
      canvas.drawLine(Offset(padL, y), Offset(padL + w, y), gridP);
      _dt(canvas, '${i * 25}%', Offset(0, y - 6), txtS, 50);
    }

    final step = (n / 12).ceil().clamp(1, 999);
    for (int i = 0; i < n; i += step) {
      final x = padL + (n == 1 ? w / 2 : i / (n - 1) * w);
      _dtRotated(canvas, periods[i], Offset(x, size.height - padB + 4), txtS, -0.52);
    }

    final totals = <String, double>{};
    for (final p in periods) {
      double s = 0;
      for (final g in groups) s += byPeriod[p]?[g] ?? 0;
      totals[p] = s > 0 ? s : 1;
    }

    for (int gi = groups.length - 1; gi >= 0; gi--) {
      final color = colors[gi % colors.length];
      final path = Path();
      final tops = <Offset>[];
      final bots = <Offset>[];

      for (int mi = 0; mi < n; mi++) {
        final x = padL + (n == 1 ? w / 2 : mi / (n - 1) * w);
        final total = totals[periods[mi]] ?? 1;
        double ct = 0, cb = 0;
        for (int g2 = 0; g2 <= gi; g2++)
          ct += (byPeriod[periods[mi]]?[groups[g2]] ?? 0) / total;
        for (int g2 = 0; g2 < gi; g2++)
          cb += (byPeriod[periods[mi]]?[groups[g2]] ?? 0) / total;
        tops.add(Offset(x, padT + h - ct * h * progress));
        bots.add(Offset(x, padT + h - cb * h * progress));
      }

      if (tops.isEmpty) continue;
      path.moveTo(bots.first.dx, bots.first.dy);
      for (final pt in tops) path.lineTo(pt.dx, pt.dy);
      for (final pt in bots.reversed) path.lineTo(pt.dx, pt.dy);
      path.close();

      canvas.drawPath(path, Paint()..color = color.withOpacity(0.65)..style = PaintingStyle.fill);
      canvas.drawPath(path, Paint()..color = color..strokeWidth = 1.5..style = PaintingStyle.stroke);

      final dotP = Paint()..color = color..style = PaintingStyle.fill;
      for (int mi = 0; mi < n; mi++) canvas.drawCircle(tops[mi], 3, dotP);
    }

    if (selectedIdx != null && selectedIdx! < n) {
      final x = padL + (n == 1 ? w / 2 : selectedIdx! / (n - 1) * w);
      canvas.drawLine(Offset(x, padT), Offset(x, padT + h),
          Paint()..color = Colors.grey.withOpacity(0.3)..strokeWidth = 1);
    }
  }

  void _dtRotated(Canvas canvas, String text, Offset pivot, TextStyle s, double angle) {
    final tp = TextPainter(text: TextSpan(text: text, style: s),
        textDirection: ui.TextDirection.ltr)..layout(maxWidth: 60);
    canvas.save();
    canvas.translate(pivot.dx, pivot.dy);
    canvas.rotate(angle);
    tp.paint(canvas, Offset(-tp.width / 2, 0));
    canvas.restore();
  }

  void _dt(Canvas canvas, String text, Offset off, TextStyle s, double mw) {
    final tp = TextPainter(text: TextSpan(text: text, style: s),
        textDirection: ui.TextDirection.ltr)..layout(maxWidth: mw);
    tp.paint(canvas, off);
  }

  @override
  bool shouldRepaint(_StackedAreaPainter old) =>
      old.progress != progress || old.selectedIdx != selectedIdx || old.byPeriod != byPeriod;
}

// ══════════════════════════════════════════════════════════════════
// HEATMAP — Configurable (dùng cho cả 3 heatmap)
// ══════════════════════════════════════════════════════════════════

class _HeatmapChart extends StatefulWidget {
  final String title;
  final String countLabel;
  final List<Color> colorStops;
  final List<HeatmapCell> cells;
  final bool loading;
  final bool isDark;
  final void Function(int periodMinutes) onPeriodChanged;
  final List<HeatmapProduct> products;
  final Set<int>             selectedProductIds;
  final void Function(Set<int>) onProductFilterChanged;
  final String? heatmapMode;                              // ← THÊM
  final void Function(String)? onHeatmapModeChanged;      // ← THÊM

  const _HeatmapChart({
    required this.title,
    required this.countLabel,
    required this.colorStops,
    required this.cells,
    required this.loading,
    required this.isDark,
    required this.onPeriodChanged,
    required this.onProductFilterChanged,
    required this.products,
    required this.selectedProductIds,
    this.heatmapMode,                                     // ← THÊM
    this.onHeatmapModeChanged,                            // ← THÊM
  });

  @override
  State<_HeatmapChart> createState() => _HeatmapChartState();
}

class _HeatmapChartState extends State<_HeatmapChart>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;
  HeatmapCell? _hovered;

  int _periodMinutes = 60;
  double _step = 1.0;
  bool _stepOverridden = false;

  static const _dowLabels = [
    'Thứ 2', 'Thứ 3', 'Thứ 4', 'Thứ 5', 'Thứ 6', 'Thứ 7', 'CN',
  ];

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1000));
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);
    _ctrl.forward();
  }

  @override
  void didUpdateWidget(_HeatmapChart old) {
    super.didUpdateWidget(old);
    if (old.cells != widget.cells) {
      if (!_stepOverridden && widget.cells.isNotEmpty) {
        final backendStep = widget.cells.first.step;
        setState(() => _step = backendStep);
      }
      _ctrl.forward(from: 0);
    }
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  static const _startMin      = 7 * 60;
  static const _defaultEndMin = 22 * 60;
  static const _dayEndMin     = 24 * 60;

  int get _endMin {
    int latestSlotStart = -1;
    for (final c in widget.cells) {
      if (c.hour > latestSlotStart) latestSlotStart = c.hour;
    }
    if (latestSlotStart < 0) return _defaultEndMin;
    final end = latestSlotStart + _periodMinutes;
    if (end < _defaultEndMin) return _defaultEndMin;
    return end > _dayEndMin ? _dayEndMin : end;
  }

  int get _slotsPerDay =>
      ((_endMin - _startMin) / _periodMinutes).ceil();

  List<String> get _slotLabels {
    return List.generate(_slotsPerDay, (i) {
      final m = _startMin + i * _periodMinutes;
      return '${m ~/ 60}:${(m % 60).toString().padLeft(2, '0')}';
    });
  }

  Map<String, HeatmapCell> get _cellMap {
    final m = <String, HeatmapCell>{};
    for (final c in widget.cells) {
      final slotIdx = (c.hour - _startMin) ~/ _periodMinutes;
      if (slotIdx < 0 || slotIdx >= _slotsPerDay) continue;
      final dow = c.date.replaceFirst('DOW_', '');
      m['${dow}_$slotIdx'] = c;
    }
    return m;
  }

  Color _cellColor(double count, bool hasData) {
    if (!hasData) {
      return widget.isDark
          ? Colors.white.withOpacity(0.03)
          : const Color(0xFFEEF2F7);
    }
    if (count <= 0) {
      return widget.isDark
          ? Colors.white.withOpacity(0.06)
          : const Color(0xFFF1F5F9);
    }
    final level = (count / _step).floor().clamp(0, 8);
    return widget.colorStops[level + 1];
  }

  List<String> get _legendLabels {
    return [
      'Trống',
      '0–${_fmt(_step)}',
      '${_fmt(_step)}–${_fmt(_step*2)}',
      '${_fmt(_step*2)}–${_fmt(_step*3)}',
      '${_fmt(_step*3)}–${_fmt(_step*4)}',
      '${_fmt(_step*4)}–${_fmt(_step*5)}',
      '${_fmt(_step*5)}–${_fmt(_step*6)}',
      '${_fmt(_step*6)}–${_fmt(_step*7)}',
      '${_fmt(_step*7)}–${_fmt(_step*8)}',
      '≥${_fmt(_step*8)}',
    ];
  }

  String _fmt(double v) =>
      v == v.truncateToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);

  String _fmtCustomRange(DateTime? from, DateTime? to) {
    if (from == null && to == null) return 'Tuỳ chọn';
    final fmt = DateFormat('dd/MM/yyyy');
    if (from != null && to != null) return '${fmt.format(from)} – ${fmt.format(to)}';
    if (from != null) return 'Từ ${fmt.format(from)}';
    return 'Đến ${fmt.format(to!)}';
  }

  void _onPeriodChanged(int p) {
    setState(() {
      _periodMinutes  = p;
      _stepOverridden = false;
      _hovered        = null;
    });
    widget.onPeriodChanged(p);
  }

  @override
  Widget build(BuildContext context) {
    final cs     = Theme.of(context).colorScheme;
    final border = widget.isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final fmt    = NumberFormat('#,###', 'vi_VN');
    final cellMap = _cellMap;
    final slots   = _slotsPerDay;
    final labelStep = (slots / 8).ceil().clamp(1, 999);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: widget.isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // ── Title + Dropdowns ─────────────────────────────────────
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(widget.title,
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: cs.onSurface)),
              const SizedBox(height: 2),
              Consumer(
                builder: (context, ref, _) {
                  final ctrl = ref.watch(dashboardControllerProvider);
                  final period = ctrl.period;
                  final label = switch (period) {
                    DashboardPeriod.today   => 'Hôm nay',
                    DashboardPeriod.days7   => '7 ngày gần đây',
                    DashboardPeriod.days28  => '28 ngày gần đây',
                    DashboardPeriod.days30  => '30 ngày gần đây',
                    DashboardPeriod.months3 => '3 tháng gần đây',
                    DashboardPeriod.months6 => '6 tháng gần đây',
                    DashboardPeriod.year    => '1 năm gần đây',
                    DashboardPeriod.custom  => _fmtCustomRange(ctrl.customFrom, ctrl.customTo),
                  };
                  return Text(label,
                      style: TextStyle(fontSize: 11, color: cs.onSurface.withOpacity(0.45)));
                },
              ),
            ]),
          ),
          const SizedBox(width: 8),
          if (widget.heatmapMode != null && widget.onHeatmapModeChanged != null)
            _HeatmapDropdown<String>(
              label: 'Loại',
              value: widget.heatmapMode!,
              items: const [
                ('order',      'Số đơn'),
                ('product',    'Số sản phẩm'),
                ('ingredient', 'Số nguyên liệu'),
              ],
              isDark: widget.isDark,
              onChanged: widget.onHeatmapModeChanged!,
            ),
          const SizedBox(width: 8),
          _HeatmapDropdown<int>(
            label: 'Khung giờ',
            value: _periodMinutes,
            items: const [(30, '30 phút'), (60, '1 giờ'), (120, '2 giờ')],
            isDark: widget.isDark,
            onChanged: _onPeriodChanged,
          ),
          const SizedBox(width: 8),
          _ProductFilterButton(
            products: widget.products,
            selectedIds: widget.selectedProductIds,
            isDark: widget.isDark,
            onApply: widget.onProductFilterChanged,
          ),
        ]),
        const SizedBox(height: 12),

        // ── Color legend ─────────────────────────────────────────
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: List.generate(10, (i) {
              final color = i == 0
                  ? (widget.isDark ? Colors.white.withOpacity(0.06) : const Color(0xFFF1F5F9))
                  : widget.colorStops[i];
              return Padding(
                padding: const EdgeInsets.only(right: 5),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Container(width: 20, height: 12,
                    decoration: BoxDecoration(
                      color: color, borderRadius: BorderRadius.circular(2),
                      border: Border.all(color: cs.onSurface.withOpacity(0.1), width: 0.5),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(_legendLabels[i],
                      style: TextStyle(fontSize: 7, color: cs.onSurface.withOpacity(0.4))),
                ]),
              );
            }),
          ),
        ),
        const SizedBox(height: 12),

        if (widget.loading)
          const SizedBox(height: 200,
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)))
        else
          AnimatedBuilder(
            animation: _anim,
            builder: (_, __) => LayoutBuilder(
              builder: (ctx, cst) {
                const rowLabelW = 52.0;
                const cellH     = 30.0;
                final cellW     = (cst.maxWidth - rowLabelW) / slots;

                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => setState(() => _hovered = null),
                  child: Stack(children: [
                    Column(children: [
                      Row(children: [
                        const SizedBox(width: rowLabelW),
                        ...List.generate(slots, (si) {
                          final show = si % labelStep == 0;
                          return SizedBox(width: cellW,
                            child: show
                                ? Text(_slotLabels[si], textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 7,
                                    color: cs.onSurface.withOpacity(0.45)))
                                : const SizedBox.shrink(),
                          );
                        }),
                      ]),
                      const SizedBox(height: 4),
                      ...List.generate(7, (dowIdx) {
                        final dow = dowIdx + 1;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 3),
                          child: Row(children: [
                            SizedBox(width: rowLabelW,
                              child: Text(_dowLabels[dowIdx],
                                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600,
                                      color: cs.onSurface.withOpacity(0.65))),
                            ),
                            ...List.generate(slots, (si) {
                              final cell  = cellMap['${dow}_$si'];
                              final count = cell?.orderCount ?? 0.0;
                              final hasData = widget.cells
                                  .where((c) => c.date == 'DOW_$dow')
                                  .map((c) => c.hasData)
                                  .firstOrNull ?? false;
                              final color = _cellColor(count, hasData);

                              final waveX = si / slots;
                              final waveY = dowIdx / 7;
                              final delay = waveX * 0.6 + waveY * 0.4;
                              final lp = Curves.easeOut.transform(
                                  ((_anim.value - delay * 0.7) / 0.5).clamp(0.0, 1.0));

                              return MouseRegion(
                                onEnter: (_) {
                                  if (cell != null && count > 0)
                                    setState(() => _hovered = cell);
                                },
                                onExit: (_) {
                                  if (_hovered == cell)
                                    setState(() => _hovered = null);
                                },
                                child: GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTapDown: (_) {
                                    if (cell != null)
                                      setState(() =>
                                      _hovered = _hovered == cell ? null : cell);
                                  },
                                  child: AnimatedScale(
                                    scale: _hovered == cell && count > 0 ? 1.12 : 1.0,
                                    duration: const Duration(milliseconds: 120),
                                    child: Container(
                                      width: cellW - 2, height: cellH,
                                      margin: const EdgeInsets.symmetric(horizontal: 1),
                                      decoration: BoxDecoration(
                                        color: Color.lerp(
                                            widget.isDark
                                                ? Colors.white.withOpacity(0.05)
                                                : const Color(0xFFF1F5F9),
                                            color, lp),
                                        borderRadius: BorderRadius.circular(3),
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }),
                          ]),
                        );
                      }),
                    ]),

                    // ── Tooltip ───────────────────────────────────
                    if (_hovered != null)
                      Positioned(
                        top: 30, right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: widget.isDark ? const Color(0xFF0F172A) : Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: [BoxShadow(
                                color: Colors.black.withOpacity(0.15), blurRadius: 10)],
                            border: Border.all(color: border),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(_hovered!.dayLabel,
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800,
                                      color: cs.onSurface)),
                              const SizedBox(height: 2),
                              Text(_hovered!.hourLabel,
                                  style: TextStyle(fontSize: 11, color: cs.primary,
                                      fontWeight: FontWeight.w600)),
                              const SizedBox(height: 6),
                              Row(children: [
                                Icon(Icons.receipt_outlined, size: 13,
                                    color: cs.onSurface.withOpacity(0.6)),
                                const SizedBox(width: 5),
                                Text('TB ${_hovered!.orderCount.toStringAsFixed(2)} ${widget.countLabel}',
                                    style: TextStyle(fontSize: 12, color: cs.onSurface)),
                              ]),
                              const SizedBox(height: 3),
                              Row(children: [
                                Icon(Icons.attach_money_rounded, size: 13,
                                    color: cs.onSurface.withOpacity(0.6)),
                                const SizedBox(width: 5),
                                Text('${fmt.format(_hovered!.totalRevenue)}đ',
                                    style: TextStyle(fontWeight: FontWeight.w700,
                                        color: cs.primary, fontSize: 12)),
                              ]),
                            ],
                          ),
                        ),
                      ),
                  ]),
                );
              },
            ),
          ),
      ]),
    );
  }
}

// ── Generic dropdown ─────────────────────────────────────────────

class _HeatmapDropdown<T> extends StatelessWidget {
  final String label;
  final T value;
  final List<(T, String)> items;
  final bool isDark;
  final void Function(T) onChanged;

  const _HeatmapDropdown({
    required this.label, required this.value, required this.items,
    required this.isDark, required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final cs  = Theme.of(context).colorScheme;
    final cur = items.firstWhere((e) => e.$1 == value);

    return GestureDetector(
      onTap: () => _show(context, cs),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: cs.primary.withOpacity(0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: cs.primary.withOpacity(0.5), width: 1.5),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(cur.$2, style: TextStyle(
              fontSize: 11.5, fontWeight: FontWeight.w700, color: cs.primary)),
          const SizedBox(width: 2),
          Icon(Icons.arrow_drop_down_rounded, size: 16, color: cs.primary),
        ]),
      ),
    );
  }

  void _show(BuildContext context, ColorScheme cs) {
    showModalBottomSheet(
      context: context, backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 90),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 36, height: 4,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2)),
          ),
          Text(label, style: TextStyle(
              fontSize: 15, fontWeight: FontWeight.w800, color: cs.onSurface)),
          const SizedBox(height: 12),
          ...items.map((item) {
            final isSel = item.$1 == value;
            return GestureDetector(
              onTap: () { Navigator.pop(context); onChanged(item.$1); },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: isSel ? cs.primary.withOpacity(0.1) : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: isSel ? cs.primary : cs.primary.withOpacity(0.25),
                      width: isSel ? 1.5 : 1),
                ),
                child: Row(children: [
                  Text(item.$2, style: TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w600,
                      color: isSel ? cs.primary : cs.onSurface)),
                  const Spacer(),
                  if (isSel) Icon(Icons.check_rounded, color: cs.primary, size: 18),
                ]),
              ),
            );
          }),
        ]),
      ),
    );
  }
}

class _ProductFilterButton extends StatelessWidget {
  final List<HeatmapProduct> products;
  final Set<int>             selectedIds;
  final bool                 isDark;
  final void Function(Set<int>) onApply;

  const _ProductFilterButton({
    required this.products, required this.selectedIds,
    required this.isDark, required this.onApply,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final hasFilter = selectedIds.isNotEmpty;

    return GestureDetector(
      onTap: () => _show(context, cs),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: hasFilter
              ? const Color(0xFF059669).withOpacity(0.12)
              : cs.surfaceContainerHighest.withOpacity(0.5),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color: hasFilter ? const Color(0xFF059669) : cs.onSurface.withOpacity(0.2),
              width: hasFilter ? 1.5 : 1),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.fastfood_rounded, size: 13,
              color: hasFilter ? const Color(0xFF059669) : cs.onSurface.withOpacity(0.5)),
          const SizedBox(width: 4),
          Text(hasFilter ? '${selectedIds.length} món' : 'Tất cả',
              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600,
                  color: hasFilter ? const Color(0xFF059669) : cs.onSurface.withOpacity(0.6))),
          const SizedBox(width: 2),
          Icon(Icons.arrow_drop_down_rounded, size: 16,
              color: hasFilter ? const Color(0xFF059669) : cs.onSurface.withOpacity(0.4)),
        ]),
      ),
    );
  }

  void _show(BuildContext context, ColorScheme cs) {
    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (_) => _ProductPickerSheet(
        products: products, selectedIds: selectedIds,
        isDark: isDark, onApply: (ids) { Navigator.pop(context); onApply(ids); },
      ),
    );
  }
}

class _ProductPickerSheet extends StatefulWidget {
  final List<HeatmapProduct>    products;
  final Set<int>                selectedIds;
  final bool                    isDark;
  final void Function(Set<int>) onApply;

  const _ProductPickerSheet({
    required this.products, required this.selectedIds,
    required this.isDark, required this.onApply,
  });

  @override
  State<_ProductPickerSheet> createState() => _ProductPickerSheetState();
}

class _ProductPickerSheetState extends State<_ProductPickerSheet> {
  final _searchCtrl = TextEditingController();
  String _query = '';
  late Set<int> _local;

  @override
  void initState() {
    super.initState();
    _local = Set<int>.from(widget.selectedIds);
  }

  @override
  void dispose() { _searchCtrl.dispose(); super.dispose(); }

  List<HeatmapProduct> get _filtered {
    if (_query.isEmpty) return widget.products;
    return widget.products
        .where((p) => p.name.toLowerCase().contains(_query.toLowerCase()))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final cs     = Theme.of(context).colorScheme;
    final border = widget.isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final bg     = widget.isDark ? const Color(0xFF1E293B) : Colors.white;
    const green  = Color(0xFF059669);
    final maxH   = MediaQuery.of(context).size.height * 0.8;

    return Container(
      constraints: BoxConstraints(maxHeight: maxH),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 36, height: 4,
          margin: const EdgeInsets.only(top: 12, bottom: 4),
          decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.3),
              borderRadius: BorderRadius.circular(2)),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Row(children: [
            Text('Lọc theo món',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: cs.onSurface)),
            const Spacer(),
            if (_local.isNotEmpty)
              GestureDetector(
                onTap: () => setState(() => _local.clear()),
                child: Text('Bỏ chọn tất cả',
                    style: TextStyle(fontSize: 12, color: cs.error, fontWeight: FontWeight.w600)),
              ),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TextField(
            controller: _searchCtrl,
            onChanged: (v) => setState(() => _query = v),
            decoration: InputDecoration(
              hintText: 'Tìm tên món...',
              prefixIcon: const Icon(Icons.search_rounded, size: 18),
              isDense: true, filled: true,
              fillColor: cs.surfaceContainerHighest.withOpacity(0.5),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Flexible(
          child: _filtered.isEmpty
              ? Padding(padding: const EdgeInsets.all(24),
              child: Text('Không tìm thấy món',
                  style: TextStyle(color: cs.onSurface.withOpacity(0.4))))
              : ListView.builder(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            itemCount: _filtered.length,
            itemBuilder: (_, i) {
              final p = _filtered[i];
              final isSel = _local.contains(p.id);
              return GestureDetector(
                onTap: () => setState(() {
                  isSel ? _local.remove(p.id) : _local.add(p.id);
                }),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                  decoration: BoxDecoration(
                    color: isSel ? green.withOpacity(0.08) : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: isSel ? green : border,
                        width: isSel ? 1.5 : 1),
                  ),
                  child: Row(children: [
                    Expanded(child: Text(p.name,
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                            color: isSel ? green : cs.onSurface))),
                    if (isSel)
                      const Icon(Icons.check_circle_rounded, color: green, size: 18)
                    else
                      Icon(Icons.radio_button_unchecked_rounded,
                          color: cs.onSurface.withOpacity(0.3), size: 18),
                  ]),
                ),
              );
            },
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(
              16, 8, 16, MediaQuery.of(context).viewInsets.bottom + 90),
          child: SizedBox(
            width: double.infinity, height: 46,
            child: FilledButton(
              onPressed: () => widget.onApply(Set<int>.from(_local)),
              style: FilledButton.styleFrom(
                backgroundColor: green,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(
                  _local.isEmpty ? 'Áp dụng (Tất cả)' : 'Áp dụng (${_local.length} món)',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
            ),
          ),
        ),
      ]),
    );
  }
}