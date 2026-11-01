// lib/features/order_scan/screens/order_scan_result_dialog.dart
//
// Dialog debug hiển thị kết quả trích xuất — giai đoạn xác thực trước khi
// map sang model chuẩn để chuẩn bị nhập kho.

import 'package:flutter/material.dart';
import '../models/parsed_order_form.dart';

class OrderScanResultDialog extends StatelessWidget {
  final ParsedOrderForm result;
  const OrderScanResultDialog({super.key, required this.result});

  static Future<void> show(BuildContext ctx, ParsedOrderForm r) =>
      showDialog(context: ctx, builder: (_) => OrderScanResultDialog(result: r));

  @override
  Widget build(BuildContext context) {
    final customerOk = result.isOriginalTaste;
    final customerFound = result.customerName != null;

    Widget row(String label, String? value, {bool ok = true}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(width: 120, child: Text(label,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
        Expanded(child: Text(
          value ?? '— không tìm thấy —',
          style: TextStyle(
            fontSize: 13,
            color: value == null ? Colors.red : (ok ? Colors.black87 : Colors.orange.shade900),
            fontWeight: value == null ? FontWeight.w600 : FontWeight.normal,
          ),
        )),
      ]),
    );

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 620),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            // Header
            Row(children: [
              Icon(
                customerOk ? Icons.check_circle : Icons.warning_amber_rounded,
                color: customerOk ? Colors.green : Colors.orange, size: 26,
              ),
              const SizedBox(width: 8),
              const Expanded(child: Text('Kết quả trích xuất',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700))),
              IconButton(icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop()),
            ]),
            const Divider(),

            // Body scrollable
            Expanded(child: SingleChildScrollView(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Customer status
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: customerOk ? Colors.green.shade50
                        : (customerFound ? Colors.orange.shade50 : Colors.red.shade50),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: customerOk ? Colors.green.shade200
                          : (customerFound ? Colors.orange.shade200 : Colors.red.shade200),
                    ),
                  ),
                  child: Text(
                    !customerFound
                        ? '❌ Không tìm thấy tên khách hàng trên phiếu'
                        : customerOk
                        ? '✅ Khách hàng: Original Taste — hợp lệ'
                        : '⚠ Khách hàng KHÔNG phải Original Taste ("${result.customerName}") — sẽ dừng xử lý',
                    style: TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600,
                      color: customerOk ? Colors.green.shade900
                          : (customerFound ? Colors.orange.shade900 : Colors.red.shade900),
                    ),
                  ),
                ),

                row('Tên khách hàng:', result.customerName, ok: customerOk),
                row('Số phiếu:', result.orderNumber),
                const SizedBox(height: 8),

                Text('Danh sách sản phẩm (${result.items.length})',
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                const SizedBox(height: 6),
                if (result.items.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 10),
                    child: Text('— chưa trích xuất được sản phẩm nào —',
                        style: TextStyle(color: Colors.red, fontSize: 13)),
                  )
                else
                  ...result.items.asMap().entries.map((e) {
                    final i = e.key + 1; final it = e.value;
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      margin: const EdgeInsets.only(bottom: 4),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Row(children: [
                        SizedBox(width: 20, child: Text('$i.',
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
                        Expanded(child: Text(it.name,
                            style: const TextStyle(fontSize: 13))),
                        const SizedBox(width: 8),
                        Text('${it.quantity ?? "?"} ${it.unit ?? ""}',
                            style: const TextStyle(
                                fontSize: 12, fontWeight: FontWeight.w700, color: Colors.blue)),
                      ]),
                    );
                  }),

                const SizedBox(height: 14),
                const Text('Raw text (dùng debug parser)',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(8),
                  margin: const EdgeInsets.only(top: 4),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: SelectableText(
                    result.rawText.isEmpty ? '(rỗng)' : result.rawText,
                    style: const TextStyle(fontSize: 10, fontFamily: 'monospace'),
                  ),
                ),
              ],
            ))),
            const SizedBox(height: 10),
            Align(alignment: Alignment.centerRight, child: TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Đóng'),
            )),
          ]),
        ),
      ),
    );
  }
}