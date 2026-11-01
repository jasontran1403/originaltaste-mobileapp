// lib/data/models/pos/pos_shift_model.dart

class PosShiftModel {
  final int    id;
  final String staffName;
  final String status;
  final String shiftDate;
  final bool   isFirstShiftOfDay;
  final int    openTime;
  final int?   closeTime;
  final double? openingCash;
  final double? closingCash;
  final double? transferAmount;
  final String? note;
  final List<Map<String, dynamic>> openDenominations;
  final List<Map<String, dynamic>> closeDenominations;
  final List<Map<String, dynamic>> openInventory;
  final List<Map<String, dynamic>> closeInventory;
  final int    totalOrders;
  final double totalRevenue;
  final double offlineRevenue;

  // ─── Store / Reopen info ───
  final int?   storeId;
  final int?   reopenedAt;
  final int?   reopenedBy;
  final int    reopenCount;

  const PosShiftModel({
    required this.id,
    required this.staffName,
    required this.status,
    required this.shiftDate,
    required this.isFirstShiftOfDay,
    required this.openTime,
    this.closeTime,
    this.openingCash,
    this.closingCash,
    this.transferAmount,
    this.note,
    required this.openDenominations,
    required this.closeDenominations,
    required this.openInventory,
    required this.closeInventory,
    required this.totalOrders,
    required this.totalRevenue,
    this.offlineRevenue = 0.0,
    this.storeId,
    this.reopenedAt,
    this.reopenedBy,
    this.reopenCount = 0,
  });

  bool get isOpen   => status == 'OPEN';
  bool get isClosed => status == 'CLOSED';

  /// Ca có thuộc ngày hôm nay (so sánh theo shiftDate yyyy-MM-dd).
  bool get isToday {
    final today = DateTime.now();
    final todayStr =
        '${today.year.toString().padLeft(4, '0')}-'
        '${today.month.toString().padLeft(2, '0')}-'
        '${today.day.toString().padLeft(2, '0')}';
    return shiftDate == todayStr;
  }

  factory PosShiftModel.fromJson(Map<String, dynamic> j) => PosShiftModel(
    id:                j['id'] as int,
    staffName:         j['staffName'] as String,
    status:            j['status'] as String,
    shiftDate:         j['shiftDate'] as String,
    isFirstShiftOfDay: j['isFirstShiftOfDay'] as bool? ?? false,
    openTime:          j['openTime'] as int? ?? 0,
    closeTime:         j['closeTime'] as int?,
    openingCash:       (j['openingCash'] as num?)?.toDouble(),
    closingCash:       (j['closingCash'] as num?)?.toDouble(),
    transferAmount:    (j['transferAmount'] as num?)?.toDouble(),
    note:              j['note'] as String?,
    openDenominations:  _toMapList(j['openDenominations']),
    closeDenominations: _toMapList(j['closeDenominations']),
    openInventory:      _toMapList(j['openInventory']),
    closeInventory:     _toMapList(j['closeInventory']),
    totalOrders:    j['totalOrders'] as int? ?? 0,
    totalRevenue:   (j['totalRevenue'] as num?)?.toDouble() ?? 0.0,
    offlineRevenue: (j['offlineRevenue'] as num?)?.toDouble() ?? 0.0,
    storeId:        j['storeId'] as int?,
    reopenedAt:     j['reopenedAt'] as int?,
    reopenedBy:     j['reopenedBy'] as int?,
    reopenCount:    j['reopenCount'] as int? ?? 0,
  );

  static List<Map<String, dynamic>> _toMapList(dynamic raw) =>
      (raw as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
}