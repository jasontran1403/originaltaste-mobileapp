// lib/features/management/screens/inventory_history_screen.dart
// 1:1 với GetX gốc — infinite scroll, filter by ingredientId

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/app_colors.dart';
import '../../../data/models/management/management_models.dart';
import '../../../services/seller_service.dart';
import '../../../shared/widgets/management_shared_widgets.dart';

// ── State ─────────────────────────────────────────────────────────

class _HistoryState {
  final List<InventoryLogModel> logs;
  final bool isLoading;
  final bool hasMore;
  final int page;
  final String? error;

  const _HistoryState({
    this.logs      = const [],
    this.isLoading = false,
    this.hasMore   = true,
    this.page      = 0,
    this.error,
  });

  _HistoryState copyWith({
    List<InventoryLogModel>? logs,
    bool? isLoading, bool? hasMore, int? page, String? error,
    bool clearError = false,
  }) => _HistoryState(
    logs:      logs      ?? this.logs,
    isLoading: isLoading ?? this.isLoading,
    hasMore:   hasMore   ?? this.hasMore,
    page:      page      ?? this.page,
    error:     clearError ? null : (error ?? this.error),
  );
}

// ── Notifier ──────────────────────────────────────────────────────

class _HistoryNotifier extends FamilyNotifier<_HistoryState, int> {
  @override
  _HistoryState build(int arg) {
    Future.microtask(() => _fetch());
    return const _HistoryState(isLoading: true);
  }

  Future<void> _fetch({bool refresh = false}) async {
    if (state.isLoading && !refresh && state.page > 0) return;
    final page = refresh ? 0 : state.page;

    state = state.copyWith(
      isLoading: true,
      clearError: true,
      logs: refresh ? [] : state.logs,
    );

    final result = await SellerService.instance.getInventoryLogs(
      page: page, size: 20, ingredientId: arg,
    );

    if (result.isSuccess && result.data != null) {
      final paged  = result.data!;
      final merged = [...(refresh ? <InventoryLogModel>[] : state.logs),
                      ...paged.content];
      state = state.copyWith(
        logs:      merged,
        isLoading: false,
        hasMore:   paged.hasMore,
        page:      page + 1,
      );
    } else {
      state = state.copyWith(
        isLoading: false,
        error: result.message ?? 'Không tải được lịch sử kho',
      );
    }
  }

  Future<void> refresh() => _fetch(refresh: true);
  void loadMore() {
    if (!state.hasMore || state.isLoading) return;
    _fetch();
  }
}

final _historyProvider =
    NotifierProviderFamily<_HistoryNotifier, _HistoryState, int>(
        _HistoryNotifier.new);

// ── Screen ────────────────────────────────────────────────────────

class InventoryHistoryScreen extends ConsumerWidget {
  final IngredientModel ingredient;
  const InventoryHistoryScreen({super.key, required this.ingredient});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark    = Theme.of(context).brightness == Brightness.dark;
    final bg        = isDark ? AppColors.darkBg    : AppColors.lightBg;
    final cardBg    = isDark ? AppColors.darkCard  : Colors.white;
    final border    = isDark ? AppColors.darkBorder : const Color(0xFFE5E7EB);
    final onBg      = isDark ? AppColors.darkTextPrimary : Colors.black87;
    final secondary = isDark ? AppColors.darkTextSecondary : const Color(0xFF6B7280);
    final primary   = isDark ? AppColors.primary : AppColors.primaryDark;
    final top       = MediaQuery.of(context).padding.top;
    final bottom    = MediaQuery.of(context).padding.bottom;

    final notifier = ref.read(_historyProvider(ingredient.id).notifier);
    final state    = ref.watch(_historyProvider(ingredient.id));

    return Scaffold(
      backgroundColor: bg,
      body: Column(children: [

        // ── App bar ────────────────────────────────────────
        Container(
          padding: EdgeInsets.fromLTRB(4, top + 8, 16, 12),
          decoration: BoxDecoration(
            color:  cardBg,
            border: Border(bottom: BorderSide(color: border)),
          ),
          child: Row(children: [
            IconButton(
              icon: Icon(Icons.arrow_back_ios_new_rounded,
                  size: 20, color: onBg),
              onPressed: () => Navigator.pop(context),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                ingredient.name.isNotEmpty
                    ? 'Lịch sử: ${ingredient.name}'
                    : 'Lịch sử xuất/nhập kho',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: onBg),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ]),
        ),

        // ── Table header ──────────────────────────────────
        Container(
          color: primary.withOpacity(0.08),
          padding: const EdgeInsets.symmetric(
              horizontal: 20, vertical: 12),
          child: Row(children: [
            Expanded(flex: 4,
                child: Text('Nguyên liệu / Ngày',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: onBg))),
            Expanded(flex: 4,
                child: Center(
                    child: Text('Mục đích',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: onBg)))),
            Expanded(flex: 2,
                child: Text('Số lượng',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: onBg))),
            Expanded(flex: 2,
                child: Center(
                    child: Text('Trạng thái',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: onBg)))),
          ]),
        ),
        Divider(height: 0, color: border),

        // ── Body ──────────────────────────────────────────
        Expanded(
          child: _HistoryBody(
            state:     state,
            notifier:  notifier,
            isDark:    isDark,
            primary:   primary,
            secondary: secondary,
            border:    border,
            bottom:    bottom,
          ),
        ),
      ]),
    );
  }
}

