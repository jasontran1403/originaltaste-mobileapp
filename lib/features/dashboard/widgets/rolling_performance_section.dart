// lib/features/dashboard/widgets/rolling_performance_section.dart
//
// Khu vực "Rolling Performance" — cửa sổ trượt 7 / 28 / 30 ngày.
// Hiển thị 4 chỉ số (Doanh thu, Số đơn, Số sản phẩm, AOV): giá trị hiện tại,
// so với kỳ liền trước cùng độ dài (%), và line chart xu hướng theo ngày.
//
// Ẩn hoàn toàn (SizedBox.shrink) khi rollingWindow == null.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

import '../../../app/theme/app_colors.dart';
import '../../../data/models/dashboard/rolling_performance_model.dart';
import '../../../shared/widgets/dashboard_shared_widgets.dart';
import '../controller/dashboard_controller.dart';

// Màu thống nhất cho 4 chỉ số
const _cRevenue   = Color(0xFF2563EB); // xanh dương
const _cOrders    = Color(0xFF22C55E); // xanh lá
const _cProducts  = Color(0xFFD946EF); // hồng tím
const _cAov       = Color(0xFFF59E0B); // cam

/// Nhãn trục gọn: 1500 → "1,5K", 2000000 → "2M".
/// Dùng cho 2 trục đếm (Số đơn / Số sản phẩm) để không chiếm chỗ biểu đồ.
String _axisLabel(num v) {
  final d = v.toDouble();
  final a = d.abs();
  String trim(String s) =>
      s.endsWith('.0') ? s.substring(0, s.length - 2) : s;

  if (a >= 1000000) {
    return '${trim((d / 1000000).toStringAsFixed(1)).replaceAll('.', ',')}M';
  }
  if (a >= 1000) {
    return '${trim((d / 1000).toStringAsFixed(1)).replaceAll('.', ',')}K';
  }
  return trim(d.toStringAsFixed(d == d.roundToDouble() ? 0 : 1))
      .replaceAll('.', ',');
}

class RollingPerformanceSection extends ConsumerWidget {
  const RollingPerformanceSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(dashboardControllerProvider);
    if (s.rollingWindow == null) return const SizedBox.shrink();

