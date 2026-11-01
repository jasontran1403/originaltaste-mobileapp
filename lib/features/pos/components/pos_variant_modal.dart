import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import 'package:originaltaste/services/pos_service.dart';
import 'package:originaltaste/data/models/pos/pos_product_model.dart';
import 'package:originaltaste/data/models/pos/pos_cart_model.dart';

class PosVariantModal extends StatefulWidget {
  final PosProductModel product;
  final PriceOption selectedPrice;

  /// Kênh bán hiện tại: null = tại quán, 'SHOPEE_FOOD', 'GRAB_FOOD'.
  /// Quyết định addon lấy giá nào — giá app thường cao hơn giá tại quán.
  final String? platform;
  final void Function(List<VariantGroupSelection> selections, String? note) onConfirm;

  const PosVariantModal({
    super.key,
    required this.product,
    required this.selectedPrice,
    required this.onConfirm,
    this.platform,
  });

  @override
  State<PosVariantModal> createState() => _PosVariantModalState();
}

class _PosVariantModalState extends State<PosVariantModal> {
  // variantId → {ingredientId → qty}
  final Map<int, Map<int, int>> _selections = {};
  // addonGroup variantId → {addonId → qty}
  final Map<int, Map<int, int>> _addons = {};
  final _noteCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();

    // Khởi tạo map rỗng cho tất cả groups
    for (final v in widget.product.variants) {
      if (v.isAddonGroup) {
        _addons[v.id] = {};
      } else {
        _selections[v.id] = {};
      }
    }

