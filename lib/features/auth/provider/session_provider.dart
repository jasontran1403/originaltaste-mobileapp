// lib/features/auth/providers/session_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/enums/user_role.dart';
import '../../../data/storage/session_storage.dart';

final userRoleProvider = FutureProvider<UserRole?>((ref) async {
  final roleStr = await SessionStorage.getRole();
  return UserRole.fromString(roleStr);
});