    final isDark  = Theme.of(context).brightness == Brightness.dark;
    final primary = isDark ? AppColors.primary : AppColors.primaryDark;
    final border  = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final cardBg  = isDark ? AppColors.darkCard   : AppColors.lightCard;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color:        cardBg,
        borderRadius: BorderRadius.circular(12),
        border:       Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ────────────────────────────────────────────
          Row(children: [
            Icon(Icons.timelapse, size: 18, color: primary),
            const SizedBox(width: 8),
            const DashboardSectionTitle('Rolling Performance'),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color:        primary.withOpacity(0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${s.rollingWindow} ngày gần nhất',
                style: TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w600, color: primary),
              ),
            ),
          ]),
          const SizedBox(height: 4),
          Text(
            'So sánh với ${s.rollingWindow} ngày liền trước',
            style: TextStyle(
                fontSize: 11.5,
                color: Theme.of(context).textTheme.bodySmall?.color),
          ),
          const SizedBox(height: 14),

          // ── Body ──────────────────────────────────────────────
          if (s.rollingLoading && s.rollingData == null)
            _loading(primary)
          else if (s.rollingError != null && s.rollingData == null)
            _error(s.rollingError!)
          else if (s.rollingData != null)
              _content(context, s.rollingData!, isDark)
            else
              const SizedBox(
                height: 80,
                child: Center(child: Text('Không có dữ liệu')),
              ),
        ],
      ),
    );
  }

  Widget _loading(Color primary) => SizedBox(
    height: 120,
    child: Center(
      child: CircularProgressIndicator(color: primary, strokeWidth: 2),
    ),
  );

  Widget _error(String msg) => SizedBox(
    height: 80,
    child: Center(
      child: Text(msg,
          style: const TextStyle(color: AppColors.error, fontSize: 12)),
    ),
  );

  Widget _content(BuildContext context, RollingPerformanceModel d, bool isDark) {
    final cur = d.current;
    final dp  = d.deltaPct;

    return LayoutBuilder(builder: (context, c) {
      final isNarrow = c.maxWidth < 560;

      final cards = <Widget>[
        _KpiCard(
          label: 'Doanh thu',
          value: fmtCurrencyShort(cur.revenue),
          deltaPct: dp.revenue,
          color: _cRevenue,
          icon: Icons.payments_outlined,
        ),
        _KpiCard(
          label: 'Số đơn',
          value: fmtNum(cur.orders),
          deltaPct: dp.orders,
          color: _cOrders,
          icon: Icons.receipt_long_outlined,
        ),
        _KpiCard(
          label: 'Số sản phẩm',
          value: fmtNum(cur.products),
          deltaPct: dp.products,
          color: _cProducts,
          icon: Icons.fastfood_outlined,
        ),
        _KpiCard(
          label: 'AOV',
          value: fmtCurrencyShort(cur.aov),
          deltaPct: dp.aov,
          color: _cAov,
          icon: Icons.trending_up_outlined,
        ),
      ];

      final grid = isNarrow
          ? Column(children: [
        Row(children: [
          Expanded(child: cards[0]),
          const SizedBox(width: 10),
          Expanded(child: cards[1]),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: cards[2]),
          const SizedBox(width: 10),
          Expanded(child: cards[3]),
        ]),
      ])
          : Row(children: [
        for (int i = 0; i < cards.length; i++) ...[
          Expanded(child: cards[i]),
          if (i != cards.length - 1) const SizedBox(width: 10),
        ],
      ]);

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          grid,
          const SizedBox(height: 16),
          Text('Xu hướng rolling ${d.window} ngày',
              style: const TextStyle(
                  fontSize: 12.5, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          SizedBox(height: 280, child: _chart(d, isDark)),
        ],
      );
    });
  }

  Widget _chart(RollingPerformanceModel d, bool isDark) {
    final data = d.series;
    if (data.isEmpty) {
      return const Center(child: Text('Không có dữ liệu'));
    }

    // Cấu hình trục:
    //   • TRÁI  = đơn vị ĐẾM  → dùng CHUNG cho 2 cột (Số đơn + Số sản phẩm),
    //             nên 2 cột so sánh trực tiếp được, không scale riêng.
    //   • PHẢI  = đơn vị TIỀN → line Doanh thu.
    //   • AOV   = trục ẩn riêng, vẫn tự co giãn như trước
    //             (giá trị chính xác xem ở trackball tooltip).
    return SfCartesianChart(
      enableAxisAnimation: false,
      primaryXAxis: const CategoryAxis(
        labelRotation: -30,
        majorGridLines: MajorGridLines(width: 0),
      ),
      // ── TRỤC TRÁI: Số đơn + Số sản phẩm (chung thang đo) ───────
      primaryYAxis: NumericAxis(
        name: 'count',
        title: const AxisTitle(
          text: '',
          textStyle: TextStyle(
              fontSize: 10, fontWeight: FontWeight.w700, color: _cOrders),
        ),
        labelStyle: const TextStyle(fontSize: 10, color: _cOrders),
        axisLabelFormatter: (args) =>
            ChartAxisLabel(_axisLabel(args.value), args.textStyle),
        axisLine: const AxisLine(width: 1, color: _cOrders),
        majorTickLines: const MajorTickLines(size: 4, color: _cOrders),
        minimum: 0,
      ),
      axes: <ChartAxis>[
        // ── TRỤC PHẢI: Doanh thu (tiền) ─────────────────────────
        NumericAxis(
          name: 'money',
          opposedPosition: true,
          title: const AxisTitle(
            text: '',
            textStyle: TextStyle(
                fontSize: 10, fontWeight: FontWeight.w700, color: _cRevenue),
          ),
          labelStyle: const TextStyle(fontSize: 10, color: _cRevenue),
          axisLabelFormatter: (args) =>
              ChartAxisLabel(_axisLabel(args.value), args.textStyle),
          majorGridLines: const MajorGridLines(width: 0),
          axisLine: const AxisLine(width: 1, color: _cRevenue),
          majorTickLines: const MajorTickLines(size: 4, color: _cRevenue),
          minimum: 0,
        ),
        // Trục ẩn: AOV (line cam) — tự co giãn
        const NumericAxis(name: 'aov', isVisible: false, opposedPosition: true),
      ],
      legend: const Legend(
        isVisible: true,
        position: LegendPosition.top,
        overflowMode: LegendItemOverflowMode.wrap,
      ),
      // Chạm vào bất kỳ đâu theo trục X → hiện cả 4 chỉ số
      trackballBehavior: TrackballBehavior(
        enable: true,
        activationMode: ActivationMode.singleTap,
        tooltipDisplayMode: TrackballDisplayMode.groupAllPoints,
        lineType: TrackballLineType.vertical,
        markerSettings: const TrackballMarkerSettings(
          markerVisibility: TrackballVisibilityMode.visible,
        ),
        builder: (context, details) {
          int idx = -1;
          final g = details.groupingModeInfo;
          if (g != null && g.currentPointIndices.isNotEmpty) {
            idx = g.currentPointIndices.first;
          } else if (details.pointIndex != null) {
            idx = details.pointIndex!;
          }
          if (idx < 0 || idx >= data.length) return const SizedBox.shrink();
          return _tooltipCard(data[idx], isDark);
        },
      ),
      series: <CartesianSeries<RollingPoint, String>>[
        // ── Cột: Số đơn + Số sản phẩm — CÙNG trục trái 'count' ────
        ColumnSeries<RollingPoint, String>(
          name: 'Số đơn',
          dataSource: data,
          xValueMapper: (e, _) => e.shortLabel,
          yValueMapper: (e, _) => e.orders,
          yAxisName: 'count',
          color: _cOrders,
          width: 0.7,
          spacing: 0.15,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(2)),
        ),
        ColumnSeries<RollingPoint, String>(
          name: 'Số sản phẩm',
          dataSource: data,
          xValueMapper: (e, _) => e.shortLabel,
          yValueMapper: (e, _) => e.products,
          yAxisName: 'count',
          color: _cProducts,
          width: 0.7,
          spacing: 0.15,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(2)),
        ),

        // ── Line: Doanh thu (trục phải) + AOV (trục ẩn) ───────────
        // Mỗi ngày có 1 dot tròn viền trắng để đọc được từng điểm.
        LineSeries<RollingPoint, String>(
          name: 'Doanh thu',
          dataSource: data,
          xValueMapper: (e, _) => e.shortLabel,
          yValueMapper: (e, _) => e.revenue,
          yAxisName: 'money',
          color: _cRevenue,
          width: 2,
          // QUAN TRỌNG: phải set `color` cho marker.
          // Bỏ trống thì Syncfusion tô marker bằng màu nền plot area
          // (trắng ở light mode) → chấm trắng viền trắng = vô hình.
          markerSettings: const MarkerSettings(
            isVisible: true,
            shape: DataMarkerType.circle,
            height: 8,
            width: 8,
            color: _cRevenue,
            borderWidth: 1.5,
            borderColor: Colors.white,
          ),
        ),
        LineSeries<RollingPoint, String>(
          name: 'AOV',
          dataSource: data,
          xValueMapper: (e, _) => e.shortLabel,
          yValueMapper: (e, _) => e.aov,
          yAxisName: 'aov',
          color: _cAov,
          width: 2,
          dashArray: const [6, 3],
          markerSettings: const MarkerSettings(
            isVisible: true,
            shape: DataMarkerType.circle,
            height: 8,
            width: 8,
            color: _cAov,
            borderWidth: 1.5,
            borderColor: Colors.white,
          ),
        ),
      ],
    );
  }

  // Tooltip gộp cả 4 chỉ số cho ngày được chạm
  Widget _tooltipCard(RollingPoint p, bool isDark) {
    final bg     = isDark ? const Color(0xFF23262B) : Colors.white;
    final txt    = isDark ? Colors.white : const Color(0xFF1F2937);
    final vnFull = NumberFormat('#,##0', 'vi_VN');

    Widget row(Color c, String label, String value) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 1.5),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 8, height: 8,
            decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text('$label: ',
            style: TextStyle(fontSize: 11, color: txt.withOpacity(0.75))),
        Text(value,
            style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.w700, color: txt)),
      ]),
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.18), blurRadius: 8),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Ngày ${p.shortLabel}',
              style: TextStyle(
                  fontSize: 11.5, fontWeight: FontWeight.w800, color: txt)),
          const SizedBox(height: 4),
          row(_cRevenue,   'Doanh thu', '${vnFull.format(p.revenue)} đ'),
          row(_cOrders,    'Số đơn',    vnFull.format(p.orders)),
          row(_cProducts, 'Số sản phẩm', vnFull.format(p.products)),
          row(_cAov,       'AOV',       '${vnFull.format(p.aov)} đ'),
        ],
      ),
    );
  }
}

