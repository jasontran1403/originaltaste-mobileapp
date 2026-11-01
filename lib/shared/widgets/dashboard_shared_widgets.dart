// lib/features/dashboard/widgets/dashboard_shared_widgets.dart
//
// Tập hợp các widget dùng chung giữa POS, Wholesale, Retail dashboard.

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_datepicker/datepicker.dart';
import '../../../app/theme/app_colors.dart';
import '../../../data/models/dashboard/dashboard_period.dart';

// ══════════════════════════════════════════════════════════════════
// FORMATTERS (top-level functions để các widget khác dùng)
// ══════════════════════════════════════════════════════════════════

String fmtCurrency(double v) => NumberFormat('#,###', 'vi_VN').format(v);
String fmtNum(num v)         => NumberFormat('#,###', 'vi_VN').format(v);
String fmtDate(int? ts) {
  if (ts == null) return '—';
  return DateFormat('dd/MM HH:mm').format(DateTime.fromMillisecondsSinceEpoch(ts));
}

String fmtCompact(double v) {
  if (v >= 1e9) {
    final t = v / 1e9;
    return t % 1 == 0 ? '${t.toInt()} Tỷ' : '${t.toStringAsFixed(1)} Tỷ';
  }
  if (v >= 1e6) {
    final t = v / 1e6;
    return t % 1 == 0 ? '${t.toInt()} Tr' : '${t.toStringAsFixed(1)} Tr';
  }
  if (v >= 1e3) {
    final t = v / 1e3;
    return t % 1 == 0 ? '${t.toInt()}K' : '${t.toStringAsFixed(1)}K';
  }
  return fmtNum(v.toInt());
}

// ══════════════════════════════════════════════════════════════════
// STATUS HELPERS
// ══════════════════════════════════════════════════════════════════

Color statusColor(String s) => switch (s) {
  'COMPLETED'  => Colors.green,
  'CANCELLED'  => Colors.red,
  'FAILED'     => Colors.red,
  'PENDING'    => Colors.orange,
  'DELIVERING' => Colors.blue,
  _            => Colors.grey,
};

String statusLabel(String s) => switch (s) {
  'COMPLETED'  => 'Hoàn thành',
  'CANCELLED'  => 'Đã hủy',
  'FAILED'     => 'Thất bại',
  'PENDING'    => 'Chờ xử lý',
  'CONFIRMED'  => 'Xác nhận',
  'PREPARING'  => 'Đang làm',
  'READY'      => 'Sẵn sàng',
  'DELIVERING' => 'Giao hàng',
  _            => s,
};

// ══════════════════════════════════════════════════════════════════
// SECTION TITLE
// ══════════════════════════════════════════════════════════════════

