// lib/features/customer/widgets/customer_widgets.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../controller/customer_controller.dart';

// ══════════════════════════════════════════════════════════════════
// CONSTANTS
// ══════════════════════════════════════════════════════════════════

const _teal   = Color(0xFF0D9488);
const _blue   = Color(0xFF0284C7);
const _orange = Color(0xFFF97316);

// ══════════════════════════════════════════════════════════════════
// MODE TOGGLE (chỉ superAdmin)
// ══════════════════════════════════════════════════════════════════

class CustomerModeToggle extends StatelessWidget {
  final CustomerMode current;
  final ValueChanged<CustomerMode> onChanged;

  const CustomerModeToggle({
    super.key,
    required this.current,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final cs   = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: dark ? Colors.black.withOpacity(0.3)
            : cs.onSurface.withOpacity(0.07),
        borderRadius: BorderRadius.circular(10),
      ),
      padding: const EdgeInsets.all(3),
      child: Row(children: [
        _pill(context, 'Sỉ / Lẻ', CustomerMode.b2b,  _teal),
        _pill(context, 'POS',     CustomerMode.pos,  _blue),
      ]),
    );
  }

  Widget _pill(BuildContext context, String label,
      CustomerMode mode, Color color) {
    final active = current == mode;
    return Expanded(
      child: GestureDetector(
        onTap: () => onChanged(mode),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          decoration: BoxDecoration(
            color: active ? color : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text(label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: active ? Colors.white
                    : Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════
// SEARCH BAR
// ══════════════════════════════════════════════════════════════════

class CustomerSearchBar extends StatelessWidget {
  final String hint;
  final ValueChanged<String> onChanged;
  final TextEditingController? controller;

  const CustomerSearchBar({
    super.key,
    required this.hint,
    required this.onChanged,
    this.controller,
  });

  @override
  Widget build(BuildContext context) {
    final cs   = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: dark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(
            color: Colors.black.withOpacity(0.04), blurRadius: 8)],
      ),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        style: TextStyle(fontSize: 14,
            color: dark ? Colors.white : const Color(0xFF0F172A)),
        decoration: InputDecoration(
          hintText: hint,
          prefixIcon: Icon(Icons.search_rounded,
              color: cs.onSurface.withOpacity(0.4), size: 20),
          border: InputBorder.none,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
              vertical: 12, horizontal: 4),
          hintStyle: TextStyle(fontSize: 14,
              color: cs.onSurface.withOpacity(0.4)),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════
// TYPE FILTER CHIPS (B2B)
// ══════════════════════════════════════════════════════════════════

class B2bTypeFilterRow extends StatelessWidget {
  final String? selected; // null | 'COMPANY' | 'RETAIL'
  final ValueChanged<String?> onChanged;

  const B2bTypeFilterRow({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(children: [
        _chip(context, 'Tất cả',       null,      Icons.people_rounded),
        const SizedBox(width: 8),
        _chip(context, 'Doanh nghiệp', 'COMPANY', Icons.business_rounded),
        const SizedBox(width: 8),
        _chip(context, 'Khách lẻ',     'RETAIL',  Icons.person_rounded),
      ]),
    );
  }

  Widget _chip(BuildContext context, String label,
      String? value, IconData icon) {
    final active = selected == value;
    final cs     = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: () => onChanged(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: active ? _teal : cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: active ? _teal : cs.outline.withOpacity(0.3),
          ),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 14,
              color: active ? Colors.white
                  : cs.onSurface.withOpacity(0.6)),
          const SizedBox(width: 5),
          Text(label, style: TextStyle(
            fontSize: 12, fontWeight: FontWeight.w600,
            color: active ? Colors.white
                : cs.onSurface.withOpacity(0.7),
          )),
        ]),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════
// B2B CUSTOMER CARD
// ══════════════════════════════════════════════════════════════════

class B2bCustomerCard extends StatelessWidget {
  final B2bCustomerModel customer;
  final VoidCallback onTap;

  const B2bCustomerCard({
    super.key,
    required this.customer,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs   = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final isCompany = customer.isCompany;
    final color = isCompany ? _teal : _orange;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: dark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Row(children: [
          // Avatar với chữ đầu
          Container(
            width: 46, height: 46,
            decoration: BoxDecoration(
                color: color.withOpacity(0.12), shape: BoxShape.circle),
            child: Center(child: Text(
              (customer.customerCode?.isNotEmpty == true
                  ? customer.customerCode![0].toUpperCase()
                  : customer.displayName.isNotEmpty
                  ? customer.displayName[0].toUpperCase()
                  : '?'),
              style: TextStyle(fontSize: 18,
                  fontWeight: FontWeight.w800, color: color),
            )),
          ),
          const SizedBox(width: 12),

          Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Code + type badge
            Row(children: [
              Text(customer.customerCode ?? customer.displayName,
                  style: TextStyle(fontSize: 12,
                      fontWeight: FontWeight.w700, color: color)),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6)),
                child: Text(
                  isCompany ? 'DN' : 'Lẻ',
                  style: TextStyle(fontSize: 10,
                      fontWeight: FontWeight.w700, color: color),
                ),
              ),
            ]),
            const SizedBox(height: 2),
            Text(customer.displayName,
                style: TextStyle(fontSize: 14,
                    fontWeight: FontWeight.w700, color: cs.onSurface),
                maxLines: 1, overflow: TextOverflow.ellipsis),
            if (customer.phone != null) ...[
              const SizedBox(height: 2),
              Text(customer.phone!,
                  style: TextStyle(fontSize: 12,
                      color: cs.onSurface.withOpacity(0.5))),
            ],
          ])),

          // Discount badge
          if (customer.discountRate > 0)
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                  color: _teal.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8)),
              child: Text('CK ${customer.discountRate}%',
                  style: const TextStyle(fontSize: 11,
                      fontWeight: FontWeight.w700, color: _teal)),
            ),

          const SizedBox(width: 8),
          Icon(Icons.chevron_right_rounded,
              size: 18, color: cs.onSurface.withOpacity(0.3)),
        ]),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════
