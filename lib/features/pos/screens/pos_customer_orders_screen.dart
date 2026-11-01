// pos_customer_orders_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:originaltaste/core/constants/api_constants.dart';
import 'package:originaltaste/data/network/dio_client.dart';

import '../../../data/models/pos/pos_customer_order_models.dart';
// import models trên

class PosCustomerOrdersScreen extends StatefulWidget {
  final String customerPhone;
  final String customerName;

  const PosCustomerOrdersScreen({
    super.key,
    required this.customerPhone,
    required this.customerName,
  });

  @override
  State<PosCustomerOrdersScreen> createState() =>
      _PosCustomerOrdersScreenState();
}

class _PosCustomerOrdersScreenState
    extends State<PosCustomerOrdersScreen> {
  final _scrollCtrl = ScrollController();
  final List<CustomerOrderSummary> _orders = [];
  int  _page     = 0;
  bool _hasNext  = true;
  bool _loading  = false;

  static const _pageSize = 20;

  final _fmt     = NumberFormat('#,###', 'vi_VN');
  final _fmtDate = DateFormat('dd/MM/yyyy HH:mm');

  @override
  void initState() {
    super.initState();
    _loadMore();
    _scrollCtrl.addListener(() {
      if (_scrollCtrl.position.pixels >=
          _scrollCtrl.position.maxScrollExtent - 200) {
        _loadMore();
      }
    });
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadMore() async {
    if (_loading || !_hasNext) return;
    setState(() => _loading = true);
    try {
      final res = await DioClient.instance.get<Map<String, dynamic>>(
        '${ApiConstants.posBase}/customers/${widget.customerPhone}/orders',
        queryParams: {'page': _page, 'size': _pageSize},
        fromData: (d) => d as Map<String, dynamic>,
      );
      if (!mounted) return;
      if (res.isSuccess && res.data != null) {
        final data    = res.data!;
        final content = (data['content'] as List? ?? [])
            .map((e) => CustomerOrderSummary.fromJson(
            e as Map<String, dynamic>))
            .toList();
        setState(() {
          _orders.addAll(content);
          _hasNext = data['hasNext'] as bool? ?? false;
          _page++;
        });
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _refresh() async {
    setState(() { _orders.clear(); _page = 0; _hasNext = true; });
    await _loadMore();
  }

  String _srcLabel(String s) => switch (s) {
    'SHOPEE_FOOD' => 'ShopeeFood',
    'GRAB_FOOD'   => 'GrabFood',
    _             => 'Offline',
  };

  Color _srcColor(String s) => switch (s) {
    'SHOPEE_FOOD' => const Color(0xFFEE4D2D),
    'GRAB_FOOD'   => const Color(0xFF00B14F),
    _             => const Color(0xFF2563EB),
  };

  String _pmLabel(String m) => switch (m) {
    'CASH'          => 'Tiền mặt',
    'BANK_TRANSFER' => 'Chuyển khoản',
    'TRANSFER'      => 'Chuyển khoản',
    'MOMO'          => 'MoMo',
    _               => m,
  };

  @override
  Widget build(BuildContext context) {
    final isDark  = Theme.of(context).brightness == Brightness.dark;
    final cs      = Theme.of(context).colorScheme;
    final border  = isDark
        ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final cardBg  = isDark ? const Color(0xFF1E293B) : Colors.white;
    const teal    = Color(0xFF0D9488);

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
      appBar: AppBar(
        backgroundColor: isDark
            ? const Color(0xFF1E293B) : Colors.white,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.customerName,
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w800)),
            Text('Lịch sử đơn hàng',
                style: TextStyle(
                    fontSize: 11,
                    color: cs.onSurface.withOpacity(0.5))),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        color: teal,
        child: _orders.isEmpty && !_loading
            ? const Center(child: Text('Chưa có đơn hàng nào'))
            : ListView.builder(
          controller: _scrollCtrl,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
          itemCount: _orders.length + (_loading ? 1 : 0),
          itemBuilder: (_, i) {
            if (i == _orders.length) {
              return const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator(
                    strokeWidth: 2)),
              );
            }
            final o = _orders[i];
            final src   = _srcColor(o.orderSource);
            final dt    = DateTime.fromMillisecondsSinceEpoch(
                o.createdAt);

            return GestureDetector(
              onTap: () => _openDetail(o.id),
              child: Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: border),
                ),
                child: Row(children: [
                  // Source dot
                  Container(
                    width: 38, height: 38,
                    decoration: BoxDecoration(
                      color: src.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Center(child: Text(
                      _srcLabel(o.orderSource)[0],
                      style: TextStyle(fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: src),
                    )),
                  ),
                  const SizedBox(width: 12),

                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Text(o.orderCode,
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: src)),
                        const Spacer(),
                        Text(_fmt.format(o.displayAmount),
                            style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF0D9488))),
                        Text('đ', style: TextStyle(
                            fontSize: 11,
                            color: cs.onSurface.withOpacity(0.5))),
                      ]),
                      const SizedBox(height: 4),
                      Row(children: [
                        Icon(Icons.access_time_rounded,
                            size: 11,
                            color: cs.onSurface.withOpacity(0.4)),
                        const SizedBox(width: 4),
                        Text(_fmtDate.format(dt),
                            style: TextStyle(
                                fontSize: 11,
                                color: cs.onSurface.withOpacity(0.5))),
                        const Spacer(),
                        Text('${o.itemCount} món',
                            style: TextStyle(
                                fontSize: 11,
                                color: cs.onSurface.withOpacity(0.5))),
                        const SizedBox(width: 8),
                        Text(_pmLabel(o.paymentMethod),
                            style: TextStyle(
                                fontSize: 10,
                                color: src.withOpacity(0.8),
                                fontWeight: FontWeight.w600)),
                      ]),
                    ],
                  )),

                  const SizedBox(width: 8),
                  Icon(Icons.chevron_right_rounded,
                      size: 18,
                      color: cs.onSurface.withOpacity(0.3)),
                ]),
              ),
            );
          },
        ),
      ),
    );
  }

  void _openDetail(int orderId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _OrderDetailSheet(orderId: orderId),
    );
  }
}

