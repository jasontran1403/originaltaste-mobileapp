// lib/features/management/screens/management_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/enums/user_role.dart';
import '../../../shared/widgets/management_shared_widgets.dart';
import '../../auth/provider/session_provider.dart';
import '../controller/management_tab_controller.dart';
import '../widgets/category_list_pane.dart';
import '../widgets/ingredient_list_pane.dart';
import '../widgets/product_list_pane.dart';
import 'admin_management_screen.dart';

class ManagementScreen extends ConsumerWidget {
  const ManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final roleAsync = ref.watch(userRoleProvider);

    return roleAsync.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (_, __) => const _SellerManagementScreen(),
      data: (role) => switch (role) {
        UserRole.admin      => const AdminManagementScreen(),
        UserRole.superAdmin => const _SellerManagementScreen(), // giữ nguyên
        _                   => const _SellerManagementScreen(),
      },
    );
  }
}

// ── Seller screen (giữ nguyên như cũ) ────────────────────────────
class _SellerManagementScreen extends ConsumerWidget {
  const _SellerManagementScreen();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tab    = ref.watch(managementTabProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? AppColors.darkCard   : AppColors.lightCard;
    final border = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final bottom = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : AppColors.lightBg,
      body: Column(children: [
        _SellerTabBar(tab: tab, isDark: isDark, border: border, cardBg: cardBg),
        Expanded(
          child: Padding(
            padding: EdgeInsets.fromLTRB(12, 8, 12, 12 + bottom),
            child: Container(
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: border),
                boxShadow: [BoxShadow(
                  color: Colors.black.withOpacity(isDark ? 0.22 : 0.05),
                  blurRadius: 10, offset: const Offset(0, 3),
                )],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(15),
                child: IndexedStack(
                  index: tab.index,
                  children: const [
                    ProductListPane(),
                    IngredientListPane(),
                    CategoryListPane(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}

class _SellerTabBar extends ConsumerWidget {
  final ManagementTab tab;
  final bool isDark;
  final Color border, cardBg;
  const _SellerTabBar({
    required this.tab, required this.isDark,
    required this.border, required this.cardBg,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final secondary = isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 30, 16, 10),
      decoration: BoxDecoration(
        color: cardBg,
        border: Border(bottom: BorderSide(color: border)),
      ),
      child: Row(children: [
        if (!isMobile)
          Expanded(child: Text(
            _subtitle(tab),
            style: TextStyle(fontSize: 12, color: secondary),
          )),
        Expanded(
          child: MgmtTabBar<ManagementTab>(
            selected: tab,
            onSelect: (t) =>
            ref.read(managementTabProvider.notifier).state = t,
            tabs: const [
              MgmtTabItem(value: ManagementTab.product,
                  label: 'Sản phẩm', icon: Icons.storefront_outlined),
              MgmtTabItem(value: ManagementTab.ingredient,
                  label: 'Nguyên liệu', icon: Icons.science_outlined),
              MgmtTabItem(value: ManagementTab.category,
                  label: 'Danh mục', icon: Icons.category_outlined),
            ],
          ),
        ),
      ]),
    );
  }

  String _subtitle(ManagementTab t) => switch (t) {
    ManagementTab.product    => 'Danh sách sản phẩm bán hàng',
    ManagementTab.ingredient => 'Quản lý kho nguyên liệu',
    ManagementTab.category   => 'Phân loại sản phẩm',
  };
}