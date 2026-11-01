// lib/core/enums/user_role.dart

enum UserRole {
  superAdmin,
  admin,
  seller,
  pos,
  accountant,
  warehouse,  // ← THÊM
  shipper;    // ← THÊM

  static UserRole? fromString(String? value) {
    if (value == null) return null;
    return switch (value.toUpperCase().trim()) {
      'SUPERADMIN' => UserRole.superAdmin,
      'ADMIN'      => UserRole.admin,
      'SELLER'     => UserRole.seller,
      'POS'        => UserRole.pos,
      'ACCOUNTANT'  => UserRole.accountant,  // ← THÊM
      'WAREHOUSE'  => UserRole.warehouse,  // ← THÊM
      'SHIPPER'    => UserRole.shipper,    // ← THÊM
      _            => null,
    };
  }

  String get rawValue => switch (this) {
    UserRole.superAdmin => 'SUPERADMIN',
    UserRole.admin      => 'ADMIN',
    UserRole.seller     => 'SELLER',
    UserRole.pos        => 'POS',
    UserRole.accountant => 'ACCOUNTANT',
    UserRole.warehouse  => 'WAREHOUSE',  // ← THÊM
    UserRole.shipper    => 'SHIPPER',    // ← THÊM
  };
}