class DashboardSectionTitle extends StatelessWidget {
  final String text;
  const DashboardSectionTitle(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Text(
      text,
      style: TextStyle(
        fontWeight: FontWeight.w700,
        fontSize: 14,
        color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════
// STATUS BADGE
// ══════════════════════════════════════════════════════════════════

class StatusBadge extends StatelessWidget {
  final String label;
  final Color  color;
  const StatusBadge({super.key, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color:        color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize:   10,
          fontWeight: FontWeight.w600,
          color:      color,
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════
// PERIOD FILTER
// ══════════════════════════════════════════════════════════════════

class DashboardPeriodFilter extends StatelessWidget {
  final DashboardPeriod  selected;
  final DateTime?        customFrom;
  final DateTime?        customTo;
  final void Function(DashboardPeriod)  onSelect;
  final void Function(DateTime, DateTime) onCustom;

  // Rolling Window (chỉ hiện khi onRollingSelect != null — dành cho SUPERADMIN)
  final int?                  rollingWindow;   // null = tắt; 7 | 28 | 30
  final void Function(int?)?  onRollingSelect;

  const DashboardPeriodFilter({
    super.key,
    required this.selected,
    required this.customFrom,
    required this.customTo,
    required this.onSelect,
    required this.onCustom,
    this.rollingWindow,
    this.onRollingSelect,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          ...DashboardPeriod.values
              .where((p) => p != DashboardPeriod.custom)
              .map((p) => _PeriodChip(
            period:   p,
            selected: selected == p,
            onTap:    () => onSelect(p),
          )),
          _CustomChip(
            selected:   selected == DashboardPeriod.custom,
            customFrom: customFrom,
            customTo:   customTo,
            onPicked:   onCustom,
          ),
          if (onRollingSelect != null)
            _RollingChip(
              window:   rollingWindow,
              onSelect: onRollingSelect!,
            ),
        ],
      ),
    );
  }
}

// ── Rolling Window chip (popup 7 / 28 / 30 + Tắt) ─────────────────
class _RollingChip extends StatelessWidget {
  final int?                 window;   // null = tắt
  final void Function(int?)  onSelect;

  const _RollingChip({required this.window, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final isDark  = Theme.of(context).brightness == Brightness.dark;
    final primary = isDark ? AppColors.primary : AppColors.primaryDark;
    final bool selected = window != null;
    final String label = selected ? 'Rolling ${window}n' : 'Rolling Window';

    return PopupMenuButton<int>(
      tooltip: 'Rolling Window',
      offset:  const Offset(0, 38),
      onSelected: (v) => onSelect(v),
      itemBuilder: (_) => [
        _rollItem(7,  '7 ngày',  window),
        _rollItem(28, '28 ngày', window),
        _rollItem(30, '30 ngày', window),
      ],
      child: Container(
        margin:  const EdgeInsets.only(right: 6),
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
        decoration: BoxDecoration(
          color:        selected ? primary : primary.withOpacity(0.07),
          borderRadius: BorderRadius.circular(20),
          border:       Border.all(
            color: selected ? primary : primary.withOpacity(0.22),
          ),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.timelapse,
              size: 13, color: selected ? Colors.white : primary),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize:   11,
              fontWeight: FontWeight.w600,
              color:      selected ? Colors.white : null,
            ),
          ),
          Icon(Icons.arrow_drop_down,
              size: 16, color: selected ? Colors.white : primary),
        ]),
      ),
    );
  }

  PopupMenuItem<int> _rollItem(int value, String text, int? current) =>
      PopupMenuItem<int>(
        value: value,
        child: Row(children: [
          Icon(
            current == value
                ? Icons.radio_button_checked
                : Icons.radio_button_unchecked,
            size: 16,
          ),
          const SizedBox(width: 8),
          Text(text, style: const TextStyle(fontSize: 13)),
        ]),
      );
}

class _PeriodChip extends StatelessWidget {
  final DashboardPeriod period;
  final bool            selected;
  final VoidCallback    onTap;

  const _PeriodChip({
    required this.period,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = isDark ? AppColors.primary : AppColors.primaryDark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 6),
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
        decoration: BoxDecoration(
          color:        selected ? primary : primary.withOpacity(0.07),
          borderRadius: BorderRadius.circular(20),
          border:       Border.all(
            color: selected ? primary : primary.withOpacity(0.22),
          ),
        ),
        child: Text(
          period.label,
          style: TextStyle(
            fontSize:   11,
            fontWeight: FontWeight.w600,
            color:      selected ? Colors.white : null,
          ),
        ),
      ),
    );
  }
}

String fmtCurrencyShort(double value) {
  if (value >= 1000000000) {
    final v = value / 1000000000;
    // Nếu chẵn tỷ thì bỏ thập phân
    final s = v == v.truncateToDouble() ? v.toInt().toString() : v.toStringAsFixed(2);
    return '$s Tỷ';
  }
  if (value >= 1000000) {
    final v = value / 1000000;
    final s = v == v.truncateToDouble() ? v.toInt().toString() : v.toStringAsFixed(2);
    return '$s Tr';
  }
  // < 1 triệu: dùng format thường (có dấu phân cách)
  return fmtCurrency(value);
}

class _CustomChip extends StatelessWidget {
  final bool selected;
  final DateTime? customFrom;
  final DateTime? customTo;
  final void Function(DateTime, DateTime) onPicked;

