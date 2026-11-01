// lib/features/management/controller/management_tab_controller.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';

enum ManagementTab { product, ingredient, category }

enum AdminManagementTab { store, menu, ingredient, category }

final managementTabProvider =
StateProvider<ManagementTab>((ref) => ManagementTab.product);

final adminManagementTabProvider =
StateProvider<AdminManagementTab>((ref) => AdminManagementTab.store);