// lib/data/models/general/auth_model.dart

class AuthModel {
  final int    userId;
  final String fullName;
  final bool   isLock;
  final String role;
  final String accessToken;

  const AuthModel({
    required this.userId,
    required this.fullName,
    required this.isLock,
    required this.role,
    required this.accessToken,
  });

  factory AuthModel.fromJson(Map<String, dynamic> json) => AuthModel(
    userId:      json['userId']      as int?    ?? 0,
    fullName:    json['fullName']    as String? ?? '',
    isLock:      json['isLock']      as bool?   ?? false,
    role:        json['role']        as String? ?? '',
    accessToken: json['accessToken'] as String? ?? '',
  );
}
