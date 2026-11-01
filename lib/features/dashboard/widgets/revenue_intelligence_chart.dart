// lib/features/dashboard/widgets/revenue_intelligence_chart.dart

import 'dart:ui' as ui;
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../data/models/dashboard/dashboard_period.dart';
import '../../../data/models/dashboard/revenue_intelligence_model.dart';
import '../controller/dashboard_controller.dart';

// ══════════════════════════════════════════════════════════════════
// COLOR CONSTANTS
// ══════════════════════════════════════════════════════════════════

const _colAlertLow       = Color(0x55EF4444); // đỏ đậm hơn
const _colBelowExpected  = Color(0x45F97316); // cam rõ ràng
const _colNormal         = Color(0x301EE0A7); // xanh lá nhạt
const _colAboveExpected  = Color(0x40416BF3); // teal/cyan
const _colStrongOutperf  = Color(0x55E879F9); // hồng fuchsia

const _colExpectedLine   = Color(0xFF1E293B);
const _colActualLine     = Color(0xFF2563EB);

// Layout constants
const _kPadL   = 55.0;  // Y-axis label width
const _kPadR   = 20.0;
const _kPadT   = 15.0;
const _kPadB   = 45.0;
const _kPointSpacing = 40.0; // px giữa 2 điểm liên tiếp
const _kMaxVisible   = 20;   // Số điểm hiển thị trong viewport

// ══════════════════════════════════════════════════════════════════
// MAIN WIDGET
// ══════════════════════════════════════════════════════════════════

class RevenueIntelligenceChart extends ConsumerStatefulWidget {
  const RevenueIntelligenceChart({super.key});

  @override
  ConsumerState<RevenueIntelligenceChart> createState() =>
      _RevenueIntelligenceChartState();
}