  const _CustomChip({
    required this.selected,
    required this.customFrom,
    required this.customTo,
    required this.onPicked,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = isDark ? AppColors.primary : AppColors.primaryDark;

    return GestureDetector(
      onTap: () async {
        DateTimeRange? selectedRange;

        await showDialog(
          context: context,
          builder: (context) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
              contentPadding: const EdgeInsets.all(16),
              content: SizedBox(
                width: 300,
                height: 400,
                child: SfDateRangePicker(
                  selectionMode: DateRangePickerSelectionMode.range,
                  initialSelectedRange: selected && customFrom != null && customTo != null
                      ? PickerDateRange(customFrom, customTo)
                      : null,
                  monthViewSettings: DateRangePickerMonthViewSettings(
                    firstDayOfWeek: 1,
                    weekendDays: const [6, 7],
                    viewHeaderStyle: DateRangePickerViewHeaderStyle(
                      textStyle: TextStyle(color: isDark ? Colors.white : Colors.black),
                    ),
                  ),
                  selectionColor: primary,
                  rangeSelectionColor: primary.withOpacity(0.2),
                  startRangeSelectionColor: primary,
                  endRangeSelectionColor: primary,
                  todayHighlightColor: primary,
                  headerStyle: DateRangePickerHeaderStyle(
                    textStyle: TextStyle(color: isDark ? Colors.white : Colors.black, fontWeight: FontWeight.bold),
                    backgroundColor: isDark ? AppColors.darkCard : Colors.white,
                  ),
                  backgroundColor: isDark ? AppColors.darkCard : Colors.white,
                  onSelectionChanged: (args) {
                    if (args.value is PickerDateRange) {
                      final range = args.value as PickerDateRange;
                      selectedRange = DateTimeRange(
                        start: range.startDate!,
                        end: range.endDate ?? range.startDate!,
                      );
                    }
                  },
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Hủy'),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: const Text('Chọn'),
                ),
              ],
            );
          },
        );

        if (selectedRange != null) {
          onPicked(
            selectedRange!.start,
            selectedRange!.end.copyWith(hour: 23, minute: 59, second: 59),
          );
        }
      },
      child: Container(
        margin: const EdgeInsets.only(right: 6),
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? primary : primary.withOpacity(0.07),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? primary : primary.withOpacity(0.22),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.calendar_today_outlined,
              size: 11,
              color: selected ? Colors.white : primary,
            ),
            const SizedBox(width: 4),
            Text(
              selected && customFrom != null
                  ? '${DateFormat('dd/MM').format(customFrom!)} – ${DateFormat('dd/MM').format(customTo!)}'
                  : 'Tuỳ chọn',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════
// MODE TOGGLE (POS / Sỉ / Lẻ) — chỉ dùng cho SuperAdmin
// ══════════════════════════════════════════════════════════════════

class DashboardModeToggle extends StatelessWidget {
  final int                       selected; // 0=POS, 1=Sỉ, 2=Lẻ
  final void Function(int) onChanged;

  const DashboardModeToggle({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isDark  = Theme.of(context).brightness == Brightness.dark;
    final primary = isDark ? AppColors.primary : AppColors.primaryDark;
    final border  = isDark ? AppColors.darkBorder : AppColors.lightBorder;

    return Container(
      height: 34,
      decoration: BoxDecoration(
        color:        border.withOpacity(0.4),
        borderRadius: BorderRadius.circular(9),
        border:       Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ModeTab(label: 'POS', active: selected == 0, primary: primary,
              onTap: () => onChanged(0)),
          _ModeTab(label: 'Sỉ',  active: selected == 1, primary: primary,
              onTap: () => onChanged(1)),
          _ModeTab(label: 'Lẻ',  active: selected == 2, primary: primary,
              onTap: () => onChanged(2)),
        ],
      ),
    );
  }
}

class _ModeTab extends StatelessWidget {
  final String       label;
  final bool         active;
  final Color        primary;
  final VoidCallback onTap;

  const _ModeTab({
    required this.label,
    required this.active,
    required this.primary,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color:        active ? primary : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize:   12,
            fontWeight: FontWeight.w700,
            color:      active ? Colors.white : null,
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════
// STAT CARD — dùng chung cho cả POS và Restaurant
// ══════════════════════════════════════════════════════════════════

class DashboardStatCard extends StatelessWidget {
  final IconData icon;
  final Color    color;
  final String   title;
  final String   line1;
  final String   line2;
  final double   value;
  final bool     isCurrency;

  const DashboardStatCard({
    super.key,
    required this.icon,
    required this.color,
    required this.title,
    required this.value,
    required this.isCurrency,
    this.line1 = '',
    this.line2 = '',
  });

  String _fmt(double v) => isCurrency
      ? fmtCompact(v)
      : fmtNum(v.toInt());

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color:        isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color:        color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, size: 20, color: color),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color:        color.withOpacity(0.10),
              borderRadius: BorderRadius.circular(5),
            ),
            child: Text(
              title,
              style: TextStyle(
                fontSize:   10,
                fontWeight: FontWeight.w700,
                color:      color,
              ),
            ),
          ),
        ]),
        const SizedBox(height: 14),
        TweenAnimationBuilder<double>(
          tween:    Tween<double>(begin: 0, end: value),
          duration: const Duration(milliseconds: 1400),
          curve:    Curves.easeOut,
          builder:  (_, v, __) => FittedBox(
            fit:       BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              _fmt(v),
              style: TextStyle(
                fontSize:   22,
                fontWeight: FontWeight.w800,
                color:      color,
              ),
            ),
          ),
        ),
        if (line1.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(line1, style: Theme.of(context).textTheme.labelSmall),
        ],
        if (line2.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(line2, style: Theme.of(context).textTheme.labelSmall),
        ],
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════════
// ORDER ID CELL
// ══════════════════════════════════════════════════════════════════

class OrderIdCell extends StatelessWidget {
  final String code;
  final Color  color;
  final double fontSize;

