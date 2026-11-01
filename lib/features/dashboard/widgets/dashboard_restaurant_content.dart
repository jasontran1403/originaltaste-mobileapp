// lib/features/dashboard/widgets/dashboard_restaurant_content.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:syncfusion_flutter_maps/maps.dart';
import '../../../app/theme/app_colors.dart';
import '../../../data/models/dashboard/dashboard_restaurant_model.dart';
import '../../../shared/widgets/dashboard_shared_widgets.dart';
import '../controller/dashboard_controller.dart';

const _kPaymentColors = [
  Color(0xFF2563EB), Color(0xFF16A34A), Color(0xFFD946EF), Color(0xFFEA580C),
  Color(0xFF0891B2), Color(0xFF7C3AED), Color(0xFFF59E0B), Color(0xFFE11D48),
];
Color _pmColor(int i) => _kPaymentColors[i % _kPaymentColors.length];

// Tọa độ các tỉnh thành Việt Nam (giữ nguyên)
const Map<String, List<double>> _kProvinceCoords = {
  'Tuyên Quang': [22.1469, 105.2282], 'Cao Bằng': [22.6657, 106.2522],
  'Lai Châu': [22.3860, 103.4711],    'Lào Cai': [22.3364, 104.1500],
  'Thái Nguyên': [21.5928, 105.8442], 'Điện Biên': [21.3860, 103.0230],
  'Lạng Sơn': [21.8537, 106.7615],    'Sơn La': [21.1022, 103.7289],
  'Phú Thọ': [21.3450, 105.0500],     'Bắc Ninh': [21.1861, 106.0763],
  'Quảng Ninh': [21.0064, 107.2925],  'Hà Nội': [21.0285, 105.8542],
  'Hưng Yên': [20.6466, 106.0511],    'Ninh Bình': [20.2506, 105.9745],
  'Hải Phòng': [20.8449, 106.6881],   'Thanh Hóa': [19.8078, 105.7764],
  'Nghệ An': [19.2342, 104.9200],     'Hà Tĩnh': [18.3559, 105.8877],
  'Quảng Trị': [16.8163, 106.6600],   'Huế': [16.4637, 107.5909],
  'Đà Nẵng': [16.0544, 108.2022],     'Quảng Ngãi': [15.1214, 108.8040],
  'Gia Lai': [13.9810, 108.0000],     'Khánh Hòa': [12.2388, 109.1967],
  'Đắk Lắk': [12.6667, 108.0500],    'Lâm Đồng': [11.5753, 108.1429],
  'Đồng Nai': [11.0686, 107.1676],    'Hồ Chí Minh': [10.8231, 106.6297],
  'Tây Ninh': [11.3352, 106.1099],    'Đồng Tháp': [10.4938, 105.6882],
  'Vĩnh Long': [10.2397, 105.9571],   'Cần Thơ': [10.0452, 105.7469],
  'An Giang': [10.5216, 105.1259],    'Cà Mau': [9.1769, 105.1500],
  'Phú Yên': [13.0882, 109.0929],
};

Color _dotColor(int count) {
  if (count > 100) return const Color(0xFF2563EB);
  if (count >= 51) return const Color(0xFF16A34A);
  return const Color(0xFFEA580C);
}

class DashboardRestaurantContent extends ConsumerStatefulWidget {
  const DashboardRestaurantContent({super.key});

  @override
  ConsumerState<DashboardRestaurantContent> createState() => _DashboardRestaurantContentState();
}

class _DashboardRestaurantContentState extends ConsumerState<DashboardRestaurantContent> {
  String? _activeRegion;
  final MapShapeLayerController _mapController = MapShapeLayerController();
  final ScrollController _scrollCtrl = ScrollController(keepScrollOffset: false);

