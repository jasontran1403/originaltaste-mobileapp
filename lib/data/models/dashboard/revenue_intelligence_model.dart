// lib/data/models/dashboard/revenue_intelligence_model.dart

class RevenueIntelligenceConfig {
  final int shortWindow;
  final int longWindow;
  final double alpha;
  final double normalThreshold;
  final double alertThreshold;
  final String modelVersion;

  const RevenueIntelligenceConfig({
    this.shortWindow = 7,
    this.longWindow = 28,
    this.alpha = 0.5,
    this.normalThreshold = 0.05,
    this.alertThreshold = 0.15,
    this.modelVersion = 'RI_BASELINE_V1',
  });

  factory RevenueIntelligenceConfig.fromJson(Map<String, dynamic> json) {
    return RevenueIntelligenceConfig(
      shortWindow: (json['shortWindow'] as num?)?.toInt() ?? 7,
      longWindow: (json['longWindow'] as num?)?.toInt() ?? 28,
      alpha: (json['alpha'] as num?)?.toDouble() ?? 0.5,
      normalThreshold: (json['normalThreshold'] as num?)?.toDouble() ?? 0.05,
      alertThreshold: (json['alertThreshold'] as num?)?.toDouble() ?? 0.15,
      modelVersion: json['modelVersion'] as String? ?? 'RI_BASELINE_V1',
    );
  }
}

class RevenueIntelligenceSnapshot {
  final String date;
  final String dateLabel;
  final double actualRevenue;
  final double ma7;
  final double ma28;
  final double alpha;
  final double expectedRevenue;
  final double lower15;
  final double lower5;
  final double upper5;
  final double upper15;
  final double deviationPct;
  final String classification;
  final int consecutiveAbnormalDays;
  final String? abnormalDirection;
  final String modelVersion;
  final bool partial;           // true = ngày chưa chốt (hôm nay)

  const RevenueIntelligenceSnapshot({
    required this.date,
    required this.dateLabel,
    required this.actualRevenue,
    required this.ma7,
    required this.ma28,
    required this.alpha,
    required this.expectedRevenue,
    required this.lower15,
    required this.lower5,
    required this.upper5,
    required this.upper15,
    required this.deviationPct,
    required this.classification,
    required this.consecutiveAbnormalDays,
    this.abnormalDirection,
    required this.modelVersion,
    this.partial = false,
  });

  factory RevenueIntelligenceSnapshot.fromJson(Map<String, dynamic> json) {
    return RevenueIntelligenceSnapshot(
      date: json['date'] as String? ?? '',
      dateLabel: json['dateLabel'] as String? ?? '',
      actualRevenue: (json['actualRevenue'] as num?)?.toDouble() ?? 0,
      ma7: (json['ma7'] as num?)?.toDouble() ?? 0,
      ma28: (json['ma28'] as num?)?.toDouble() ?? 0,
      alpha: (json['alpha'] as num?)?.toDouble() ?? 0.5,
      expectedRevenue: (json['expectedRevenue'] as num?)?.toDouble() ?? 0,
      lower15: (json['lower15'] as num?)?.toDouble() ?? 0,
      lower5: (json['lower5'] as num?)?.toDouble() ?? 0,
      upper5: (json['upper5'] as num?)?.toDouble() ?? 0,
      upper15: (json['upper15'] as num?)?.toDouble() ?? 0,
      deviationPct: (json['deviationPct'] as num?)?.toDouble() ?? 0,
      classification: json['classification'] as String? ?? 'NORMAL',
      consecutiveAbnormalDays: (json['consecutiveAbnormalDays'] as num?)?.toInt() ?? 0,
      abnormalDirection: json['abnormalDirection'] as String?,
      modelVersion: json['modelVersion'] as String? ?? '',
      partial: json['partial'] as bool? ?? false,
    );
  }
}

class RevenueIntelligenceResponse {
  final RevenueIntelligenceConfig config;
  final List<RevenueIntelligenceSnapshot> snapshots;
  final int totalDays;
  final int normalDays;
  final int alertLowDays;
  final int strongOutperformanceDays;

  const RevenueIntelligenceResponse({
    required this.config,
    required this.snapshots,
    required this.totalDays,
    required this.normalDays,
    required this.alertLowDays,
    required this.strongOutperformanceDays,
  });

  factory RevenueIntelligenceResponse.fromJson(Map<String, dynamic> json) {
    return RevenueIntelligenceResponse(
      config: json['config'] != null
          ? RevenueIntelligenceConfig.fromJson(json['config'] as Map<String, dynamic>)
          : const RevenueIntelligenceConfig(),
      snapshots: (json['snapshots'] as List<dynamic>?)
          ?.map((e) => RevenueIntelligenceSnapshot.fromJson(e as Map<String, dynamic>))
          .toList() ??
          [],
      totalDays: (json['totalDays'] as num?)?.toInt() ?? 0,
      normalDays: (json['normalDays'] as num?)?.toInt() ?? 0,
      alertLowDays: (json['alertLowDays'] as num?)?.toInt() ?? 0,
      strongOutperformanceDays: (json['strongOutperformanceDays'] as num?)?.toInt() ?? 0,
    );
  }
}