// ── Body ──────────────────────────────────────────────────────────

class _HistoryBody extends StatelessWidget {
  final _HistoryState state;
  final _HistoryNotifier notifier;
  final bool isDark;
  final Color primary, secondary, border;
  final double bottom;

  const _HistoryBody({
    required this.state,     required this.notifier,
    required this.isDark,    required this.primary,
    required this.secondary, required this.border,
    required this.bottom,
  });

  @override
  Widget build(BuildContext context) {
    if (state.isLoading && state.logs.isEmpty) {
      return Center(
        child: CircularProgressIndicator(
            strokeWidth: 2.5,
            valueColor: AlwaysStoppedAnimation(primary)),
      );
    }
    if (state.error != null && state.logs.isEmpty) {
      return MgmtErrorState(
          message: state.error!, onRetry: notifier.refresh);
    }
    if (state.logs.isEmpty) {
      return MgmtEmptyState(
        icon:     Icons.history_rounded,
        title:    'Chưa có lịch sử xuất/nhập kho',
        subtitle: '',
      );
    }

    return RefreshIndicator(
      onRefresh: notifier.refresh,
      color: primary,
      child: ListView.builder(
        padding: EdgeInsets.only(bottom: 24 + bottom),
        itemCount: state.logs.length + (state.hasMore ? 1 : 0),
        itemBuilder: (_, i) {
          if (i == state.logs.length) {
            WidgetsBinding.instance
                .addPostFrameCallback((_) => notifier.loadMore());
            return Padding(
              padding: const EdgeInsets.all(20),
              child: Center(
                child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation(primary)),
              ),
            );
          }
          return _LogRow(
            log:       state.logs[i],
            isDark:    isDark,
            primary:   primary,
            secondary: secondary,
            border:    border,
          );
        },
      ),
    );
  }
}

// ── Log row ───────────────────────────────────────────────────────

class _LogRow extends StatelessWidget {
  final InventoryLogModel log;
  final bool isDark;
  final Color primary, secondary, border;

  const _LogRow({
    required this.log,     required this.isDark,
    required this.primary, required this.secondary,
    required this.border,
  });

  @override
  Widget build(BuildContext context) {
    final onBg     = isDark ? AppColors.darkTextPrimary : Colors.black87;
    final dateFmt  = DateFormat('dd/MM/yyyy HH:mm');
    final date     = DateTime.fromMillisecondsSinceEpoch(log.createdAt ?? 0);
    final fmtDate  = dateFmt.format(date);

    // null-safe: purpose có thể null
    final purpose    = log.purpose ?? 'Không rõ';
    final isImport   = purpose.contains('Nhập');
    final qtyColor   = isImport ? AppColors.success : AppColors.error;
    final qtyText    = '${log.quantity.toStringAsFixed(2)}'
        '${(log.unit != null && log.unit!.isNotEmpty) ? ' ${log.unit}' : ''}';

    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        border: Border(
            bottom: BorderSide(
                color: Colors.grey.shade300.withOpacity(0.5))),
      ),
      child: Row(children: [
        // Cột 1: Tên + Ngày
        Expanded(flex: 4, child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(log.ingredientName ?? 'Không xác định',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: onBg)),
            const SizedBox(height: 4),
            Text(fmtDate,
                style: TextStyle(
                    fontSize: 12, color: secondary)),
          ],
        )),

        // Cột 2: Mục đích
        Expanded(flex: 4, child: Center(
          child: Text(purpose,
              style: TextStyle(fontSize: 13, color: onBg),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis),
        )),

        // Cột 3: Số lượng
        Expanded(flex: 2, child: Text(qtyText,
            textAlign: TextAlign.right,
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: qtyColor))),

        // Cột 4: Status
        Expanded(flex: 2, child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color:        AppColors.success.withAlpha(20),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              log.status ?? 'Completed',
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.success),
            ),
          ),
        )),
      ]),
    );
  }
}
