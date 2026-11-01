// lib/features/management/widgets/ingredient_list_pane.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../data/models/management/management_models.dart';
import '../../../shared/widgets/management_shared_widgets.dart';
import '../controller/ingredient_controller.dart';
import '../screens/inventory_history_screen.dart';
import '../screens/inventory_screen.dart';
import 'ingredient_form_sheet.dart';
import '../screens/ingredient_lot_screen.dart';

class IngredientListPane extends ConsumerWidget {
  const IngredientListPane({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state     = ref.watch(ingredientListProvider);
    final notifier  = ref.read(ingredientListProvider.notifier);
    final isDark    = Theme.of(context).brightness == Brightness.dark;
    final primary   = isDark ? AppColors.primary : AppColors.primaryDark;
    final secondary = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final border    = isDark ? AppColors.darkBorder : AppColors.lightBorder;

    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 12, 10),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color:        primary.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.science_outlined, size: 18, color: primary),
          ),
          const SizedBox(width: 10),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Nguyên liệu',
                style: TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w800,
                    color: isDark
                        ? AppColors.darkTextPrimary
                        : AppColors.lightTextPrimary)),
            Text('${state.items.length} mục',
                style: TextStyle(fontSize: 11, color: secondary)),
          ]),
          const Spacer(),
          Tooltip(
            message: 'Nhập kho thủ công',
            child: GestureDetector(
              // onTap: () async {
              //   final ok = await Navigator.push<bool>(
              //     context,
              //     MaterialPageRoute(builder: (_) => const ManualImportScreen()),
              //   );
              //   if (ok == true) notifier.refresh();
              // },
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const InventoryScreen()),     // ← mới
                );
                notifier.refresh(); // luôn refresh khi quay lại, không cần check ok
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
                decoration: BoxDecoration(
                  color:        const Color(0xFF5C6BC0).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF5C6BC0).withOpacity(0.3)),
                ),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.edit_note_rounded, size: 15, color: Color(0xFF5C6BC0)),
                  SizedBox(width: 5),
                  Text('Nhập',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
                          color: Color(0xFF5C6BC0))),
                ]),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () async {
              final ok = await IngredientFormSheet.show(context);
              if (ok) notifier.refresh();
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color:        primary,
                borderRadius: BorderRadius.circular(10),
                boxShadow: [BoxShadow(
                    color: primary.withOpacity(0.35),
                    blurRadius: 6, offset: const Offset(0, 2))],
              ),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                 Icon(Icons.add_rounded, size: 16, color: Colors.white),
                 SizedBox(width: 5),
                 Text('Thêm',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                        color: Colors.white)),
              ]),
            ),
          ),
        ]),
      ),

      Divider(height: 1, color: border),

      Expanded(
        child: _IngredientBody(
          state:     state,
          notifier:  notifier,
          isDark:    isDark,
          primary:   primary,
          secondary: secondary,
          border:    border,
        ),
      ),
    ]);
  }
}

// ══════════════════════════════════════════════════════════════════
// Body với ScrollController + local _requesting flag
// ══════════════════════════════════════════════════════════════════

class _IngredientBody extends StatefulWidget {
  final IngredientListState    state;
  final IngredientListNotifier notifier;
  final bool  isDark;
  final Color primary, secondary, border;

  const _IngredientBody({
    required this.state,
    required this.notifier,
    required this.isDark,
    required this.primary,
    required this.secondary,
    required this.border,
  });

  @override
  State<_IngredientBody> createState() => _IngredientBodyState();
}

class _IngredientBodyState extends State<_IngredientBody> {
  final _scroll = ScrollController();
  bool _requesting = false;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
  }

  @override
  void didUpdateWidget(_IngredientBody old) {
    super.didUpdateWidget(old);
    // Reset flag khi load xong
    if (old.state.isLoading && !widget.state.isLoading) {
      _requesting = false;
    }
  }

  @override
  void dispose() {
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_requesting) return;
    if (!widget.state.hasMore) return;
    if (widget.state.isLoading) return;
    if (!_scroll.hasClients) return;
    if (_scroll.position.pixels < _scroll.position.maxScrollExtent - 200) return;

    _requesting = true;
    widget.notifier.loadMore();
  }

  @override
  Widget build(BuildContext context) {
    final state     = widget.state;
    final primary   = widget.primary;
    final secondary = widget.secondary;

    if (state.isLoading && state.items.isEmpty) {
      return Center(
        child: CircularProgressIndicator(
            strokeWidth: 2.5,
            valueColor: AlwaysStoppedAnimation(primary)),
      );
    }

    if (state.error != null && state.items.isEmpty) {
      return MgmtErrorState(
          message: state.error!, onRetry: widget.notifier.refresh);
    }

    if (state.items.isEmpty) {
      return MgmtEmptyState(
        icon:        Icons.science_outlined,
        title:       'Chưa có nguyên liệu',
        subtitle:    'Thêm nguyên liệu đầu tiên để bắt đầu quản lý kho',
        actionLabel: 'Thêm nguyên liệu',
        onAction: () async {
          final ok = await IngredientFormSheet.show(context);
          if (ok) widget.notifier.refresh();
        },
      );
    }

    return RefreshIndicator(
      onRefresh: widget.notifier.refresh,
      color:     primary,
      child: ListView.separated(
        controller:       _scroll,
        padding:          const EdgeInsets.fromLTRB(12, 8, 12, 24),
        itemCount:        state.items.length + (state.hasMore ? 1 : 0),
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (ctx, i) {
          if (i == state.items.length) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation(primary)),
              ),
            );
          }
          return _IngredientCard(
            item:      state.items[i],
            isDark:    widget.isDark,
            primary:   primary,
            secondary: secondary,
          );
        },
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════
// Ingredient card
// ══════════════════════════════════════════════════════════════════

