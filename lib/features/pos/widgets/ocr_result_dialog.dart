// lib/features/pos/widgets/ocr_result_dialog.dart
//
// Dialog hiển thị kết quả OCR từ server, cho phép:
//   - Xem và chỉnh sửa packQuantity / unitQuantity
//   - Thêm ingredient chưa có trong bảng (modal search)
//   - Cancel (không điền gì) hoặc Confirm (điền vào controllers)

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../services/pos_service.dart';

// ── Decimal formatter (tái sử dụng từ pos_shift_screen) ──────────────────────

class _DecimalFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue old, TextEditingValue next) {
    final t = next.text;
    if (t.isEmpty) return next;
    if (!RegExp(r'^[0-9]*\.?[0-9]*$').hasMatch(t)) return old;
    if (t.indexOf('.') != t.lastIndexOf('.')) return old;
    final dot = t.indexOf('.');
    if (dot != -1 && t.length - dot - 1 > 2) return old;
    return next;
  }
}

// ── Editable row model ────────────────────────────────────────────────────────

class _OcrRow {
  final int    ingredientId;
  final String ingredientName;
  final TextEditingController packCtrl;
  final TextEditingController unitCtrl;

  _OcrRow({
    required this.ingredientId,
    required this.ingredientName,
    required int    packQty,
    required double unitQty,
  })  : packCtrl = TextEditingController(
      text: packQty > 0 ? '$packQty' : '0'),
        unitCtrl = TextEditingController(
            text: unitQty > 0
                ? (unitQty == unitQty.roundToDouble()
                ? unitQty.toInt().toString()
                : unitQty.toStringAsFixed(2).replaceAll(RegExp(r'0+$'), ''))
                : '0');

  void dispose() {
    packCtrl.dispose();
    unitCtrl.dispose();
  }
}

// ── Main dialog ───────────────────────────────────────────────────────────────

class OcrResultDialog extends StatefulWidget {
  /// Kết quả OCR từ server — chỉ chứa các item đã match ingredient
  final ShiftOcrResult ocrResult;

  /// Toàn bộ ingredients của store — để modal add
  final List<Map<String, dynamic>> allIngredients;

  /// Callback khi user nhấn Confirm
  final void Function(List<OcrInventoryItem> confirmedItems) onConfirm;

  const OcrResultDialog({
    super.key,
    required this.ocrResult,
    required this.allIngredients,
    required this.onConfirm,
  });

  /// Helper: show dialog và chờ kết quả
  static Future<void> show(
      BuildContext context, {
        required ShiftOcrResult ocrResult,
        required List<Map<String, dynamic>> allIngredients,
        required void Function(List<OcrInventoryItem>) onConfirm,
      }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => OcrResultDialog(
        ocrResult:       ocrResult,
        allIngredients:  allIngredients,
        onConfirm:       onConfirm,
      ),
    );
  }

  @override
  State<OcrResultDialog> createState() => _OcrResultDialogState();
}

class _OcrResultDialogState extends State<OcrResultDialog> {
  late final List<_OcrRow> _rows;

  @override
  void initState() {
    super.initState();
    _rows = widget.ocrResult.inventoryList
        .where((item) => item.matchedIngredientId != null)
        .map((item) => _OcrRow(
      ingredientId:   item.matchedIngredientId!,
      ingredientName: item.matchedIngredientName ?? item.name,
      packQty:        item.packQuantity ?? 0,
      unitQty:        item.unitQuantity ?? 0,
    ))
        .toList();
  }

  @override
  void dispose() {
    for (final r in _rows) r.dispose();
    super.dispose();
  }

  // IDs đã có trong bảng
  Set<int> get _presentIds => _rows.map((r) => r.ingredientId).toSet();

  // Ingredients chưa có trong bảng
  List<Map<String, dynamic>> get _availableIngredients =>
      widget.allIngredients
          .where((i) => !_presentIds.contains(i['id'] as int))
          .toList();

  Future<void> _showAddModal() async {
    final available = _availableIngredients;
    if (available.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tất cả nguyên liệu đã có trong bảng')),
      );
      return;
    }

