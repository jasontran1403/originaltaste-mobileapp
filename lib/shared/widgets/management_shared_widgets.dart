// lib/shared/widgets/management_shared_widgets.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../app/theme/app_colors.dart';

// ══════════════════════════════════════════════════════════════════
// FORMATTERS
// ══════════════════════════════════════════════════════════════════

String fmtDate(int? ts) {
  if (ts == null) return '--';
  final dt = DateTime.fromMillisecondsSinceEpoch(ts);
  return DateFormat('dd/MM/yyyy').format(dt);
}

String fmtQty(double v) =>
    v == v.truncateToDouble() ? v.toInt().toString() : v.toStringAsFixed(2);

// ══════════════════════════════════════════════════════════════════
// TAB TOGGLE BAR
// ══════════════════════════════════════════════════════════════════

class NumericField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode? focusNode;
  final String? hint;
  final String? suffixText;
  final TextAlign textAlign;
  final bool decimal;
  final List<TextInputFormatter>? inputFormatters;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onSubmitted;
  final VoidCallback? onTap;
  final TextStyle? style;
  final InputDecoration? decoration;
  final double? width;
  final EdgeInsetsGeometry contentPadding;
  final Color? focusColor; // màu border khi focus — mặc định dùng primary của theme

  const NumericField({
    super.key,
    required this.controller,
    this.focusNode,
    this.hint,
    this.suffixText,
    this.textAlign    = TextAlign.start,
    this.decimal      = true,
    this.inputFormatters,
    this.onChanged,
    this.onSubmitted,
    this.onTap,
    this.style,
    this.decoration,
    this.width,
    this.contentPadding = const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
    this.focusColor,
  });

  @override
  Widget build(BuildContext context) {
    final isDark    = Theme.of(context).brightness == Brightness.dark;
    final primary   = focusColor ??
        (isDark ? AppColors.primary : AppColors.primaryDark);
    final secondary = isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;
    final border    = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final textColor = isDark
        ? AppColors.darkTextPrimary
        : AppColors.lightTextPrimary;

    final defaultFormatters = decimal
        ? [FilteringTextInputFormatter.allow(RegExp(r'^\d*[,.]?\d{0,2}'))]
        : [FilteringTextInputFormatter.digitsOnly];

    final field = TextField(
      controller:      controller,
      focusNode:       focusNode,
      keyboardType:    decimal
          ? const TextInputType.numberWithOptions(decimal: true)
          : TextInputType.number,
      inputFormatters: inputFormatters ?? defaultFormatters,
      textAlign:       textAlign,
      textInputAction: TextInputAction.done,
      onSubmitted:     onSubmitted != null ? (_) => onSubmitted!() : (_) => FocusScope.of(context).unfocus(),
      onChanged:       onChanged,
      onTap:           onTap,
      style: style ?? TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: textColor,
      ),
      decoration: decoration ?? InputDecoration(
        hintText:   hint,
        hintStyle:  TextStyle(fontSize: 13, color: secondary.withOpacity(0.5)),
        suffixText: suffixText,
        suffixStyle: TextStyle(
          fontSize:   12,
          fontWeight: FontWeight.w700,
          color:      primary,
        ),
        isDense:        true,
        isCollapsed:    true,
        contentPadding: contentPadding,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: border)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: border)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: primary, width: 1.5)),
      ),
    );

    if (width != null) return SizedBox(width: width, child: field);
    return field;
  }
}

class MgmtTabBar<T> extends StatelessWidget {
  final List<MgmtTabItem<T>> tabs;
  final T selected;
  final ValueChanged<T> onSelect;

  const MgmtTabBar({
    super.key,
    required this.tabs,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final isDark    = Theme.of(context).brightness == Brightness.dark;
    final primary   = isDark ? AppColors.primary : AppColors.primaryDark;
    final secondary = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final bg        = isDark ? AppColors.darkCard : AppColors.lightCard;
    final border    = isDark ? AppColors.darkBorder : AppColors.lightBorder;

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color:        bg,
        borderRadius: BorderRadius.circular(12),
        border:       Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: tabs.map((t) {
          final sel = selected == t.value;
          return GestureDetector(
            onTap: () => onSelect(t.value),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color:        sel ? primary : Colors.transparent,
                borderRadius: BorderRadius.circular(9),
                boxShadow: sel
                    ? [BoxShadow(
                    color: primary.withOpacity(0.3),
                    blurRadius: 6, offset: const Offset(0, 2))]
                    : null,
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(t.icon, size: 15, color: sel ? Colors.white : secondary),
                const SizedBox(width: 6),
                Text(t.label,
                    style: TextStyle(
                      fontSize:   13,
                      fontWeight: FontWeight.w700,
                      color:      sel ? Colors.white : secondary,
                    )),
              ]),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class MgmtTabItem<T> {
  final T value;
  final String label;
  final IconData icon;
  const MgmtTabItem({required this.value, required this.label, required this.icon});
}

// ══════════════════════════════════════════════════════════════════
// EMPTY / ERROR STATES
// ══════════════════════════════════════════════════════════════════

class MgmtEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onAction;
  final String? actionLabel;

  const MgmtEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.onAction,
    this.actionLabel,
  });

  @override
  Widget build(BuildContext context) {
    final isDark    = Theme.of(context).brightness == Brightness.dark;
    final secondary = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: secondary.withOpacity(0.07),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 36, color: secondary.withOpacity(0.5)),
          ),
          const SizedBox(height: 16),
          Text(title,
              style: TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w600,
                  color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary)),
          if (subtitle != null) ...[
            const SizedBox(height: 6),
            Text(subtitle!,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: secondary)),
          ],
          if (onAction != null) ...[
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: onAction,
              icon:  const Icon(Icons.add, size: 16),
              label: Text(actionLabel ?? 'Thêm mới'),
            ),
          ],
        ]),
      ),
    );
  }
}

class MgmtErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const MgmtErrorState({super.key, required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final secondary = Theme.of(context).brightness == Brightness.dark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.wifi_off_rounded, size: 40, color: AppColors.error.withOpacity(0.6)),
          const SizedBox(height: 12),
          Text(message,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: secondary)),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon:  const Icon(Icons.refresh_rounded, size: 16),
            label: const Text('Thử lại'),
          ),
        ]),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════
// SECTION CARD
// ══════════════════════════════════════════════════════════════════

class MgmtCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? margin;
  final EdgeInsetsGeometry padding;
  final double radius;
  final VoidCallback? onTap;
  final Color? borderColor;
  final double? elevation;

  const MgmtCard({
    super.key,
    required this.child,
    this.margin,
    this.padding = const EdgeInsets.all(16),
    this.radius = 14,
    this.onTap,
    this.borderColor,
    this.elevation = 3,
  });

  @override
  Widget build(BuildContext context) {
    final isDark          = Theme.of(context).brightness == Brightness.dark;
    final cardBg          = isDark ? AppColors.darkCard : AppColors.lightCard;
    final defaultBorder   = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final usedBorderColor = borderColor ?? defaultBorder;

    return Padding(
      padding: margin ?? EdgeInsets.zero,
      child: Material(
        color:        cardBg,
        borderRadius: BorderRadius.circular(radius),
        elevation:    elevation ?? 0,
        shadowColor:  Colors.black.withOpacity(isDark ? 0.4 : 0.15),
        child: InkWell(
          onTap:        onTap,
          borderRadius: BorderRadius.circular(radius),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(radius),
              border: Border.all(color: usedBorderColor, width: 1),
              boxShadow: elevation != null && elevation! > 0
                  ? [BoxShadow(
                color:      Colors.black.withOpacity(isDark ? 0.25 : 0.05),
                blurRadius: 8,
                offset:     const Offset(0, 3),
              )]
                  : null,
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════
// FORM FIELD HELPERS
// ══════════════════════════════════════════════════════════════════

/// Text field với label nổi.
/// [showDoneButton] = true → bàn phím số có nút Done để ẩn bàn phím.
class MgmtTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? hint;
  final IconData? prefixIcon;
  final TextInputType keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final String? Function(String?)? validator;
  final bool readOnly;
  final VoidCallback? onTap;
  final int maxLines;
  final bool showDoneButton;

  const MgmtTextField({
    super.key,
    required this.controller,
    required this.label,
    this.hint,
    this.prefixIcon,
    this.keyboardType   = TextInputType.text,
    this.inputFormatters,
    this.validator,
    this.readOnly       = false,
    this.onTap,
    this.maxLines       = 1,
    this.showDoneButton = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark    = Theme.of(context).brightness == Brightness.dark;
    final primary   = isDark ? AppColors.primary : AppColors.primaryDark;
    final secondary = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final border    = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final fillColor = isDark
        ? AppColors.darkBg.withOpacity(0.5)
        : AppColors.lightBg.withOpacity(0.6);

    return TextFormField(
      controller:      controller,
      keyboardType:    keyboardType,
      inputFormatters: inputFormatters,
      validator:       validator,
      readOnly:        readOnly,
      onTap:           onTap,
      maxLines:        maxLines,
      // ── Done button trên bàn phím ──────────────────────────────
      textInputAction: showDoneButton ? TextInputAction.done : TextInputAction.next,
      onFieldSubmitted: showDoneButton
          ? (_) => FocusScope.of(context).unfocus()
          : null,
      style: TextStyle(
        fontSize: 14,
        color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
      ),
      decoration: InputDecoration(
        labelText:  label,
        hintText:   hint,
        hintStyle:  TextStyle(fontSize: 13, color: secondary.withOpacity(0.6)),
        labelStyle: TextStyle(fontSize: 13, color: secondary),
        prefixIcon: prefixIcon != null
            ? Icon(prefixIcon, size: 18, color: secondary)
            : null,
        filled:    true,
        fillColor: fillColor,
        isDense:   true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: border)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: border)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: primary, width: 1.5)),
        errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: AppColors.error)),
        focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: AppColors.error, width: 1.5)),
      ),
    );
  }
}

