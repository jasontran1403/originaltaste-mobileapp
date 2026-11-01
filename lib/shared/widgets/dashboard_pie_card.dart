// lib/features/dashboard/widgets/dashboard_pie_card.dart

import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import '../../../app/theme/app_colors.dart';
import '../../../data/models/dashboard/dashboard_pos_model.dart';
import 'dashboard_shared_widgets.dart';

const _kSourceColors = {
  'TAKE_AWAY':   Color(0xFF6366F1),
  'DINE_IN':     Color(0xFF0891B2),
  'SHOPEE_FOOD': Color(0xFFEE4D2D),
  'GRAB_FOOD':   Color(0xFF00B14F),
  'OFFLINE':     Color(0xFF6366F1),
};

const _kCatColors = {
  'HOT':   Color(0xFFEA580C),
  'COLD':  Color(0xFF0891B2),
  'COMBO': Color(0xFF7C3AED),
};

const _kFallbackColors = [
  Color(0xFF6366F1), Color(0xFF16A34A), Color(0xFFD946EF), Color(0xFFEA580C),
  Color(0xFF0891B2), Color(0xFF7C3AED), Color(0xFFF59E0B), Color(0xFFE11D48),
];

// ── Helper format tooltip ─────────────────────────────────────────
String _fmtTooltip(double v, int type) {
  if (type == 0) return fmtCompact(v);          // Doanh thu → compact
  if (v >= 100000000) return fmtCompact(v);     // Đơn/SP > 100tr → compact
  return fmtNum(v.toInt());                      // Đơn/SP bình thường
}

// ── Slice model nội bộ ────────────────────────────────────────────
class _PieSlice {
  final String key;
  final String label;
  final int    count;
  final double amount;
  final int    items;

  const _PieSlice({
    required this.key,
    required this.label,
    required this.count,
    required this.amount,
    required this.items,
  });
}

// ═════════════════════════════════════════════════════════════════
class DashboardPieCard extends StatefulWidget {
  final PosDashboardModel data;
  const DashboardPieCard({super.key, required this.data});

  @override
  State<DashboardPieCard> createState() => _DashboardPieCardState();
}

class _DashboardPieCardState extends State<DashboardPieCard> {
  int _mode     = 0; // 0 = Nguồn, 1 = Loại
  int _type     = 0; // 0 = Doanh thu, 1 = Đơn hàng, 2 = Sản phẩm
  int _chartKey = 0;
  late TooltipBehavior _tooltipBehavior = _buildTooltip();

  TooltipBehavior _buildTooltip() => TooltipBehavior(enable: true);

  Color _pieColor(String key, int i) {
    final map = _mode == 0 ? _kSourceColors : _kCatColors;
    return map[key] ?? _kFallbackColors[i % _kFallbackColors.length];
  }

  void _toggleMode(int v) {
    if (v == _mode) return;
    setState(() {
      _mode            = v;
      _type            = 0;
      _tooltipBehavior = _buildTooltip();
      _chartKey++;
    });
  }

  void _toggleType(int v) {
    if (v == _type) return;
    setState(() {
      _type            = v;
      _tooltipBehavior = _buildTooltip();
      _chartKey++;
    });
  }

  List<_PieSlice> _buildSlices() {
    final d = widget.data;
    if (_mode == 0) {
      return d.paymentBreakdown.sourcePieItems.map((m) => _PieSlice(
        key:    m.key,
        label:  m.label,
        count:  m.count,
        amount: m.amount,
        items:  d.statFor(m.key).totalItems,
      )).toList();
    } else {
      return d.paymentBreakdown.categoryPieItems.map((m) => _PieSlice(
        key:    m.key,
        label:  m.label,
        count:  m.count,      // số đơn hàng
        amount: m.amount,
        items:  m.itemCount,  // số sản phẩm
      )).toList();
    }
  }

  double _getValue(_PieSlice s) => switch (_type) {
    1 => s.count.toDouble(),
    2 => s.items.toDouble(),
    _ => s.amount,
  };

