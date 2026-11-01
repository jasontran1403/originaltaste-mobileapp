// lib/app/router/app_router.dart — thêm route /pos/customers

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:originaltaste/features/customer/screens/customer_screen.dart';
import 'package:originaltaste/features/order/screens/order_detail_screen.dart';
import 'package:originaltaste/features/order/screens/order_history_screen.dart';
import 'package:originaltaste/features/pos/screens/pos_customer_management_screen.dart';  // ← THÊM
import '../../core/enums/user_role.dart';
import '../../data/models/pos/pos_shift_model.dart';
import '../../features/auth/screens/intro_screen.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/welcome_screen.dart';
import '../../features/pos/screens/pos_shift_screen.dart';
import '../../shared/layouts/main_layout.dart';
import '../../features/dashboard/screens/dashboard_screen.dart';
import '../../features/order/screens/order_screen.dart';
import '../../features/management/screens/management_screen.dart';
import '../../features/settings/screens/settings_screen.dart';
import '../../features/pos/screens/pos_screen.dart';
import '../../features/pos/screens/pos_history_screen.dart';
import '../../features/pos/screens/pos_menu_screen.dart';

/// Navigator key gốc — dùng để lấy BuildContext toàn cục (hiện toast hết
/// phiên từ tầng network) và điều hướng về /login khi không có context sẵn.
final rootNavigatorKey = GlobalKey<NavigatorState>();

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/intro',
    debugLogDiagnostics: false,
    routes: [
      GoRoute(path: '/intro', builder: (_, __) => const IntroScreen()),
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(
        path: '/welcome',
        builder: (context, state) {
          final role = state.extra as UserRole? ?? UserRole.pos;
          return WelcomeScreen(role: role);
        },
      ),
      ShellRoute(
        builder: (context, state, child) => MainLayout(child: child),
        routes: [
          GoRoute(path: '/dashboard',
              pageBuilder: (c, s) => _fadePage(c, s, const DashboardScreen())),
          GoRoute(path: '/order',
              pageBuilder: (c, s) => _fadePage(c, s, const OrderScreen())),
          GoRoute(path: '/order-detail/:id',
            pageBuilder: (context, state) {
              final id = int.tryParse(state.pathParameters['id'] ?? '0') ?? 0;
              return _fadePage(context, state, OrderDetailScreen(orderId: id));
            },
          ),
          GoRoute(path: '/management',
              pageBuilder: (c, s) => _fadePage(c, s, const ManagementScreen())),
          GoRoute(path: '/customer',
              pageBuilder: (c, s) => _fadePage(c, s, const CustomerScreen())),
          GoRoute(path: '/history',
              pageBuilder: (c, s) => _fadePage(c, s, const OrderHistoryScreen())),
          GoRoute(path: '/settings',
              pageBuilder: (c, s) => _fadePage(c, s, const SettingsScreen())),
          // ── POS ────────────────────────────────────────────────
          GoRoute(path: '/pos',
              pageBuilder: (c, s) => _fadePage(c, s, const PosScreen())),
          GoRoute(
            path: '/pos-shift',
            pageBuilder: (context, state) {
              final currentShift = state.extra as PosShiftModel?;
              return _fadePage(context, state,
                PosShiftScreen(
                  currentShift: currentShift,
                  onShiftChanged: (shift) {},
                ),
              );
            },
          ),
          GoRoute(path: '/pos-management',
              pageBuilder: (c, s) => _fadePage(c, s, const PosMenuScreen())),
          GoRoute(path: '/pos-history',
              pageBuilder: (c, s) => _fadePage(c, s, const PosHistoryScreen())),
          // ── POS Customers ─────────────────────────────────────
          GoRoute(
            path: '/pos/customers',                                         // ← THÊM
            pageBuilder: (c, s) => _fadePage(c, s,
                const PosCustomerManagementScreen()),
          ),
        ],
      ),
    ],
  );
});

CustomTransitionPage _fadePage(
    BuildContext context, GoRouterState state, Widget child) {
  return CustomTransitionPage(
    key: state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 200),
    transitionsBuilder: (_, animation, __, child) =>
        FadeTransition(opacity: animation, child: child),
  );
}