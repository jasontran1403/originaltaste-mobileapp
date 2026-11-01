// lib/shared/widgets/order_shared_widgets.dart
// Widgets tái sử dụng cho order feature: status badge, action button,
// summary row, price badge, section title, formatters

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../app/theme/app_colors.dart';

// ══════════════════════════════════════════════════════════════════
// FORMATTERS
// ══════════════════════════════════════════════════════════════════

String fmtMoney(double v) =>
    '${NumberFormat('#,###', 'vi_VN').format(v)}đ';

String fmtMoneyRaw(double v) =>
    NumberFormat('#,###', 'vi_VN').format(v);

String fmtOrderDate(int? ts) {
  if (ts == null) return '';
  final dt = DateTime.fromMillisecondsSinceEpoch(ts);
  return '${dt.day.toString().padLeft(2, '0')}/'
      '${dt.month.toString().padLeft(2, '0')}/'
      '${dt.year}  '
      '${dt.hour.toString().padLeft(2, '0')}:'
      '${dt.minute.toString().padLeft(2, '0')}';
}

String fmtQtyDisplay(double qty) =>
    qty == qty.truncateToDouble() ? qty.toInt().toString() : qty.toStringAsFixed(2);

// ══════════════════════════════════════════════════════════════════
// ORDER STATUS
// ══════════════════════════════════════════════════════════════════

Color orderStatusColor(String s) => switch (s) {
  'PENDING'    => Colors.orange,
  'CONFIRMED'  => Colors.blue,
  'PROCESSING' => Colors.blue,
  'COMPLETED'  => Colors.green,
  'CANCELLED'  => Colors.red,
  _            => Colors.grey,
};

String orderStatusLabel(String s) => switch (s) {
  'PENDING'    => 'Chờ xử lý',
  'CONFIRMED'  => 'Xác nhận',
  'PROCESSING' => 'Đang xử lý',
  'COMPLETED'  => 'Hoàn thành',
  'CANCELLED'  => 'Đã hủy',
  _            => s,
};

String paymentStatusLabel(String s) => switch (s) {
  'PAID'     => 'Đã thanh toán',
  'UNPAID'   => 'Chưa thanh toán',
  'REFUNDED' => 'Đã hoàn tiền',
  _          => s,
};

String paymentMethodLabel(String s) => switch (s) {
  'CASH'          => 'Tiền mặt',
  'BANK_TRANSFER' => 'Chuyển khoản',
  _               => s,
};

// ══════════════════════════════════════════════════════════════════
// ORDER STATUS BADGE
// ══════════════════════════════════════════════════════════════════

class OrderStatusBadge extends StatelessWidget {
  final String status;
  final double fontSize;

  const OrderStatusBadge({super.key, required this.status, this.fontSize = 11});

  @override
  Widget build(BuildContext context) {
    final color = orderStatusColor(status);
    final label = orderStatusLabel(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color:        color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
        border:       Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize:   fontSize,
              fontWeight: FontWeight.w600,
              color:      color)),
    );
  }
}

// ══════════════════════════════════════════════════════════════════
// PAYMENT STATUS BADGE
// ══════════════════════════════════════════════════════════════════

class PaymentStatusBadge extends StatelessWidget {
  final String status;

  const PaymentStatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      'PAID'     => Colors.green,
      'UNPAID'   => Colors.orange,
      'REFUNDED' => Colors.blue,
      _          => Colors.grey,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color:        color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        switch (status) {
          'PAID'     => 'Đã TT',
          'UNPAID'   => 'Chưa TT',
          'REFUNDED' => 'Hoàn tiền',
          _          => status,
        },
        style: TextStyle(
            fontSize:   11,
            fontWeight: FontWeight.w600,
            color:      color),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════
// SECTION TITLE (cho order screens)
// ══════════════════════════════════════════════════════════════════

class OrderSectionTitle extends StatelessWidget {
  final String text;
  final double fontSize;

  const OrderSectionTitle(this.text, {super.key, this.fontSize = 14});

