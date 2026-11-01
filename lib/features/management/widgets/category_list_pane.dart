// lib/features/management/widgets/category_list_pane.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../data/models/management/management_models.dart';
import '../../../shared/widgets/management_shared_widgets.dart';
import '../../../shared/widgets/network_image_viewer.dart';
import '../controller/category_controller.dart';
import 'category_form_sheet.dart';

class CategoryListPane extends ConsumerWidget {
  const CategoryListPane({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state    = ref.watch(categoryListProvider);
    final notifier = ref.read(categoryListProvider.notifier);
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
            child: Icon(Icons.category_outlined, size: 18, color: primary),
          ),
          const SizedBox(width: 10),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Danh mục',
                style: TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w800,
                    color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary)),
            Text('${state.items.length} mục',
                style: TextStyle(fontSize: 11, color: secondary)),
          ]),
          const Spacer(),
          GestureDetector(
            onTap: () async {
              final ok = await CategoryFormSheet.show(context);
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
        child: _buildBody(context, ref, state, notifier, isDark, primary, secondary, border),
      ),
    ]);
  }

  Widget _buildBody(
      BuildContext context,
      WidgetRef ref,
      CategoryListState state,
      CategoryListNotifier notifier,
      bool isDark,
      Color primary,
      Color secondary,
      Color border,
      ) {
    if (state.isLoading && state.items.isEmpty) {
      return Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation(primary)));
    }

    if (state.error != null && state.items.isEmpty) {
      return MgmtErrorState(message: state.error!, onRetry: notifier.refresh);
    }

    if (state.items.isEmpty) {
      return MgmtEmptyState(
        icon:        Icons.category_outlined,
        title:       'Chưa có danh mục',
        subtitle:    'Thêm danh mục đầu tiên để phân loại sản phẩm',
        actionLabel: 'Thêm danh mục',
        onAction: () async {
          final ok = await CategoryFormSheet.show(context);
          if (ok) notifier.refresh();
        },
      );
    }

    return RefreshIndicator(
      onRefresh: notifier.refresh,
      color:     primary,
      child: ListView.builder(
        padding: EdgeInsets.fromLTRB(12, 8, 12, 12 + MediaQuery.of(context).padding.bottom),
        itemCount: state.items.length,
        itemBuilder: (_, i) => _CategoryItem(
          item:      state.items[i],
          isDark:    isDark,
          primary:   primary,
          secondary: secondary,
          border:    border,
          onEdit:    () async {
            final ok = await CategoryFormSheet.show(context, category: state.items[i]);
            if (ok) notifier.refresh();
          },
          onDelete:  () async {
            final confirm = await confirmDeleteDialog(context, itemName: state.items[i].name);
            if (confirm) {
              final ok = await notifier.delete(state.items[i].id);
              if (!context.mounted) return;
              if (ok) showSuccessSnack(context, 'Đã xóa "${state.items[i].name}"');
              else showErrorSnack(context, 'Không thể xóa');
            }
          },
        ),
      ),
    );
  }
}

// ── Category Item (giống Product Item) ────────────────────────────────────────
class _CategoryItem extends StatelessWidget {
  final MgmtCategoryModel item;
  final bool isDark;
  final Color primary, secondary, border;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _CategoryItem({
    required this.item,
    required this.isDark,
    required this.primary,
    required this.secondary,
    required this.border,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final cardBg = isDark ? AppColors.darkCard : AppColors.lightCard;
    final onBg   = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;

    return MgmtCard(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        // Ảnh danh mục (vuông nhỏ)
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: SizedBox(
            width:  70,
            height: 70,
            child: item.imageUrl != null && item.imageUrl!.isNotEmpty
                ? NetworkImageViewer(
              imageUrl: item.imageUrl!,
              fit: BoxFit.cover,
              placeholder: Container(
                color: primary.withOpacity(0.06),
                child: Center(
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation(primary),
                  ),
                ),
              ),
              errorWidget: _buildNoImage(primary),
            )
                : _buildNoImage(primary),
          ),
        ),

        const SizedBox(width: 12),

        // Thông tin danh mục (chỉ tên, không trạng thái)
        Expanded(
          child: Text(
            item.name,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: onBg,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),

        // Nút more options
        PopupMenuButton<String>(
          icon: Icon(Icons.more_vert_rounded, size: 20, color: secondary),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          color: isDark ? AppColors.darkCard : Colors.white,
          onSelected: (v) {
            if (v == 'edit') onEdit();
            if (v == 'delete') onDelete();
          },
          itemBuilder: (_) => [
            PopupMenuItem(
              value: 'edit',
              child: Row(children: [
                Icon(Icons.edit_outlined, size: 18, color: primary),
                const SizedBox(width: 10),
                const Text('Chỉnh sửa'),
              ]),
            ),
            PopupMenuItem(
              value: 'delete',
              child: Row(children: [
                Icon(Icons.delete_outline, size: 18, color: AppColors.error),
                const SizedBox(width: 10),
                Text('Xóa', style: TextStyle(color: AppColors.error)),
              ]),
            ),
          ],
        ),
      ]),
    );
  }

  Widget _buildNoImage(Color primary) => Container(
    color: primary.withOpacity(0.06),
    child: Center(
      child: Icon(
        Icons.category_outlined,
        size: 32,
        color: primary.withOpacity(0.4),
      ),
    ),
  );
}