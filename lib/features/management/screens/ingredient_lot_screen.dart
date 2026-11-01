// lib/features/management/screens/ingredient_lot_screen.dart
//
// Danh sách LÔ GIÁ VỐN (FIFO) của 1 nguyên liệu.
// - Lô "OPENING" = tồn kho cũ backfill (giá vốn 0, HSD +1 năm)
// - Lô IS-xxxxx  = lô nhập kho (giá vốn + HSD tại thời điểm nhập)

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/management/inventory_batch_models.dart';
import '../../../data/models/management/management_models.dart';
import '../../../services/inventory_batch_service.dart';
import '../../../shared/widgets/management_shared_widgets.dart';

// ── State ─────────────────────────────────────────────────────────

class _LotState {
  final List<InventoryCostLotModel> lots;
  final bool    isLoading;
  final String? error;

  const _LotState({
    this.lots = const [],
    this.isLoading = false,
    this.error,
  });

  _LotState copyWith({
    List<InventoryCostLotModel>? lots,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) =>
      _LotState(
        lots:      lots ?? this.lots,
        isLoading: isLoading ?? this.isLoading,
        error:     clearError ? null : (error ?? this.error),
      );

  double get totalRemaining =>
      lots.fold(0.0, (s, l) => s + l.remainingQuantity);

  double get totalValue =>
      lots.fold(0.0, (s, l) => s + l.remainingValue);

  /// Giá vốn bình quân của tồn hiện tại.
  double get avgCost =>
      totalRemaining > 0 ? totalValue / totalRemaining : 0;
}

// ── Notifier ──────────────────────────────────────────────────────

class _LotNotifier extends FamilyNotifier<_LotState, int> {
  @override
  _LotState build(int arg) {
    Future.microtask(_fetch);
    return const _LotState(isLoading: true);
  }

  Future<void> _fetch() async {
    state = state.copyWith(isLoading: true, clearError: true);

    final res = await InventoryBatchService.instance.getCostLots(arg);

    if (res.isSuccess && res.data != null) {
      state = state.copyWith(lots: res.data!, isLoading: false);
    } else {
      state = state.copyWith(
        isLoading: false,
        error: res.message ?? 'Không tải được danh sách lô',
      );
    }
  }

  Future<void> refresh() => _fetch();
}

final _lotProvider =
NotifierProviderFamily<_LotNotifier, _LotState, int>(_LotNotifier.new);

// ── Screen ────────────────────────────────────────────────────────

class IngredientLotScreen extends ConsumerWidget {
  final IngredientModel ingredient;
  const IngredientLotScreen({super.key, required this.ingredient});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark    = Theme.of(context).brightness == Brightness.dark;
    final bg        = isDark ? AppColors.darkBg   : AppColors.lightBg;
    final cardBg    = isDark ? AppColors.darkCard : Colors.white;
    final border    = isDark ? AppColors.darkBorder : const Color(0xFFE5E7EB);
    final onBg      = isDark ? AppColors.darkTextPrimary : Colors.black87;
    final secondary = isDark ? AppColors.darkTextSecondary : const Color(0xFF6B7280);
    final primary   = isDark ? AppColors.primary : AppColors.primaryDark;
    final top       = MediaQuery.of(context).padding.top;
    final bottom    = MediaQuery.of(context).padding.bottom;

    final state    = ref.watch(_lotProvider(ingredient.id));
    final notifier = ref.read(_lotProvider(ingredient.id).notifier);

    return Scaffold(
      backgroundColor: bg,
      body: Column(children: [

        // ── App bar ──────────────────────────────────────
        Container(
          padding: EdgeInsets.fromLTRB(4, top + 8, 16, 12),
          decoration: BoxDecoration(
            color:  cardBg,
            border: Border(bottom: BorderSide(color: border)),
          ),
          child: Row(children: [
            IconButton(
              icon: Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: onBg),
              onPressed: () => Navigator.pop(context),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Lô hàng',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w700, color: onBg)),
                  Text(ingredient.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: secondary)),
                ],
              ),
            ),
            IconButton(
              icon: Icon(Icons.refresh_rounded, size: 20, color: secondary),
              onPressed: notifier.refresh,
            ),
          ]),
        ),

