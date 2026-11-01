// lib/features/pos/components/pos_weight_sheet.dart
//
// SIMPLIFIED - Chỉ 1 mode: Nhập riêng
// ✅ Nút Auto: Tự động điền theo pattern hoặc default
// ✅ Addon ingredients với màu xanh
// ✅ Fix rendering error & zero input
// ✅ Tính giá theo định lượng cho variant đơn (1 ingredient, maxSel==1)

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:originaltaste/data/models/pos/pos_cart_model.dart';
import 'package:originaltaste/data/models/pos/pos_product_model.dart';

// ────────────────────────────────────────────────────────────────
// Entry point
// ────────────────────────────────────────────────────────────────

Future<CartItem?> showPosWeightSheet(
    BuildContext context,
    CartItem cartItem,
    ) async {
  return showModalBottomSheet<CartItem>(
    context:            context,
    isScrollControlled: true,
    useSafeArea:        true,
    backgroundColor:    Colors.transparent,
    constraints: BoxConstraints(
      maxHeight: MediaQuery.of(context).size.height * 0.90,
    ),
    builder: (_) => _PosWeightSheet(cartItem: cartItem),
  );
}

// ────────────────────────────────────────────────────────────────
// Ingredient Unit Data
// ────────────────────────────────────────────────────────────────

class _IngredientUnit {
  final int    ingredientId;
  final String ingredientName;
  final String ingredientImageUrl;
  final bool   isAddon;
  final String variantGroupName;
  final int    unitIndex;
  final double defaultWeight;

  double? actualWeight;

  _IngredientUnit({
    required this.ingredientId,
    required this.ingredientName,
    required this.ingredientImageUrl,
    required this.isAddon,
    required this.variantGroupName,
    required this.unitIndex,
    required this.defaultWeight,
    this.actualWeight,
  });

  double get finalWeight => actualWeight ?? defaultWeight;
  bool get isOverridden => actualWeight != null;
  void reset() => actualWeight = null;
}

// ────────────────────────────────────────────────────────────────
// Ingredient Group
// ────────────────────────────────────────────────────────────────

class _IngredientGroup {
  final int    ingredientId;
  final String ingredientName;
  final String ingredientImageUrl;
  final bool   isAddon;
  final String variantGroupName;
  final double defaultWeight;
  final List<_IngredientUnit> units;

  _IngredientGroup({
    required this.ingredientId,
    required this.ingredientName,
    required this.ingredientImageUrl,
    required this.isAddon,
    required this.variantGroupName,
    required this.defaultWeight,
    required this.units,
  });

  double get totalWeight => units.fold(0.0, (sum, u) => sum + u.finalWeight);
  bool get hasOverride => units.any((u) => u.isOverridden);
}

// ────────────────────────────────────────────────────────────────
// Sheet widget
// ────────────────────────────────────────────────────────────────

class _PosWeightSheet extends StatefulWidget {
  final CartItem cartItem;
  const _PosWeightSheet({required this.cartItem});

  @override
  State<_PosWeightSheet> createState() => _PosWeightSheetState();
}

class _PosWeightSheetState extends State<_PosWeightSheet> {
  late List<_IngredientGroup> _groups;
  late List<_IngredientUnit> _allUnits;

  // Map: ingredientId → vi model (để tra cứu khi tính giá)
  final Map<int, PosVariantIngredientModel> _viModels = {};

  // ── Ý 2: bán xé lẻ → nhập giá tay thay vì tính theo tỉ lệ ──
  bool get _isLoose => widget.cartItem.product.canSellLoose;
  final _loosePriceCtrl = TextEditingController();

  @override
  void dispose() {
    _loosePriceCtrl.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _buildUnitsFromCart();
    if (_isLoose) {
      final p = widget.cartItem.finalUnitPrice;
      _loosePriceCtrl.text = p > 0 ? p.toInt().toString() : '';
    }
  }

