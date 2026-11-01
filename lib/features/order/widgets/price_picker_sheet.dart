// lib/features/order/widgets/price_picker_sheet.dart
// Bottom sheet chọn chế độ giá: Giá gốc / Khung tier / Giảm %
// Dùng cho cả chế độ Lẻ (chỉ base + giảm%) và Sỉ (tier + giảm%)

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../data/models/order/order_models.dart';
import '../../../shared/widgets/order_shared_widgets.dart';
import '../controller/order_cart_controller.dart';

class PricePickerSheet extends ConsumerStatefulWidget {
  final CartItem item;
  const PricePickerSheet({super.key, required this.item});

  static Future<void> show(BuildContext context, CartItem item) {
    return showModalBottomSheet(
      context:            context,
      isScrollControlled: true,
      backgroundColor:    Colors.transparent,
      useSafeArea:        true,
      builder: (_) => PricePickerSheet(item: item),
    );
  }

  @override
  ConsumerState<PricePickerSheet> createState() => _PricePickerSheetState();
}

class _PricePickerSheetState extends ConsumerState<PricePickerSheet> {
  late ItemPriceMode _mode;
  ProductPriceTierModel? _selectedTier;
  final _pctCtrl  = TextEditingController();
  bool _showPct   = false;

  CartItem        get item      => widget.item;
  ProductModel    get product   => item.product;
  OrderCartState  get cartState => ref.read(orderCartProvider);
  bool            get _isRetail => cartState.orderMode == OrderMode.retail;

  @override
  void initState() {
    super.initState();
    _mode        = _isRetail ? ItemPriceMode.base : item.priceMode;
    _selectedTier = item.selectedTier ?? item.activeTier;
    if (item.discountPercent != null) _pctCtrl.text = item.discountPercent!.toString();
    _showPct = _mode == ItemPriceMode.discountPercent;
  }

  @override
  void dispose() { _pctCtrl.dispose(); super.dispose(); }

  // ── Preview unit price ────────────────────────────────────────
  double get _previewUnit {
    final baseForPct = _isRetail
        ? product.basePrice
        : (product.firstTier?.price ?? product.basePrice);
    return switch (_mode) {
      ItemPriceMode.base            => product.basePrice,
      ItemPriceMode.tier            => _selectedTier?.price
          ?? item.activeTier?.price
          ?? product.basePrice,
      ItemPriceMode.discountPercent => () {
        final pct = int.tryParse(_pctCtrl.text) ?? 0;
        return baseForPct * (100 - pct) / 100;
      }(),
    };
  }

  bool get _canApply {
    if (_mode == ItemPriceMode.discountPercent) {
      final pct = int.tryParse(_pctCtrl.text);
      return pct != null && pct >= 1 && pct <= 100;
    }
    return true;
  }

