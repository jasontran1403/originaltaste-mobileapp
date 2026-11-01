// lib/features/pos/components/pos_quick_add_sheet.dart
//
// THAY ĐỔI: Disable nút "Chọn giá" khi:
//   1. isAppOrder == true (giá cố định theo app menu)
//   2. category tên "Combo" (hardcode — chỉ 1 giá cố định)

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:originaltaste/services/pos_service.dart';
import 'package:originaltaste/data/models/pos/pos_product_model.dart';
import 'package:originaltaste/data/models/pos/pos_cart_model.dart';

class PosQuickAddSheet extends StatefulWidget {
  final PosProductModel product;
  final PriceOption initialPrice;
  final PriceOption? fixedPrice;
  final void Function(PriceOption price) onQuickAdd;
  final void Function(PriceOption price) onOpenVariantModal;
  final List<VariantGroupSelection>? savedSelections;
  final void Function(List<VariantGroupSelection> selections, String? note)? onSelectionsUpdated;
  final String? savedNote;

  /// true khi đang ở mode Shopee / Grab — giá cố định, không cho chọn
  final bool isAppOrder;

  const PosQuickAddSheet({
    super.key,
    required this.product,
    required this.initialPrice,
    this.fixedPrice,
    required this.onQuickAdd,
    required this.onOpenVariantModal,
    this.onSelectionsUpdated,
    this.savedSelections,
    this.savedNote,
    this.isAppOrder = false,
  });

  @override
  State<PosQuickAddSheet> createState() => _PosQuickAddSheetState();
}

class _PosQuickAddSheetState extends State<PosQuickAddSheet> {
  late PriceOption _selectedPrice;
  List<VariantGroupSelection>? _savedSelections;
  String? _savedNote;

  @override
  void initState() {
    super.initState();
    _selectedPrice   = widget.fixedPrice ?? widget.initialPrice;
    _savedSelections = widget.savedSelections;
    _savedNote       = widget.savedNote;
  }

  // ── Điều kiện disable nút Chọn giá ───────────────────────────
  // Không cho chọn giá khi:
  //  1. isAppOrder — giá do app quy định
  //  2. category "Combo" — hardcode, chỉ 1 giá cố định
  bool get _priceSelectionDisabled =>
      widget.isAppOrder ||
          (widget.product.categoryName?.toLowerCase() == 'combo');

  String get _priceDisabledTooltip {
    if (widget.isAppOrder) return 'Đơn App: giá do App quy định';
    return 'Combo chỉ có 1 giá cố định';
  }

  bool get _hasRequiredVariant =>
      widget.product.variants.any((v) => !v.isAddonGroup && v.minSelect > 0);

  bool get _hasVariants => widget.product.variants.isNotEmpty;

  bool get _hasCustomSelections => _savedSelections != null;

  bool get _hasAddons => _savedSelections?.any((s) =>
  s.isAddonGroup && s.selectedIngredients.isNotEmpty) ?? false;

  String _fmt(double v) => NumberFormat('#,###', 'vi_VN').format(v);