class _RevenueIntelligenceChartState
    extends ConsumerState<RevenueIntelligenceChart>
    with SingleTickerProviderStateMixin {
  late AnimationController _animCtrl;
  late Animation<double> _anim;
  int? _selectedIdx;

  // Scroll controller cho pan ngang
  final ScrollController _chartScrollCtrl = ScrollController();
  // Key để detect khi data thay đổi → scroll to end
  int _lastDataHash = 0;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900));
    _anim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic);
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    _chartScrollCtrl.dispose();
    super.dispose();
  }

  /// Kiểm tra khoảng thời gian < 7 ngày
  bool _isShortPeriod(DashboardState ctrl) {
    if (ctrl.period == DashboardPeriod.today) return true;
    if (ctrl.period == DashboardPeriod.custom &&
        ctrl.customFrom != null &&
        ctrl.customTo != null) {
      final days = ctrl.customTo!.difference(ctrl.customFrom!).inDays;
      return days < 7;
    }
    return false;
  }

  /// Tính Y range chung cho cả chart painter và Y-axis painter
  _YRange _computeYRange(List<RevenueIntelligenceSnapshot> snapshots) {
    double minY = double.infinity, maxY = 0;
    for (final s in snapshots) {
      for (final v in [s.actualRevenue, s.upper15, s.lower15, s.expectedRevenue]) {
        if (v < minY) minY = v;
        if (v > maxY) maxY = v;
      }
    }
    minY = (minY * 0.85).clamp(0, double.infinity);
    maxY = maxY * 1.1;
    if (maxY <= minY) maxY = minY + 1;
    return _YRange(minY, maxY);
  }

  /// Scroll tới cuối (dữ liệu mới nhất) sau khi build
  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_chartScrollCtrl.hasClients &&
          _chartScrollCtrl.position.maxScrollExtent > 0) {
        _chartScrollCtrl.jumpTo(_chartScrollCtrl.position.maxScrollExtent);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final ctrl   = ref.watch(dashboardControllerProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cs     = Theme.of(context).colorScheme;
    final border = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

    final riData  = ctrl.riData;
    final loading = ctrl.riLoading;

    // ── Check short period (< 7 ngày) ──────────────────────────
    final isShortPeriod = _isShortPeriod(ctrl);

    if (isShortPeriod) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: border),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.insights_rounded, size: 40,
                color: cs.onSurface.withOpacity(0.25)),
            const SizedBox(height: 14),
            Text(
              'Revenue Intelligence',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: cs.onSurface.withOpacity(0.7)),
            ),
            const SizedBox(height: 8),
            Text(
              'Cần ít nhất 7 ngày dữ liệu để phân tích.\n'
                  'Chọn từ "7 ngày" trở lên để xem.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: cs.onSurface.withOpacity(0.45)),
            ),
          ],
        ),
      );
    }

    // Chỉ show khi có data
    if (riData == null && !loading) return const SizedBox.shrink();

    // Detect data change → scroll to end
    final dataHash = riData?.snapshots.length.hashCode ?? 0;
    if (dataHash != _lastDataHash && riData != null && riData.snapshots.isNotEmpty) {
      _lastDataHash = dataHash;
      _animCtrl.reset();
      _animCtrl.forward();
      _scrollToEnd();
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // ── Header ─────────────────────────────────────────────
        Row(children: [
          Icon(Icons.insights_rounded,
              size: 16,
              color: isDark ? const Color(0xFF818CF8) : const Color(0xFF6366F1)),
          const SizedBox(width: 6),
          Text('Revenue Intelligence',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: cs.onSurface)),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFF6366F1).withOpacity(0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text('V1',
                style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: isDark
                        ? const Color(0xFF818CF8)
                        : const Color(0xFF6366F1))),
          ),
        ]),
        const SizedBox(height: 4),
        Text('Actual vs Expected Revenue — Vùng đánh giá động ±10%, ±20%',
            style: TextStyle(
                fontSize: 10.5, color: cs.onSurface.withOpacity(0.5))),
        const SizedBox(height: 12),

        // ── Chart body ─────────────────────────────────────────
        if (loading)
          const SizedBox(
              height: 300,
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)))
        else if (riData != null && riData.snapshots.isNotEmpty) ...[
          AnimatedBuilder(
            animation: _anim,
            builder: (_, __) => _buildScrollableChart(riData, isDark),
          ),
          const SizedBox(height: 6),
          // Hint pan
          if (riData.snapshots.length > _kMaxVisible)
            Center(
              child: Text('← Vuốt ngang để xem lịch sử →',
                  style: TextStyle(
                      fontSize: 9,
                      fontStyle: FontStyle.italic,
                      color: cs.onSurface.withOpacity(0.35))),
            ),
          const SizedBox(height: 8),

          // ── Summary badges ──────────────────────────────────
          _buildSummary(riData, isDark, cs),
        ] else
          SizedBox(
            height: 200,
            child: Center(
                child: Text('Không đủ dữ liệu cho Revenue Intelligence',
                    style: TextStyle(
                        fontSize: 12, color: cs.onSurface.withOpacity(0.5)))),
          ),
      ]),
    );
  }

  // ══════════════════════════════════════════════════════════════
  // SCROLLABLE CHART — Y-axis cố định + chart cuộn ngang
  // ══════════════════════════════════════════════════════════════

  Widget _buildScrollableChart(
      RevenueIntelligenceResponse riData, bool isDark) {
    final snapshots = riData.snapshots;
    final n = snapshots.length;
    final yRange = _computeYRange(snapshots);

    return LayoutBuilder(builder: (ctx, constraints) {
      final viewportWidth = constraints.maxWidth;

      // Tính width thực tế cho chart area (không bao gồm Y-axis)
      final chartAreaViewport = viewportWidth - _kPadL;

      // Mỗi điểm cách nhau _kPointSpacing px.
      // Nếu n <= _kMaxVisible thì fit vào viewport, ngược lại mở rộng.
      final double chartContentWidth;
      if (n <= 1) {
        chartContentWidth = chartAreaViewport;
      } else {
        final neededWidth = (n - 1) * _kPointSpacing + _kPadR;
        chartContentWidth = math.max(chartAreaViewport, neededWidth);
      }

      return SizedBox(
        height: 300,
        child: Stack(children: [
          // ── Scrollable chart area ──────────────────────────
          Padding(
            padding: const EdgeInsets.only(left: _kPadL),
            child: NotificationListener<ScrollNotification>(
              onNotification: (_) {
                // Clear selection khi scroll
                if (_selectedIdx != null) {
                  setState(() => _selectedIdx = null);
                }
                return false;
              },
              child: SingleChildScrollView(
                controller: _chartScrollCtrl,
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: GestureDetector(
                  onTapDown: (details) {
                    final idx = _hitTestChart(
                        details.localPosition, chartContentWidth, n);
                    setState(() =>
                    _selectedIdx = _selectedIdx == idx ? null : idx);
                  },
                  child: SizedBox(
                    width: chartContentWidth,
                    height: 300,
                    child: CustomPaint(
                      painter: _ChartAreaPainter(
                        snapshots: snapshots,
                        progress: _anim.value,
                        isDark: isDark,
                        selectedIdx: _selectedIdx,
                        yRange: yRange,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // ── Y-axis overlay (cố định bên trái) ────────────
          Positioned(
            left: 0, top: 0, bottom: 0,
            width: _kPadL,
            child: Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                border: Border(
                  right: BorderSide(
                    color: (isDark ? Colors.white : Colors.black)
                        .withOpacity(0.08),
                  ),
                ),
              ),
              child: CustomPaint(
                size: Size(_kPadL, 300),
                painter: _YAxisPainter(
                  yRange: yRange,
                  progress: _anim.value,
                  isDark: isDark,
                ),
              ),
            ),
          ),

          // ── Tooltip overlay ───────────────────────────────
          if (_selectedIdx != null && _selectedIdx! < n)
            _buildTooltipOverlay(snapshots, n, chartContentWidth,
                viewportWidth, isDark),
        ]),
      );
    });
  }

  // ── Hit test trong chart area (không có Y-axis padding) ───────

  int? _hitTestChart(Offset pos, double contentWidth, int n) {
    if (n <= 1) return n == 1 ? 0 : null;
    final w = contentWidth - _kPadR;
    final x = pos.dx;
    if (x < 0 || x > w) return null;
    return (x / (w / (n - 1))).round().clamp(0, n - 1);
  }

  // ── Tooltip positioned relative to viewport ──────────────────

  Widget _buildTooltipOverlay(
      List<RevenueIntelligenceSnapshot> snapshots,
      int n,
      double contentWidth,
      double viewportWidth,
      bool isDark) {
    final snap = snapshots[_selectedIdx!];

    // x position trong content
    final chartWidth = contentWidth - _kPadR;
    final xInContent = n <= 1
        ? chartWidth / 2
        : _selectedIdx! / (n - 1) * chartWidth;

    // Chuyển sang viewport coordinate
    final scrollOffset = _chartScrollCtrl.hasClients
        ? _chartScrollCtrl.offset
        : 0.0;
    final xInViewport = _kPadL + xInContent - scrollOffset;

    // Nếu điểm nằm ngoài viewport → ẩn tooltip
    if (xInViewport < _kPadL - 10 || xInViewport > viewportWidth + 10) {
      return const SizedBox.shrink();
    }

    // Tooltip width
    const tooltipW = 210.0;
    // Đặt tooltip bên phải của điểm, hoặc bên trái nếu quá sát mép phải
    double left = xInViewport + 14;
    if (left + tooltipW > viewportWidth) {
      left = xInViewport - tooltipW - 14;
    }
    left = left.clamp(0, viewportWidth - tooltipW);

    return Positioned(
      left: left, top: 0,
      child: _buildTooltipCard(snap, isDark),
    );
  }

  Widget _buildTooltipCard(RevenueIntelligenceSnapshot snap, bool isDark) {
    final cs  = Theme.of(context).colorScheme;
    final fmt = NumberFormat('#,###', 'vi_VN');

    final isPartial  = snap.partial;
    final classColor = isPartial
        ? const Color(0xFF94A3B8)
        : _classColor(snap.classification);
    final classLabel = isPartial ? 'Chưa chốt' : _classLabel(snap.classification);

    return Container(
      width: 210,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.18), blurRadius: 10)
        ],
        border: Border.all(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(children: [
              Text(snap.dateLabel,
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: cs.onSurface)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: classColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(4),
                  border: isPartial
                      ? Border.all(color: classColor.withOpacity(0.4), width: 1)
                      : null,
                ),
                child: Text(classLabel,
                    style: TextStyle(
                        fontSize: 8,
                        fontWeight: FontWeight.w700,
                        color: classColor)),
              ),
            ]),
            const SizedBox(height: 8),
            _tooltipRow(
                isPartial ? 'Actual (tạm)' : 'Actual',
                fmt.format(snap.actualRevenue), 'đ',
                isPartial ? _colActualLine.withOpacity(0.5) : _colActualLine),
            const SizedBox(height: 3),
            _tooltipRow('Expected', fmt.format(snap.expectedRevenue), 'đ',
                _colExpectedLine),
            const SizedBox(height: 3),
            _tooltipRow(
                'MA7', fmt.format(snap.ma7), 'đ', cs.onSurface.withOpacity(0.5)),
            _tooltipRow('MA28', fmt.format(snap.ma28), 'đ',
                cs.onSurface.withOpacity(0.5)),
            const SizedBox(height: 6),
            if (isPartial)
              Text('Ngày chưa kết thúc — chưa tính deviation',
                  style: TextStyle(
                      fontSize: 9,
                      fontStyle: FontStyle.italic,
                      color: cs.onSurface.withOpacity(0.45)))
            else ...[
              Row(children: [
                Text('Deviation: ',
                    style: TextStyle(
                        fontSize: 10,
                        color: cs.onSurface.withOpacity(0.6))),
                Text(
                    '${snap.deviationPct >= 0 ? '+' : ''}${snap.deviationPct.toStringAsFixed(1)}%',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: classColor)),
              ]),
              if (snap.consecutiveAbnormalDays > 1) ...[
                const SizedBox(height: 3),
                Text(
                    '${snap.consecutiveAbnormalDays} ngày liên tục ${snap.abnormalDirection == 'POSITIVE' ? '↑' : '↓'}',
                    style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        color: classColor)),
              ],
            ],
          ]),
    );
  }

  Widget _tooltipRow(String label, String value, String suffix, Color color) {
    final cs = Theme.of(context).colorScheme;
    return Row(children: [
      Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 5),
      Text('$label: ',
          style: TextStyle(fontSize: 10, color: cs.onSurface.withOpacity(0.6))),
      Text('$value$suffix',
          style: TextStyle(
              fontSize: 10, fontWeight: FontWeight.w600, color: cs.onSurface)),
    ]);
  }

  // ── Summary badges ────────────────────────────────────────────

  Widget _buildSummary(
      RevenueIntelligenceResponse data, bool isDark, ColorScheme cs) {
    // Tính thêm belowExpected & aboveExpected từ snapshots
    final belowExpected = data.snapshots
        .where((s) => !s.partial && s.classification == 'BELOW_EXPECTED')
        .length;
    final aboveExpected = data.snapshots
        .where((s) => !s.partial && s.classification == 'ABOVE_EXPECTED')
        .length;

    return Wrap(spacing: 8, runSpacing: 6, children: [
      _badge('${data.totalDays} ngày', cs.onSurface.withOpacity(0.6), isDark),
      _badge('${data.normalDays} bình thường', const Color(0xFF10B981), isDark),
      _badge('$belowExpected dưới kỳ vọng', const Color(0xFFF59E0B), isDark),
      _badge('$aboveExpected trên kỳ vọng', const Color(0xFF3B82F6), isDark),
      _badge('${data.alertLowDays} alert thấp', const Color(0xFFEF4444), isDark),
      _badge('${data.strongOutperformanceDays} vượt mạnh',
          const Color(0xFF8B5CF6), isDark),
    ]);
  }

  Widget _badge(String label, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 10, fontWeight: FontWeight.w600, color: color)),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────

  Color _classColor(String c) => switch (c) {
    'ALERT_LOW'              => const Color(0xFFEF4444),
    'BELOW_EXPECTED'         => const Color(0xFFF59E0B),
    'NORMAL'                 => const Color(0xFF10B981),
    'ABOVE_EXPECTED'         => const Color(0xFF3B82F6),
    'STRONG_OUTPERFORMANCE'  => const Color(0xFF8B5CF6),
    _ => const Color(0xFF64748B),
  };

  String _classLabel(String c) => switch (c) {
    'ALERT_LOW'              => 'Alert thấp',
    'BELOW_EXPECTED'         => 'Dưới kỳ vọng',
    'NORMAL'                 => 'Bình thường',
    'ABOVE_EXPECTED'         => 'Trên kỳ vọng',
    'STRONG_OUTPERFORMANCE'  => 'Vượt mạnh',
    _ => c,
  };
}

