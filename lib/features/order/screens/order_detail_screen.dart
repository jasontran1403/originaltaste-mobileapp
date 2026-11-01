// lib/features/order/screens/order_detail_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../data/models/order/order_models.dart';
import '../../../shared/widgets/order_shared_widgets.dart';
import '../controller/order_history_controller.dart';

class OrderDetailScreen extends ConsumerStatefulWidget {
  final int orderId;
  const OrderDetailScreen({super.key, required this.orderId});

  @override
  ConsumerState<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends ConsumerState<OrderDetailScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(orderDetailProvider(widget.orderId).notifier).loadOrder();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state     = ref.watch(orderDetailProvider(widget.orderId));
    final isDark    = Theme.of(context).brightness == Brightness.dark;
    final bg        = isDark ? AppColors.darkBg : AppColors.lightBg;
    final primary   = isDark ? AppColors.primary : AppColors.primaryDark;
    final secondary = isDark
        ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    return Scaffold(
      backgroundColor: bg,
      body: state.isLoading
          ? Center(child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation(primary)))
          : state.error != null
          ? _buildError(state.error!, primary)
          : state.order == null
          ? const Center(child: Text('Không tìm thấy đơn hàng'))
          : _OrderDetailContent(
        order:     state.order!,
        orderId:   widget.orderId,
        exporting: state.isExporting,
        isDark:    isDark,
        primary:   primary,
        secondary: secondary,
      ),
    );
  }

  Widget _buildError(String msg, Color primary) => Center(
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      const Icon(Icons.error_outline_rounded,
          size: 72, color: Colors.redAccent),
      const SizedBox(height: 20),
      Text('Đã xảy ra lỗi',
          style: TextStyle(fontSize: 18,
              fontWeight: FontWeight.w600, color: Colors.redAccent)),
      const SizedBox(height: 10),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Text(msg,
            style: TextStyle(fontSize: 14,
                color: Colors.redAccent.withOpacity(0.85)),
            textAlign: TextAlign.center),
      ),
      const SizedBox(height: 28),
      ElevatedButton.icon(
        onPressed: () => ref
            .read(orderDetailProvider(widget.orderId).notifier)
            .loadOrder(),
        icon:  const Icon(Icons.refresh_rounded),
        label: const Text('Thử lại'),
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(
              horizontal: 28, vertical: 12),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10)),
        ),
      ),
    ]),
  );
}

// ════════════════════════════════════════════════════════════════
// MAIN CONTENT
// ════════════════════════════════════════════════════════════════

class _OrderDetailContent extends ConsumerWidget {
  final OrderModel order;
  final int orderId;
  final bool exporting, isDark;
  final Color primary, secondary;

