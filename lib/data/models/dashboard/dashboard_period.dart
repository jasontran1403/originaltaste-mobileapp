// lib/data/models/dashboard/dashboard_period.dart

enum DashboardPeriod {
  today('TODAY',   'Hôm nay'),
  days7('7DAYS',   '7 ngày'),
  days28('28DAYS',   '28 ngày'),
  days30('30DAYS', '30 ngày'),
  months3('3MONTHS', '3 tháng'),
  months6('6MONTHS', '6 tháng'),
  year('YEAR',     '1 năm'),
  custom('CUSTOM', 'Tuỳ chọn');

  final String apiValue;
  final String label;
  const DashboardPeriod(this.apiValue, this.label);
}