// POS CUSTOMER CARD
// ══════════════════════════════════════════════════════════════════

class PosCustomerCard extends StatelessWidget {
  final PosCustomerModel customer;
  final VoidCallback onTap;

  const PosCustomerCard({
    super.key,
    required this.customer,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs   = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final fmt  = NumberFormat('#,###', 'vi_VN');

    Color _typeColor(String type) => switch (type) {
      'CTV'  => const Color(0xFF3B82F6),
      'CTVV' => const Color(0xFFF59E0B),
      _      => const Color(0xFF94A3B8),
    };


    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: dark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Row(children: [
          Container(
            width: 46, height: 46,
            decoration: BoxDecoration(
                color: _blue.withOpacity(0.12), shape: BoxShape.circle),
            child: Center(child: Text(
              customer.name.isNotEmpty
                  ? customer.name[0].toUpperCase() : '?',
              style: const TextStyle(fontSize: 18,
                  fontWeight: FontWeight.w800, color: _blue),
            )),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(customer.name, style: TextStyle(
                fontSize: 14, fontWeight: FontWeight.w700,
                color: cs.onSurface)),
            const SizedBox(height: 2),
            Text(customer.phone, style: TextStyle(
                fontSize: 12, color: cs.onSurface.withOpacity(0.5),
                letterSpacing: 0.5)),
            const SizedBox(height: 3),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: _typeColor(customer.customerType).withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                customer.customerTypeLabel,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: _typeColor(customer.customerType),
                ),
              ),
            ),
            if (customer.storeName != null) ...[
              const SizedBox(height: 3),
              Row(children: [
                Icon(Icons.store_rounded, size: 11,
                    color: _blue.withOpacity(0.6)),
                const SizedBox(width: 3),
                Text(customer.storeName!,
                    style: TextStyle(fontSize: 11,
                        color: _blue.withOpacity(0.7),
                        fontWeight: FontWeight.w600)),
              ]),
            ],
          ])),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(fmt.format(customer.totalSpend),
                style: const TextStyle(fontSize: 14,
                    fontWeight: FontWeight.w700, color: _blue)),
            Text('đ chi tiêu', style: TextStyle(
                fontSize: 10, color: cs.onSurface.withOpacity(0.4))),
          ]),
          const SizedBox(width: 8),
          Icon(Icons.chevron_right_rounded,
              size: 18, color: cs.onSurface.withOpacity(0.3)),
        ]),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════
// FORM FIELD HELPER
// ══════════════════════════════════════════════════════════════════