  const OrderIdCell({
    super.key,
    required this.code,
    required this.color,
    this.fontSize = 11,
  });

  List<String> _parseLines() {
    final parts = code.split('-');
    if (parts.isEmpty) return [code];
    final rest = parts.skip(1).toList();
    return rest.isEmpty ? [code] : rest;
  }

  @override
  Widget build(BuildContext context) {
    final lines = _parseLines();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int i = 0; i < lines.length; i++)
          Text(
            lines[i],
            overflow:  TextOverflow.ellipsis,
            style: TextStyle(
              fontSize:   i == 0 ? fontSize : fontSize - 1,
              fontWeight: i == 0 ? FontWeight.w700 : FontWeight.w500,
              color:      i == 0 ? color : color.withOpacity(0.70),
            ),
          ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════════
// TOP TABLE (Top products / Top users / Top customers)
// ══════════════════════════════════════════════════════════════════

class DashboardTopTable extends StatelessWidget {
  final String            title;
  final IconData          icon;
  final List<String>      headers;
  final List<List<String>> rows;

  const DashboardTopTable({
    super.key,
    required this.title,
    required this.icon,
    required this.headers,
    required this.rows,
  });

  @override
  Widget build(BuildContext context) {
    final isDark   = Theme.of(context).brightness == Brightness.dark;
    final isNarrow = MediaQuery.sizeOf(context).width < 600;
    final primary  = isDark ? AppColors.primary : AppColors.primaryDark;
    final border   = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final cardBg   = isDark ? AppColors.darkCard : AppColors.lightCard;
    final secondary = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    return Container(
      decoration: BoxDecoration(
        color:        cardBg,
        borderRadius: BorderRadius.circular(12),
        border:       Border.all(color: border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
          child: Row(children: [
            Icon(icon, size: 15, color: primary),
            const SizedBox(width: 6),
            Text(title, style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize:   13,
              color:      primary,
            )),
          ]),
        ),
        Divider(height: 0, color: border),
        _tableRow(headers, isHeader: true,
            primary: primary, secondary: secondary, isNarrow: isNarrow,
            isDark: isDark),
        Divider(height: 0, color: border),
        if (rows.isEmpty)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Center(child: Text('Không có dữ liệu',
                style: TextStyle(fontSize: 12, color: secondary))),
          )
        else
          ...rows.asMap().entries.map((e) => Column(children: [
            _tableRow(e.value, rank: e.key + 1,
                primary: primary, secondary: secondary, isNarrow: isNarrow,
                isDark: isDark),
            if (e.key < rows.length - 1)
              Divider(height: 0, color: border.withOpacity(0.5)),
          ])),
      ]),
    );
  }