// ── KPI card ─────────────────────────────────────────────────────
class _KpiCard extends StatelessWidget {
  final String  label;
  final String  value;
  final double? deltaPct;   // null = không xác định (kỳ trước = 0)
  final Color   color;
  final IconData icon;

  const _KpiCard({
    required this.label,
    required this.value,
    required this.deltaPct,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = color.withOpacity(isDark ? 0.14 : 0.08);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color:        bg,
        borderRadius: BorderRadius.circular(10),
        border:       Border.all(color: color.withOpacity(0.28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, size: 15, color: color),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: color),
              ),
            ),
          ]),
          const SizedBox(height: 8),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          _DeltaChip(deltaPct: deltaPct),
        ],
      ),
    );
  }
}

class _DeltaChip extends StatelessWidget {
  final double? deltaPct;
  const _DeltaChip({required this.deltaPct});

  @override
  Widget build(BuildContext context) {
    if (deltaPct == null) {
      return Text('— so kỳ trước',
          style: TextStyle(
              fontSize: 10.5,
              color: Theme.of(context).textTheme.bodySmall?.color));
    }
    final up   = deltaPct! >= 0;
    final c    = up ? const Color(0xFF16A34A) : const Color(0xFFDC2626);
    final sign = up ? '+' : '';
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(up ? Icons.arrow_upward : Icons.arrow_downward, size: 12, color: c),
      const SizedBox(width: 2),
      Text(
        '$sign${deltaPct!.toStringAsFixed(1)}%',
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: c),
      ),
      const SizedBox(width: 3),
      Text('so kỳ trước',
          style: TextStyle(
              fontSize: 10,
              color: Theme.of(context).textTheme.bodySmall?.color)),
    ]);
  }
}