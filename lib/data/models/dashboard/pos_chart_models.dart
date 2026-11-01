// lib/data/models/dashboard/pos_chart_models.dart

class PeriodShiftPoint {
  final String periodLabel;
  final int    periodFromTs;
  final int    periodToTs;
  final int    shift;
  final String shiftLabel;
  final double revenue;
  final double orderCount;

  const PeriodShiftPoint({
    required this.periodLabel,
    required this.periodFromTs,
    required this.periodToTs,
    required this.shift,
    required this.shiftLabel,
    required this.revenue,
    required this.orderCount,
  });

  factory PeriodShiftPoint.fromJson(Map<String, dynamic> j) => PeriodShiftPoint(
    periodLabel:  j['periodLabel']  as String,
    periodFromTs: (j['periodFromTs'] as num).toInt(),
    periodToTs:   (j['periodToTs']   as num).toInt(),
    shift:        (j['shift']        as num).toInt(),
    shiftLabel:   j['shiftLabel']   as String,
    revenue:      (j['revenue']      as num).toDouble(),
    orderCount:   (j['orderCount']   as num).toDouble(),
  );
}

class PeriodStackedPoint {
  final String periodLabel;
  final int    periodFromTs;
  final int    periodToTs;
  final String groupKey;
  final String groupType;
  final double revenue;
  final double orderCount;

  const PeriodStackedPoint({
    required this.periodLabel,
    required this.periodFromTs,
    required this.periodToTs,
    required this.groupKey,
    required this.groupType,
    required this.revenue,
    required this.orderCount,
  });

  factory PeriodStackedPoint.fromJson(Map<String, dynamic> j) => PeriodStackedPoint(
    periodLabel:  j['periodLabel']  as String,
    periodFromTs: (j['periodFromTs'] as num).toInt(),
    periodToTs:   (j['periodToTs']   as num).toInt(),
    groupKey:     j['groupKey']     as String,
    groupType:    j['groupType']    as String,
    revenue:      (j['revenue']     as num).toDouble(),
    orderCount:   (j['orderCount']  as num).toDouble(),
  );
}

class HeatmapCell {
  final String date;
  final String dayLabel;
  final int    hour;
  final String hourLabel;
  final double    orderCount;
  final double totalRevenue;
  final bool    hasData;   // ← mới
  final double  step;      // ← mới

  const HeatmapCell({
    required this.date,
    required this.dayLabel,
    required this.hour,
    required this.hourLabel,
    required this.orderCount,
    required this.totalRevenue,
    required this.hasData,
    required this.step
  });

  factory HeatmapCell.fromJson(Map<String, dynamic> j) => HeatmapCell(
    date:         j['date'] as String,
    dayLabel:     j['dayLabel'] as String,
    hour:         (j['hour'] as num).toInt(),
    hourLabel:    j['hourLabel'] as String,
    orderCount:   (j['orderCount'] as num).toDouble(),
    totalRevenue: (j['totalRevenue'] as num).toDouble(),
    hasData:      j['hasData'] as bool? ?? true,
    step:         (j['step'] as num?)?.toDouble() ?? 1.0,
  );
}

class CategoryItem {
  final int    id;
  final String name;
  const CategoryItem({required this.id, required this.name});
  factory CategoryItem.fromJson(Map<String, dynamic> j) =>
      CategoryItem(id: (j['id'] as num).toInt(), name: j['name'] as String);
}

class HeatmapProduct {
  final int    id;
  final String name;
  const HeatmapProduct({required this.id, required this.name});
  factory HeatmapProduct.fromJson(Map<String, dynamic> j) =>
      HeatmapProduct(
        id:   (j['id'] as num).toInt(),
        name: j['name'] as String,
      );
}