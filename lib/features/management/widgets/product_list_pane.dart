// lib/features/management/widgets/product_list_pane.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/app_colors.dart';
import '../../../data/models/management/management_models.dart';
import '../../../shared/widgets/management_shared_widgets.dart';
import '../../../shared/widgets/network_image_viewer.dart';
import '../controller/product_controller.dart';
import 'product_form_sheet.dart';

class ProductListPane extends ConsumerWidget {
  const ProductListPane({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state    = ref.watch(productListProvider);
    final notifier = ref.read(productListProvider.notifier);
    final isDark   = Theme.of(context).brightness == Brightness.dark;
    final primary  = isDark ? AppColors.primary : AppColors.primaryDark;
    final secondary = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final border   = isDark ? AppColors.darkBorder : AppColors.lightBorder;

    return Column(children: [
      // ── Header ─────────────────────────────────────────────
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 12, 10),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color:        primary.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.storefront_outlined, size: 18, color: primary),
          ),
          const SizedBox(width: 10),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Sản phẩm',
                style: TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w800,
                    color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary)),
            Text('${state.items.length} sản phẩm',
                style: TextStyle(fontSize: 11, color: secondary)),
          ]),
          const Spacer(),
          GestureDetector(
            onTap: () async {
              final ok = await ProductFormSheet.show(context);
              if (ok) notifier.refresh();
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color:        primary,
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                      color:      primary.withOpacity(0.35),
                      blurRadius: 6,
                      offset:     const Offset(0, 2))
                ],
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.add_rounded, size: 16, color: Colors.white),
                const SizedBox(width: 5),
                const Text('Thêm',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Colors.white)),
              ]),
            ),
          ),
        ]),
      ),

      Divider(height: 1, color: border),

      // ── Body ───────────────────────────────────────────────
      Expanded(
        child: _buildBody(context, ref, state, notifier,
            isDark, primary, secondary),
      ),
    ]);
  }

  Widget _buildBody(
      BuildContext context, WidgetRef ref,
      ProductListState state, ProductListNotifier notifier,
      bool isDark, Color primary, Color secondary) {
    if (state.isLoading && state.items.isEmpty) {
      return Center(
        child: CircularProgressIndicator(
            strokeWidth: 2.5,
            valueColor: AlwaysStoppedAnimation(primary)),
      );
    }

    if (state.error != null && state.items.isEmpty) {
      return MgmtErrorState(message: state.error!, onRetry: notifier.refresh);
    }

    if (state.items.isEmpty) {
      return MgmtEmptyState(
        icon:        Icons.storefront_outlined,
        title:       'Chưa có sản phẩm',
        subtitle:    'Thêm sản phẩm đầu tiên để bắt đầu bán hàng',
        actionLabel: 'Thêm sản phẩm',
        onAction: () async {
          final ok = await ProductFormSheet.show(context);
          if (ok) notifier.refresh();
        },
      );
    }

    return RefreshIndicator(
      onRefresh: notifier.refresh,
      color:     primary,
      child: ListView.separated(
        padding: EdgeInsets.fromLTRB(
            12, 8, 12, 12 + MediaQuery.of(context).padding.bottom),
        itemCount: state.items.length + (state.hasMore ? 1 : 0),
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (ctx, i) {
          if (i == state.items.length) {
            WidgetsBinding.instance
                .addPostFrameCallback((_) => notifier.loadMore());
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation(primary)),
              ),
            );
          }
          return _ProductCard(
            item:      state.items[i],
            isDark:    isDark,
            primary:   primary,
            secondary: secondary,
          );
        },
      ),
    );
  }
}

// ── Product card ──────────────────────────────────────────────────

class _ProductCard extends ConsumerWidget {
  final MgmtProductModel item;
  final bool isDark;
  final Color primary, secondary;

  const _ProductCard({
    required this.item,
    required this.isDark,
    required this.primary,
    required this.secondary,
  });

  static final _fmt =
  NumberFormat.currency(locale: 'vi_VN', symbol: '₫', decimalDigits: 0);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final onBg = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;

    return MgmtCard(
      padding: const EdgeInsets.all(0),
      child: Row(children: [
        // ── Thumbnail ────────────────────────────────────────
        ClipRRect(
          borderRadius: const BorderRadius.horizontal(
              left: Radius.circular(14)),
          child: SizedBox(
            width: 80, height: 80,
            child: item.imageUrl != null && item.imageUrl!.isNotEmpty
                ?
            NetworkImageViewer(
              imageUrl: item.imageUrl!,
              fit: BoxFit.cover,
              // Placeholder tùy chỉnh giống cũ
              placeholder: Container(
                color: primary.withOpacity(0.06),
                child: Center(
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation(primary),
                  ),
                ),
              ),
              // Error widget tùy chỉnh (giống _noImage())
              errorWidget: _noImage(),
            )
                : _noImage(),
          ),
        ),

        const SizedBox(width: 12),

        // ── Info ─────────────────────────────────────────────
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(item.name,
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: onBg),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 3),
                Text(_fmt.format(item.price),
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: primary)),
                const SizedBox(height: 4),
                Row(children: [
                  if (item.categoryName != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color:        primary.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(item.categoryName!,
                          style: TextStyle(
                              fontSize: 10,
                              color: primary,
                              fontWeight: FontWeight.w600)),
                    ),
                    const SizedBox(width: 6),
                  ],
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: (item.isAvailable
                          ? AppColors.success
                          : AppColors.error)
                          .withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      item.isAvailable ? 'Đang bán' : 'Ngừng bán',
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: item.isAvailable
                              ? AppColors.success
                              : AppColors.error),
                    ),
                  ),
                ]),
              ],
            ),
          ),
        ),

        // ── Actions ──────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.only(right: 4),
          child: PopupMenuButton<String>(
            icon: Icon(Icons.more_vert_rounded,
                size: 20, color: secondary),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            color: isDark ? AppColors.darkCard : Colors.white,
            onSelected: (v) async {
              if (v == 'edit') {
                final ok = await ProductFormSheet.show(
                    context, product: item);
                if (ok) {
                  ref.read(productListProvider.notifier).refresh();
                }
              } else if (v == 'delete') {
                final confirm = await confirmDeleteDialog(
                    context, itemName: item.name);
                if (confirm) {
                  final ok = await ref
                      .read(productListProvider.notifier)
                      .delete(item.id);
                  if (!context.mounted) return;
                  if (ok)
                    showSuccessSnack(context, 'Đã xóa "${item.name}"');
                  else
                    showErrorSnack(context, 'Không thể xóa');
                }
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'edit',
                child: Row(children: [
                  Icon(Icons.edit_outlined,
                      size: 16, color: primary),
                  const SizedBox(width: 8),
                  const Text('Chỉnh sửa'),
                ]),
              ),
              PopupMenuItem(
                value: 'delete',
                child: Row(children: [
                  Icon(Icons.delete_outline,
                      size: 16, color: AppColors.error),
                  const SizedBox(width: 8),
                  Text('Xóa',
                      style: TextStyle(color: AppColors.error)),
                ]),
              ),
            ],
          ),
        ),
      ]),
    );
  }

  Widget _noImage() => Container(
    color: primary.withOpacity(0.06),
    child: Center(
      child: Icon(Icons.image_outlined,
          size: 28, color: primary.withOpacity(0.3)),
    ),
  );
}