class _IngredientCard extends ConsumerWidget {
  final IngredientModel item;
  final bool isDark;
  final Color primary, secondary;

  const _IngredientCard({
    required this.item,
    required this.isDark,
    required this.primary,
    required this.secondary,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final onBg = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;

    Color  expiryColor = secondary;
    String expiryLabel = '--';
    if (item.expiryDate != null) {
      final exp  = DateTime.fromMillisecondsSinceEpoch(item.expiryDate!);
      final days = exp.difference(DateTime.now()).inDays;
      expiryLabel = fmtDate(item.expiryDate);
      if (days < 0)       expiryColor = AppColors.error;
      else if (days < 30) expiryColor = AppColors.warning;
      else                expiryColor = AppColors.success;
    }

    return MgmtCard(
      padding: const EdgeInsets.all(0),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => InventoryHistoryScreen(ingredient: item)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
        child: Row(children: [
          Container(
            width: 42, height: 42,
            decoration: BoxDecoration(
              color:        primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Icon(Icons.science_outlined, size: 20, color: primary),
            ),
          ),
          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(item.name,
                    style: TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w700, color: onBg),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 3),
                Row(children: [
                  if (item.importDate != null) ...[
                    Icon(Icons.login_rounded, size: 11, color: secondary),
                    const SizedBox(width: 3),
                    Text(fmtDate(item.importDate),
                        style: TextStyle(fontSize: 11, color: secondary)),
                    const SizedBox(width: 10),
                  ],
                  if (item.expiryDate != null) ...[
                    Icon(Icons.schedule_rounded, size: 11, color: expiryColor),
                    const SizedBox(width: 3),
                    Text(expiryLabel,
                        style: TextStyle(
                            fontSize: 11, color: expiryColor,
                            fontWeight: FontWeight.w600)),
                  ],
                ]),
              ],
            ),
          ),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color:        primary.withOpacity(0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: primary.withOpacity(0.2)),
            ),
            child: Column(children: [
              Text(fmtQty(item.stockQuantity),
                  style: TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w800, color: primary)),
              Text(item.unit,
                  style: TextStyle(fontSize: 10, color: secondary)),
            ]),
          ),

          const SizedBox(width: 8),

          Tooltip(
            message: 'Danh sách lô',
            child: GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => IngredientLotScreen(ingredient: item),
                ),
              ),
              child: Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: const Color(0xFF5C6BC0).withOpacity(0.10),
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(
                      color: const Color(0xFF5C6BC0).withOpacity(0.28)),
                ),
                child: const Icon(Icons.layers_rounded,
                    size: 17, color: Color(0xFF5C6BC0)),
              ),
            ),
          ),

          const SizedBox(width: 4),

          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert_rounded, size: 20, color: secondary),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            color: isDark ? AppColors.darkCard : Colors.white,
            onOpened: () {},
            onSelected: (v) async {
              if (v == 'lots') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => IngredientLotScreen(ingredient: item)),
                );
              } else if (v == 'edit') {
                final ok = await IngredientFormSheet.show(
                    context, ingredient: item);
                if (ok) ref.read(ingredientListProvider.notifier).refresh();
              } else if (v == 'delete') {
                final confirm = await confirmDeleteDialog(
                    context, itemName: item.name);
                if (confirm) {
                  final ok = await ref
                      .read(ingredientListProvider.notifier)
                      .delete(item.id);
                  if (!context.mounted) return;
                  if (ok) {
                    showSuccessSnack(context, 'Đã xóa "${item.name}"');
                  } else {
                    showErrorSnack(context, 'Không thể xóa');
                  }
                }
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(                                // ← THÊM item này
                value: 'lots',
                child: Row(children: [
                  Icon(Icons.layers_rounded, size: 16,
                      color: Color(0xFF5C6BC0)),
                  SizedBox(width: 8),
                  Text('Xem lô hàng'),
                ]),
              ),
              PopupMenuItem(
                value: 'edit',
                child: Row(children: [
                  Icon(Icons.edit_outlined, size: 16, color: primary),
                  const SizedBox(width: 8),
                  const Text('Chỉnh sửa'),
                ]),
              ),
              // PopupMenuItem(
              //   value: 'delete',
              //   child: Row(children: [
              //     Icon(Icons.delete_outline, size: 16, color: AppColors.error),
              //     const SizedBox(width: 8),
              //     Text('Xóa', style: TextStyle(color: AppColors.error)),
              //   ]),
              // ),
            ],
          ),
        ]),
      ),
    );
  }
}