  void _buildUnitsFromCart() {
    final item = widget.cartItem;
    _allUnits = [];
    _viModels.clear();

    for (final v in item.product.variants) {
      for (final vi in v.ingredients) {
        _viModels[vi.ingredientId] = vi;
      }
    }

    for (final sel in item.variantSelections) {
      final isAddon = sel.isAddonGroup;

      for (final entry in sel.selectedIngredients.entries) {
        final ingredientId  = entry.key;
        final selectedCount = entry.value;
        if (selectedCount <= 0) continue;

        final vi = _viModels[ingredientId];
        if (vi == null) continue;

        final defaultPerUnit  = vi.stockDeductPerUnit;
        final existingWeights = sel.unitWeightsMap[ingredientId];
        final totalUnits      = selectedCount * item.quantity;

        for (int i = 0; i < totalUnits; i++) {
          final initVal = (existingWeights != null && i < existingWeights.length)
              ? existingWeights[i]
              : defaultPerUnit;

          _allUnits.add(_IngredientUnit(
            ingredientId:       ingredientId,
            ingredientName:     vi.ingredientName,
            ingredientImageUrl: vi.ingredientImageUrl ?? '',
            isAddon:            isAddon,
            variantGroupName:   sel.groupName,
            unitIndex:          i,
            defaultWeight:      defaultPerUnit,
            actualWeight:       (existingWeights != null && i < existingWeights.length)
                ? initVal
                : null,
          ));
        }
      }
    }

    _allUnits.sort((a, b) {
      if (a.isAddon != b.isAddon) return a.isAddon ? 1 : -1;
      var cmp = a.variantGroupName.compareTo(b.variantGroupName);
      if (cmp != 0) return cmp;
      cmp = a.ingredientName.compareTo(b.ingredientName);
      if (cmp != 0) return cmp;
      return a.unitIndex.compareTo(b.unitIndex);
    });

    final Map<int, List<_IngredientUnit>> groupMap = {};
    for (final unit in _allUnits) {
      groupMap.putIfAbsent(unit.ingredientId, () => []).add(unit);
    }

    _groups = groupMap.entries.map((e) {
      final first = e.value.first;
      return _IngredientGroup(
        ingredientId:       first.ingredientId,
        ingredientName:     first.ingredientName,
        ingredientImageUrl: first.ingredientImageUrl,
        isAddon:            first.isAddon,
        variantGroupName:   first.variantGroupName,
        defaultWeight:      first.defaultWeight,
        units:              e.value,
      );
    }).toList();

    _groups.sort((a, b) {
      if (a.isAddon != b.isAddon) return a.isAddon ? 1 : -1;
      var cmp = a.variantGroupName.compareTo(b.variantGroupName);
      if (cmp != 0) return cmp;
      return a.ingredientName.compareTo(b.ingredientName);
    });
  }

  String _formatWeight(double v) {
    if (v == v.roundToDouble() && v >= 1) return v.toStringAsFixed(0);
    return v.toStringAsFixed(4)
        .replaceAll(RegExp(r'0+$'), '')
        .replaceAll(RegExp(r'\.$'), '');
  }

  double _parseWeight(String s) => double.tryParse(s.trim()) ?? 0.0;

  double get _totalWeight => _allUnits.fold(0.0, (sum, u) => sum + u.finalWeight);
  bool get _hasAnyOverride => _allUnits.any((u) => u.isOverridden);

  // ── Tìm vi eligible từ ingredient đang có trong _allUnits ────
  // Điều kiện: non-addon, variant chứa đúng 1 ingredient, maxSel == 1
  // Trả về map: ingredientId → vi (có thể nhiều variant eligible)
  Map<int, PosVariantIngredientModel> _getEligibleViMap() {
    final result = <int, PosVariantIngredientModel>{};

    for (final v in widget.cartItem.product.variants) {
      if (v.isAddonGroup) continue;
      if (v.ingredients.length != 1) continue; // ← chỉ giữ điều kiện này

      final vi = v.ingredients.first;

      final isActive = _allUnits.any(
            (u) => u.ingredientId == vi.ingredientId && !u.isAddon,
      );
      if (isActive) result[vi.ingredientId] = vi;
    }

    return result;
  }