  @override
  Widget build(BuildContext context) {
    final isDark    = Theme.of(context).brightness == Brightness.dark;
    final border    = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final cardBg    = isDark ? AppColors.darkCard : AppColors.lightCard;
    final secondary = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    final slices = _buildSlices();
    final total  = slices.fold<double>(0, (s, e) => s + _getValue(e));

    return Container(
      padding:    const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color:        cardBg,
        borderRadius: BorderRadius.circular(12),
        border:       Border.all(color: border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Expanded(child: DashboardSectionTitle('Phân tích đơn hàng')),
          _PieModeToggle(mode: _mode, onChanged: _toggleMode),
        ]),
        const SizedBox(height: 8),
        _TypeToggle(type: _type, onChanged: _toggleType),
        const SizedBox(height: 8),
        SizedBox(
          height: 290,
          child: slices.isEmpty || total == 0
              ? Center(child: Text('Không có dữ liệu',
              style: TextStyle(color: secondary)))
              : SfCircularChart(
            key:             ValueKey(_chartKey),
            tooltipBehavior: _tooltipBehavior,
            onTooltipRender: (TooltipArgs args) {
              final idx    = (args.pointIndex as num?)?.toInt() ?? 0;
              final points = args.dataPoints;
              if (points == null || idx >= points.length) return;
              final raw    = (points[idx].y as num?)?.toDouble() ?? 0.0;
              final label  = points[idx].x?.toString() ?? '';
              args.text    = label + ': ' + _fmtTooltip(raw, _type);
            },
            legend: const Legend(
              isVisible:    true,
              position:     LegendPosition.bottom,
              overflowMode: LegendItemOverflowMode.wrap,
            ),
            series: [
              DoughnutSeries<_PieSlice, String>(
                dataSource:       slices,
                xValueMapper:     (m, _) {
                  if (m.label == 'ShopeeFood') return 'Shopee';
                  if (m.label == 'GrabFood')   return 'Grab';
                  return m.label;
                },
                yValueMapper:     (m, _) => _getValue(m),
                pointColorMapper: (m, i) => _pieColor(m.key, i),
                dataLabelMapper:  (m, _) {
                  final v = _getValue(m);
                  if (total <= 0) return '';
                  final pct = v / total * 100;
                  return pct < 3 ? '' : '${pct.toStringAsFixed(1)}%';
                },
                dataLabelSettings: const DataLabelSettings(
                  isVisible:     true,
                  labelPosition: ChartDataLabelPosition.outside,
                  textStyle:     TextStyle(
                      fontSize: 10, fontWeight: FontWeight.w600),
                ),
                animationDuration: 300,
                innerRadius:       '55%',
                radius:            '85%',
              ),
            ],
          ),
        ),
      ]),
    );
  }
}

// ── Mode toggle (Nguồn / Loại) ────────────────────────────────────

class _PieModeToggle extends StatelessWidget {
  final int mode;
  final ValueChanged<int> onChanged;
  const _PieModeToggle({required this.mode, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final isDark  = Theme.of(context).brightness == Brightness.dark;
    final primary = isDark ? AppColors.primary : AppColors.primaryDark;
    final border  = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    return Container(
      decoration: BoxDecoration(
        color:        border.withOpacity(0.4),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        _btn(0, 'Nguồn', primary),
        _btn(1, 'Loại',  primary),
      ]),
    );
  }

  Widget _btn(int idx, String label, Color primary) {
    final active = mode == idx;
    return GestureDetector(
      onTap: () => onChanged(idx),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color:        active ? primary : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(label, style: TextStyle(
          fontSize:   11,
          fontWeight: FontWeight.w600,
          color:      active ? Colors.white : null,
        )),
      ),
    );
  }
}

// ── Type toggle (Doanh thu / Đơn hàng / Sản phẩm) ────────────────

class _TypeToggle extends StatelessWidget {
  final int type;
  final ValueChanged<int> onChanged;
  const _TypeToggle({required this.type, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final isDark  = Theme.of(context).brightness == Brightness.dark;
    final primary = isDark ? AppColors.primary : AppColors.primaryDark;
    final border  = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    return Container(
      decoration: BoxDecoration(
        color:        border.withOpacity(0.3),
        borderRadius: BorderRadius.circular(8),
        border:       Border.all(color: border.withOpacity(0.5)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        _btn(0, 'Doanh thu', primary),
        _btn(1, 'Đơn hàng',  primary),
        _btn(2, 'Sản phẩm',  primary),
      ]),
    );
  }

  Widget _btn(int idx, String label, Color primary) {
    final active = type == idx;
    return GestureDetector(
      onTap: () => onChanged(idx),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color:        active ? primary : Colors.transparent,
          borderRadius: BorderRadius.circular(7),
        ),
        child: Text(label, style: TextStyle(
          fontSize:   10,
          fontWeight: FontWeight.w600,
          color:      active ? Colors.white : null,
        )),
      ),
    );
  }
}