/// Date picker field
class MgmtDateField extends StatelessWidget {
  final String label;
  final DateTime? value;
  final ValueChanged<DateTime?> onChanged;
  final bool allowClear;

  const MgmtDateField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.allowClear = true,
  });

  @override
  Widget build(BuildContext context) {
    final isDark    = Theme.of(context).brightness == Brightness.dark;
    final primary   = isDark ? AppColors.primary : AppColors.primaryDark;
    final secondary = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final border    = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final fillColor = isDark
        ? AppColors.darkBg.withOpacity(0.5)
        : AppColors.lightBg.withOpacity(0.6);
    final hasValue  = value != null;

    return GestureDetector(
      onTap: () async {
        final picked = await showDatePicker(
          context:     context,
          initialDate: value ?? DateTime.now(),
          firstDate:   DateTime(2000),
          lastDate:    DateTime(2100),
          builder: (ctx, child) => Theme(
            data: Theme.of(ctx).copyWith(
              colorScheme: ColorScheme.fromSeed(
                  seedColor: primary,
                  brightness: Theme.of(ctx).brightness),
            ),
            child: child!,
          ),
        );
        if (picked != null) onChanged(picked);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color:        fillColor,
          borderRadius: BorderRadius.circular(10),
          border:       Border.all(color: border),
        ),
        child: Row(children: [
          Icon(Icons.calendar_today_outlined, size: 17,
              color: hasValue ? primary : secondary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize:       MainAxisSize.min,
              children: [
                Text(label, style: TextStyle(fontSize: 11, color: secondary)),
                const SizedBox(height: 2),
                Text(
                  hasValue ? fmtDate(value!.millisecondsSinceEpoch) : 'Chưa chọn',
                  style: TextStyle(
                    fontSize: 14,
                    color: hasValue
                        ? (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary)
                        : secondary.withOpacity(0.6),
                  ),
                ),
              ],
            ),
          ),
          if (hasValue && allowClear)
            GestureDetector(
              onTap: () => onChanged(null),
              child: Icon(Icons.close_rounded, size: 16,
                  color: secondary.withOpacity(0.7)),
            ),
        ]),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════
// CONFIRM DELETE DIALOG
// ══════════════════════════════════════════════════════════════════

Future<bool> confirmDeleteDialog(
    BuildContext context, {required String itemName}) async {
  final ok = await showDialog<bool>(
    context:          context,
    useRootNavigator: false,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      title: Row(children: [
        Icon(Icons.delete_outline_rounded, color: AppColors.error, size: 22),
        const SizedBox(width: 8),
        const Expanded(
            child: Text('Xác nhận xóa',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700))),
      ]),
      content: RichText(
        text: TextSpan(
          style: const TextStyle(fontSize: 14, color: Colors.grey),
          children: [
            const TextSpan(text: 'Bạn có chắc muốn xóa '),
            TextSpan(text: '"$itemName"',
                style: const TextStyle(
                    fontWeight: FontWeight.w700, color: Colors.black87)),
            const TextSpan(text: '? Hành động này không thể hoàn tác.'),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Hủy')),
        ElevatedButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white),
          child: const Text('Xóa'),
        ),
      ],
    ),
  );
  return ok == true;
}

// ══════════════════════════════════════════════════════════════════
// SNACKBAR HELPERS
// ══════════════════════════════════════════════════════════════════

void showSuccessSnack(BuildContext context, String msg) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Row(children: [
      const Icon(Icons.check_circle_outline, color: Colors.white, size: 18),
      const SizedBox(width: 8),
      Expanded(child: Text(msg)),
    ]),
    backgroundColor: Colors.green.shade700,
    behavior:        SnackBarBehavior.floating,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    margin: const EdgeInsets.all(12),
  ));
}

void showErrorSnack(BuildContext context, String msg) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Row(children: [
      const Icon(Icons.error_outline, color: Colors.white, size: 18),
      const SizedBox(width: 8),
      Expanded(child: Text(msg)),
    ]),
    backgroundColor: Colors.red.shade700,
    behavior:        SnackBarBehavior.floating,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    margin: const EdgeInsets.all(12),
  ));
}

// ══════════════════════════════════════════════════════════════════
// COMING SOON PLACEHOLDER
// ══════════════════════════════════════════════════════════════════

class ComingSoonPane extends StatelessWidget {
  final String tabName;
  const ComingSoonPane({super.key, required this.tabName});

  @override
  Widget build(BuildContext context) {
    final isDark    = Theme.of(context).brightness == Brightness.dark;
    final secondary = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final primary   = isDark ? AppColors.primary : AppColors.primaryDark;

    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: primary.withOpacity(0.08),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.construction_rounded,
              size: 44, color: primary.withOpacity(0.6)),
        ),
        const SizedBox(height: 20),
        Text('$tabName đang được phát triển',
            style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.w700,
                color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary)),
        const SizedBox(height: 8),
        Text('Tính năng sẽ sớm ra mắt',
            style: TextStyle(fontSize: 13, color: secondary)),
      ]),
    );
  }
}