  void _apply() {
    final ctrl = ref.read(orderCartProvider.notifier);
    switch (_mode) {
      case ItemPriceMode.base:
        ctrl.selectBasePriceForItem(item);
      case ItemPriceMode.tier:
        if (_selectedTier != null) {
          ctrl.selectTierForItem(item, _selectedTier!);
        } else {
          ctrl.resetToAutoTier(item);
        }
      case ItemPriceMode.discountPercent:
        final pct = int.tryParse(_pctCtrl.text);
        if (pct != null && pct >= 1 && pct <= 100) {
          ctrl.setDiscountPercentForItem(item, pct);
        }
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isDark     = Theme.of(context).brightness == Brightness.dark;
    final primary    = isDark ? AppColors.primary : AppColors.primaryDark;
    final secondary  = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final surface    = isDark ? AppColors.darkCard : Colors.white;
    final baseForPct = _isRetail
        ? product.basePrice
        : (product.firstTier?.price ?? product.basePrice);

    return Container(
      decoration: BoxDecoration(
        color:        surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom +
            MediaQuery.of(context).padding.bottom + 80,
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        // Handle
        Container(
          margin: const EdgeInsets.only(top: 12, bottom: 8),
          width: 36, height: 4,
          decoration: BoxDecoration(
            color:        secondary.withOpacity(0.3),
            borderRadius: BorderRadius.circular(2),
          ),
        ),

        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
          child: Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(product.name,
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: primary)),
              Text(
                'SL: ${fmtQtyDisplay(item.quantity)} • Giá gốc: ${fmtMoney(product.basePrice)}',
                style: TextStyle(fontSize: 12, color: secondary),
              ),
            ])),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(fmtMoney(_previewUnit),
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: primary)),
              Text('đơn giá', style: TextStyle(fontSize: 11, color: secondary)),
            ]),
          ]),
        ),

        // Mode badge
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Align(
            alignment: Alignment.centerLeft,
            child: _ModeBadge(isRetail: _isRetail, primary: primary),
          ),
        ),

        Divider(height: 20, color: secondary.withOpacity(0.15)),

        // ── CHẾ ĐỘ LẺ ────────────────────────────────────────────
        if (_isRetail) ...[
          // Giá gốc — info tĩnh
          _OptionTile(
            selected: true,
            icon:     Icons.sell_outlined,
            title:    'Giá bán lẻ',
            subtitle: '${fmtMoney(product.basePrice)} • Giá cố định',
            color:    primary,
            trailing: Icon(Icons.check_circle, size: 18, color: primary),
            onTap:    null,
          ),
          // Giảm %
          _OptionTile(
            selected: _mode == ItemPriceMode.discountPercent,
            icon:     Icons.percent,
            title:    'Giảm theo %',
            subtitle: 'Tính trên ${fmtMoney(baseForPct)} (giá lẻ)',
            color:    Colors.green,
            onTap: () => setState(() {
              _mode    = ItemPriceMode.discountPercent;
              _showPct = true;
            }),
          ),
        ],

        // ── CHẾ ĐỘ SỈ ────────────────────────────────────────────
        if (!_isRetail) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 6),
            child: Row(children: [
              Icon(Icons.layers_outlined, size: 13, color: secondary),
              const SizedBox(width: 6),
              Text('Khung giá theo số lượng (tự động)',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: secondary)),
            ]),
          ),

          if (product.priceTiers.isEmpty)
            _OptionTile(
              selected: _mode == ItemPriceMode.tier,
              icon:     Icons.label_outline,
              title:    'Giá sỉ',
              subtitle: fmtMoney(product.basePrice),
              color:    primary,
              onTap: () => setState(() {
                _mode         = ItemPriceMode.tier;
                _selectedTier = null;
                _showPct      = false;
              }),
            )
          else
            ...product.priceTiers.map((tier) {
              final isAutoActive = item.activeTier?.id == tier.id
                  && item.priceMode == ItemPriceMode.tier
                  && item.selectedTier == null;
              final isSelected = _mode == ItemPriceMode.tier
                  && (_selectedTier?.id == tier.id
                      || (_selectedTier == null && isAutoActive));
              return _OptionTile(
                selected: isSelected,
                icon:     Icons.label_outline,
                title:    tier.tierName,
                subtitle: '${fmtMoney(tier.price)} • ${tier.rangeLabel}',
                color:    primary,
                badge:    isAutoActive ? 'auto' : null,
                onTap: () => setState(() {
                  _mode         = ItemPriceMode.tier;
                  _selectedTier = tier;
                  _showPct      = false;
                }),
              );
            }),

          _OptionTile(
            selected: _mode == ItemPriceMode.discountPercent,
            icon:     Icons.percent,
            title:    'Giảm theo %',
            subtitle: 'Tính trên ${fmtMoney(baseForPct)} (khung đầu tiên)',
            color:    Colors.green,
            onTap: () => setState(() {
              _mode    = ItemPriceMode.discountPercent;
              _showPct = true;
            }),
          ),
        ],

        // % input
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          child: _showPct
              ? Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
            child: Row(children: [
              Expanded(
                child: TextField(
                  controller:      _pctCtrl,
                  autofocus:       true,
                  keyboardType:    TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    MaxValueFormatter(100),
                  ],
                  onChanged: (_) => setState(() {}),
                  style: const TextStyle(fontSize: 14),
                  decoration: InputDecoration(
                    hintText:    '1 – 100',
                    suffixText:  '%',
                    isDense:     true,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8)),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide:   const BorderSide(
                          color: Colors.green, width: 1.5),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                    () {
                  final pct    = int.tryParse(_pctCtrl.text) ?? 0;
                  final result = baseForPct * (100 - pct) / 100;
                  return '→ ${fmtMoney(result)}';
                }(),
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w700, color: Colors.green),
              ),
            ]),
          )
              : const SizedBox.shrink(),
        ),

        const SizedBox(height: 8),

        // Apply
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _canApply ? _apply : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: primary,
                foregroundColor: Colors.white,
                disabledBackgroundColor: primary.withOpacity(0.35),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Áp dụng',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            ),
          ),
        ),
      ]),
    );
  }
}

// ── Sub-widgets ──────────────────────────────────────────────────

class _ModeBadge extends StatelessWidget {
  final bool isRetail;
  final Color primary;
  const _ModeBadge({required this.isRetail, required this.primary});

  @override
  Widget build(BuildContext context) {
    final c = isRetail ? Colors.orange : primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color:        c.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border:       Border.all(color: c.withOpacity(0.4)),
      ),
      child: Text(
        isRetail ? 'Chế độ: Lẻ' : 'Chế độ: Sỉ',
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: c),
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  final bool     selected;
  final IconData icon;
  final String   title;
  final String   subtitle;
  final Color    color;
  final String?  badge;
  final Widget?  trailing;
  final VoidCallback? onTap;

  const _OptionTile({
    required this.selected,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    this.badge,
    this.trailing,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final secondary = Theme.of(context).brightness == Brightness.dark
        ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin:  const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color:  selected ? color.withOpacity(0.08) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? color.withOpacity(0.5) : secondary.withOpacity(0.15),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color:        color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(7),
            ),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text(title,
                  style: TextStyle(
                      fontSize:   13,
                      fontWeight: FontWeight.w600,
                      color:      selected ? color : null)),
              if (badge != null) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color:        Colors.blue.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(badge!,
                      style: const TextStyle(
                          fontSize: 9, fontWeight: FontWeight.w700, color: Colors.blue)),
                ),
              ],
            ]),
            Text(subtitle, style: TextStyle(fontSize: 11, color: secondary)),
          ])),
          trailing ?? (selected ? Icon(Icons.check_circle, size: 18, color: color) : const SizedBox.shrink()),
        ]),
      ),
    );
  }
}