    final selected = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddIngredientModal(ingredients: available),
    );

    if (selected == null || !mounted) return;

    setState(() {
      _rows.add(_OcrRow(
        ingredientId:   selected['id'] as int,
        ingredientName: selected['name'] as String,
        packQty:        0,
        unitQty:        0,
      ));
    });
  }

  void _removeRow(int index) {
    setState(() {
      _rows[index].dispose();
      _rows.removeAt(index);
    });
  }

  void _confirm() {
    final items = _rows.map((row) {
      final pack = int.tryParse(row.packCtrl.text.trim()) ?? 0;
      final unit = double.tryParse(row.unitCtrl.text.trim()) ?? 0.0;
      return OcrInventoryItem(
        name:                  row.ingredientName,
        packQuantity:          pack,
        unitQuantity:          unit,
        matchedIngredientId:   row.ingredientId,
        matchedIngredientName: row.ingredientName,
      );
    }).toList();

    Navigator.of(context).pop();
    widget.onConfirm(items);
  }

  @override
  Widget build(BuildContext context) {
    final cs     = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Thông tin OCR header
    final staffName = widget.ocrResult.staffName;
    final date      = widget.ocrResult.date;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Header ───────────────────────────────────────────────
            _buildHeader(cs, isDark, staffName, date),

            const Divider(height: 1),

            // ── Column labels ─────────────────────────────────────────
            _buildColumnHeader(cs),

            // ── Rows (scrollable) ─────────────────────────────────────
            Flexible(
              child: _rows.isEmpty
                  ? Padding(
                padding: const EdgeInsets.symmetric(vertical: 32),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.inventory_2_outlined,
                      size: 40,
                      color: cs.onSurface.withOpacity(0.25)),
                  const SizedBox(height: 8),
                  Text(
                    'Không nhận dạng được nguyên liệu nào',
                    style: TextStyle(
                        color: cs.onSurface.withOpacity(0.4),
                        fontSize: 13),
                  ),
                ]),
              )
                  : ListView.separated(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: _rows.length,
                separatorBuilder: (_, __) =>
                    Divider(height: 1, color: cs.outlineVariant.withOpacity(0.4)),
                itemBuilder: (_, i) => _buildRow(_rows[i], i, cs),
              ),
            ),

            const Divider(height: 1),

            // ── Footer: Add + Cancel/Confirm ──────────────────────────
            _buildFooter(cs),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(
      ColorScheme cs, bool isDark, String? staffName, String? date) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 16, 14),
      decoration: BoxDecoration(
        color: Colors.blue.shade50.withOpacity(isDark ? 0.1 : 1),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.blue.shade100,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(Icons.camera_alt_outlined,
              size: 20, color: Colors.blue.shade700),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Kết quả OCR',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            if (staffName != null || date != null)
              Text(
                [if (staffName != null) staffName, if (date != null) date]
                    .join(' · '),
                style: TextStyle(fontSize: 12, color: cs.onSurface.withOpacity(0.55)),
              )
            else
              Text('Kiểm tra và chỉnh sửa trước khi xác nhận',
                  style: TextStyle(
                      fontSize: 12, color: cs.onSurface.withOpacity(0.5))),
          ]),
        ),
        // badge số lượng
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.blue.shade600,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            '${_rows.length} mục',
            style: const TextStyle(
                color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
          ),
        ),
      ]),
    );
  }

  Widget _buildColumnHeader(ColorScheme cs) {
    const style = TextStyle(fontSize: 10, fontWeight: FontWeight.w700);
    return Container(
      color: cs.surfaceContainerHighest.withOpacity(0.5),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(children: [
        const Expanded(flex: 5, child: Text('Tên nguyên liệu', style: style)),
        Expanded(
            flex: 2,
            child: Text('Bịch',
                style: style.copyWith(color: Colors.orange.shade700),
                textAlign: TextAlign.center)),
        Expanded(
            flex: 2,
            child: Text('Lẻ',
                style: style.copyWith(color: Colors.blue.shade700),
                textAlign: TextAlign.center)),
        const SizedBox(width: 32), // xóa button placeholder
      ]),
    );
  }

  Widget _buildRow(_OcrRow row, int index, ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(children: [
        // Tên ingredient
        Expanded(
          flex: 5,
          child: Text(
            row.ingredientName,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        // Pack input
        Expanded(
          flex: 2,
          child: _EditCell(
            controller: row.packCtrl,
            isDecimal:  false,
            color:      Colors.orange,
          ),
        ),
        const SizedBox(width: 4),
        // Unit input
        Expanded(
          flex: 2,
          child: _EditCell(
            controller: row.unitCtrl,
            isDecimal:  true,
            color:      Colors.blue,
          ),
        ),
        const SizedBox(width: 4),
        // Xóa dòng
        GestureDetector(
          onTap: () => _removeRow(index),
          child: Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.red.shade200),
            ),
            child: Icon(Icons.close_rounded,
                size: 14, color: Colors.red.shade400),
          ),
        ),
      ]),
    );
  }

  Widget _buildFooter(ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
      child: Row(children: [
        // Add ingredient
        OutlinedButton.icon(
          icon: const Icon(Icons.add_rounded, size: 16),
          label: const Text('Thêm', style: TextStyle(fontSize: 13)),
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.blue.shade700,
            side: BorderSide(color: Colors.blue.shade300),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
            padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
          onPressed: _showAddModal,
        ),
        const Spacer(),
        // Cancel
        OutlinedButton(
          style: OutlinedButton.styleFrom(
            foregroundColor: cs.onSurface.withOpacity(0.7),
            side: BorderSide(color: cs.outline.withOpacity(0.4)),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
            padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          ),
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Hủy', style: TextStyle(fontSize: 13)),
        ),
        const SizedBox(width: 8),
        // Confirm
        FilledButton.icon(
          icon: const Icon(Icons.check_rounded, size: 16),
          label: const Text('Xác nhận',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
          style: FilledButton.styleFrom(
            backgroundColor: Colors.blue.shade600,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
            padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          ),
          onPressed: _rows.isEmpty ? null : _confirm,
        ),
      ]),
    );
  }
}