  void _showPriceSelector() {
    if (_priceSelectionDisabled) return; // guard
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Center(child: Container(
              width: 40, height: 5,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(4),
              ),
            )),
            const SizedBox(height: 8),
            const Text('Chọn mức giá',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ...[0, 10, 20, 100].map((percent) {
              final price      = widget.product.basePrice * (1 - percent / 100);
              final isSelected = _selectedPrice.discountPercent == percent;
              return ListTile(
                leading: isSelected
                    ? const Icon(Icons.check_circle, color: Colors.green)
                    : const Icon(Icons.circle_outlined, color: Colors.grey),
                title: Text(
                  percent == 100
                      ? 'Miễn phí (0đ)'
                      : 'Giảm $percent% (${_fmt(price)}đ)',
                  style: TextStyle(
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                onTap: () {
                  setState(() {
                    _selectedPrice = PriceOption(
                      discountPercent: percent,
                      price:           price,
                      label: percent == 100 ? 'Miễn phí' : 'Giảm $percent%',
                    );
                  });
                  Navigator.pop(context);
                },
              );
            }),
            const SizedBox(height: 60),
          ]),
        ),
      ),
    );
  }

  void _quickAdd() {
    if (_hasCustomSelections) {
      Navigator.pop(context, QuickAddResult(
        price:      _selectedPrice,
        selections: _savedSelections!,
        note:       _savedNote,
      ));
    } else {
      widget.onQuickAdd(_selectedPrice);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final p  = widget.product;

    String variantBtnLabel = _hasCustomSelections
        ? 'Đã chọn'
        : (_hasRequiredVariant ? 'Chọn biến thể *' : 'Chọn biến thể');

    // Màu badge giá cố định
    final badgeColor = widget.isAppOrder
        ? const Color(0xFFEE4D2D)
        : cs.primary;

    return Container(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 40),
      decoration: BoxDecoration(
        color:        cs.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 44),
        child: Column(mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start, children: [

              // Handle
              Center(child: Container(
                width: 40, height: 5,
                decoration: BoxDecoration(
                  color: cs.onSurface.withOpacity(0.25),
                  borderRadius: BorderRadius.circular(4),
                ),
              )),
              const SizedBox(height: 16),

              // Tên + giá
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(p.name,
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.bold),
                      maxLines: 2, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Row(children: [
                    Text('${_fmt(_selectedPrice.price)}đ',
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: cs.primary)),
                    // Badge "Giá App" / "Giá cố định"
                    if (_priceSelectionDisabled) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color:        badgeColor.withOpacity(0.10),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                              color: badgeColor.withOpacity(0.35)),
                        ),
                        child: Text(
                          widget.isAppOrder ? 'Giá App' : 'Giá cố định',
                          style: TextStyle(
                            fontSize:   10,
                            fontWeight: FontWeight.w600,
                            color:      badgeColor,
                          ),
                        ),
                      ),
                    ],
                  ]),
                ])),
                IconButton(
                  icon: Icon(Icons.close_rounded, color: cs.onSurface),
                  onPressed: () => Navigator.pop(context),
                ),
              ]),

              // Addons đã chọn
              if (_hasCustomSelections && _hasAddons) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6, runSpacing: 4,
                  children: _savedSelections!
                      .where((s) =>
                  s.isAddonGroup && s.selectedIngredients.isNotEmpty)
                      .expand((s) => s.selectedIngredients.entries)
                      .map((e) {
                    String name = 'Addon #${e.key}';
                    for (final v in p.variants.where((v) => v.isAddonGroup)) {
                      final ing = v.ingredients
                          .where((i) => i.ingredientId == e.key)
                          .firstOrNull;
                      if (ing != null) { name = ing.ingredientName; break; }
                    }
                    return Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color:        cs.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                            color: cs.primary.withOpacity(0.3)),
                      ),
                      child: Text('$name x${e.value}',
                          style: TextStyle(
                              fontSize: 11,
                              color: cs.primary,
                              fontWeight: FontWeight.w600)),
                    );
                  }).toList(),
                ),
              ],

              const SizedBox(height: 20),

              // Buttons
              Row(children: [
                // ── Nút Chọn giá ─────────────────────────────────
                Expanded(
                  child: Tooltip(
                    message: _priceSelectionDisabled
                        ? _priceDisabledTooltip : '',
                    child: OutlinedButton.icon(
                      icon: Icon(Icons.price_change_rounded, size: 18,
                          color: _priceSelectionDisabled
                              ? cs.onSurface.withOpacity(0.3)
                              : cs.primary),
                      label: Text('Chọn giá',
                          style: TextStyle(
                            color: _priceSelectionDisabled
                                ? cs.onSurface.withOpacity(0.3)
                                : cs.primary,
                          )),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            vertical: 16, horizontal: 12),
                        minimumSize:    const Size.fromHeight(56),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        side: BorderSide(
                          color: _priceSelectionDisabled
                              ? cs.onSurface.withOpacity(0.15)
                              : cs.primary,
                        ),
                        foregroundColor: _priceSelectionDisabled
                            ? cs.onSurface.withOpacity(0.3)
                            : cs.primary,
                        textStyle: const TextStyle(
                            fontWeight: FontWeight.w600),
                      ),
                      onPressed: _priceSelectionDisabled
                          ? null : _showPriceSelector,
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // ── Nút Chọn biến thể ─────────────────────────────
                if (_hasVariants)
                  Expanded(
                    child: FilledButton.icon(
                      icon: Icon(
                        _hasCustomSelections
                            ? Icons.check_circle_outline
                            : Icons.tune_rounded,
                        size: 18,
                      ),
                      label: Text(variantBtnLabel,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold)),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            vertical: 16, horizontal: 12),
                        minimumSize:     const Size.fromHeight(56),
                        backgroundColor: _hasCustomSelections
                            ? Colors.green : cs.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () =>
                          widget.onOpenVariantModal(_selectedPrice),
                    ),
                  ),
                const SizedBox(width: 8),

                // ── Nút Thêm nhanh ────────────────────────────────
                Expanded(
                  child: FilledButton.icon(
                    icon: const Icon(
                        Icons.add_shopping_cart_rounded, size: 18),
                    label: const Text('Thêm nhanh'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          vertical: 16, horizontal: 12),
                      minimumSize:     const Size.fromHeight(56),
                      backgroundColor: cs.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: _quickAdd,
                  ),
                ),
              ]),

              if (_hasRequiredVariant && !_hasCustomSelections) ...[
                const SizedBox(height: 12),
                Text(
                  '* Có biến thể bắt buộc. Thêm nhanh sẽ tự động phân phối nguyên liệu.',
                  style: TextStyle(
                    fontSize:   12,
                    color:      cs.primary.withOpacity(0.8),
                    fontStyle:  FontStyle.italic,
                  ),
                ),
              ],

              const SizedBox(height: 20),
            ]),
      ),
    );
  }
}

class QuickAddResult {
  final PriceOption price;
  final List<VariantGroupSelection> selections;
  final String? note;
  const QuickAddResult({
    required this.price,
    required this.selections,
    this.note,
  });
}