  @override
  Widget build(BuildContext context) {
    final isDark  = Theme.of(context).brightness == Brightness.dark;
    final primary = isDark ? AppColors.primary : AppColors.primaryDark;
    return Text(
      text,
      style: TextStyle(
        fontWeight: FontWeight.w700,
        fontSize:   fontSize,
        color:      primary,
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════
// SUMMARY ROW (dùng cho cart summary + detail summary)
// ══════════════════════════════════════════════════════════════════

class SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isBold;
  final Color? valueColor;
  final double fontSize;
  final bool muted;

  const SummaryRow({
    super.key,
    required this.label,
    required this.value,
    this.isBold      = false,
    this.valueColor,
    this.fontSize    = 13,
    this.muted       = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark     = Theme.of(context).brightness == Brightness.dark;
    final secondary  = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final onBg       = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Text(label,
                style: TextStyle(
                  fontSize:   fontSize,
                  fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
                  color:      muted ? secondary : onBg,
                )),
          ),
          const SizedBox(width: 8),
          Text(value,
              style: TextStyle(
                fontSize:   fontSize,
                fontWeight: isBold ? FontWeight.w700 : FontWeight.w600,
                color:      valueColor ?? onBg,
              )),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════
// ACTION BUTTON (outline / filled)
// ══════════════════════════════════════════════════════════════════

class OrderActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool outlined;
  final bool loading;
  final Color? color;

  const OrderActionButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.outlined = false,
    this.loading  = false,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final isDark   = Theme.of(context).brightness == Brightness.dark;
    final primary  = isDark ? AppColors.primary : AppColors.primaryDark;
    final c        = color ?? primary;
    final disabled = onTap == null;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color:  outlined ? Colors.transparent
              : (disabled ? c.withOpacity(0.4) : c),
          border: outlined ? Border.all(color: c.withOpacity(0.35)) : null,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            loading
                ? SizedBox(
              width: 14, height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: outlined ? c : Colors.white,
              ),
            )
                : Icon(icon, size: 14, color: outlined ? c : Colors.white),
            const SizedBox(width: 5),
            Text(label,
                style: TextStyle(
                  fontSize:   12,
                  fontWeight: FontWeight.w600,
                  color: outlined ? c : Colors.white,
                )),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════
// INFO ROW (icon + text, dùng trong order detail)
// ══════════════════════════════════════════════════════════════════

class InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color? color;

  const InfoRow(this.icon, this.text, {super.key, this.color});

  @override
  Widget build(BuildContext context) {
    final isDark    = Theme.of(context).brightness == Brightness.dark;
    final secondary = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon,
              size:  14,
              color: color ?? secondary.withOpacity(0.6)),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize:   13,
                color:      color,
                fontWeight: color != null ? FontWeight.w600 : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════
// BACK BUTTON (dùng trong order screens)
// ══════════════════════════════════════════════════════════════════

class OrderBackButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const OrderBackButton({super.key, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark  = Theme.of(context).brightness == Brightness.dark;
    final primary = isDark ? AppColors.primary : AppColors.primaryDark;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color:        primary.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
          border:       Border.all(color: primary.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.arrow_back_rounded, size: 18, color: primary),
            const SizedBox(width: 7),
            Text(label,
                style: TextStyle(
                    fontSize:   13,
                    fontWeight: FontWeight.w700,
                    color:      primary)),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════
// EMPTY STATE (dùng chung cho history, cart trống, v.v.)
// ══════════════════════════════════════════════════════════════════

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final isDark    = Theme.of(context).brightness == Brightness.dark;
    final secondary = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(0),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 56, color: secondary.withOpacity(0.2)),
          const SizedBox(height: 14),
          Text(title,
              style: TextStyle(
                  fontSize:   15,
                  fontWeight: FontWeight.w600,
                  color:      secondary)),
          if (subtitle != null) ...[
            const SizedBox(height: 5),
            Text(subtitle!,
                style: TextStyle(fontSize: 12, color: secondary),
                textAlign: TextAlign.center),
          ],
        ]),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════
// ERROR STATE
// ══════════════════════════════════════════════════════════════════

class ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const ErrorState({super.key, required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.error_outline, size: 52, color: AppColors.error),
          const SizedBox(height: 12),
          Text(message,
              style: const TextStyle(color: AppColors.error),
              textAlign: TextAlign.center),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: onRetry,
            icon:  const Icon(Icons.refresh),
            label: const Text('Thử lại'),
          ),
        ]),
      ),
    );
  }
}