        // ── Summary ──────────────────────────────────────
        if (state.lots.isNotEmpty)
          Container(
            color: primary.withOpacity(0.06),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(children: [
              _Summary(
                label: 'Tồn theo lô',
                value: '${fmtQty(state.totalRemaining)} ${ingredient.unit}',
                color: primary, secondary: secondary, onBg: onBg,
              ),
              _Summary(
                label: 'Giá vốn TB',
                value: '${AppFormatter.money(state.avgCost.round())}đ',
                color: primary, secondary: secondary, onBg: onBg,
              ),
              _Summary(
                label: 'Giá trị tồn',
                value: '${AppFormatter.money(state.totalValue.round())}đ',
                color: primary, secondary: secondary, onBg: onBg,
              ),
            ]),
          ),

        Divider(height: 1, color: border),

        // ── Body ─────────────────────────────────────────
        Expanded(
          child: Builder(builder: (_) {
            if (state.isLoading && state.lots.isEmpty) {
              return Center(
                child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor: AlwaysStoppedAnimation(primary)),
              );
            }
            if (state.error != null && state.lots.isEmpty) {
              return MgmtErrorState(
                  message: state.error!, onRetry: notifier.refresh);
            }
            if (state.lots.isEmpty) {
              return const MgmtEmptyState(
                icon:     Icons.layers_outlined,
                title:    'Chưa có lô nào',
                subtitle: 'Lô sẽ được tạo khi bạn nhập kho nguyên liệu này',
              );
            }

            return RefreshIndicator(
              onRefresh: notifier.refresh,
              color: primary,
              child: ListView.separated(
                padding: EdgeInsets.fromLTRB(12, 12, 12, 24 + bottom),
                itemCount: state.lots.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (_, i) => _LotCard(
                  lot:       state.lots[i],
                  unit:      ingredient.unit,
                  isDark:    isDark,
                  primary:   primary,
                  secondary: secondary,
                ),
              ),
            );
          }),
        ),
      ]),
    );
  }
}

// ── Summary cell ──────────────────────────────────────────────────

class _Summary extends StatelessWidget {
  final String label, value;
  final Color color, secondary, onBg;

  const _Summary({
    required this.label,
    required this.value,
    required this.color,
    required this.secondary,
    required this.onBg,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: TextStyle(fontSize: 11, color: secondary)),
          const SizedBox(height: 2),
          Text(value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w800, color: onBg)),
        ],
      ),
    );
  }
}

// ── Lot card ──────────────────────────────────────────────────────

class _LotCard extends StatelessWidget {
  final InventoryCostLotModel lot;
  final String unit;
  final bool   isDark;
  final Color  primary, secondary;

  const _LotCard({
    required this.lot,
    required this.unit,
    required this.isDark,
    required this.primary,
    required this.secondary,
  });

  @override
  Widget build(BuildContext context) {
    final onBg = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;

    // Màu HSD theo số ngày còn lại
    final days = lot.daysToExpiry;
    Color expiryColor = secondary;
    if (days != null) {
      if (days < 0)       expiryColor = AppColors.error;
      else if (days < 30) expiryColor = AppColors.warning;
      else                expiryColor = AppColors.success;
    }

    final depleted = lot.depleted;

    return Opacity(
      opacity: depleted ? 0.55 : 1,
      child: MgmtCard(
        padding: const EdgeInsets.all(0),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Hàng 1: mã lô + trạng thái ──────────────────
              Row(children: [
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: (lot.opening ? AppColors.warning : primary)
                        .withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    lot.opening
                        ? Icons.inventory_2_outlined
                        : Icons.layers_rounded,
                    size: 18,
                    color: lot.opening ? AppColors.warning : primary,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        lot.opening ? 'Tồn kho cũ (OPENING)' : lot.sourceRef,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: onBg),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        lot.createdAt > 0
                            ? 'Nhập: ${DateFormat('dd/MM/yyyy HH:mm').format(
                            DateTime.fromMillisecondsSinceEpoch(lot.createdAt))}'
                            : 'Tồn đầu kỳ',
                        style: TextStyle(fontSize: 11, color: secondary),
                      ),
                    ],
                  ),
                ),
                _Chip(
                  text: depleted
                      ? 'Hết lô'
                      : (lot.expired ? 'Quá hạn' : 'Còn hàng'),
                  color: depleted
                      ? secondary
                      : (lot.expired ? AppColors.error : AppColors.success),
                ),
              ]),

              const SizedBox(height: 10),
              Divider(height: 1, color: secondary.withOpacity(0.18)),
              const SizedBox(height: 10),

              // ── Hàng 2: số liệu ────────────────────────────
              Row(children: [
                _Cell(
                  label: 'Còn lại',
                  value: '${fmtQty(lot.remainingQuantity)} $unit',
                  valueColor: depleted ? secondary : primary,
                  secondary: secondary,
                ),
                _Cell(
                  label: 'Nhập',
                  value: '${fmtQty(lot.originalQuantity)} $unit',
                  valueColor: onBg,
                  secondary: secondary,
                ),
                _Cell(
                  label: 'Giá vốn',
                  value: '${AppFormatter.money(lot.unitCost.round())}đ',
                  valueColor: onBg,
                  secondary: secondary,
                ),
                _Cell(
                  label: 'HSD',
                  value: fmtDate(lot.expiryDate),
                  valueColor: expiryColor,
                  secondary: secondary,
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}

class _Cell extends StatelessWidget {
  final String label, value;
  final Color valueColor, secondary;

  const _Cell({
    required this.label,
    required this.value,
    required this.valueColor,
    required this.secondary,
  });

  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: TextStyle(fontSize: 10, color: secondary)),
        const SizedBox(height: 3),
        Text(value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: valueColor)),
      ],
    ),
  );
}

