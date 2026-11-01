// lib/features/pos/widgets/pos_loose_sale_sheet.dart
//
// Ý 2 — Bán xé lẻ: nhập số lượng (theo đơn vị nhỏ nhất của nguyên liệu) +
// tổng giá bán (giá tay). Đơn vị hiển thị lấy theo cấu hình nguyên liệu.
// Nếu đơn vị là Kg/Lít → cho nhập số lẻ tối đa 3 chữ số thập phân.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class LooseSaleResult {
  final double amount;     // số lượng theo đơn vị nhỏ nhất (miếng / kg...)
  final double totalPrice; // tổng giá bán
  const LooseSaleResult({required this.amount, required this.totalPrice});
}

class PosLooseSaleSheet extends StatefulWidget {
  final String productName;
  final String mainUnit;   // đơn vị chính (Túi/Kg)
  final String smallUnit;  // đơn vị nhỏ nhất (Miếng/Kg)
  final num ratio;         // 1 mainUnit = ratio smallUnit (cho phép số lẻ)
  final bool allowDecimal; // Kg/Lít → cho số lẻ

  const PosLooseSaleSheet({
    super.key,
    required this.productName,
    required this.mainUnit,
    required this.smallUnit,
    required this.ratio,
    this.allowDecimal = false,
  });

  static Future<LooseSaleResult?> show(
    BuildContext context, {
    required String productName,
    required String mainUnit,
    required String smallUnit,
    required num ratio,
    bool allowDecimal = false,
  }) {
    return showModalBottomSheet<LooseSaleResult>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => PosLooseSaleSheet(
        productName: productName,
        mainUnit: mainUnit,
        smallUnit: smallUnit,
        ratio: ratio,
        allowDecimal: allowDecimal,
      ),
    );
  }

  @override
  State<PosLooseSaleSheet> createState() => _PosLooseSaleSheetState();
}

class _PosLooseSaleSheetState extends State<PosLooseSaleSheet> {
  final _amountCtrl = TextEditingController(text: '1');
  final _priceCtrl = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _amountCtrl.dispose();
    _priceCtrl.dispose();
    super.dispose();
  }

  String _fmtRatio(num r) =>
      r == r.toInt() ? r.toInt().toString() : r.toString();

  void _confirm() {
    final amount = double.tryParse(_amountCtrl.text.trim().replaceAll(',', '.')) ?? 0;
    final price = double.tryParse(_priceCtrl.text.trim()) ?? 0;
    if (amount <= 0) {
      setState(() => _error = 'Số ${widget.smallUnit.toLowerCase()} phải > 0');
      return;
    }
    if (price <= 0) {
      setState(() => _error = 'Nhập giá bán > 0');
      return;
    }
    Navigator.pop(context, LooseSaleResult(amount: amount, totalPrice: price));
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final bottom = MediaQuery.of(context).viewInsets.bottom +
        MediaQuery.of(context).padding.bottom +
        16;

    // Formatter cho ô số lượng
    final List<TextInputFormatter> amountFormatters = widget.allowDecimal
        ? [
            // Chỉ cho số, tối đa 3 chữ số sau dấu chấm
            FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
            TextInputFormatter.withFunction((oldV, newV) {
              final t = newV.text;
              if (t.isEmpty) return newV;
              if ('.'.allMatches(t).length > 1) return oldV; // tối đa 1 dấu chấm
              final dot = t.indexOf('.');
              if (dot >= 0 && t.length - dot - 1 > 3) return oldV; // tối đa 3 số lẻ
              return newV;
            }),
          ]
        : [FilteringTextInputFormatter.digitsOnly];

    InputDecoration deco(String label, String hint, {String? suffix}) =>
        InputDecoration(
          labelText: label,
          hintText: hint,
          suffixText: suffix,
          filled: true,
          fillColor: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF5F5F5),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: cs.outlineVariant)),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: cs.outlineVariant)),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: cs.primary, width: 1.5)),
        );

    return Container(
      decoration: BoxDecoration(
        color: surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(20, 12, 20, bottom),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 40,
          height: 4,
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: cs.outlineVariant,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        Row(children: [
          Icon(Icons.call_split_rounded, color: cs.primary, size: 22),
          const SizedBox(width: 8),
          Expanded(
            child: Text('Bán xé lẻ: ${widget.productName}',
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w700)),
          ),
        ]),
        const SizedBox(height: 6),
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
              '1 ${widget.mainUnit} = ${_fmtRatio(widget.ratio)} ${widget.smallUnit}',
              style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _amountCtrl,
          keyboardType: TextInputType.numberWithOptions(
              decimal: widget.allowDecimal),
          inputFormatters: amountFormatters,
          decoration: deco('Số ${widget.smallUnit} bán *',
              widget.allowDecimal ? 'VD: 0.25' : 'VD: 2',
              suffix: widget.smallUnit),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _priceCtrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: deco('Tổng giá bán *', 'VD: 140000', suffix: 'đ'),
        ),
        if (_error != null) ...[
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(_error!,
                style: TextStyle(color: cs.error, fontSize: 12)),
          ),
        ],
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _confirm,
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Thêm vào đơn',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          ),
        ),
      ]),
    );
  }
}