  // ── Làm tròn lên đơn vị nghìn ────────────────────────────────
  static double _roundUpToThousand(double price) {
    if (price <= 0) return 0;
    final remainder = price % 1000;
    if (remainder < 0.0001) return price;
    return price - remainder + 1000;
  }

  // ── Auto Fill ────────────────────────────────────────────────
  void _autoFill() {
    setState(() {
      final Map<int, List<_IngredientUnit>> unitsByIngredient = {};
      for (final unit in _allUnits) {
        unitsByIngredient.putIfAbsent(unit.ingredientId, () => []).add(unit);
      }

      for (final entry in unitsByIngredient.entries) {
        final units = entry.value;
        final firstOverridden = units.firstWhere(
              (u) => u.isOverridden,
          orElse: () => units.first,
        );
        final fillValue = firstOverridden.isOverridden
            ? firstOverridden.actualWeight!
            : firstOverridden.defaultWeight;

        for (final unit in units) {
          if (!unit.isOverridden) unit.actualWeight = fillValue;
        }
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('Đã tự động điền định lượng'),
      duration: Duration(seconds: 1),
    ));
  }

  void _resetAll() {
    setState(() {
      for (final unit in _allUnits) unit.reset();
    });
  }

  // ── Confirm ──────────────────────────────────────────────────
  void _confirm() {
    final item = widget.cartItem;

    // Cập nhật unitWeightsMap
    final updatedSelections = item.variantSelections.map((sel) {
      final newMap = Map<int, List<double>>.from(sel.unitWeightsMap);

      for (final entry in sel.selectedIngredients.entries) {
        final ingredientId = entry.key;

        final unitsForThisIng = _allUnits
            .where((u) =>
        u.ingredientId == ingredientId &&
            u.variantGroupName == sel.groupName)
            .toList();

        if (unitsForThisIng.isEmpty) continue;

        final weights = unitsForThisIng.map((u) => u.finalWeight).toList();
        final def     = unitsForThisIng.first.defaultWeight;

        final isAllDefault = weights.every((w) => (w - def).abs() < 0.0001);
        if (isAllDefault) {
          newMap.remove(ingredientId);
        } else {
          newMap[ingredientId] = weights;
        }
      }

      return sel.copyWith(unitWeightsMap: newMap);
    }).toList();

    // ── Ý 2: bán xé lẻ → dùng giá tay, đánh dấu looseSale ──────
    // unitWeights đã encode số miếng nên kho trừ đúng; chỉ ghi đè GIÁ.
    if (_isLoose) {
      final manual = double.tryParse(_loosePriceCtrl.text.trim()) ?? 0;
      final loosePrice = PriceOption(
        discountPercent: 0,
        price: manual,
        label: 'Xé lẻ',
      );
      Navigator.pop(
        context,
        item.copyWith(
          variantSelections: updatedSelections,
          selectedPrice: loosePrice,
          overriddenUnitPrice: manual,
          looseSale: true,
        ),
      );
      return;
    }

    // ── Tính giá mới theo định lượng ─────────────────────────
    // Chỉ tính khi có đúng 1 non-addon ingredient eligible trong _allUnits
    // (tức là user đang chỉnh 1 variant đơn nguyên liệu)
    PriceOption updatedPrice = item.selectedPrice;
    final eligibleMap = _getEligibleViMap();

    // Chỉ xử lý khi toàn bộ non-addon units đều thuộc eligible
    final nonAddonUnits = _allUnits.where((u) => !u.isAddon).toList();
    final allNonAddonEligible = nonAddonUnits.isNotEmpty &&
        nonAddonUnits.every((u) => eligibleMap.containsKey(u.ingredientId));

    if (allNonAddonEligible && nonAddonUnits.isNotEmpty) {
      // Nhóm theo ingredientId để lấy unit đầu tiên (vì maxSel==1, chỉ 1 unit)
      final Map<int, _IngredientUnit> firstUnitByIngredient = {};
      for (final u in nonAddonUnits) {
        firstUnitByIngredient.putIfAbsent(u.ingredientId, () => u);
      }

      // Nếu chỉ có 1 ingredient eligible → tính giá theo nó
      if (firstUnitByIngredient.length == 1) {
        final ingredientId = firstUnitByIngredient.keys.first;
        final unit         = firstUnitByIngredient[ingredientId]!;
        final vi           = eligibleMap[ingredientId]!;

        if (vi.stockDeductPerUnit > 0) {
          final actualQty = unit.finalWeight;
          final deduct    = vi.stockDeductPerUnit;
          final basePrice = item.selectedPrice.price;

          final newPrice = (basePrice * actualQty / deduct).roundToDouble();

          updatedPrice = PriceOption(
            discountPercent: item.selectedPrice.discountPercent,
            price:           newPrice,
            label:           item.selectedPrice.label,
          );
        }
      }
    }

    Navigator.pop(
      context,
      item.copyWith(
        variantSelections: updatedSelections,
        selectedPrice:     updatedPrice,
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottom = MediaQuery.of(context).viewInsets.bottom
        + MediaQuery.of(context).padding.bottom + 16;
    final surface = isDark ? const Color(0xFF1C1C1E) : Colors.white;
    const accent  = Color(0xFF0D9488);

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Container(
        decoration: BoxDecoration(
          color: surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: EdgeInsets.fromLTRB(20, 0, 20, bottom),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Center(
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.black12,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          _buildHeader(isDark, accent),
          const SizedBox(height: 12),
          const Divider(height: 1),
          if (_groups.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Text(
                'Sản phẩm này không có nguyên liệu cần điều chỉnh.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? Colors.white54 : Colors.black45,
                ),
              ),
            )
          else
            Flexible(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: _groups.length,
                itemBuilder: (ctx, i) =>
                    _buildIngredientGroup(_groups[i], isDark, accent),
              ),
            ),
          const SizedBox(height: 12),
          if (_isLoose) _buildLoosePriceField(isDark, accent),
          _buildFooter(isDark, accent),
          const SizedBox(height: 4),
        ]),
      ),
    );
  }