// ══════════════════════════════════════════════════════════════════
// Y-RANGE DATA CLASS
// ══════════════════════════════════════════════════════════════════

class _YRange {
  final double minY;
  final double maxY;
  double get range => maxY - minY;
  const _YRange(this.minY, this.maxY);
}

// ══════════════════════════════════════════════════════════════════
// Y-AXIS PAINTER — cố định bên trái, không cuộn
// ══════════════════════════════════════════════════════════════════

class _YAxisPainter extends CustomPainter {
  final _YRange yRange;
  final double progress;
  final bool isDark;

  _YAxisPainter({
    required this.yRange,
    required this.progress,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final h = size.height - _kPadT - _kPadB;
    final fmtC = NumberFormat.compactCurrency(locale: 'vi', symbol: '');
    final labelStyle = TextStyle(
        fontSize: 9,
        color: (isDark ? Colors.white : Colors.black).withOpacity(0.5));

    for (int i = 0; i <= 5; i++) {
      final val = yRange.minY + yRange.range * i / 5;
      final y = _kPadT + h - ((val - yRange.minY) / yRange.range * h * progress);
      _drawText(canvas, fmtC.format(val), Offset(0, y - 6), labelStyle,
          TextAlign.right, size.width - 6);
    }
  }

  void _drawText(Canvas canvas, String text, Offset off, TextStyle s,
      TextAlign a, double mw) {
    final tp = TextPainter(
        text: TextSpan(text: text, style: s),
        textDirection: ui.TextDirection.ltr,
        textAlign: a)
      ..layout(maxWidth: mw);
    tp.paint(canvas, off);
  }

  @override
  bool shouldRepaint(_YAxisPainter old) =>
      old.progress != progress || old.yRange != yRange;
}

// ══════════════════════════════════════════════════════════════════
// CHART AREA PAINTER — vẽ bands, lines, dots, x-labels
// Không vẽ Y-axis (đã tách ra _YAxisPainter).
// padL = 0 vì Y-axis nằm ngoài scroll area.
// ══════════════════════════════════════════════════════════════════

class _ChartAreaPainter extends CustomPainter {
  final List<RevenueIntelligenceSnapshot> snapshots;
  final double progress;
  final bool isDark;
  final int? selectedIdx;
  final _YRange yRange;