    // TỰ ĐỘNG PHÂN PHỐI cho các nhóm bắt buộc hoặc full-auto
    for (final v in widget.product.variants.where((v) => !v.isAddonGroup)) {
      if (v.minSelect > 0) {  // Chỉ phân phối cho nhóm bắt buộc
        _selections[v.id] = _autoDistributeIngredients(v);
      }
    }
  }

  Map<int, int> _autoDistributeIngredients(PosVariantModel v) {
    final result    = <int, int>{};
    if (v.ingredients.isEmpty) return result;

    // Số lượng cần chọn: minSelect (bằng maxSelect khi cố định).
    int remaining = v.minSelect > 0 ? v.minSelect : v.maxSelect;
    if (remaining <= 0) return result;

    // Dồn theo THỨ TỰ nguyên liệu (displayOrder): tối đa vào NL đầu tiên trước
    // (giới hạn bởi maxSelectableCount), hết mới sang NL kế — KHÔNG chia đều.
    final ings = [...v.ingredients]
      ..sort((a, b) => a.displayOrder.compareTo(b.displayOrder));

    for (final ing in ings) {
      if (remaining <= 0) break;
      final cap  = ing.maxSelectableCount ?? 1;
      final give = remaining < cap ? remaining : cap;
      if (give > 0) result[ing.ingredientId] = give;
      remaining -= give;
    }
    return result;
  }

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  bool get _isValid {
    for (final v in widget.product.variants.where((v) => !v.isAddonGroup)) {
      final sel = _selections[v.id] ?? {};
      final total = sel.values.fold(0, (s, x) => s + x);
      if (total < v.minSelect) return false;
    }
    return true;
  }

  String? _groupError(PosVariantModel v) {
    if (v.isAddonGroup) return null;
    final sel = _selections[v.id] ?? {};
    final total = sel.values.fold(0, (s, x) => s + x);
    if (total < v.minSelect) {
      return 'Chọn ít nhất ${v.minSelect}';
    }
    return null;
  }

  void _confirm() {
    if (!_isValid) return;
    final result = <VariantGroupSelection>[];

    // ── Variant groups (không phải addon) ────────────────────
    for (final v in widget.product.variants.where((v) => !v.isAddonGroup)) {
      result.add(VariantGroupSelection(
        variantId:           v.id,
        groupName:           v.groupName,
        isAddonGroup:        false,
        selectedIngredients: Map.from(_selections[v.id] ?? {}),
        addonItems:          null,
      ));
    }

    // ── Addon groups — build AddonItem với đúng addonPrice ────
    for (final v in widget.product.variants.where((v) => v.isAddonGroup)) {
      final addonMap = _addons[v.id] ?? {};

      // Build AddonItem list từ selectedIngredients + addonPrice từ model
      final addonItems = addonMap.entries
          .where((e) => e.value > 0)
          .map((e) {
        final ingId  = e.key;
        final qty    = e.value;
        // Tìm ingredient model để lấy addonPrice
        final ingModel = v.ingredients
            .where((i) => i.ingredientId == ingId)
            .firstOrNull;
        // Lấy giá theo ĐÚNG kênh bán đang chọn
        final addonPrice = ingModel?.priceFor(widget.platform) ?? 0.0;
        return AddonItem(
          ingredientId:          ingId,
          ingredientName:        ingModel?.ingredientName ?? 'Addon #$ingId',
          baseAddonPrice:        addonPrice,
          discountedAddonPrice:  addonPrice, // không discount addon
          quantity:              qty,
        );
      })
          .toList();

      result.add(VariantGroupSelection(
        variantId:           v.id,
        groupName:           v.groupName,
        isAddonGroup:        true,
        selectedIngredients: Map<int,int>.from(addonMap),
        addonItems:          addonItems.isEmpty ? null : addonItems,
      ));
    }

    widget.onConfirm(
      result,
      _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final maxH = MediaQuery.of(context).size.height * 0.85;
    final p = widget.product;

    return Container(
      constraints: BoxConstraints(maxHeight: maxH),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10),
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: cs.onSurface.withOpacity(0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 16, 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(p.name,
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 4),
                      _PriceRow(product: p, selectedPrice: widget.selectedPrice),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Scrollable groups
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Regular variant groups
                  ...widget.product.variants
                      .where((v) => !v.isAddonGroup)
                      .map((v) => _VariantGroup(
                            variant: v,
                            selections: _selections[v.id] ?? {},
                            error: _groupError(v),
                            onChanged: (ingId, delta) {
                              setState(() {
                                final sel = _selections[v.id]!;
                                final cur = sel[ingId] ?? 0;
                                final next = (cur + delta).clamp(0, 999);
                                final total = sel.values.fold(0, (s, x) => s + x) + delta;
                                if (delta > 0 && total > v.maxSelect) return;
                                if (next <= 0) {
                                  sel.remove(ingId);
                                } else {
                                  sel[ingId] = next;
                                }
                              });
                            },
                          )),

                  // Addon groups
                  ...widget.product.variants
                      .where((v) => v.isAddonGroup)
                      .map((v) => _AddonGroup(
                            variant: v,
                            selections: _addons[v.id] ?? {},
                            onChanged: (addonId, delta) {
                              setState(() {
                                final sel = _addons[v.id]!;
                                final cur = sel[addonId] ?? 0;
                                final next = (cur + delta).clamp(0, 999);
                                if (next <= 0) {
                                  sel.remove(addonId);
                                } else {
                                  sel[addonId] = next;
                                }
                              });
                            },
                          )),

                  // Note
                  const SizedBox(height: 12),
                  Text('Ghi chú',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: cs.onSurface)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _noteCtrl,
                    maxLines: 2,
                    decoration: InputDecoration(
                      hintText: 'Ghi chú cho đơn hàng...',
                      hintStyle: TextStyle(
                          color: cs.onSurface.withOpacity(0.35)),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10)),
                      isDense: true,
                      contentPadding: const EdgeInsets.all(12),
                    ),
                  ),

                  const SizedBox(height: 80), // space for button
                ],
              ),
            ),
          ),

          // Confirm button
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 52),
            decoration: BoxDecoration(
              color: cs.surface,
              border: Border(top: BorderSide(color: cs.outlineVariant)),
            ),
            child: SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton.icon(
                label: const Text('Xác nhận',
                    style: TextStyle(
                        fontSize: 15, fontWeight: FontWeight.bold)),
                onPressed: _isValid ? _confirm : null,
                style: FilledButton.styleFrom(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _imgFallback(ColorScheme cs) => Container(
        width: 72, height: 72,
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(Icons.fastfood,
            color: cs.onSurface.withOpacity(0.3), size: 32),
      );
}

// ─────────────────────────────────────────────────────────────
// Price row (shows discount options)
// ─────────────────────────────────────────────────────────────

class _PriceRow extends StatelessWidget {
  final PosProductModel product;
  final PriceOption selectedPrice;

  const _PriceRow({required this.product, required this.selectedPrice});

  String _fmt(double v) => v
      .toStringAsFixed(0)
      .replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final price = selectedPrice.price;

    return Row(
      children: [
        Text('${_fmt(price)}đ',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: cs.primary)),
        if (selectedPrice.discountPercent > 0) ...[
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(selectedPrice.label,
                style: const TextStyle(
                    fontSize: 11,
                    color: Colors.green,
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Regular Variant Group
// ─────────────────────────────────────────────────────────────

class _VariantGroup extends StatelessWidget {
  final PosVariantModel variant;
  final Map<int, int> selections;
  final String? error;
  final void Function(int ingId, int delta) onChanged;

  const _VariantGroup({
    required this.variant,
    required this.selections,
    this.error,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final total = selections.values.fold(0, (s, x) => s + x);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Expanded(
            child: Text(variant.groupName,
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.bold)),
          ),
          Text(
            '$total / ${variant.maxSelect}',
            style: TextStyle(
                fontSize: 12,
                color: total < variant.minSelect
                    ? cs.error
                    : cs.onSurface.withOpacity(0.5)),
          ),
        ]),
        Text(
          'Chọn ${variant.minSelect}–${variant.maxSelect}',
          style: TextStyle(
              fontSize: 11, color: cs.onSurface.withOpacity(0.45)),
        ),
        if (error != null) ...[
          const SizedBox(height: 2),
          Text(error!,
              style: TextStyle(fontSize: 11, color: cs.error)),
        ],
        const SizedBox(height: 8),
        ...variant.ingredients.map((ing) {
          final qty        = selections[ing.ingredientId] ?? 0;
          final maxReached = total >= variant.maxSelect;
          final canIncrement = !maxReached || qty > 0;

          // Cap mỗi nguyên liệu:
          //  - allowRepeat=true  → theo maxSelectableCount riêng của từng NL
          //    (tổng vẫn bị chặn bởi maxSelect ở handler onChanged)
          //  - allowRepeat=false → mỗi NL tối đa 1 (chọn phân biệt)
          final maxIng = variant.allowRepeat == true
              ? (ing.maxSelectableCount ?? 1)
              : 1;

          return _IngredientRow(
            name:        ing.ingredientName,
            qty:         qty,
            maxReached:  maxReached && qty == 0,
            maxForIng:   maxIng,
            onIncrement: canIncrement ? () => onChanged(ing.ingredientId, 1) : null,
            onDecrement: qty > 0 ? () => onChanged(ing.ingredientId, -1) : null,
          );
        }),
        const SizedBox(height: 16),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Addon Group
// ─────────────────────────────────────────────────────────────

class _AddonGroup extends StatelessWidget {
  final PosVariantModel variant;
  final Map<int, int> selections;
  final void Function(int addonId, int delta) onChanged;

  const _AddonGroup({
    required this.variant,
    required this.selections,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: cs.primaryContainer,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text('Addon',
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: cs.primary)),
          ),
          const SizedBox(width: 8),
          Text(variant.groupName,
              style: const TextStyle(
                  fontSize: 15, fontWeight: FontWeight.bold)),
        ]),
        const SizedBox(height: 2),
        Text('Tùy chọn — không bắt buộc',
            style: TextStyle(
                fontSize: 11, color: cs.onSurface.withOpacity(0.45))),
        const SizedBox(height: 8),
        ...variant.ingredients.map((ing) {
          final qty = selections[ing.ingredientId] ?? 0;
          return _IngredientRow(
            name: ing.ingredientName,
            qty: qty,
            maxReached: false,
            maxForIng: 999,
            onIncrement: () => onChanged(ing.ingredientId, 1),
            onDecrement: qty > 0 ? () => onChanged(ing.ingredientId, -1) : null,
          );
        }),
        const SizedBox(height: 16),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Ingredient Row
// ─────────────────────────────────────────────────────────────

class _IngredientRow extends StatelessWidget {
  final String name;
  final int qty;
  final bool maxReached;
  final int maxForIng;
  final VoidCallback? onIncrement;
  final VoidCallback? onDecrement;

  const _IngredientRow({
    required this.name,
    required this.qty,
    required this.maxReached,
    required this.maxForIng,
    this.onIncrement,
    this.onDecrement,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isSelected = qty > 0;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected
                    ? cs.primaryContainer.withOpacity(0.4)
                    : cs.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isSelected
                      ? cs.primary
                      : cs.onSurface.withOpacity(0.1),
                  width: isSelected ? 1.5 : 1,
                ),
              ),
              child: Text(name,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isSelected
                        ? FontWeight.bold
                        : FontWeight.normal,
                    color: maxReached
                        ? cs.onSurface.withOpacity(0.35)
                        : cs.onSurface,
                  )),
            ),
          ),
          const SizedBox(width: 10),
          // Counter
          Row(
            children: [
              _Btn(
                icon: Icons.remove,
                onTap: onDecrement,
                active: onDecrement != null,
                color: cs.error,
              ),
              SizedBox(
                width: 30,
                child: Text('$qty',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: qty > 0
                            ? cs.primary
                            : cs.onSurface.withOpacity(0.3))),
              ),
              _Btn(
                icon: Icons.add,
                onTap: onIncrement,
                active: onIncrement != null && qty < maxForIng,
                color: cs.primary,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Btn extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final bool active;
  final Color color;

  const _Btn({
    required this.icon,
    this.onTap,
    required this.active,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: active ? onTap : null,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: 28, height: 28,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: active ? color.withOpacity(0.15) : Colors.grey.shade100,
        ),
        child: Icon(icon, size: 16,
            color: active ? color : Colors.grey.shade400),
      ),
    );
  }
}