class CustomerFormField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? hint;
  final IconData icon;
  final bool readOnly;
  final bool required;
  final TextInputType keyboard;
  final List<TextInputFormatter>? formatters;
  final int maxLines;
  final Color? accentColor;

  const CustomerFormField({
    super.key,
    required this.controller,
    required this.label,
    this.hint,
    required this.icon,
    this.readOnly    = false,
    this.required    = false,
    this.keyboard    = TextInputType.text,
    this.formatters,
    this.maxLines    = 1,
    this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cs     = Theme.of(context).colorScheme;
    final color  = accentColor ?? _teal;
    final bg     = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final border = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final txtSec = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return TextFormField(
      controller:  controller,
      readOnly:    readOnly,
      keyboardType: maxLines > 1 ? TextInputType.multiline : keyboard,
      maxLines:    maxLines,
      inputFormatters: formatters,
      style: TextStyle(fontSize: 14,
          color: readOnly
              ? (isDark ? Colors.white70 : const Color(0xFF334155))
              : (isDark ? Colors.white   : const Color(0xFF0F172A))),
      decoration: InputDecoration(
        labelText: required ? '$label *' : label,
        hintText:  hint,
        prefixIcon: Icon(icon, size: 18,
            color: readOnly
                ? txtSec.withOpacity(0.4) : color.withOpacity(0.7)),
        filled:     true,
        fillColor:  readOnly ? color.withOpacity(0.03) : bg,
        contentPadding: const EdgeInsets.symmetric(
            horizontal: 14, vertical: 13),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: border)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: border)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: color, width: 1.5)),
        labelStyle: TextStyle(fontSize: 13, color: txtSec),
        hintStyle:  TextStyle(fontSize: 13,
            color: txtSec.withOpacity(0.6)),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════
// DOB PICKER BUTTON (reusable)
// ══════════════════════════════════════════════════════════════════

class DobPickerButton extends StatelessWidget {
  final DateTime? value;
  final bool readOnly;
  final VoidCallback onTap;
  final VoidCallback? onClear;
  final Color? accentColor;

  const DobPickerButton({
    super.key,
    required this.value,
    required this.onTap,
    this.readOnly    = false,
    this.onClear,
    this.accentColor,
  });

  String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/'
          '${d.month.toString().padLeft(2, '0')}/${d.year}';

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cs     = Theme.of(context).colorScheme;
    final color  = accentColor ?? _teal;
    final bg     = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final border = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final txtSec = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return GestureDetector(
      onTap: readOnly ? null : onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: readOnly ? color.withOpacity(0.03) : bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: value != null ? color.withOpacity(0.5) : border,
            width: value != null ? 1.5 : 1,
          ),
        ),
        child: Row(children: [
          Icon(Icons.cake_rounded, size: 18,
              color: readOnly
                  ? txtSec.withOpacity(0.4) : color.withOpacity(0.7)),
          const SizedBox(width: 12),
          Expanded(child: Text(
            value != null ? _fmt(value!) : 'Ngày sinh (tùy chọn)',
            style: TextStyle(fontSize: 14,
              color: value != null
                  ? (isDark ? Colors.white : const Color(0xFF0F172A))
                  : txtSec.withOpacity(0.6),
            ),
          )),
          if (value != null && !readOnly && onClear != null)
            GestureDetector(
              onTap: onClear,
              child: Icon(Icons.clear_rounded, size: 16,
                  color: txtSec.withOpacity(0.5)),
            )
          else if (!readOnly)
            Icon(Icons.arrow_drop_down_rounded, size: 20,
                color: txtSec.withOpacity(0.5)),
        ]),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════
// SECTION LABEL
// ══════════════════════════════════════════════════════════════════

class FormSectionLabel extends StatelessWidget {
  final String label;
  final Color? color;

  const FormSectionLabel({
    super.key,
    required this.label,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final txtSec = Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    return Row(children: [
      Container(
        width: 3, height: 13,
        decoration: BoxDecoration(
            color: color ?? _teal,
            borderRadius: BorderRadius.circular(2)),
      ),
      const SizedBox(width: 7),
      Text(label, style: TextStyle(
          fontSize: 12, fontWeight: FontWeight.w700,
          color: txtSec, letterSpacing: 0.3)),
    ]);
  }
}

// ══════════════════════════════════════════════════════════════════
// EMPTY STATE
// ══════════════════════════════════════════════════════════════════

class CustomerEmptyState extends StatelessWidget {
  final String text;
  final IconData icon;

  const CustomerEmptyState({
    super.key,
    required this.text,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) =>
      Center(child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 60, color: Colors.grey.withOpacity(0.3)),
          const SizedBox(height: 12),
          Text(text, style: TextStyle(
              fontSize: 15, color: Colors.grey.withOpacity(0.5))),
        ],
      ));
}