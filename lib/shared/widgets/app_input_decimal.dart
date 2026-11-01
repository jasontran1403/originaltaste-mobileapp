import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Input số lẻ — tối đa 2 chữ số thập phân, min 0.01
/// Dùng cho: định lượng nguyên liệu (Kg), số lượng nhập kho
/// Tự động chấp nhận dấu phẩy hoặc dấu chấm tùy bàn phím
class AppInputDecimal extends StatefulWidget {
  final String label;
  final String? hint;
  final String? suffixText;
  final String? helperText;
  final double? initialValue;
  final double min;
  final double max;
  final int decimalPlaces; // mặc định 2
  final void Function(double value) onChanged;
  final bool enabled;
  final bool isDense;

  const AppInputDecimal({
    super.key,
    required this.label,
    this.hint,
    this.suffixText,
    this.helperText,
    this.initialValue,
    this.min = 0.01,
    this.max = 9999.99,
    this.decimalPlaces = 2,
    required this.onChanged,
    this.enabled = true,
    this.isDense = true,
  });

  @override
  State<AppInputDecimal> createState() => _AppInputDecimalState();
}

class _AppInputDecimalState extends State<AppInputDecimal> {
  late final TextEditingController _ctrl;
  late final FocusNode _focus;

  @override
  void initState() {
    super.initState();
    _focus = FocusNode();
    final initial = widget.initialValue;
    _ctrl = TextEditingController(
      text: initial != null && initial > 0
          ? _formatValue(initial)
          : '',
    );
    _focus.addListener(() {
      if (!_focus.hasFocus) {
        final raw = _normalizeDecimal(_ctrl.text);
        final v = double.tryParse(raw);
        if (v != null) {
          _ctrl.text = _formatValue(v);
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

  String _normalizeDecimal(String raw) => raw.replaceAll(',', '.');

  String _formatValue(double v) {
    // Nếu là số nguyên → không hiện .0
    if (v == v.truncateToDouble() && widget.decimalPlaces == 0) {
      return v.toInt().toString();
    }
    // Nếu số lẻ thực sự
    String s = v.toStringAsFixed(widget.decimalPlaces);
    // Xóa trailing zeros: 1.50 → 1.5, 1.00 → 1
    if (s.contains('.')) {
      s = s.replaceAll(RegExp(r'0+$'), '');
      s = s.replaceAll(RegExp(r'\.$'), '');
    }
    return s;
  }

  void _onChanged(String value) {
    // Cho phép nhập dở (VD: "1." hoặc "1,")
    final normalized = _normalizeDecimal(value);
    if (normalized.isEmpty) { widget.onChanged(0); return; }
    // Trailing dot/comma → đang nhập tiếp, không parse
    if (normalized.endsWith('.')) return;
    final v = double.tryParse(normalized);
    if (v == null) return;
    widget.onChanged(v);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return TextField(
      controller: _ctrl,
      focusNode: _focus,
      enabled: widget.enabled,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        // Cho phép số, dấu chấm, dấu phẩy — chỉ 1 dấu phân cách
        FilteringTextInputFormatter.allow(RegExp(r'[\d.,]')),
        _DecimalInputFormatter(decimalPlaces: widget.decimalPlaces),
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

/// Formatter đảm bảo chỉ có 1 dấu phân cách và tối đa N chữ số thập phân
class _DecimalInputFormatter extends TextInputFormatter {
  final int decimalPlaces;
  _DecimalInputFormatter({required this.decimalPlaces});

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    String text = newValue.text.replaceAll(',', '.');
    // Chỉ cho 1 dấu chấm
    final parts = text.split('.');
    if (parts.length > 2) text = '${parts[0]}.${parts.sublist(1).join('')}';
    // Giới hạn số chữ số thập phân
    if (parts.length == 2 && parts[1].length > decimalPlaces) {
      text = '${parts[0]}.${parts[1].substring(0, decimalPlaces)}';
    }
    return newValue.copyWith(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

/// Input số nguyên nhỏ gọn với nút +/- (dùng cho số lượng nguyên liệu trong variant)
class AppInputQuantityCounter extends StatelessWidget {
  final int value;
  final int min;
  final int max;
  final void Function(int) onChanged;
  final Color? color;

  const AppInputQuantityCounter({
    super.key,
    required this.value,
    this.min = 0,
    this.max = 999,
    required this.onChanged,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final c = color ?? cs.primary;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _btn(Icons.remove, value > min ? () => onChanged(value - 1) : null, c),
        SizedBox(
          width: 32,
          child: Text(
            '$value',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: value > 0 ? c : Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
            ),
          ),
        ),
        _btn(Icons.add, value < max ? () => onChanged(value + 1) : null, c),
      ],
    );
  }

  Widget _btn(IconData icon, VoidCallback? onTap, Color c) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: 26, height: 26,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: onTap != null ? c : Colors.grey.shade200,
        ),
        child: Icon(icon, size: 14,
            color: onTap != null ? Colors.white : Colors.grey),
      ),
    );
  }
}