  Widget _buildHeader(bool isDark, Color accent) {
    // Hiển thị preview giá mới nếu có eligible ingredient đang override
    final eligibleMap    = _getEligibleViMap();
    final nonAddonUnits  = _allUnits.where((u) => !u.isAddon).toList();
    final allEligible    = nonAddonUnits.isNotEmpty &&
        nonAddonUnits.every((u) => eligibleMap.containsKey(u.ingredientId));
    final firstOverride  = nonAddonUnits.where((u) => u.isOverridden).firstOrNull;

    String? pricePreview;
    if (allEligible && firstOverride != null) {
      final vi = eligibleMap[firstOverride.ingredientId];
      if (vi != null && vi.stockDeductPerUnit > 0) {
        final newP = (widget.cartItem.selectedPrice.price *
            firstOverride.finalWeight /
            vi.stockDeductPerUnit).roundToDouble();

        // Format số
        final formatted = newP >= 1000
            ? newP.toInt().toString().replaceAllMapped(
            RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
                (m) => '${m[1]},')
            : newP.toInt().toString();
        pricePreview = '$formattedđ';
      }
    }

    return Row(children: [
      Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: accent.withOpacity(0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(Icons.scale_rounded, size: 18, color: accent),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Điều chỉnh định lượng',
              style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : Colors.black87,
              )),
          Text(
            '${widget.cartItem.product.name} × ${widget.cartItem.quantity}',
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.white54 : Colors.black45,
            ),
          ),
        ]),
      ),
      // Badge: weight + giá preview
      Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: _hasAnyOverride ? Colors.orange : accent.withOpacity(0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(children: [
            Text(
              _formatWeight(_totalWeight),
              style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.bold,
                color: _hasAnyOverride ? Colors.white : accent,
              ),
            ),
            if (_hasAnyOverride)
              const Text('Đã chỉnh',
                  style: TextStyle(
                      fontSize: 9, color: Colors.white, fontWeight: FontWeight.w600)),
          ]),
        ),
        if (pricePreview != null) ...[
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.12),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.green.withOpacity(0.3)),
            ),
            child: Text(pricePreview,
                style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Colors.green)),
          ),
        ],
      ]),
    ]);
  }

  Widget _buildIngredientGroup(
      _IngredientGroup group, bool isDark, Color accent) {
    final borderColor = group.isAddon ? Colors.green[300]! : Colors.grey[300]!;
    final bgColor     = group.isAddon ? Colors.green[50]!  : Colors.grey[100]!;

    return Container(
      key: ValueKey('group_${group.ingredientId}'),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        border: Border.all(color: borderColor, width: 1.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius:
            const BorderRadius.vertical(top: Radius.circular(11)),
          ),
          child: Row(children: [
            if (group.ingredientImageUrl.isNotEmpty)
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(8),
                  image: DecorationImage(
                    image: NetworkImage(group.ingredientImageUrl),
                    fit: BoxFit.cover,
                  ),
                ),
              )
            else
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(8)),
                child: Icon(Icons.fastfood, color: Colors.grey[400]),
              ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  if (group.isAddon) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                          color: Colors.green,
                          borderRadius: BorderRadius.circular(4)),
                      child: const Text('ADDON',
                          style: TextStyle(
                              fontSize: 9,
                              color: Colors.white,
                              fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(width: 6),
                  ],
                  Expanded(
                    child: Text(group.ingredientName,
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: group.isAddon
                                ? Colors.green[700]
                                : Colors.black87)),
                  ),
                ]),
                Text(group.variantGroupName,
                    style: TextStyle(fontSize: 11, color: Colors.grey[600])),
              ]),
            ),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(_formatWeight(group.totalWeight),
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue)),
              Text('${group.units.length} unit',
                  style: TextStyle(fontSize: 10, color: Colors.grey[600])),
            ]),
          ]),
        ),
        ...group.units.map((unit) => _buildUnitRow(unit, isDark, accent)),
      ]),
    );
  }

  Widget _buildUnitRow(_IngredientUnit unit, bool isDark, Color accent) {
    return _UnitInputRow(
      key: ValueKey('unit_${unit.ingredientId}_${unit.unitIndex}'),
      unit: unit,
      isDark: isDark,
      accent: accent,
      formatWeight: _formatWeight,
      parseWeight: _parseWeight,
      onChanged: () {
        if (mounted) Future.microtask(() { if (mounted) setState(() {}); });
      },
    );
  }

  Widget _buildLoosePriceField(bool isDark, Color accent) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.withOpacity(0.4)),
      ),
      child: Row(children: [
        Icon(Icons.call_split_rounded, size: 18, color: Colors.orange[800]),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            'Bán xé lẻ — nhập giá bán:',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
        ),
        SizedBox(
          width: 130,
          child: TextField(
            controller: _loosePriceCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : Colors.black87,
            ),
            decoration: InputDecoration(
              isDense: true,
              hintText: '0',
              suffixText: 'đ',
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              filled: true,
              fillColor: isDark ? const Color(0xFF2A2A2A) : Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: Colors.orange.withOpacity(0.4)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: Colors.orange.withOpacity(0.4)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: Colors.orange[700]!, width: 1.5),
              ),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _buildFooter(bool isDark, Color accent) {    return Row(children: [
      Expanded(
        child: OutlinedButton(
          onPressed: _resetAll,
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
            side: const BorderSide(color: Colors.red),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
          ),
          child: const Text('Reset',
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.red)),
        ),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: OutlinedButton.icon(
          onPressed: _autoFill,
          icon: const Icon(Icons.auto_fix_high, size: 16),
          label: const Text('Auto',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
            side: BorderSide(color: Colors.blue[700]!),
            foregroundColor: Colors.blue[700],
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
          ),
        ),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: ElevatedButton(
          onPressed: _confirm,
          style: ElevatedButton.styleFrom(
            backgroundColor: accent,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
          ),
          child: const Text('Xác nhận',
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.white)),
        ),
      ),
    ]);
  }
}