// ── Editable cell ─────────────────────────────────────────────────────────────

class _EditCell extends StatelessWidget {
  final TextEditingController controller;
  final bool  isDecimal;
  final Color color;

  const _EditCell({
    required this.controller,
    required this.isDecimal,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SizedBox(
      height: 34,
      child: TextField(
        controller:      controller,
        keyboardType:    TextInputType.numberWithOptions(decimal: isDecimal),
        inputFormatters: isDecimal
            ? [_DecimalFormatter()]
            : [FilteringTextInputFormatter.digitsOnly],
        textAlign: TextAlign.center,
        style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: color.withOpacity(0.85)),
        decoration: InputDecoration(
          isDense:        true,
          contentPadding:
          const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
          filled:    true,
          fillColor: color.withOpacity(0.07),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(7),
            borderSide: BorderSide(color: color.withOpacity(0.3)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(7),
            borderSide: BorderSide(color: color.withOpacity(0.3)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(7),
            borderSide: BorderSide(color: color, width: 1.5),
          ),
        ),
      ),
    );
  }
}

// ── Add Ingredient Modal ──────────────────────────────────────────────────────

class _AddIngredientModal extends StatefulWidget {
  final List<Map<String, dynamic>> ingredients;
  const _AddIngredientModal({required this.ingredients});

  @override
  State<_AddIngredientModal> createState() => _AddIngredientModalState();
}

class _AddIngredientModalState extends State<_AddIngredientModal> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get _filtered {
    if (_query.isEmpty) return widget.ingredients;
    final q = _query.toLowerCase();
    return widget.ingredients
        .where((i) => (i['name'] as String).toLowerCase().contains(q))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final cs     = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final filtered = _filtered;

    return Container(
      margin:  const EdgeInsets.all(16),
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        // Handle bar
        Container(
          width: 40, height: 4,
          margin: const EdgeInsets.only(top: 12, bottom: 14),
          decoration: BoxDecoration(
              color: cs.outline.withOpacity(0.3),
              borderRadius: BorderRadius.circular(2)),
        ),

        // Title
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(children: [
            Icon(Icons.add_circle_outline, color: Colors.blue.shade600, size: 20),
            const SizedBox(width: 8),
            Text('Thêm nguyên liệu',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade700)),
            const Spacer(),
            // Số chưa có
            Container(
              padding:
              const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.blue.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text('${widget.ingredients.length} chưa thêm',
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade700)),
            ),
          ]),
        ),

        const SizedBox(height: 12),

        // Search box
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TextField(
            controller: _searchCtrl,
            autofocus:  true,
            onChanged:  (v) => setState(() => _query = v),
            style: const TextStyle(fontSize: 14),
            decoration: InputDecoration(
              hintText:       'Tìm theo tên...',
              hintStyle:      TextStyle(color: cs.onSurface.withOpacity(0.4)),
              prefixIcon:     const Icon(Icons.search_rounded, size: 18),
              isDense:        true,
              contentPadding:
              const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
              filled:    true,
              fillColor: cs.surfaceContainerHighest.withOpacity(0.5),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),

        const SizedBox(height: 8),

        // List
        ConstrainedBox(
          constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.38),
          child: filtered.isEmpty
              ? Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Text('Không tìm thấy nguyên liệu',
                style: TextStyle(
                    color: cs.onSurface.withOpacity(0.4),
                    fontSize: 13)),
          )
              : ListView.separated(
            padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 4),
            shrinkWrap: true,
            itemCount: filtered.length,
            separatorBuilder: (_, __) => Divider(
                height: 1,
                color: cs.outlineVariant.withOpacity(0.35)),
            itemBuilder: (ctx, i) {
              final ing  = filtered[i];
              final name = ing['name'] as String;
              final type = (ing['ingredientType'] as String?) ?? '';
              final isMain = type.toUpperCase() != 'SUB';

              return ListTile(
                dense:         true,
                contentPadding:
                const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 2),
                leading: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: (isMain
                        ? Colors.blue
                        : Colors.deepOrange)
                        .withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    isMain
                        ? Icons.kitchen_outlined
                        : Icons.add_box_outlined,
                    size: 16,
                    color: isMain
                        ? Colors.blue.shade600
                        : Colors.deepOrange.shade600,
                  ),
                ),
                title: Text(name,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600)),
                subtitle: Text(
                    isMain ? 'Nguyên liệu chính' : 'Nguyên liệu phụ',
                    style: TextStyle(
                        fontSize: 10,
                        color: cs.onSurface.withOpacity(0.5))),
                trailing: Icon(Icons.add_rounded,
                    size: 18, color: Colors.blue.shade500),
                onTap: () => Navigator.of(ctx).pop(ing),
              );
            },
          ),
        ),

        const SizedBox(height: 4),
      ]),
    );
  }
}