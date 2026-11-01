import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Input tiền tệ — chỉ nhập số nguyên, tự format 1.000 khi nhập
/// VD: nhập 1000 → hiển thị "1.000"
class AppInputCurrency extends StatefulWidget {
  final String label;
  final String? hint;
  final String suffixText;
  final String? helperText;
  final double? initialValue;
  final void Function(double value) onChanged;
  final bool enabled;
  final bool isDense;

  const AppInputCurrency({
    super.key,
    required this.label,
    this.hint,
    this.suffixText = 'đ',
    this.helperText,
    this.initialValue,
    required this.onChanged,
    this.enabled = true,
    this.isDense = true,
  });

  @override
  State<AppInputCurrency> createState() => _AppInputCurrencyState();
}

class _AppInputCurrencyState extends State<AppInputCurrency> {
  late final TextEditingController _ctrl;
  late final FocusNode _focus;

  @override
  void initState() {
    super.initState();
    _focus = FocusNode();
    final initial = widget.initialValue;
    _ctrl = TextEditingController(
      text: initial != null && initial > 0
          ? _formatDisplay(initial.toInt().toString())
          : '',
    );
    _focus.addListener(() {
      if (!_focus.hasFocus) {
        // Khi rời focus: re-format
        final raw = _ctrl.text.replaceAll('.', '').replaceAll(',', '');
        if (raw.isNotEmpty) {
          _ctrl.text = _formatDisplay(raw);
          _ctrl.selection = TextSelection.collapsed(offset: _ctrl.text.length);
        }
      }
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  String _formatDisplay(String raw) {
    if (raw.isEmpty) return '';
    final n = int.tryParse(raw);
    if (n == null) return raw;
    // Format với dấu chấm phân cách hàng nghìn
    return n.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]}.',
    );
  }

  void _onChanged(String value) {
    // Xóa tất cả dấu chấm/phẩy để lấy số thực
    final raw = value.replaceAll('.', '').replaceAll(',', '');
    if (raw.isEmpty) {
      widget.onChanged(0);
      return;
    }
    final n = int.tryParse(raw);
    if (n == null) return;

    // Format lại và đặt cursor cuối
    final formatted = _formatDisplay(raw);
    final cursorPos = formatted.length;

    _ctrl.value = TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: cursorPos),
    );
    widget.onChanged(n.toDouble());
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return TextField(
      controller: _ctrl,
      focusNode: _focus,
      enabled: widget.enabled,
      keyboardType: TextInputType.number,
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'[\d.,]')),
      ],
      onChanged: _onChanged,
      decoration: InputDecoration(
        labelText: widget.label,
        hintText: widget.hint ?? '0',
        helperText: widget.helperText,
        suffixText: widget.suffixText,
        isDense: widget.isDense,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: cs.primary, width: 1.5),
        ),
      ),
    );
  }
}