  @override
  void dispose() {
    _currentMapController?.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = ref.watch(dashboardControllerProvider);

    if (ctrl.restaurantLoading && ctrl.restaurantData == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (ctrl.restaurantError != null) {
      return _buildError(ctrl.restaurantError!);
    }

    if (ctrl.restaurantData == null) {
      return const Center(child: Text('Không có dữ liệu'));
    }

    return Stack(
      children: [
        Opacity(
          opacity: ctrl.restaurantLoading ? 0.6 : 1.0,
          child: RefreshIndicator(
            color: AppColors.primary,
            onRefresh: () async {
              ref.read(dashboardControllerProvider.notifier).pullRefresh();
              // Chờ loading xong (tối đa 15s để tránh treo)
              await Future.doWhile(() async {
                await Future.delayed(const Duration(milliseconds: 100));
                return ctrl.restaurantLoading;
              });
            },
            child: SingleChildScrollView(
              controller: _scrollCtrl,
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isNarrow = constraints.maxWidth < 600;
                  final isSuperAdmin = ref.read(dashboardControllerProvider).mode != DashboardMode.pos;

                  return Column(children: [
                    _buildCards(ctrl.restaurantData!, isNarrow: isNarrow),
                    const SizedBox(height: 14),
                    if (isNarrow) ...[
                      _buildChart(ctrl.restaurantData!),
                      const SizedBox(height: 14),
                      _buildPaymentPie(ctrl.restaurantData!),
                    ] else
                      IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(flex: 3, child: _buildChart(ctrl.restaurantData!)),
                            const SizedBox(width: 12),
                            Expanded(flex: 2, child: _buildPaymentPie(ctrl.restaurantData!)),
                          ],
                        ),
                      ),
                    const SizedBox(height: 14),
                    if (isNarrow) ...[
                      _buildRegionMap(ctrl.restaurantData!),
                      const SizedBox(height: 14),
                      _buildTopProducts(ctrl.restaurantData!),
                    ] else
                      IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(flex: 3, child: _buildRegionMap(ctrl.restaurantData!)),
                            const SizedBox(width: 12),
                            Expanded(flex: 2, child: _buildTopProducts(ctrl.restaurantData!)),
                          ],
                        ),
                      ),
                    const SizedBox(height: 14),
                    if (isNarrow) ...[
                      _buildTopUsers(ctrl.restaurantData!),
                      const SizedBox(height: 14),
                      if (ctrl.restaurantData!.topCustomers.isNotEmpty) _buildTopCustomers(ctrl.restaurantData!),
                    ] else
                      IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(child: _buildTopUsers(ctrl.restaurantData!)),
                            if (ctrl.restaurantData!.topCustomers.isNotEmpty) ...[
                              const SizedBox(width: 12),
                              Expanded(child: _buildTopCustomers(ctrl.restaurantData!)),
                            ],
                          ],
                        ),
                      ),
                    const SizedBox(height: 14),
                    _buildRecentOrders(ctrl.restaurantData!, isNarrow: isNarrow),
                    const SizedBox(height: 100),
                  ]);
                },
              ),
            ),
          ),
        ),

        // Overlay loading nhẹ khi reload (chỉ khi đã có data)
        if (ctrl.restaurantLoading)
          const Center(child: CircularProgressIndicator()),
      ],
    );
  }

  // ── Skeleton ──────────────────────────────────────────────────
  Widget _buildSkeleton() {
    final isDark  = Theme.of(context).brightness == Brightness.dark;
    final border  = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final cardBg  = isDark ? AppColors.darkCard : AppColors.lightCard;
    final shimmer = isDark
        ? Colors.white.withOpacity(0.06)
        : Colors.black.withOpacity(0.06);

    Widget box(double w, double h) => Container(
      width: w, height: h,
      decoration: BoxDecoration(
        color: shimmer, borderRadius: BorderRadius.circular(8),
      ),
    );

    Widget card() => Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg, borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [box(36, 36), const Spacer(), box(50, 18)]),
        const SizedBox(height: 14),
        box(80, 26),
        const SizedBox(height: 8),
        box(120, 12),
        const SizedBox(height: 4),
        box(100, 12),
      ]),
    );

    Widget panel(double h) => Container(
      height: h,
      decoration: BoxDecoration(
        color: cardBg, borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        box(140, 16),
        const SizedBox(height: 12),
        Expanded(child: box(double.infinity, double.infinity)),
      ]),
    );

    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Column(children: [
        Row(children: [
          Expanded(child: card()), const SizedBox(width: 10),
          Expanded(child: card()),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: card()), const SizedBox(width: 10),
          Expanded(child: card()),
        ]),
        const SizedBox(height: 14),
        panel(352),
        const SizedBox(height: 14),
        panel(300),
        const SizedBox(height: 14),
        panel(420),
        const SizedBox(height: 100),
      ]),
    );
  }

  // ── Body ──────────────────────────────────────────────────────
  Widget _buildBody(RestaurantDashboardModel d) {
    return RefreshIndicator(
      color:     AppColors.primary,
      onRefresh: () async {
        ref.read(dashboardControllerProvider.notifier).pullRefresh();
        await Future.doWhile(() async {
          await Future.delayed(const Duration(milliseconds: 80));
          return mounted &&
              ref.read(dashboardControllerProvider).restaurantLoading;
        });
      },
      child: SingleChildScrollView(
        controller: _scrollCtrl,
        physics:    const AlwaysScrollableScrollPhysics(),
        padding:    const EdgeInsets.all(16),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isNarrow = constraints.maxWidth < 600;
            final isSuperAdmin = ref.read(dashboardControllerProvider).mode
                != DashboardMode.pos; // wholesale/retail → can have topCustomers
            return Column(children: [
              _buildCards(d, isNarrow: isNarrow),
              const SizedBox(height: 14),
              if (isNarrow) ...[
                _buildChart(d),
                const SizedBox(height: 14),
                _buildPaymentPie(d),
              ] else
                IntrinsicHeight(child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(flex: 3, child: _buildChart(d)),
                    const SizedBox(width: 12),
                    Expanded(flex: 2, child: _buildPaymentPie(d)),
                  ],
                )),
              const SizedBox(height: 14),
              if (isNarrow) ...[
                _buildRegionMap(d),
                const SizedBox(height: 14),
                _buildTopProducts(d),
              ] else
                IntrinsicHeight(child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(flex: 3, child: _buildRegionMap(d)),
                    const SizedBox(width: 12),
                    Expanded(flex: 2, child: _buildTopProducts(d)),
                  ],
                )),
              const SizedBox(height: 14),
              // Top users + Top customers (side by side trên wide)
              if (isNarrow) ...[
                _buildTopUsers(d),
                const SizedBox(height: 14),
                if (d.topCustomers.isNotEmpty) _buildTopCustomers(d),
              ] else
                IntrinsicHeight(child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: _buildTopUsers(d)),
                    if (d.topCustomers.isNotEmpty) ...[
                      const SizedBox(width: 12),
                      Expanded(child: _buildTopCustomers(d)),
                    ],
                  ],
                )),
              const SizedBox(height: 14),
              _buildRecentOrders(d, isNarrow: isNarrow),
              const SizedBox(height: 100),
            ]);
          },
        ),
      ),
    );
  }

  // ── Stat cards ────────────────────────────────────────────────
  Widget _buildCards(RestaurantDashboardModel d, {bool isNarrow = false}) {
    final cards = [
      DashboardStatCard(
        icon: Icons.receipt_long_outlined, color: AppColors.primary,
        title: 'Đơn hàng', value: d.orderSummary.totalOrders.toDouble(),
        isCurrency: false,
        line1: 'Hoàn thành: ${fmtNum(d.orderSummary.completedOrders)}',
        line2: 'Đang xử lý: ${fmtNum(d.orderSummary.activeOrders)}',
      ),
      DashboardStatCard(
        icon: Icons.people_outline, color: Colors.teal,
        title: 'Khách hàng', value: d.customerSummary.total.toDouble(),
        isCurrency: false,
        line1: 'Mới: ${fmtNum(d.customerSummary.newCustomers)}',
        line2: 'Quay lại: ${fmtNum(d.customerSummary.returningCustomers)}',
      ),
      DashboardStatCard(
        icon: Icons.check_circle_outline, color: Colors.green,
        title: 'Doanh thu', value: d.revenueSummary.completedRevenue,
        isCurrency: true,
        line1: 'CK: ${fmtCurrency(d.revenueSummary.totalDiscount)}',
        line2: 'VAT: ${fmtCurrency(d.revenueSummary.totalVat)}',
      ),
      DashboardStatCard(
        icon: Icons.pending_outlined,
        color: Colors.orange,
        title: 'Thống kê',
        value: d.orderSummary.totalOrders.toDouble(),
        isCurrency: true,
        line1: 'Hủy: ${fmtNum(d.orderSummary.cancelledOrders)} đơn',
        line2: 'Thất bại: ${fmtNum(d.orderSummary.failedOrders)} đơn',
      ),
    ];
    if (isNarrow) {
      return Column(children: [
        Row(children: [
          Expanded(child: cards[0]), const SizedBox(width: 10),
          Expanded(child: cards[1]),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: cards[2]), const SizedBox(width: 10),
          Expanded(child: cards[3]),
        ]),
      ]);
    }
    return Row(children: [
      Expanded(child: cards[0]), const SizedBox(width: 10),
      Expanded(child: cards[1]), const SizedBox(width: 10),
      Expanded(child: cards[2]), const SizedBox(width: 10),
      Expanded(child: cards[3]),
    ]);
  }

  // ── Time-series chart ─────────────────────────────────────────
  Widget _buildChart(RestaurantDashboardModel d) {
    final isDark  = Theme.of(context).brightness == Brightness.dark;
    final primary = isDark ? AppColors.primary : AppColors.primaryDark;
    final border  = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final cardBg  = isDark ? AppColors.darkCard : AppColors.lightCard;

    return Container(
      padding:     const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg, borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const DashboardSectionTitle('Đơn hàng theo thời gian'),
        const SizedBox(height: 12),
        SizedBox(
          height: 320,
          child: d.ordersByTime.isEmpty
              ? Center(child: Text('Không có dữ liệu',
              style: Theme.of(context).textTheme.bodySmall))
              : SfCartesianChart(
              enableAxisAnimation: false,
            primaryXAxis: CategoryAxis(labelRotation: -30,
                majorGridLines: const MajorGridLines(width: 0)),
            primaryYAxis: NumericAxis(
                name: 'orders', numberFormat: NumberFormat.compact()),
            axes: [NumericAxis(
              name: 'revenue', opposedPosition: true,
              numberFormat: NumberFormat.compactCurrency(locale: 'vi', symbol: ''),
              majorGridLines: const MajorGridLines(width: 0),
            )],
            tooltipBehavior: TooltipBehavior(enable: true),
            legend: Legend(isVisible: true, position: LegendPosition.top),
            series: [
              ColumnSeries<RestaurantOrderByTimeModel, String>(
                name: 'Đơn hàng', dataSource: d.ordersByTime,
                xValueMapper: (e, _) => e.timeBucket,
                yValueMapper: (e, _) => e.orderCount,
                color: primary, width: 0.5,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
              ),
              LineSeries<RestaurantOrderByTimeModel, String>(
                name: 'Doanh thu', dataSource: d.ordersByTime,
                xValueMapper: (e, _) => e.timeBucket,
                yValueMapper: (e, _) => e.revenue,
                yAxisName: 'revenue', color: Colors.green,
                markerSettings: const MarkerSettings(isVisible: true),
              ),
            ],
          ),
        ),
      ]),
    );
  }

  // ── Payment pie ───────────────────────────────────────────────
  Widget _buildPaymentPie(RestaurantDashboardModel d) {
    final isDark    = Theme.of(context).brightness == Brightness.dark;
    final border    = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final cardBg    = isDark ? AppColors.darkCard : AppColors.lightCard;
    final secondary = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final methods = d.paymentBreakdown.methods;
    final total   = d.paymentBreakdown.totalAmount;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg, borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const DashboardSectionTitle('Phương thức thanh toán'),
        const SizedBox(height: 12),
        if (methods.isEmpty)
          SizedBox(height: 260, child: Center(child: Text('Không có dữ liệu',
              style: TextStyle(color: secondary))))
        else
          SizedBox(height: 260, child: SfCircularChart(
            legend: Legend(isVisible: true, position: LegendPosition.bottom,
                overflowMode: LegendItemOverflowMode.wrap),
            tooltipBehavior: TooltipBehavior(enable: true),
            series: [DoughnutSeries<RestaurantPaymentMethodItem, String>(
              dataSource: methods,
              xValueMapper: (m, i) => m.label,
              yValueMapper: (m, _) => m.amount,
              pointColorMapper: (m, i) => _pmColor(i),
              dataLabelMapper: (m, _) => total > 0
                  ? '${(m.amount / total * 100).toStringAsFixed(1)}%' : '',
              dataLabelSettings: const DataLabelSettings(
                isVisible: true,
                labelPosition: ChartDataLabelPosition.outside,
                textStyle: TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
              ),
              innerRadius: '55%', radius: '85%',
            )],
          )),
        if (methods.isNotEmpty) ...[
          const Divider(height: 16),
          ...methods.asMap().entries.map((e) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(children: [
              Container(width: 10, height: 10,
                  decoration: BoxDecoration(
                      color: _pmColor(e.key), shape: BoxShape.circle)),
              const SizedBox(width: 7),
              Expanded(child: Text(e.value.label,
                  style: const TextStyle(fontSize: 11))),
              Text('${e.value.count} đơn',
                  style: TextStyle(fontSize: 10, color: secondary)),
              const SizedBox(width: 8),
              Text(fmtCurrency(e.value.amount), style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w600,
                  color: _pmColor(e.key))),
            ]),
          )),
        ],
      ]),
    );
  }

  MapShapeLayerController? _currentMapController;
  String _lastMapKey = '';

  // ── Region map ────────────────────────────────────────────────
  Widget _buildRegionMap(RestaurantDashboardModel d) {
    final isDark    = Theme.of(context).brightness == Brightness.dark;
    final primary   = isDark ? AppColors.primary : AppColors.primaryDark;
    final border    = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final cardBg    = isDark ? AppColors.darkCard : AppColors.lightCard;
    final secondary = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    final markers = d.regionBreakdown
        .where((r) => _kProvinceCoords.containsKey(r.region))
        .toList();

    // Tạo controller mới khi markers thay đổi
    final mapKey = markers.map((m) => '${m.region}_${m.orderCount}').join('|');
    if (mapKey != _lastMapKey || _currentMapController == null) {
      _currentMapController?.dispose();
      _currentMapController = MapShapeLayerController();
      _lastMapKey = mapKey;
      _activeRegion = null;
    }
    final mapCtrl = _currentMapController!;

    const mapSource = MapShapeSource.asset(
      'assets/data/vietnam_map.json',
      shapeDataField: 'name',
    );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg, borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const DashboardSectionTitle('Đơn hàng theo vị trí'),
        const SizedBox(height: 8),
        SizedBox(
          height: 420,
          child: markers.isEmpty
              ? Center(child: Text('Không có dữ liệu vị trí',
              style: TextStyle(color: secondary)))
              : SfMaps(layers: [
            MapShapeLayer(
              source: mapSource,
              controller: mapCtrl,
              loadingBuilder: (_) => const Center(child: SizedBox(
                  width: 28, height: 28,
                  child: CircularProgressIndicator(strokeWidth: 2.5))),
              strokeColor: Colors.white,
              strokeWidth: 0.5,
              color: secondary.withOpacity(0.1),
              initialMarkersCount: markers.length,
              markerBuilder: (_, index) {
                final r       = markers[index];
                final coord   = _kProvinceCoords[r.region]!;
                final color   = _dotColor(r.orderCount);
                final isActive = _activeRegion == r.region;
                return MapMarker(
                  latitude:  coord[0],
                  longitude: coord[1],
                  alignment: Alignment.center,
                  child: RegionDot(
                    color:    color,
                    isActive: isActive,
                    onTap: () {
                      setState(() =>
                      _activeRegion = isActive ? null : r.region);
                      mapCtrl.updateMarkers(
                          List.generate(markers.length, (i) => i));
                      showDialog(
                        context: context,
                        barrierColor: Colors.transparent,
                        builder: (_) => Stack(children: [
                          GestureDetector(
                            onTap: () {
                              setState(() => _activeRegion = null);
                              Navigator.pop(context);
                            },
                            child: const SizedBox.expand(),
                          ),
                          Center(child: Material(
                            color: Colors.transparent,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 18, vertical: 14),
                              decoration: BoxDecoration(
                                color: cardBg,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [BoxShadow(
                                  color:      color.withOpacity(0.25),
                                  blurRadius: 20,
                                  offset:     const Offset(0, 6),
                                )],
                              ),
                              child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Row(mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Container(width: 10, height: 10,
                                              decoration: BoxDecoration(
                                                  shape: BoxShape.circle,
                                                  color: color)),
                                          const SizedBox(width: 7),
                                          Text(r.region, style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w700,
                                              color: primary)),
                                        ]),
                                    const SizedBox(height: 6),
                                    Text('${r.orderCount} đơn hàng',
                                        style: TextStyle(
                                            fontSize: 13, color: color,
                                            fontWeight: FontWeight.w600)),
                                  ]),
                            ),
                          )),
                        ]),
                      ).then((_) {
                        setState(() => _activeRegion = null);
                        mapCtrl.updateMarkers(
                            List.generate(markers.length, (i) => i));
                      });
                    },
                  ),
                );
              },
            ),
          ]),
        ),
        const SizedBox(height: 10),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          _legendDot(const Color(0xFFEA580C), '< 50 đơn', secondary),
          const SizedBox(width: 16),
          _legendDot(const Color(0xFF16A34A), '51–100 đơn', secondary),
          const SizedBox(width: 16),
          _legendDot(const Color(0xFF2563EB), '> 100 đơn', secondary),
        ]),
      ]),
    );
  }

  Widget _legendDot(Color color, String label, Color secondary) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(width: 10, height: 10,
          decoration: BoxDecoration(shape: BoxShape.circle, color: color)),
      const SizedBox(width: 5),
      Text(label, style: TextStyle(fontSize: 11, color: secondary)),
    ],
  );

  // ── Top tables ────────────────────────────────────────────────
  Widget _buildTopProducts(RestaurantDashboardModel d) =>
      DashboardTopTable(
        title: 'Top sản phẩm', icon: Icons.fastfood_outlined,
        headers: const ['Sản phẩm', 'SL', 'Doanh thu'],
        rows: d.topProducts.map((p) => [
          p.productName, fmtNum(p.totalQuantity), fmtCurrency(p.totalRevenue),
        ]).toList(),
      );

  Widget _buildTopUsers(RestaurantDashboardModel d) =>
      DashboardTopTable(
        title: 'Top nhân viên', icon: Icons.badge_outlined,
        headers: const ['Nhân viên', 'Đơn', 'Doanh thu'],
        rows: d.topUsers.map((u) => [
          u.fullName.isNotEmpty ? u.fullName : u.userName,
          fmtNum(u.orderCount), fmtCurrency(u.totalRevenue),
        ]).toList(),
      );

  Widget _buildTopCustomers(RestaurantDashboardModel d) =>
      DashboardTopTable(
        title: 'Top khách hàng', icon: Icons.group_outlined,
        headers: const ['Khách hàng', 'Đơn', 'Chi tiêu'],
        rows: d.topCustomers.map((c) => [
          c.customerName, fmtNum(c.orderCount), fmtCurrency(c.totalSpent),
        ]).toList(),
      );

  // ── Recent orders ─────────────────────────────────────────────
  Widget _buildRecentOrders(RestaurantDashboardModel d,
      {bool isNarrow = false}) {
    final isDark    = Theme.of(context).brightness == Brightness.dark;
    final border    = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final cardBg    = isDark ? AppColors.darkCard : AppColors.lightCard;
    final secondary = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final primary   = isDark ? AppColors.primary : AppColors.primaryDark;

    return Container(
      decoration: BoxDecoration(
        color: cardBg, borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
          child: const DashboardSectionTitle('Đơn hàng mới nhất'),
        ),
        Divider(height: 0, color: border),
        _recentOrderHeader(
            isNarrow: isNarrow, secondary: secondary),
        Divider(height: 0, color: border),
        if (d.recentOrders.isEmpty)
          Padding(padding: const EdgeInsets.all(24),
              child: Center(child: Text('Không có đơn hàng',
                  style: TextStyle(color: secondary))))
        else
          ...d.recentOrders.map((o) => Column(children: [
            _recentOrderRow(o, isNarrow: isNarrow,
                primary: primary, secondary: secondary),
            Divider(height: 0, color: border.withOpacity(0.5)),
          ])),
      ]),
    );
  }

  Widget _recentOrderHeader(
      {bool isNarrow = false, required Color secondary}) {
    final s = TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: secondary);
    return Container(
      color:   secondary.withOpacity(0.06),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
      child: isNarrow
          ? Row(children: [
        Expanded(flex: 3, child: Text('Mã đơn',     style: s)),
        Expanded(flex: 3, child: Text('Khách hàng', style: s)),
        Expanded(flex: 3, child: Text('Tổng tiền',  style: s)),
        Expanded(flex: 2, child: Text('Trạng thái', style: s,
            textAlign: TextAlign.center)),
      ])
          : Row(children: [
        Expanded(flex: 2, child: Text('Mã đơn',          style: s)),
        Expanded(flex: 2, child: Text('Khách hàng',      style: s)),
        Expanded(flex: 1, child: Text('Thời gian',       style: s)),
        Expanded(flex: 2, child: Text('Tổng / CK / VAT', style: s)),
        Expanded(flex: 1, child: Text('Trạng thái', style: s,
            textAlign: TextAlign.center)),
      ]),
    );
  }

  Widget _recentOrderRow(RestaurantRecentOrderModel o,
      {bool isNarrow = false,
        required Color primary,
        required Color secondary}) {
    final color = statusColor(o.status);
    final badge = StatusBadge(label: statusLabel(o.status), color: color);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: isNarrow
          ? Row(children: [
        Expanded(flex: 3,
            child: OrderIdCell(code: o.orderCode, color: primary, fontSize: 11)),
        Expanded(flex: 3, child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              o.customerName?.isNotEmpty == true
                  ? o.customerName! : 'Khách lẻ',
              style: const TextStyle(fontSize: 11),
              overflow: TextOverflow.ellipsis,
            ),
            Text(fmtDate(o.createdAt),
                style: TextStyle(fontSize: 10, color: secondary)),
          ],
        )),
        Expanded(flex: 3, child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(fmtCurrency(o.finalAmount), style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.w700, color: primary)),
            Text('CK: -${fmtCurrency(o.discountAmount)}',
                style: TextStyle(fontSize: 10, color: secondary)),
          ],
        )),
        Expanded(flex: 2, child: Center(child: badge)),
      ])
          : Row(children: [
        Expanded(flex: 2,
            child: OrderIdCell(code: o.orderCode, color: primary, fontSize: 12)),
        Expanded(flex: 2, child: Text(
            o.customerName?.isNotEmpty == true
                ? o.customerName! : 'Khách lẻ',
            style: const TextStyle(fontSize: 12),
            overflow: TextOverflow.ellipsis)),
        Expanded(flex: 1, child: Text(fmtDate(o.createdAt),
            style: TextStyle(fontSize: 11, color: secondary))),
        Expanded(flex: 2, child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(fmtCurrency(o.finalAmount), style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.w700, color: primary)),
            Text(
              'CK: -${fmtCurrency(o.discountAmount)}'
                  '  VAT: +${fmtCurrency(o.vatAmount)}',
              style: TextStyle(fontSize: 10, color: secondary),
            ),
          ],
        )),
        Expanded(flex: 1, child: Center(child: badge)),
      ]),
    );
  }

  // ── Error ─────────────────────────────────────────────────────
  Widget _buildError(String error) {
    return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.error_outline, size: 52, color: AppColors.error),
      const SizedBox(height: 12),
      Text(error, style: const TextStyle(color: AppColors.error)),
      const SizedBox(height: 16),
      ElevatedButton.icon(
        onPressed: () =>
            ref.read(dashboardControllerProvider.notifier).reload(),
        icon:  const Icon(Icons.refresh),
        label: const Text('Thử lại'),
      ),
    ]));
  }
}