// ── Order Detail Sheet ────────────────────────────────────────────

class _OrderDetailSheet extends StatefulWidget {
  final int orderId;
  const _OrderDetailSheet({required this.orderId});

  @override
  State<_OrderDetailSheet> createState() => _OrderDetailSheetState();
}

class _OrderDetailSheetState extends State<_OrderDetailSheet> {
  CustomerOrderDetail? _detail;
  bool _loading = true;

  final _fmt     = NumberFormat('#,###', 'vi_VN');
  final _fmtDate = DateFormat('dd/MM/yyyy HH:mm');

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final res = await DioClient.instance.get<CustomerOrderDetail>(
        '${ApiConstants.posBase}/customers/orders/${widget.orderId}',
        fromData: (d) => CustomerOrderDetail.fromJson(
            d as Map<String, dynamic>),
      );
      if (mounted && res.isSuccess && res.data != null) {
        setState(() { _detail = res.data; _loading = false; });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _srcLabel(String s) => switch (s) {
    'SHOPEE_FOOD' => 'ShopeeFood',
    'GRAB_FOOD'   => 'GrabFood',
    _             => 'Offline',
  };

  Color _srcColor(String s) => switch (s) {
    'SHOPEE_FOOD' => const Color(0xFFEE4D2D),
    'GRAB_FOOD'   => const Color(0xFF00B14F),
    _             => const Color(0xFF2563EB),
  };

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cs     = Theme.of(context).colorScheme;
    final bg     = isDark ? const Color(0xFF1E293B) : Colors.white;
    final border = isDark
        ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final txtSec = isDark
        ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    const teal   = Color(0xFF0D9488);
    final maxH   = MediaQuery.of(context).size.height * 0.9;

    return Container(
      constraints: BoxConstraints(maxHeight: maxH),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(
            top: Radius.circular(20)),
      ),
      child: _loading
          ? const SizedBox(height: 200,
          child: Center(child: CircularProgressIndicator(
              strokeWidth: 2)))
          : _detail == null
          ? const SizedBox(height: 200,
          child: Center(child: Text('Không tải được đơn hàng')))
          : _buildContent(_detail!, isDark, cs, bg, border, txtSec),
    );
  }

  Widget _buildContent(
      CustomerOrderDetail d,
      bool isDark, ColorScheme cs,
      Color bg, Color border, Color txtSec) {
    final src        = _srcColor(d.orderSource);
    final dt         = DateTime.fromMillisecondsSinceEpoch(d.createdAt);
    final isAppOrder = d.isAppOrder;

    // VAT breakdown theo từng mức %
    final vatGroups = <int, double>{};
    for (final item in d.items) {
      if (item.vatPercent > 0) {
        vatGroups[item.vatPercent] =
            (vatGroups[item.vatPercent] ?? 0) + (item.vatAmount);
      }
    }
    final sortedVatKeys = vatGroups.keys.toList()..sort();

    return Column(mainAxisSize: MainAxisSize.min, children: [
      // Handle
      Container(
        width: 36, height: 4,
        margin: const EdgeInsets.only(top: 12, bottom: 8),
        decoration: BoxDecoration(
            color: Colors.grey.withOpacity(0.3),
            borderRadius: BorderRadius.circular(2)),
      ),

      // Header
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: src.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(_srcLabel(d.orderSource),
                style: TextStyle(fontSize: 12,
                    fontWeight: FontWeight.w700, color: src)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(d.orderCode,
                    style: TextStyle(fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: cs.onSurface)),
                if (isAppOrder &&
                    d.appOrderCode != null &&
                    d.appOrderCode!.isNotEmpty)
                  Text(
                    'Mã app: ${d.appOrderCode}',
                    style: TextStyle(
                        fontSize: 10,
                        color: src.withOpacity(0.85),
                        fontWeight: FontWeight.w600),
                  ),
              ],
            ),
          ),
          Text(_fmtDate.format(dt),
              style: TextStyle(fontSize: 11, color: txtSec)),
        ]),
      ),

      const Divider(height: 1),

      Flexible(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 80),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              // Danh sách món
              ...d.items.map((item) {
                final displayUnitPrice = isAppOrder
                    ? item.basePrice
                    : item.finalUnitPrice;
                // Tổng của DÒNG MÓN — chưa gồm addon.
                // Addon được liệt kê thành dòng riêng bên dưới, nên không gộp
                // vào đây (item.subtotal đã bao gồm addonAmount).
                final displaySubtotal = isAppOrder
                    ? item.basePrice * item.quantity
                    : item.finalUnitPrice * item.quantity;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Badge số lượng món chính (sát tên món)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0D9488).withOpacity(0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'x${item.quantity}',
                              style: const TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF0D9488),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),

                          // Tên món
                          Expanded(
                            child: Text(
                              item.productName,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: cs.onSurface,
                              ),
                            ),
                          ),

                          // Giá đơn vị
                          SizedBox(
                            width: 85,
                            child: Text(
                              '${_fmt.format(displayUnitPrice)}đ',
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                fontSize: 13,
                                color: const Color(0xFF0D9488).withOpacity(0.85),
                              ),
                            ),
                          ),

                          // Tổng tiền món chính
                          SizedBox(
                            width: 100,
                            child: Text(
                              '${_fmt.format(displaySubtotal)}đ',
                              textAlign: TextAlign.right,
                              style: const TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF0D9488),
                              ),
                            ),
                          ),
                        ],
                      ),

                      // Note của món chính
                      if (item.note != null && item.note!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(left: 42, top: 4, bottom: 4),
                          child: Text(item.note!,
                              style: TextStyle(
                                  fontSize: 11.5,
                                  color: txtSec,
                                  fontStyle: FontStyle.italic)),
                        ),

                      // MÓN THÊM
                      if (item.addons.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(left: 42, top: 8),
                          child: Column(
                            children: item.addons.map((addon) {
                              final addonTotal = addon.addonPriceSnapshot * addon.selectedCount;

                              return Padding(
                                padding: const EdgeInsets.only(bottom: 6),
                                child: Row(
                                  children: [
                                    Expanded(
                                      flex: 3,
                                      child: Text('• Addon: ${addon.ingredientName}',
                                          style: TextStyle(
                                              fontSize: 13,
                                              color: txtSec)),
                                    ),
                                    SizedBox(
                                      width: 48,
                                      child: Text('x${addon.selectedCount}',
                                          textAlign: TextAlign.right,
                                          style: TextStyle(
                                              fontSize: 13,
                                              color: txtSec.withOpacity(0.9))),
                                    ),
                                    SizedBox(
                                      width: 85,
                                      child: Text('${_fmt.format(addon.addonPriceSnapshot)}đ',
                                          textAlign: TextAlign.right,
                                          style: TextStyle(
                                              fontSize: 13,
                                              color: const Color(0xFF0D9488).withOpacity(0.85))),
                                    ),
                                    SizedBox(
                                      width: 100,
                                      child: Text('${_fmt.format(addonTotal)}đ',
                                          textAlign: TextAlign.right,
                                          style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w700,
                                              color: Color(0xFF0D9488))),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                    ],
                  ),
                );
              }),

              Divider(color: border),
              const SizedBox(height: 12),

              // Tổng kết
              _SummaryRow(
                label: 'Tạm tính',
                value: '${_fmt.format(d.totalAmount)}đ',
                txtSec: txtSec, cs: cs,
              ),

              _SummaryRow(
                label: d.discountNote != null && d.discountNote!.isNotEmpty
                    ? 'Giảm (${d.discountNote})'
                    : 'Giảm giá',
                value: '- ${_fmt.format(d.discountAmount)}đ',
                color: Colors.red.shade400,
                txtSec: txtSec, cs: cs,
              ),

              if (!isAppOrder &&
                  d.eVoucherCode != null &&
                  (d.eVoucherDiscountAmount ?? 0) > 0)
                _SummaryRow(
                  label: 'Voucher (${d.eVoucherCode})',
                  value: '- ${_fmt.format(d.eVoucherDiscountAmount!)}đ',
                  color: Colors.purple.shade400,
                  txtSec: txtSec, cs: cs,
                ),

              _SummaryRow(
                label: 'VAT (đã bao gồm trong giá):',
                value: d.totalVatAmount > 0
                    ? '${_fmt.format(d.totalVatAmount)}đ'
                    : '0đ',
                txtSec: txtSec, cs: cs,
              ),

              // VAT Breakdown
              if (sortedVatKeys.isNotEmpty) ...[
                const SizedBox(height: 4),
                ...sortedVatKeys.map((pct) => Padding(
                  padding: const EdgeInsets.only(left: 20, bottom: 4),
                  child: Row(children: [
                    Icon(Icons.indeterminate_check_box,
                        size: 14, color: txtSec.withOpacity(0.5)),
                    const SizedBox(width: 6),
                    Text('VAT $pct%',
                        style: TextStyle(fontSize: 12, color: txtSec)),
                    const Spacer(),
                    Text('${_fmt.format(vatGroups[pct]!)}đ',
                        style: TextStyle(fontSize: 12, color: txtSec)),
                  ]),
                )),
              ],

              const SizedBox(height: 8),
              Divider(color: border),

              // Tổng cộng
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Row(children: [
                  Text('Tổng cộng',
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: cs.onSurface)),
                  const Spacer(),
                  Text(
                    '${_fmt.format(d.finalAmount)}đ',
                    style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0D9488)),
                  ),
                ]),
              ),

              if (d.note != null && d.note!.isNotEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: cs.onSurface.withOpacity(0.04),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(children: [
                    Icon(Icons.note_rounded, size: 16, color: txtSec),
                    const SizedBox(width: 10),
                    Expanded(child: Text(d.note!,
                        style: TextStyle(fontSize: 13, color: txtSec))),
                  ]),
                ),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    ]);
  }
}

class _SummaryRow extends StatelessWidget {
  final String  label;
  final String  value;
  final Color?  color;
  final String? note;
  final Color   txtSec;
  final ColorScheme cs;

  const _SummaryRow({
    required this.label,
    required this.value,
    this.color,
    this.note,
    required this.txtSec,
    required this.cs,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(children: [
        Text(label,
            style: TextStyle(fontSize: 13, color: txtSec)),
        if (note != null) ...[
          const SizedBox(width: 4),
          Text('($note)',
              style: TextStyle(
                  fontSize: 10,
                  color: txtSec.withOpacity(0.6),
                  fontStyle: FontStyle.italic)),
        ],
        const Spacer(),
        Text(value,
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: color ?? cs.onSurface)),
      ]),
    );
  }
}