// ────────────────────────────────────────────────────────────────
// Unit Input Row (StatefulWidget)
// ────────────────────────────────────────────────────────────────

class _UnitInputRow extends StatefulWidget {
  final _IngredientUnit unit;
  final bool isDark;
  final Color accent;
  final String Function(double) formatWeight;
  final double Function(String) parseWeight;
  final VoidCallback onChanged;

  const _UnitInputRow({
    super.key,
    required this.unit,
    required this.isDark,
    required this.accent,
    required this.formatWeight,
    required this.parseWeight,
    required this.onChanged,
  });

  @override
  State<_UnitInputRow> createState() => _UnitInputRowState();
}

class _UnitInputRowState extends State<_UnitInputRow> {
  late TextEditingController _controller;
  double? _lastSyncedActualWeight;

  @override
  void initState() {
    super.initState();
    _lastSyncedActualWeight = widget.unit.actualWeight;
    _controller = TextEditingController(
      text: widget.unit.isOverridden
          ? widget.formatWeight(widget.unit.actualWeight!)
          : '',
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.unit.actualWeight != _lastSyncedActualWeight) {
      _lastSyncedActualWeight = widget.unit.actualWeight;
      final expectedText = widget.unit.isOverridden
          ? widget.formatWeight(widget.unit.actualWeight!)
          : '';
      if (_controller.text != expectedText) _controller.text = expectedText;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
          border: Border(top: BorderSide(color: Colors.grey[200]!))),
      child: Row(children: [
        Container(
          width: 32, height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: widget.unit.isOverridden ? Colors.orange : Colors.grey[200],
            shape: BoxShape.circle,
          ),
          child: Text(
            '${widget.unit.unitIndex + 1}',
            style: TextStyle(
              fontSize: 12, fontWeight: FontWeight.bold,
              color: widget.unit.isOverridden ? Colors.white : Colors.grey[700],
            ),
          ),
        ),
        const SizedBox(width: 12),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Mặc định',
              style: TextStyle(fontSize: 10, color: Colors.grey)),
          Text(widget.formatWeight(widget.unit.defaultWeight),
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey[700])),
        ]),
        const SizedBox(width: 12),
        const Icon(Icons.arrow_forward, size: 14, color: Colors.grey),
        const SizedBox(width: 12),
        Expanded(
          child: TextField(
            controller: _controller,
            keyboardType:
            const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
            ],
            decoration: InputDecoration(
              hintText: 'Nhập',
              filled: true,
              fillColor: Colors.grey[100],
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 8),
            ),
            onChanged: (text) {
              if (text.isEmpty || text == '0') {
                widget.unit.actualWeight = null;
              } else {
                final value = widget.parseWeight(text);
                if (value > 0) {
                  widget.unit.actualWeight = value;
                  _lastSyncedActualWeight  = value;
                }
              }
              widget.onChanged();
            },
          ),
        ),
        const SizedBox(width: 8),
        if (widget.unit.isOverridden)
          IconButton(
            icon: const Icon(Icons.refresh, size: 18),
            color: Colors.orange,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: () {
              widget.unit.reset();
              _controller.clear();
              widget.onChanged();
            },
          ),
      ]),
    );
  }
}