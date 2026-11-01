// lib/core/enums/nav_item.dart — thêm posCustomers

import 'package:flutter/material.dart';
import 'user_role.dart';

enum NavItem {
  dashboard,
  order,
  management,
  customer,
  history,
  settings,
  pos,
  posManagement,
  posCustomers,   // ← THÊM
  posHistory;

  String get label => switch (this) {
    NavItem.dashboard     => 'Dashboard',
    NavItem.order         => 'Order',
    NavItem.customer      => 'Customer',
    NavItem.management    => 'Management',
    NavItem.history       => 'History',
    NavItem.settings      => 'Settings',
    NavItem.pos           => 'Bán hàng',
    NavItem.posManagement => 'Menu',
    NavItem.posCustomers  => 'Khách hàng',  // ← THÊM
    NavItem.posHistory    => 'Lịch sử',
  };

  IconData get icon => switch (this) {
    NavItem.dashboard     => Icons.home_rounded,
    NavItem.order         => Icons.receipt_long_rounded,
    NavItem.management    => Icons.business_center_rounded,
    NavItem.customer      => Icons.people_rounded,
    NavItem.history       => Icons.history_rounded,
    NavItem.settings      => Icons.settings_rounded,
    NavItem.pos           => Icons.point_of_sale_rounded,
    NavItem.posManagement => Icons.menu_book_rounded,
    NavItem.posCustomers  => Icons.people_alt_rounded,   // ← THÊM
    NavItem.posHistory    => Icons.history_rounded,
  };

  String get route => switch (this) {
    NavItem.dashboard     => '/dashboard',
    NavItem.order         => '/order',
    NavItem.customer      => '/customer',
    NavItem.management    => '/management',
    NavItem.history       => '/history',
    NavItem.settings      => '/settings',
    NavItem.pos           => '/pos',
    NavItem.posManagement => '/pos-management',
    NavItem.posCustomers  => '/pos/customers',  // ← THÊM
    NavItem.posHistory    => '/pos-history',
  };
}

extension RoleNavItems on UserRole {
  List<NavItem> get navItems => switch (this) {
    UserRole.superAdmin => [
      NavItem.dashboard,
      NavItem.management,
      NavItem.customer,
      NavItem.history,
      NavItem.settings,
    ],
    UserRole.admin => [
      NavItem.dashboard,
      NavItem.management,
      NavItem.customer,
      NavItem.history,
      NavItem.settings,
    ],
    UserRole.seller => [
      NavItem.order,
      NavItem.management,
      NavItem.customer,
      NavItem.history,
      NavItem.settings,
    ],
    UserRole.pos => [
      NavItem.pos,
      NavItem.posManagement,
      NavItem.posCustomers,
      NavItem.posHistory,
      NavItem.settings,
    ],
    UserRole.accountant => [   // ← THÊM
      NavItem.dashboard,
      NavItem.history,
      NavItem.settings,
    ],
    UserRole.warehouse => [    // ← THÊM
      NavItem.dashboard,
      NavItem.management,
      NavItem.settings,
    ],
    UserRole.shipper => [      // ← THÊM
      NavItem.order,
      NavItem.history,
      NavItem.settings,
    ],
  };

  NavItem get defaultNav => navItems.first;

  String get homeRoute => defaultNav.route;
}