  const _OrderDetailContent({
    required this.order,
    required this.orderId,
    required this.exporting,
    required this.isDark,
    required this.primary,
    required this.secondary,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cardBg = isDark ? AppColors.darkCard : AppColors.lightCard;
    final border  = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final top     = MediaQuery.of(context).padding.top;
    final bottom  = MediaQuery.of(context).padding.bottom;

    return Column(children: [
      // ── Top bar ────────────────────────────────────────────────
      Container(
        color: cardBg,
        padding: EdgeInsets.fromLTRB(16, top + 12, 16, 12),
        child: Row(children: [
          GestureDetector(
            onTap: () => context.pop(),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color:        secondary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.arrow_back_rounded,
                  size: 18, color: secondary),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(order.orderCode,
                    style: TextStyle(
                        fontSize:   17,
                        fontWeight: FontWeight.w800,
                        color:      primary)),
                if (order.createdAt != null)
                  Text(fmtOrderDate(order.createdAt),
                      style: TextStyle(fontSize: 12, color: secondary)),
              ])),
          OrderStatusBadge(status: order.status, fontSize: 12),
        ]),
      ),
      Container(height: 1,
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder),

      // ── Scrollable body ───────────────────────────────────────
      Expanded(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(16, 16, 16, bottom + 24),
          child: Container(
            decoration: BoxDecoration(
              color:        cardBg,
              borderRadius: BorderRadius.circular(14),
              border:       Border.all(color: border),
              boxShadow: [BoxShadow(
                color: Colors.black
                    .withOpacity(isDark ? 0.2 : 0.05),
                blurRadius: 8,
                offset: const Offset(0, 3),
              )],
            ),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Customer + payment
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                    child: _buildCustomerSection(),
                  ),
                  const SizedBox(height: 16),
                  Divider(height: 1, color: border),
                  const SizedBox(height: 16),

                  // Items
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                    child: _buildItemsTable(border),
                  ),
                  const SizedBox(height: 16),
                  Divider(height: 1, color: border),
                  const SizedBox(height: 14),

                  // Summary
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    child: _buildSummary(),
                  ),
                ]),
          ),
        ),
      ),
    ]);
  }

  // ── Customer section ──────────────────────────────────────────
  Widget _buildCustomerSection() {
    final hasInfo = (order.customerName?.isNotEmpty ?? false) ||
        (order.customerPhone?.isNotEmpty ?? false) ||
        (order.shippingAddress?.isNotEmpty ?? false);

    return LayoutBuilder(builder: (ctx, constraints) {
      final isNarrow = constraints.maxWidth < 480;

      final customerCol = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            OrderSectionTitle('Thông tin khách hàng'),
            const SizedBox(height: 10),
            if (order.customerName?.isNotEmpty ?? false)
              InfoRow(Icons.person_outline, order.customerName!.trim()),
            if (order.customerPhone?.isNotEmpty ?? false)
              InfoRow(Icons.phone_outlined, order.customerPhone!.trim()),
            if (order.shippingAddress?.isNotEmpty ?? false)
              InfoRow(Icons.location_on_outlined,
                  order.shippingAddress!.trim()),
            if (!hasInfo)
              Text('Khách vãng lai',
                  style: TextStyle(fontSize: 13, color: secondary)),
          ]);

      final paymentCol = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            OrderSectionTitle('Thanh toán & Ghi chú'),
            const SizedBox(height: 10),
            InfoRow(
              order.paymentStatus == 'PAID'
                  ? Icons.check_circle_outline
                  : Icons.radio_button_unchecked,
              paymentStatusLabel(order.paymentStatus),
              color: order.paymentStatus == 'PAID'
                  ? Colors.green : Colors.orange,
            ),
            if (order.paymentMethod?.isNotEmpty ?? false)
              InfoRow(Icons.payment_outlined,
                  paymentMethodLabel(order.paymentMethod!.trim())),
            if (order.notes?.isNotEmpty ?? false)
              InfoRow(Icons.notes_outlined, order.notes!.trim(),
                  color: Colors.orange.shade700),
          ]);

      if (isNarrow) {
        return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              customerCol,
              const SizedBox(height: 18),
              paymentCol,
            ]);
      }

      return Row(crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: customerCol),
            const SizedBox(width: 20),
            Expanded(child: paymentCol),
          ]);
    });
  }

  // ── Items table ───────────────────────────────────────────────
  Widget _buildItemsTable(Color border) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          OrderSectionTitle('Sản phẩm (${order.items.length})'),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              border:       Border.all(color: border),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(children: [
              // Header
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 9),
                decoration: BoxDecoration(
                  color: secondary.withOpacity(0.06),
                  borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(7)),
                ),
                child: Row(children: [
                  Expanded(flex: 4,
                      child: _TH('Tên sản phẩm')),
                  Expanded(flex: 1,
                      child: _TH('SL', center: true)),
                  Expanded(flex: 2,
                      child: _TH('Đơn giá', center: true)),
                  Expanded(flex: 2,
                      child: _TH('Thành tiền', right: true)),
                ]),
              ),

              // Rows
              ...order.items.asMap().entries.map((entry) {
                final idx  = entry.key;
                final item = entry.value;
                final evenBg = isDark
                    ? Colors.white.withOpacity(0.02)
                    : Colors.black.withOpacity(0.015);

                return Container(
                  decoration: BoxDecoration(
                    border: Border(top: BorderSide(color: border)),
                    color: idx.isEven ? Colors.transparent : evenBg,
                  ),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Tên + badge
                        Expanded(flex: 4, child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(item.productName,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13)),
                              _PriceModeBadge(
                                  item: item, primary: primary),
                              if (item.notes?.isNotEmpty ?? false)
                                Text('Ghi chú: ${item.notes}',
                                    style: TextStyle(
                                        fontSize:   11,
                                        color:      Colors.orange.shade700,
                                        fontStyle:  FontStyle.italic)),
                            ])),

                        // SL
                        Expanded(flex: 1, child: Text(
                          '${fmtQtyDisplay(item.quantity)} ${item.unit ?? ''}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w500),
                        )),

                        // Đơn giá
                        Expanded(flex: 2, child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Text(fmtMoney(item.unitPrice),
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                      fontSize:   12,
                                      fontWeight: FontWeight.w600,
                                      color:      primary)),
                              if (item.basePrice != item.unitPrice)
                                Text(fmtMoney(item.basePrice),
                                    style: TextStyle(
                                        fontSize: 10,
                                        color: secondary.withOpacity(0.7),
                                        decoration:
                                        TextDecoration.lineThrough)),
                            ])),

                        // Thành tiền
                        Expanded(flex: 2, child: Text(
                          fmtMoney(item.subtotal),
                          textAlign: TextAlign.right,
                          style: TextStyle(
                              fontSize:   12,
                              fontWeight: FontWeight.w600,
                              color:      primary),
                        )),
                      ]),
                );
              }),
            ]),
          ),
        ]);
  }

  // ── Summary ───────────────────────────────────────────────────
  Widget _buildSummary() {
    final vatBreakdown = <int, double>{};
    for (final item in order.items) {
      if (item.vatRate > 0 && item.vatAmount > 0) {
        vatBreakdown.update(
          item.vatRate,
              (v) => v + item.vatAmount,
          ifAbsent: () => item.vatAmount,
        );
      }
    }

    return Align(
      alignment: Alignment.centerRight,
      child: SizedBox(
        width: 280,
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _SummaryLine(
                  label:  'Tạm tính',
                  value:  fmtMoney(order.totalAmount),
                  isDark: isDark),
              if (order.discountAmount > 0)
                _SummaryLine(
                    label:      'Chiết khấu',
                    value:      '-${fmtMoney(order.discountAmount)}',
                    valueColor: Colors.green,
                    isDark:     isDark),
              if (order.vatAmount > 0) ...[
                _SummaryLine(
                    label:      'VAT',
                    value:      '+${fmtMoney(order.vatAmount)}',
                    valueColor: Colors.orange,
                    isDark:     isDark),
                ...vatBreakdown.entries.map((e) => Padding(
                  padding: const EdgeInsets.only(left: 16),
                  child: _SummaryLine(
                      label:      '↳ VAT ${e.key}%',
                      value:      '+${fmtMoney(e.value)}',
                      valueColor: Colors.orange.withOpacity(0.75),
                      fontSize:   12,
                      isDark:     isDark),
                )),
              ],
              const SizedBox(height: 8),
              Divider(
                  color: secondary.withOpacity(0.2), height: 1),
              const SizedBox(height: 8),
              _SummaryLine(
                  label:      'Tổng cộng',
                  value:      fmtMoney(order.finalAmount),
                  bold:       true,
                  valueColor: primary,
                  fontSize:   16,
                  isDark:     isDark),
            ]),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// PRIVATE HELPERS
// ════════════════════════════════════════════════════════════════

class _TH extends StatelessWidget {
  final String text;
  final bool center, right;
  const _TH(this.text, {this.center = false, this.right = false});

  @override
  Widget build(BuildContext context) => Text(text,
      textAlign: right
          ? TextAlign.right
          : center ? TextAlign.center : TextAlign.left,
      style: const TextStyle(
          fontWeight: FontWeight.w700, fontSize: 11));
}

class _PriceModeBadge extends StatelessWidget {
  final OrderItemModel item;
  final Color primary;
  const _PriceModeBadge(
      {required this.item, required this.primary});

  @override
  Widget build(BuildContext context) {
    final (color, label) = switch (item.priceMode) {
      'TIER' => (
      primary,
      item.tierName != null
          ? 'Khung: ${item.tierName}'
          : 'Giá khung',
      ),
      'DISCOUNT_PERCENT' => (
      Colors.green,
      item.discountPercent != null
          ? 'Giảm ${item.discountPercent}%'
          : 'Giảm giá',
      ),
      _ => (Colors.grey.shade500, 'Giá gốc'),
    };

    if (label == 'Giá gốc') return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(top: 3),
      padding: const EdgeInsets.symmetric(
          horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color:        color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize:   10,
              fontWeight: FontWeight.w600,
              color:      color)),
    );
  }
}

class _SummaryLine extends StatelessWidget {
  final String label, value;
  final Color? valueColor;
  final bool bold, isDark;
  final double fontSize;

  const _SummaryLine({
    required this.label,
    required this.value,
    required this.isDark,
    this.valueColor,
    this.bold     = false,
    this.fontSize = 13,
  });

  @override
  Widget build(BuildContext context) {
    final secondary = isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;
    final onBg = isDark
        ? AppColors.darkTextPrimary
        : AppColors.lightTextPrimary;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style: TextStyle(
                    fontSize:   fontSize,
                    fontWeight: bold
                        ? FontWeight.w700 : FontWeight.w400,
                    color: bold ? onBg : secondary)),
            Text(value,
                style: TextStyle(
                    fontSize:   fontSize,
                    fontWeight: bold
                        ? FontWeight.w700 : FontWeight.w500,
                    color: valueColor ?? onBg)),
          ]),
    );
  }
}