// lib/features/pos/components/pos_app_item_price_sheet.dart
// Feature 4: đổi giá bán nhanh cho món trong đơn App
// Click vào CartItem khi đang ở mode Shopee/Grab → sheet này hiện ra

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:originaltaste/data/models/pos/pos_cart_model.dart';

// ── Result ────────────────────────────────────────────────────────

class AppItemPriceResult {
  final double newPrice; // giá bán mới → final_unit_price trong DB
  const AppItemPriceResult(this.newPrice);
}

// ── Public API ────────────────────────────────────────────────────

Future<AppItemPriceResult?> showAppItemPriceSheet(
    BuildContext context, {
      required CartItem cartItem,
    }) {
  return showModalBottomSheet<AppItemPriceResult>(
    context:            context,
    isScrollControlled: true,
    backgroundColor:    Colors.transparent,
    builder: (_) => Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom),
      child: _AppItemPriceSheet(cartItem: cartItem),
    ),
  );
}

// ── Sheet widget ──────────────────────────────────────────────────

class _AppItemPriceSheet extends StatefulWidget {
  final CartItem cartItem;
  const _AppItemPriceSheet({required this.cartItem});
  @override
  State<_AppItemPriceSheet> createState() => _AppItemPriceSheetState();
}

class _AppItemPriceSheetState extends State<_AppItemPriceSheet> {
  final _ctrl = TextEditingController();
  String? _error;

  static final _fmt = NumberFormat('#,###', 'vi_VN');

  double get _basePrice    => widget.cartItem.product.basePrice;
  double get _currentPrice => widget.cartItem.selectedPrice.price;

  @override
  void initState() {
    super.initState();
    _ctrl.text = _fmt.format(_currentPrice.toInt());
    _ctrl.addListener(() => setState(() => _error = null));
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  double get _rawInput {
    final s = _ctrl.text.replaceAll(',', '').replaceAll('.', '');
    return double.tryParse(s) ?? 0;
  }

  void _confirm() {
    final val = _rawInput;
    if (val <= 0) {
      setState(() => _error = 'Vui lòng nhập giá hợp lệ');
      return;
    }
    Navigator.pop(context, AppItemPriceResult(val));
  }

  void _resetToBase() => setState(() {
    _ctrl.text = _fmt.format(_currentPrice.toInt());
    _error = null;
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    const blue = Color(0xFF0284C7);
    final changed = _rawInput > 0 && _rawInput != _currentPrice;

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 90),
      child: Column(mainAxisSize: MainAxisSize.min, children: [

        Center(child: Container(width: 36, height: 4,
            decoration: BoxDecoration(
                color: cs.onSurface.withOpacity(0.2),
                borderRadius: BorderRadius.circular(2)))),
        const SizedBox(height: 20),

        // Header
        Row(children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
                color: blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.edit_rounded, color: blue, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(widget.cartItem.product.name,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                maxLines: 1, overflow: TextOverflow.ellipsis),
            Text(
              'Giá App: ${_fmt.format(_currentPrice.toInt())}đ'
                  '  ·  Gốc: ${_fmt.format(_basePrice.toInt())}đ',
              style: TextStyle(fontSize: 11,
                  color: cs.onSurface.withOpacity(0.55)),
            ),
          ])),
        ]),
        const SizedBox(height: 8),

        // Info note
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
              color: cs.primaryContainer.withOpacity(0.4),
              borderRadius: BorderRadius.circular(8)),
          child: Row(children: [
            Icon(Icons.info_outline_rounded, size: 14,
                color: cs.primary.withOpacity(0.7)),
            const SizedBox(width: 8),
            Expanded(child: Text(
              'Chỉ áp dụng cho đơn này. base_price trong DB không thay đổi.',
              style: TextStyle(fontSize: 11,
                  color: cs.onSurface.withOpacity(0.65)),
            )),
          ]),
        ),
        const SizedBox(height: 16),

        // Input
        TextField(
          controller:   _ctrl,
          autofocus:    true,
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            _ThousandFormatter(),
          ],
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
          decoration: InputDecoration(
            labelText:  'Giá bán cho đơn này (đ)',
            suffixText: 'đ',
            errorText:  _error,
            filled:     true,
            fillColor:  cs.surfaceContainerHighest,
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 16),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: cs.outline)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: cs.outline)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: blue, width: 1.5)),
            errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: cs.error)),
          ),
          onSubmitted: (_) => _confirm(),
        ),

        // Diff
        if (changed) ...[
          const SizedBox(height: 10),
          Text(
            _rawInput > _currentPrice
                ? '▲ Tăng ${_fmt.format((_rawInput - _currentPrice).toInt())}đ'
                : '▼ Giảm ${_fmt.format((_currentPrice - _rawInput).toInt())}đ',
            style: TextStyle(
              fontSize: 12, fontWeight: FontWeight.w600,
              color: _rawInput > _currentPrice
                  ? Colors.green.shade700
                  : const Color(0xFFEE4D2D),
            ),
          ),
        ],
        const SizedBox(height: 20),

        Row(children: [
          OutlinedButton.icon(
            onPressed: _resetToBase,
            icon:  const Icon(Icons.restart_alt_rounded, size: 16),
            label: const Text('Giá gốc',
                style: TextStyle(fontSize: 13)),
            style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12))),
          ),
          const SizedBox(width: 8),
          Expanded(child: OutlinedButton(
            onPressed: () => Navigator.pop(context, null),
            style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12))),
            child: const Text('Hủy'),
          )),
          const SizedBox(width: 10),
          Expanded(flex: 2, child: FilledButton.icon(
            onPressed: _confirm,
            icon:  const Icon(Icons.check_rounded, size: 18),
            label: const Text('Xác nhận',
                style: TextStyle(fontWeight: FontWeight.w700)),
            style: FilledButton.styleFrom(
                backgroundColor: blue,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12))),
          )),

        ]),
      ]),
    );
  }
}

class _ThousandFormatter extends TextInputFormatter {
  static final _fmt = NumberFormat('#,###', 'vi_VN');
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue old, TextEditingValue value) {
    if (value.text.isEmpty) return value;
    final digits = value.text.replaceAll(',', '');
    final number = int.tryParse(digits);
    if (number == null) return old;
    final formatted = _fmt.format(number);
    return TextEditingValue(
        text: formatted,
        selection: TextSelection.collapsed(offset: formatted.length));
  }
}