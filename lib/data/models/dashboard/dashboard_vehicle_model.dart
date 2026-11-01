// lib/data/models/dashboard/dashboard_vehicle_model.dart

class PosVehicle {
  final int     id;
  final String  name;
  final String? avatarUrl;
  final String? address;
  final String? phone;
  final int?    storeId;

  const PosVehicle({
    required this.id,
    required this.name,
    this.avatarUrl,
    this.address,
    this.phone,
    this.storeId,
  });

  factory PosVehicle.fromJson(Map<String, dynamic> j) => PosVehicle(
    id:        j['id']        ?? 0,
    name:      j['name']      ?? '',
    avatarUrl: j['avatarUrl'] as String?,
    address:   j['address']   as String?,
    phone:     j['phone']     as String?,
    storeId:   j['storeId']   as int?,
  );
}