  _ChartAreaPainter({
    required this.snapshots,
    required this.progress,
    required this.isDark,
    required this.yRange,
    this.selectedIdx,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (snapshots.isEmpty) return;

    // Trong scroll area: padL = 0 (Y-axis ở ngoài)
    const padL = 0.0;
    final w = size.width - padL - _kPadR;
    final h = size.height - _kPadT - _kPadB;
    final n = snapshots.length;

    double yOf(double val) =>
        _kPadT + h - ((val - yRange.minY) / yRange.range * h * progress);
    double xOf(int i) => padL + (n == 1 ? w / 2 : i / (n - 1) * w);

    // ── Grid lines (horizontal) ───────────────────────────────
    final gridPaint = Paint()
      ..color = (isDark ? Colors.white : Colors.black).withOpacity(0.06)
      ..strokeWidth = 1;

    for (int i = 0; i <= 5; i++) {
      final val = yRange.minY + yRange.range * i / 5;
      final y = yOf(val);
      canvas.drawLine(Offset(padL, y), Offset(padL + w, y), gridPaint);
    }

    // ── X labels ──────────────────────────────────────────────
    final labelStyle = TextStyle(
        fontSize: 9,
        color: (isDark ? Colors.white : Colors.black).withOpacity(0.5));
    // Mỗi 1-5 điểm tuỳ mật độ
    final step = (n / 30).ceil().clamp(1, 999);
    for (int i = 0; i < n; i += step) {
      final x = xOf(i);
      _drawTextRotated(canvas, snapshots[i].dateLabel,
          Offset(x, size.height - _kPadB + 4), labelStyle, -0.52);
    }
    // Luôn vẽ label cuối
    if (n > 1 && (n - 1) % step != 0) {
      _drawTextRotated(canvas, snapshots[n - 1].dateLabel,
          Offset(xOf(n - 1), size.height - _kPadB + 4), labelStyle, -0.52);
    }

    // ── Draw bands (5 colored zones) ──────────────────────────
    _drawBand(canvas, n, xOf, (s) => yOf(yRange.minY), (s) => yOf(s.lower15),
        _colAlertLow);
    _drawBand(canvas, n, xOf, (s) => yOf(s.lower15), (s) => yOf(s.lower5),
        _colBelowExpected);
    _drawBand(canvas, n, xOf, (s) => yOf(s.lower5), (s) => yOf(s.upper5),
        _colNormal);
    _drawBand(canvas, n, xOf, (s) => yOf(s.upper5), (s) => yOf(s.upper15),
        _colAboveExpected);
    _drawBand(canvas, n, xOf, (s) => yOf(s.upper15), (s) => yOf(yRange.maxY),
        _colStrongOutperf);

    // ── Expected Revenue line ─────────────────────────────────
    _drawLine(canvas, n, xOf, (i) => yOf(snapshots[i].expectedRevenue),
        isDark ? Colors.white.withOpacity(0.8) : _colExpectedLine,
        2.5, false);

    // ── Actual Revenue line (solid for completed, dashed for partial) ──
    int lastCompleteIdx = n - 1;
    while (lastCompleteIdx >= 0 && snapshots[lastCompleteIdx].partial) {
      lastCompleteIdx--;
    }

    if (lastCompleteIdx >= 0) {
      _drawLine(canvas, lastCompleteIdx + 1, xOf,
              (i) => yOf(snapshots[i].actualRevenue),
          _colActualLine, 2.5, true);
    }

    // Dashed line + hollow dot cho partial day
    if (lastCompleteIdx < n - 1 && lastCompleteIdx >= 0) {
      final partialPaint = Paint()
        ..color = _colActualLine.withOpacity(0.4)
        ..strokeWidth = 2.0
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;

      final p1 = Offset(
          xOf(lastCompleteIdx), yOf(snapshots[lastCompleteIdx].actualRevenue));
      final p2 = Offset(xOf(lastCompleteIdx + 1),
          yOf(snapshots[lastCompleteIdx + 1].actualRevenue));
      final dist = (p2 - p1).distance;
      final segs = (dist / 8).floor().clamp(1, 999);
      for (int j = 0; j < segs; j++) {
        if (j % 2 == 0) {
          canvas.drawLine(
              Offset.lerp(p1, p2, j / segs)!,
              Offset.lerp(p1, p2, (j + 0.6) / segs)!, partialPaint);
        }
      }

      // Hollow dot
      final px = xOf(lastCompleteIdx + 1);
      final py = yOf(snapshots[lastCompleteIdx + 1].actualRevenue);
      canvas.drawCircle(
          Offset(px, py),
          5,
          Paint()
            ..color = (isDark ? const Color(0xFF1E293B) : Colors.white)
            ..style = PaintingStyle.fill);
      canvas.drawCircle(
          Offset(px, py),
          5,
          Paint()
            ..color = _colActualLine.withOpacity(0.5)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2);
    }

    // ── Selected vertical line ────────────────────────────────
    if (selectedIdx != null && selectedIdx! < n) {
      final x = xOf(selectedIdx!);
      canvas.drawLine(
          Offset(x, _kPadT),
          Offset(x, _kPadT + h),
          Paint()
            ..color = Colors.grey.withOpacity(0.3)
            ..strokeWidth = 1);

      final s = snapshots[selectedIdx!];
      _drawDot(canvas, x, yOf(s.expectedRevenue),
          isDark ? Colors.white : _colExpectedLine, 5);

      if (s.partial) {
        canvas.drawCircle(
            Offset(x, yOf(s.actualRevenue)),
            7,
            Paint()
              ..color = _colActualLine.withOpacity(0.15)
              ..style = PaintingStyle.fill);
        canvas.drawCircle(
            Offset(x, yOf(s.actualRevenue)),
            7,
            Paint()
              ..color = _colActualLine.withOpacity(0.6)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2);
      } else {
        _drawDot(canvas, x, yOf(s.actualRevenue), _colActualLine, 6);
      }
    }
  }

  // ── Band drawing ──────────────────────────────────────────────

  void _drawBand(
      Canvas canvas,
      int n,
      double Function(int) xOf,
      double Function(RevenueIntelligenceSnapshot) topYOf,
      double Function(RevenueIntelligenceSnapshot) botYOf,
      Color color) {
    if (n == 0) return;
    final path = Path();
    path.moveTo(xOf(0), botYOf(snapshots[0]));
    for (int i = 0; i < n; i++) {
      path.lineTo(xOf(i), botYOf(snapshots[i]));
    }
    for (int i = n - 1; i >= 0; i--) {
      path.lineTo(xOf(i), topYOf(snapshots[i]));
    }
    path.close();
    canvas.drawPath(path, Paint()..color = color..style = PaintingStyle.fill);
  }

  // ── Line drawing ──────────────────────────────────────────────

  void _drawLine(Canvas canvas, int n, double Function(int) xOf,
      double Function(int) yOf, Color color, double width, bool showDots) {
    if (n == 0) return;
    final totalPts = (n * progress).ceil().clamp(1, n);
    final paint = Paint()
      ..color = color
      ..strokeWidth = width
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path()..moveTo(xOf(0), yOf(0));
    for (int i = 1; i < totalPts; i++) {
      path.lineTo(xOf(i), yOf(i));
    }
    canvas.drawPath(path, paint);

    if (showDots) {
      final dotPaint = Paint()..color = color..style = PaintingStyle.fill;
      final dotBorder = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;
      for (int i = 0; i < totalPts; i++) {
        canvas.drawCircle(Offset(xOf(i), yOf(i)), 4, dotPaint);
        canvas.drawCircle(Offset(xOf(i), yOf(i)), 4, dotBorder);
      }
    }
  }

  void _drawDot(Canvas canvas, double x, double y, Color c, double r) {
    canvas.drawCircle(
        Offset(x, y), r + 3, Paint()..color = c.withOpacity(0.2));
    canvas.drawCircle(Offset(x, y), r, Paint()..color = c);
  }

  // ── Text helpers ──────────────────────────────────────────────

  void _drawTextRotated(
      Canvas canvas, String text, Offset pivot, TextStyle s, double angle) {
    final tp = TextPainter(
        text: TextSpan(text: text, style: s),
        textDirection: ui.TextDirection.ltr)
      ..layout(maxWidth: 60);
    canvas.save();
    canvas.translate(pivot.dx, pivot.dy);
    canvas.rotate(angle);
    tp.paint(canvas, Offset(-tp.width / 2, 0));
    canvas.restore();
  }

  @override
  bool shouldRepaint(_ChartAreaPainter old) =>
      old.progress != progress ||
          old.selectedIdx != selectedIdx ||
          old.snapshots != snapshots;
}