class _Chip extends StatelessWidget {
  final String text;
  final Color  color;
  const _Chip({required this.text, required this.color});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
    decoration: BoxDecoration(
      color: color.withOpacity(0.12),
      borderRadius: BorderRadius.circular(6),
      border: Border.all(color: color.withOpacity(0.3)),
    ),
    child: Text(text,
        style: TextStyle(
            fontSize: 10.5, fontWeight: FontWeight.w700, color: color)),
  );
}

class InventoryCostLotModel {
  final int     id;
  final int     ingredientId;
  final String  ingredientName;
  final String  unit;

  /// Mã phiếu nhập tạo ra lô, hoặc "OPENING" (tồn kho cũ backfill).
  final String  sourceRef;
  final bool    opening;

  final double  unitCost;
  final double  originalQuantity;
  final double  remainingQuantity;
  final double  remainingValue;

  final int?    expiryDate;   // epoch ms
  final int     createdAt;    // epoch ms (0 với lô OPENING)

  final bool    depleted;     // đã xuất hết
  final bool    expired;      // quá HSD

  const InventoryCostLotModel({
    required this.id,
    required this.ingredientId,
    required this.ingredientName,
    required this.unit,
    required this.sourceRef,
    required this.opening,
    required this.unitCost,
    required this.originalQuantity,
    required this.remainingQuantity,
    required this.remainingValue,
    this.expiryDate,
    required this.createdAt,
    required this.depleted,
    required this.expired,
  });

  factory InventoryCostLotModel.fromJson(Map<String, dynamic> j) =>
      InventoryCostLotModel(
        id:                (j['id'] as num?)?.toInt() ?? 0,
        ingredientId:      (j['ingredientId'] as num?)?.toInt() ?? 0,
        ingredientName:    j['ingredientName'] ?? '',
        unit:              j['unit'] ?? '',
        sourceRef:         j['sourceRef'] ?? '',
        opening:           j['opening'] == true,
        unitCost:          (j['unitCost']          as num?)?.toDouble() ?? 0,
        originalQuantity:  (j['originalQuantity']  as num?)?.toDouble() ?? 0,
        remainingQuantity: (j['remainingQuantity'] as num?)?.toDouble() ?? 0,
        remainingValue:    (j['remainingValue']    as num?)?.toDouble() ?? 0,
        expiryDate:        (j['expiryDate'] as num?)?.toInt(),
        createdAt:         (j['createdAt']  as num?)?.toInt() ?? 0,
        depleted:          j['depleted'] == true,
        expired:           j['expired']  == true,
      );

  /// Số ngày còn lại tới HSD (null nếu không có HSD).
  int? get daysToExpiry {
    if (expiryDate == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(expiryDate!)
        .difference(DateTime.now())
        .inDays;
  }
}