  Widget _tableRow(
      List<String> cells, {
        bool   isHeader  = false,
        int    rank      = 0,
        required Color  primary,
        required Color  secondary,
        required bool   isNarrow,
        required bool   isDark,
      }) {
    return Container(
      color: isHeader ? secondary.withOpacity(0.06) : null,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      child: Row(children: [
        if (!isHeader)
          Container(
            width: 22, height: 22,
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: rank <= 3
                  ? primary.withOpacity(0.12)
                  : secondary.withOpacity(0.08),
              borderRadius: BorderRadius.circular(5),
            ),
            child: Center(child: Text('$rank', style: TextStyle(
              fontSize:   10,
              fontWeight: FontWeight.w700,
              color:      rank <= 3 ? primary : secondary,
            ))),
          )
        else
          const SizedBox(width: 30),

        Expanded(flex: 3, child: Text(cells[0],
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize:   isHeader ? 11 : 12,
            fontWeight: isHeader ? FontWeight.w700 : FontWeight.w500,
            color:      isHeader ? secondary : null,
          ),
        )),

        if (isNarrow && !isHeader)
          Expanded(flex: 2, child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(cells[1], style: const TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w600)),
              Text(_shortMoney(cells[2]), style: TextStyle(
                  fontSize: 11, color: primary, fontWeight: FontWeight.w700)),
            ],
          ))
        else ...[
          Expanded(flex: 1, child: Text(cells[1],
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize:   isHeader ? 11 : 12,
              fontWeight: isHeader ? FontWeight.w700 : FontWeight.normal,
              color:      isHeader ? secondary : null,
            ),
          )),
          Expanded(flex: 2, child: Text(cells[2],
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize:   isHeader ? 11 : 12,
              fontWeight: isHeader ? FontWeight.w700 : FontWeight.w600,
              color:      isHeader ? secondary : primary,
            ),
          )),
        ],
      ]),
    );
  }

  String _shortMoney(String value) {
    final clean = value
        .replaceAll('đ', '').replaceAll('.', '').replaceAll(',', '').trim();
    final number = double.tryParse(clean) ?? 0;
    if (number >= 1e9) return '${(number / 1e9).toStringAsFixed(2)} T';
    if (number >= 1e6) return '${(number / 1e6).toStringAsFixed(2)} Tr';
    if (number >= 1e3) return '${(number / 1e3).toStringAsFixed(0)} K';
    return number.toStringAsFixed(0);
  }
}

// ══════════════════════════════════════════════════════════════════
// REGION DOT (bản đồ marker)
// ══════════════════════════════════════════════════════════════════

// RegionDot — StatelessWidget, không dùng AnimationController/repeat()
// AnimationController.repeat() trong SfMaps markerBuilder gây dirty semantics
// liên tục → crash. Dùng AnimatedContainer (implicit animation) thay thế.
class RegionDot extends StatelessWidget {
  final Color        color;
  final bool         isActive;
  final VoidCallback onTap;

  const RegionDot({
    super.key,
    required this.color,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final dotSize    = isActive ? 20.0 : 14.0;
    final glowBlur   = isActive ? 12.0 : 3.0;
    final glowSpread = isActive ? 4.0  : 0.0;
    final glowAlpha  = isActive ? 0.7  : 0.35;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        width:  dotSize + 24,
        height: dotSize + 24,
        child: Center(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            width:  dotSize,
            height: dotSize,
            decoration: BoxDecoration(
              shape:  BoxShape.circle,
              color:  color,
              border: Border.all(
                  color: Colors.white,
                  width: isActive ? 3.0 : 2.0),
              boxShadow: [
                BoxShadow(
                    color:        color.withOpacity(glowAlpha),
                    blurRadius:   glowBlur,
                    spreadRadius: glowSpread),
              ],
            ),
          ),
        ),
      ),
    );
  }
}