// lib/shared/layouts/main_layout.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/enums/nav_item.dart';
import '../../core/enums/user_role.dart';
import '../../features/auth/controller/auth_controller.dart';
import '../widgets/app_navbar.dart';

class MainLayout extends ConsumerWidget {
  final Widget child;

  const MainLayout({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);
    final role = authState.role ?? UserRole.pos;
    final navItems = role.navItems;

    // Xác định tab đang active từ current route
    final location = GoRouterState.of(context).uri.path;
    final selected = _routeToNavItem(location, navItems);

    return Scaffold(
      body: child,
      extendBody: true, // content đằng sau navbar
      bottomNavigationBar: AppNavbar(
        items: navItems,
        selected: selected,
        onTap: (item) => context.go(item.route),
      ),
    );
  }

  NavItem _routeToNavItem(String route, List<NavItem> items) {
    // Sort by route length descending — longest match wins
    // Prevents '/pos' from matching '/pos-management' or '/pos-history'
    final sorted = [...items]..sort((a, b) => b.route.length.compareTo(a.route.length));
    for (final item in sorted) {
      if (route.startsWith(item.route)) return item;
    }
    return items.first;
  }
}