// lib/data/models/dashboard/rolling_performance_model.dart
//
// Model cho nhóm "Rolling Performance" (cửa sổ trượt 7 / 28 / 30 ngày).
// Map từ endpoint: GET /api/superadmin/dashboard/pos/rolling

double _d(dynamic v) {
  if (v == null) return 0;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString()) ?? 0;
}

int _i(dynamic v) {
  if (v == null) return 0;
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse(v.toString()) ?? 0;
}

double? _dn(dynamic v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString());
}

Map<String, dynamic> _m(dynamic v) =>
    v is Map<String, dynamic> ? v : <String, dynamic>{};

// ── 4 chỉ số của 1 kỳ ────────────────────────────────────────────
class RollingMetrics {
  final double revenue;
  final int    orders;
  final int    products;
  final double aov;

  const RollingMetrics({
    this.revenue   = 0,
    this.orders    = 0,
    this.products  = 0,
    this.aov       = 0,
  });

  factory RollingMetrics.fromJson(Map<String, dynamic> j) => RollingMetrics(
    revenue:   _d(j['revenue']),
    orders:    _i(j['orders']),
    products:  _i(j['products']),
    aov:       _d(j['aov']),
  );
}

// ── % thay đổi so với kỳ liền trước (null = kỳ trước = 0, không xác định) ──
class RollingDeltaPct {
  final double? revenue;
  final double? orders;
  final double? products;
  final double? aov;

  const RollingDeltaPct({
    this.revenue,
    this.orders,
    this.products,
    this.aov,
  });

  factory RollingDeltaPct.fromJson(Map<String, dynamic> j) => RollingDeltaPct(
    revenue:   _dn(j['revenue']),
    orders:    _dn(j['orders']),
    products:  _dn(j['products']),
    aov:       _dn(j['aov']),
  );
}

// ── 1 điểm rolling theo ngày (giá trị rolling tại ngày kết thúc) ──
class RollingPoint {
  final String date;   // yyyy-MM-dd
  final int    ts;
  final double revenue;
  final int    orders;
  final int    products;
  final double aov;

  const RollingPoint({
    required this.date,
    this.ts        = 0,
    this.revenue   = 0,
    this.orders    = 0,
    this.products  = 0,
    this.aov       = 0,
  });

  factory RollingPoint.fromJson(Map<String, dynamic> j) => RollingPoint(
    date:      j['date']?.toString() ?? '',
    ts:        _i(j['ts']),
    revenue:   _d(j['revenue']),
    orders:    _i(j['orders']),
    products:  _i(j['products']),
    aov:       _d(j['aov']),
  );

  // Nhãn ngắn để hiển thị trục X: dd/MM
  String get shortLabel {
    final parts = date.split('-');
    if (parts.length == 3) return '${parts[2]}/${parts[1]}';
    return date;
  }
}

// ── Top-level ────────────────────────────────────────────────────
class RollingPerformanceModel {
  final int              window;    // 7 | 28 | 30
  final RollingMetrics   current;
  final RollingMetrics   previous;
  final RollingDeltaPct  deltaPct;
  final List<RollingPoint> series;

  const RollingPerformanceModel({
    required this.window,
    required this.current,
    required this.previous,
    required this.deltaPct,
    this.series = const [],
  });

  factory RollingPerformanceModel.fromJson(Map<String, dynamic> j) =>
      RollingPerformanceModel(
        window:   _i(j['window']),
        current:  RollingMetrics.fromJson(_m(j['current'])),
        previous: RollingMetrics.fromJson(_m(j['previous'])),
        deltaPct: RollingDeltaPct.fromJson(_m(j['deltaPct'])),
        series: ((j['series'] as List?) ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(RollingPoint.fromJson)
            .toList(),
      );
}