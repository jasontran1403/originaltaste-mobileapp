// lib/shared/widgets/app_input_number.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/utils/formatters.dart';

/// Loại số nhập
enum NumberInputType { money, quantity }

class AppInputNumber extends StatefulWidget {
  final String? label;
  final String? hint;
  final TextEditingController? controller;
  final NumberInputType type;
  final void Function(double value)? onChanged;
  final String? Function(String?)? validator;
  final TextInputAction textInputAction;
  final FocusNode? focusNode;
  final bool readOnly;

  const AppInputNumber({
    super.key,
    this.label,
    this.hint,
    this.controller,
    this.type = NumberInputType.money,
    this.onChanged,
    this.validator,
    this.textInputAction = TextInputAction.next,
    this.focusNode,
    this.readOnly = false,
  });

  @override
  State<AppInputNumber> createState() => _AppInputNumberState();
}

class _AppInputNumberState extends State<AppInputNumber> {
  late TextEditingController _ctrl;
  bool _isExternal = false;

  @override
  void initState() {
    super.initState();
    if (widget.controller != null) {
      _ctrl = widget.controller!;
      _isExternal = true;
    } else {
      _ctrl = TextEditingController();
    }
  }

  @override
  void dispose() {
    if (!_isExternal) _ctrl.dispose();
    super.dispose();
  }

  void _onChanged(String raw) {
    final formatted = widget.type == NumberInputType.money
        ? AppFormatter.moneyInput(raw)
        : AppFormatter.quantityInput(raw);

    // Giữ cursor ở cuối
    if (_ctrl.text != formatted) {
      _ctrl.value = TextEditingValue(
        text: formatted,
        selection: TextSelection.collapsed(offset: formatted.length),
      );
    }

    final parsed = widget.type == NumberInputType.money
        ? AppFormatter.parseMoney(formatted)
        : AppFormatter.parseQuantity(formatted);

    widget.onChanged?.call(parsed);
  }

  @override
  Widget build(BuildContext context) {
    final suffix = widget.type == NumberInputType.money ? 'đ' : null;

    return TextFormField(
      controller: _ctrl,
      focusNode: widget.focusNode,
      readOnly: widget.readOnly,
      textInputAction: widget.textInputAction,
      keyboardType: widget.type == NumberInputType.money
          ? TextInputType.number
          : const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        widget.type == NumberInputType.money
            ? FilteringTextInputFormatter.digitsOnly
            : FilteringTextInputFormatter.allow(RegExp(r'[\d,.]')),
      ],
      onChanged: _onChanged,
      validator: widget.validator,
      style: Theme.of(context).textTheme.bodyLarge,
      decoration: InputDecoration(
        labelText: widget.label,
        hintText: widget.hint ?? (widget.type == NumberInputType.money ? '0' : '0'),
        suffixText: suffix,
      ),
    );
  }
}
