// lib/features/dashboard/widgets/dashboard_pos_content.dart

import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/constants/api_constants.dart';
import '../../../data/models/dashboard/dashboard_period.dart';
import '../../../data/models/dashboard/dashboard_pos_model.dart';
import '../../../data/storage/session_storage.dart';
import '../../core/enums/user_role.dart';
import '../../features/auth/controller/auth_controller.dart';
import '../../features/dashboard/controller/dashboard_controller.dart';
import '../../features/dashboard/widgets/pos_advanced_charts.dart';
import '../../features/dashboard/widgets/rolling_performance_section.dart';
import 'dashboard_pie_card.dart';
import 'dashboard_shared_widgets.dart';
import '../../features/dashboard/widgets/revenue_intelligence_chart.dart';

// ── POS source helpers ────────────────────────────────────────────

IconData _srcIcon(String s) => switch (s) {
  'SHOPEE_FOOD' => Icons.delivery_dining_outlined,
  'GRAB_FOOD'   => Icons.two_wheeler_outlined,
  _             => Icons.storefront_outlined,
};

Color _srcColor(String s) => switch (s) {
  'SHOPEE_FOOD' => const Color(0xFFEE4D2D),
  'GRAB_FOOD'   => const Color(0xFF00B14F),
  _             => const Color(0xFF2563EB),
};

String _srcLabel(String s) => switch (s) {
  'SHOPEE_FOOD' => 'ShopeeFood',
  'GRAB_FOOD'   => 'GrabFood',
  _             => 'Offline',
};

String _pmLabel(String? m) => switch (m) {
  'CASH'          => 'Tiền mặt',
  'BANK_TRANSFER' => 'Chuyển khoản',
  'TRANSFER'      => 'Chuyển khoản',
  'MOMO'          => 'MoMo',
  'VNPAY'         => 'VNPay',
  'ZALOPAY'       => 'ZaloPay',
  _               => m ?? '—',
};

String _periodStr(DashboardPeriod p) => switch (p) {
  DashboardPeriod.today   => 'TODAY',
  DashboardPeriod.days7   => '7DAYS',
  DashboardPeriod.days28  => '28DAYS',
  DashboardPeriod.days30  => '30DAYS',
  DashboardPeriod.months3 => '3MONTHS',
  DashboardPeriod.months6 => '6MONTHS',
  DashboardPeriod.year    => 'YEAR',
  DashboardPeriod.custom  => 'CUSTOM',
};

// ══════════════════════════════════════════════════════════════════
// POS DASHBOARD CONTENT
// ══════════════════════════════════════════════════════════════════

class DashboardPosContent extends ConsumerStatefulWidget {
  const DashboardPosContent({super.key});

  @override
  ConsumerState<DashboardPosContent> createState() =>
      _DashboardPosContentState();
}

class _DashboardPosContentState extends ConsumerState<DashboardPosContent> {
  final ScrollController _scrollCtrl =
  ScrollController(keepScrollOffset: false);
  late final TooltipBehavior _tooltip = TooltipBehavior(enable: true);

  bool _showSkeleton = false;
  int? _lastAnimKey;
  bool _isExporting  = false;

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  // ── Export Orders ─────────────────────────────────────────────
  // Future<void> _exportOrders() async {
  //   if (_isExporting) return;
  //   setState(() => _isExporting = true);
  //
  //   try {
  //     final ctrl = ref.read(dashboardControllerProvider);
  //     final isSuperAdmin = ref.read(authControllerProvider).role
  //         == UserRole.superAdmin;
  //
  //     final endpoint = isSuperAdmin
  //         ? '/api/superadmin/dashboard/pos/export'
  //         : '/api/admin/dashboard/pos/export';   // ← THÊM
  //
  //     final params = <String, dynamic>{
  //       'period': _periodStr(ctrl.period),
  //     };
  //     if (ctrl.period == DashboardPeriod.custom) {
  //       if (ctrl.customFrom != null)
  //         params['fromTs'] = ctrl.customFrom!.millisecondsSinceEpoch;
  //       if (ctrl.customTo != null)
  //         params['toTs'] = ctrl.customTo!.millisecondsSinceEpoch;
  //     }
  //
  //     final token = await SessionStorage.getAccessToken();
  //     final dio   = Dio(BaseOptions(
  //       baseUrl:        ApiConstants.baseUrl,
  //       receiveTimeout: const Duration(seconds: 60),
  //       connectTimeout: const Duration(seconds: 15),
  //       headers: {
  //         if (token != null) 'Authorization': 'Bearer $token',
  //       },
  //     ));
  //
  //     if (isSuperAdmin) {
  //       // ── SuperAdmin: nhận JSON message, gửi Telegram ──────────
  //       final response = await dio.get(
  //         endpoint,
  //         queryParameters: params,
  //         options: Options(responseType: ResponseType.json),
  //       );
  //       if (!mounted) return;
  //       final msg = (response.data?['data'] as String?)
  //           ?? 'Báo cáo sẽ được gửi vào Telegram';
  //       ScaffoldMessenger.of(context).showSnackBar(SnackBar(
  //         content: Row(children: [
  //           const Icon(Icons.telegram, color: Colors.white, size: 16),
  //           const SizedBox(width: 8),
  //           Expanded(child: Text(msg)),
  //         ]),
  //         backgroundColor: const Color(0xFF14B8A6),
  //         behavior: SnackBarBehavior.floating,
  //         shape: RoundedRectangleBorder(
  //             borderRadius: BorderRadius.circular(10)),
  //         duration: const Duration(seconds: 4),
  //       ));
  //     } else {
  //       // ── Admin: nhận file bytes, lưu và share ────────────────
  //       final response = await dio.get(
  //         endpoint,
  //         queryParameters: params,
  //         options: Options(responseType: ResponseType.bytes),
  //       );
  //
  //       if (response.statusCode == 200 && response.data != null) {
  //         final dir      = await getTemporaryDirectory();
  //         final datePart = DateFormat('yyyyMMdd').format(DateTime.now());
  //         final fileName = 'orders_$datePart.xlsx';
  //         final file     = File('${dir.path}/$fileName');
  //         await file.writeAsBytes(response.data as List<int>);
  //
  //         if (!mounted) return;
  //         await Share.shareXFiles(
  //           [XFile(
  //             file.path,
  //             mimeType: 'application/vnd.openxmlformats-officedocument'
  //                 '.spreadsheetml.sheet',
  //             name: fileName,
  //           )],
  //           subject: 'Báo cáo đơn hàng POS - $datePart',
  //         );
  //       } else {
  //         _snackError('Lỗi server: ${response.statusCode}');
  //       }
  //     }
  //   } on DioException catch (e) {
  //     final msg = e.response?.statusCode == 401
  //         ? 'Phiên đăng nhập hết hạn'
  //         : 'Lỗi kết nối: ${e.message}';
  //     _snackError(msg);
  //   } catch (e) {
  //     _snackError('Lỗi export: $e');
  //   } finally {
  //     if (mounted) setState(() => _isExporting = false);
  //   }
  // }

  Future<void> _exportOrders() async {
    if (_isExporting) return;
    setState(() => _isExporting = true);

    try {
      final ctrl = ref.read(dashboardControllerProvider);
      final isSuperAdmin = ref.read(authControllerProvider).role
          == UserRole.superAdmin;

      final endpoint = isSuperAdmin
          ? '/api/superadmin/dashboard/pos/export'
          : '/api/admin/dashboard/pos/export';

      final params = <String, dynamic>{
        'period': _periodStr(ctrl.period),
      };
      if (ctrl.period == DashboardPeriod.custom) {
        if (ctrl.customFrom != null)
          params['fromTs'] = ctrl.customFrom!.millisecondsSinceEpoch;
        if (ctrl.customTo != null)
          params['toTs'] = ctrl.customTo!.millisecondsSinceEpoch;
      }

      final token = await SessionStorage.getAccessToken();
      final dio   = Dio(BaseOptions(
        baseUrl:        ApiConstants.baseUrl,
        receiveTimeout: const Duration(seconds: 60),
        connectTimeout: const Duration(seconds: 15),
        headers: {
          if (token != null) 'Authorization': 'Bearer $token',
        },
      ));

      // ── Cả SuperAdmin và Admin đều nhận JSON message ──────────
      final response = await dio.get(
        endpoint,
        queryParameters: params,
        options: Options(responseType: ResponseType.json),
      );
      if (!mounted) return;
      final msg = (response.data?['message'] as String?)
          ?? 'Báo cáo sẽ được gửi vào Telegram';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Row(children: [
          const Icon(Icons.telegram, color: Colors.white, size: 16),
          const SizedBox(width: 8),
          Expanded(child: Text(msg)),
        ]),
        backgroundColor: const Color(0xFF14B8A6),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 4),
      ));

    } on DioException catch (e) {
      final msg = e.response?.statusCode == 401
          ? 'Phiên đăng nhập hết hạn'
          : 'Lỗi kết nối: ${e.message}';
      _snackError(msg);
    } catch (e) {
      _snackError('Lỗi export: $e');
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  void _snackError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content:         Text(msg),
      backgroundColor: Colors.red.shade700,
      behavior:        SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  // Widget _buildExportButton() {
  //   final isDark     = Theme.of(context).brightness == Brightness.dark;
  //   final primary    = isDark ? AppColors.primary : AppColors.primaryDark;
  //   final isSuperAdmin = ref.read(authControllerProvider).role
  //       == UserRole.superAdmin;
  //
  //   // SuperAdmin → icon Telegram, Admin → icon download
  //   final icon  = isSuperAdmin
  //       ? Icons.send_outlined
  //       : Icons.file_download_outlined;
  //   final label = isSuperAdmin ? 'Telegram' : 'Export';
  //
  //   return SizedBox(
  //     height: 32,
  //     child: _isExporting
  //         ? OutlinedButton.icon(
  //       icon: SizedBox(width: 13, height: 13,
  //           child: CircularProgressIndicator(
  //               strokeWidth: 2, color: primary)),
  //       label: Text('Đang tạo...',
  //           style: TextStyle(fontSize: 11, color: primary)),
  //       style: OutlinedButton.styleFrom(
  //         side:    BorderSide(color: primary.withOpacity(0.3)),
  //         padding: const EdgeInsets.symmetric(horizontal: 10),
  //         shape:   RoundedRectangleBorder(
  //             borderRadius: BorderRadius.circular(8)),
  //       ),
  //       onPressed: null,
  //     )
  //         : OutlinedButton.icon(
  //       icon:  Icon(icon, size: 15, color: primary),
  //       label: Text(label,
  //           style: TextStyle(fontSize: 11, color: primary,
  //               fontWeight: FontWeight.w600)),
  //       style: OutlinedButton.styleFrom(
  //         side:    BorderSide(color: primary.withOpacity(0.5)),
  //         padding: const EdgeInsets.symmetric(horizontal: 10),
  //         shape:   RoundedRectangleBorder(
  //             borderRadius: BorderRadius.circular(8)),
  //       ),
  //       onPressed: _exportOrders,
  //     ),
  //   );
  // }

  Widget _buildExportButton() {
    final isDark  = Theme.of(context).brightness == Brightness.dark;
    final primary = isDark ? AppColors.primary : AppColors.primaryDark;

    return SizedBox(
      height: 32,
      child: _isExporting
          ? OutlinedButton.icon(
        icon: SizedBox(width: 13, height: 13,
            child: CircularProgressIndicator(
                strokeWidth: 2, color: primary)),
        label: Text('Đang tạo...',
            style: TextStyle(fontSize: 11, color: primary)),
        style: OutlinedButton.styleFrom(
          side:    BorderSide(color: primary.withOpacity(0.3)),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          shape:   RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8)),
        ),
        onPressed: null,
      )
          : OutlinedButton.icon(
        icon:  Icon(Icons.send_outlined, size: 15, color: primary),
        label: Text('Telegram',
            style: TextStyle(fontSize: 11, color: primary,
                fontWeight: FontWeight.w600)),
        style: OutlinedButton.styleFrom(
          side:    BorderSide(color: primary.withOpacity(0.5)),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          shape:   RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8)),
        ),
        onPressed: _exportOrders,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = ref.watch(dashboardControllerProvider);

    if (ctrl.posLoading || _showSkeleton) {
      return _buildSkeleton();
    }
    if (ctrl.posError != null) {
      return _buildError(ctrl.posError!);
    }
    if (ctrl.posData == null) {
      return const Center(child: Text('Không có dữ liệu'));
    }
    return _buildBody(ctrl);
  }

  // ── Skeleton ──────────────────────────────────────────────────
  Widget _buildSkeleton() {
    final isDark  = Theme.of(context).brightness == Brightness.dark;
    final border  = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final cardBg  = isDark ? AppColors.darkCard   : AppColors.lightCard;
    final shimmer = isDark
        ? Colors.white.withOpacity(0.06)
        : Colors.black.withOpacity(0.06);

    Widget box(double w, double h) => Container(
      width: w, height: h,
      decoration: BoxDecoration(
          color: shimmer, borderRadius: BorderRadius.circular(8)),
    );

    Widget card() => Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: cardBg, borderRadius: BorderRadius.circular(12),
          border: Border.all(color: border)),
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
          border: Border.all(color: border)),
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
        panel(260),
        const SizedBox(height: 100),
      ]),
    );
  }

  // ── Body ──────────────────────────────────────────────────────
  Widget _buildBody(DashboardState ctrl) {
    final d = ctrl.posData!;
    return RefreshIndicator(
      color:     AppColors.primary,
      onRefresh: () async {
        ref.read(dashboardControllerProvider.notifier).pullRefresh();
        await Future.doWhile(() async {
          await Future.delayed(const Duration(milliseconds: 80));
          return mounted &&
              ref.read(dashboardControllerProvider).posLoading;
        });
      },
      child: SingleChildScrollView(
        controller: _scrollCtrl,
        physics:    const AlwaysScrollableScrollPhysics(),
        padding:    const EdgeInsets.all(16),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isNarrow = constraints.maxWidth < 600;
            return Column(children: [
              _buildCards(d,
                  animKey: ctrl.posAnimationKey,
                  isNarrow: isNarrow),
              const SizedBox(height: 14),

              // ── Rolling Performance (chỉ SUPERADMIN khi bật cửa sổ trượt) ──
              if (ctrl.rollingWindow != null) ...[
                const RollingPerformanceSection(),
                const SizedBox(height: 14),
              ],

              if (isNarrow) ...[
                _buildChart(),
                const SizedBox(height: 14),
                DashboardPieCard(data: d),
              ] else
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(flex: 3, child: _buildChart()),
                      const SizedBox(width: 12),
                      Expanded(flex: 2, child: DashboardPieCard(data: d)),
                    ],
                  ),
                ),
              const SizedBox(height: 14),
              const PosAdvancedCharts(),
              const SizedBox(height: 14),
              const RevenueIntelligenceChart(),
              const SizedBox(height: 14),
              _buildTopProducts(d),
              const SizedBox(height: 14),
              _buildRecentOrders(d, isNarrow: isNarrow),
              const SizedBox(height: 80),
            ]);
          },
        ),
      ),
    );
  }

  // ── 4 Stat cards ─────────────────────────────────────────────
  Widget _buildCards(PosDashboardModel d,
      {required int animKey, bool isNarrow = false}) {
    final tw = d.statFor('TAKE_AWAY');
    final di = d.statFor('DINE_IN');
    final sf = d.statFor('SHOPEE_FOOD');
    final gf = d.statFor('GRAB_FOOD');

    // ── Tính tổng ──────────────────────────────────────────────────
    final totalOrders  = tw.totalOrders  + di.totalOrders  + sf.totalOrders  + gf.totalOrders;
    final totalItems   = tw.totalItems   + di.totalItems   + sf.totalItems   + gf.totalItems;
    final totalRevenue = tw.totalRevenue + di.totalRevenue + sf.totalRevenue + gf.totalRevenue;

    final cards = [
      DashboardStatCard(
        key:        ValueKey('pos_c1_$animKey'),
        icon:       Icons.storefront_outlined,
        color:      const Color(0xFF2563EB),
        title:      'Take Away',
        value:      tw.totalItems.toDouble(),
        isCurrency: false,
        line1:      '${fmtNum(tw.totalOrders)} đơn',
        line2:      fmtCurrencyShort(tw.totalRevenue),
      ),
      DashboardStatCard(
        key:        ValueKey('pos_c2_$animKey'),
        icon:       Icons.table_restaurant_outlined,
        color:      const Color(0xFF0891B2),
        title:      'Dine In',
        value:      di.totalItems.toDouble(),
        isCurrency: false,
        line1:      '${fmtNum(di.totalOrders)} đơn',
        line2:      fmtCurrencyShort(di.totalRevenue),
      ),
      DashboardStatCard(
        key:        ValueKey('pos_c3_$animKey'),
        icon:       Icons.delivery_dining_outlined,
        color:      const Color(0xFFEE4D2D),
        title:      'ShopeeFood',
        value:      sf.totalItems.toDouble(),
        isCurrency: false,
        line1:      '${fmtNum(sf.totalOrders)} đơn',
        line2:      fmtCurrencyShort(sf.totalRevenue),
      ),
      DashboardStatCard(
        key:        ValueKey('pos_c4_$animKey'),
        icon:       Icons.two_wheeler_outlined,
        color:      const Color(0xFF00B14F),
        title:      'GrabFood',
        value:      gf.totalItems.toDouble(),
        isCurrency: false,
        line1:      '${fmtNum(gf.totalOrders)} đơn',
        line2:      fmtCurrencyShort(gf.totalRevenue),
      ),
    ];

    // ── Card tổng hợp ─────────────────────────────────────────────
    final isDark   = Theme.of(context).brightness == Brightness.dark;
    final border   = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final cardBg   = isDark ? AppColors.darkCard   : AppColors.lightCard;
    final textSec  = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    const gradient = [Color(0xFF6366F1), Color(0xFF8B5CF6)];

    final summaryCard = Container(
      key: ValueKey('pos_summary_$animKey'),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: gradient,
          begin: Alignment.topLeft,
          end:   Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color:      const Color(0xFF6366F1).withOpacity(0.3),
            blurRadius: 12,
            offset:     const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Icon
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color:        Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.bar_chart_rounded,
                color: Colors.white, size: 22),
          ),
          const SizedBox(width: 14),

          // Title
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Tổng cộng',
                    style: TextStyle(
                        fontSize:   13,
                        fontWeight: FontWeight.w700,
                        color:      Colors.white)),
                const SizedBox(height: 2),
                Text('${fmtNum(totalOrders)} đơn  •  ${fmtNum(totalItems)} món',
                    style: TextStyle(
                        fontSize: 11,
                        color:    Colors.white.withOpacity(0.85))),
              ],
            ),
          ),

          // Doanh thu
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(fmtCurrencyShort(totalRevenue),
                  style: const TextStyle(
                      fontSize:   20,
                      fontWeight: FontWeight.w800,
                      color:      Colors.white)),
              Text('doanh thu',
                  style: TextStyle(
                      fontSize: 10,
                      color:    Colors.white.withOpacity(0.75))),
            ],
          ),
        ],
      ),
    );

    if (isNarrow) {
      return Column(children: [
        // Card tổng — full width
        summaryCard,
        const SizedBox(height: 10),
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

    return Column(children: [
      // Card tổng — full width trên cùng
      summaryCard,
      const SizedBox(height: 10),
      Row(children: [
        Expanded(child: cards[0]), const SizedBox(width: 10),
        Expanded(child: cards[1]), const SizedBox(width: 10),
        Expanded(child: cards[2]), const SizedBox(width: 10),
        Expanded(child: cards[3]),
      ]),
    ]);
  }

  // ── Chart ─────────────────────────────────────────────────────
  Widget _buildChart() {
    final isDark  = Theme.of(context).brightness == Brightness.dark;
    final primary = isDark ? AppColors.primary : AppColors.primaryDark;
    final border  = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final cardBg  = isDark ? AppColors.darkCard   : AppColors.lightCard;

    const colorRevenue = Color(0xFF2563EB);
    const colorAov     = Color(0xFFF59E0B);
    const colorItems   = Color(0xFFD946EF); // fuchsia — khác hẳn 3 màu còn lại

    final ctrl         = ref.watch(dashboardControllerProvider);
    final filterType   = ctrl.chartFilterType;
    final chartData    = ctrl.chartOrdersByTime;
    final chartLoading = ctrl.chartLoading;

    final double aovMax = chartData.isEmpty
        ? 1
        : chartData.map((e) => e.aov).reduce((a, b) => a > b ? a : b);
    final double aovAxisMax = aovMax > 0 ? aovMax / 0.6 : 0.8;

    return Container(
      padding:    const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color:        cardBg,
        borderRadius: BorderRadius.circular(12),
        border:       Border.all(color: border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // ── Header: title + filter chips ──────────────────────────
        Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          const DashboardSectionTitle('Đơn hàng'),
          const SizedBox(width: 12),
          Expanded(
            child: _PosChartFilterBar(
              current:   filterType,
              isDark:    isDark,
              compact:   true,
              onChanged: (f) => ref
                  .read(dashboardControllerProvider.notifier)
                  .setChartFilterType(f),
            ),
          ),
        ]),
        const SizedBox(height: 12),

        // ── Chart body ─────────────────────────────────────────────
        SizedBox(
          height: 300,
          child: chartLoading
              ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                      color: primary, strokeWidth: 2),
                  const SizedBox(height: 10),
                  Text('Đang tải...',
                      style: TextStyle(
                          fontSize: 12,
                          color: primary.withOpacity(0.7))),
                ],
              ))
              : chartData.isEmpty
              ? Center(child: Text('Không có dữ liệu',
              style: Theme.of(context).textTheme.bodySmall))
              : GestureDetector(
            onTap: () => _tooltip.hide(),
            child: SfCartesianChart(
              enableAxisAnimation: false,
              primaryXAxis: const CategoryAxis(
                labelRotation:  -30,
                majorGridLines: MajorGridLines(width: 0),
              ),

              // ── Trục trái: Đơn hàng + Sản phẩm (chung) ─
              primaryYAxis: NumericAxis(
                name:           'orders',
                numberFormat:   NumberFormat.compact(),
                axisLine:       const AxisLine(width: 0),
                majorTickLines: const MajorTickLines(size: 0),
              ),

              axes: [
                // ── Trục phải 1: Doanh thu ───────────────
                NumericAxis(
                  name:            'money',
                  opposedPosition: true,
                  numberFormat:    NumberFormat.compactCurrency(
                      locale: 'vi', symbol: ''),
                  majorGridLines:  const MajorGridLines(width: 0),
                  axisLine:        const AxisLine(width: 0),
                  majorTickLines:  const MajorTickLines(size: 0),
                ),
                // ── Trục phải 2: AOV (ẩn) ────────────────
                NumericAxis(
                  name:            'aov',
                  isVisible:       false,
                  minimum:         0,
                  maximum:         aovAxisMax,
                  opposedPosition: true,
                ),
              ],

              tooltipBehavior: _tooltip,
              legend: const Legend(
                isVisible:    true,
                position:     LegendPosition.top,
                overflowMode: LegendItemOverflowMode.wrap,
              ),

              series: [
                // ── Cột 1: Đơn hàng ──────────────────────
                ColumnSeries<PosOrderByTimeModel, String>(
                  name:              'Đơn hàng',
                  dataSource:        chartData,
                  xValueMapper:      (e, _) => e.timeBucket,
                  yValueMapper:      (e, _) => e.orderCount,
                  yAxisName:         'orders',
                  color:             primary.withOpacity(0.85),
                  width:             0.4,
                  spacing:           0.1,
                  animationDuration: 300,
                  borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(3)),
                ),

                // ── Cột 2: Số sản phẩm ───────────────────
                ColumnSeries<PosOrderByTimeModel, String>(
                  name:              'Sản phẩm',
                  dataSource:        chartData,
                  xValueMapper:      (e, _) => e.timeBucket,
                  yValueMapper:      (e, _) => e.itemCount,
                  yAxisName:         'orders', // chung trục trái
                  color:             colorItems.withOpacity(0.75),
                  width:             0.4,
                  spacing:           0.1,
                  animationDuration: 300,
                  borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(3)),
                ),

                // ── Line 1: Doanh thu ─────────────────────
                LineSeries<PosOrderByTimeModel, String>(
                  name:              'Doanh thu',
                  dataSource:        chartData,
                  xValueMapper:      (e, _) => e.timeBucket,
                  yValueMapper:      (e, _) => e.revenue,
                  yAxisName:         'money',
                  color:             colorRevenue,
                  width:             2,
                  animationDuration: 300,
                  markerSettings: const MarkerSettings(
                      isVisible: true),
                ),

                // ── Line 2: AOV ───────────────────────────
                LineSeries<PosOrderByTimeModel, String>(
                  name:              'AOV',
                  dataSource:        chartData,
                  xValueMapper:      (e, _) => e.timeBucket,
                  yValueMapper:      (e, _) => e.aov,
                  yAxisName:         'aov',
                  color:             colorAov,
                  width:             2,
                  animationDuration: 300,
                  dashArray:         const [6, 3],
                  markerSettings: const MarkerSettings(
                    isVisible: true,
                    shape:     DataMarkerType.diamond,
                  ),
                ),
              ],
            ),
          ),
        ),
      ]),
    );
  }

  // ── Top products ──────────────────────────────────────────────
  Widget _buildTopProducts(PosDashboardModel d) {
    return DashboardTopTable(
      title:   'Top sản phẩm',
      icon:    Icons.fastfood_outlined,
      headers: const ['Sản phẩm', 'SL', 'Doanh thu'],
      rows: d.topProducts.map((p) => [
        p.productName,
        fmtNum(p.totalQuantity),
        fmtCurrency(p.totalRevenue),
      ]).toList(),
    );
  }

  // ── Recent orders ─────────────────────────────────────────────
  Widget _buildRecentOrders(PosDashboardModel d,
      {bool isNarrow = false}) {
    final isDark    = Theme.of(context).brightness == Brightness.dark;
    final border    = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final cardBg    = isDark ? AppColors.darkCard   : AppColors.lightCard;
    final secondary = isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;

    return Container(
      decoration: BoxDecoration(
        color:        cardBg,
        borderRadius: BorderRadius.circular(12),
        border:       Border.all(color: border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
          child: Row(children: [
            Icon(Icons.receipt_long_outlined, size: 15,
                color: isDark
                    ? AppColors.primary : AppColors.primaryDark),
            const SizedBox(width: 6),
            DashboardSectionTitle('Đơn hàng gần đây'),
            const Spacer(),
            _buildExportButton(),
          ]),
        ),
        Divider(height: 0, color: border),
        _orderHeader(isNarrow: isNarrow, secondary: secondary),
        Divider(height: 0, color: border),
        if (d.recentOrders.isEmpty)
          Padding(
            padding: const EdgeInsets.all(24),
            child: Center(child: Text('Không có đơn hàng',
                style: TextStyle(color: secondary))),
          )
        else
          ...d.recentOrders.map((o) => Column(children: [
            _orderRow(o, isNarrow: isNarrow, secondary: secondary),
            Divider(height: 0, color: border.withOpacity(0.5)),
          ])),
      ]),
    );
  }

  Widget _orderHeader(
      {bool isNarrow = false, required Color secondary}) {
    final s = TextStyle(
        fontSize: 11, fontWeight: FontWeight.w700, color: secondary);
    return Container(
      color:   secondary.withOpacity(0.06),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: isNarrow
          ? Row(children: [
        Expanded(flex: 3, child: Text('Mã đơn',     style: s)),
        Expanded(flex: 3, child: Text('Nguồn',      style: s)),
        Expanded(flex: 3, child: Text('Tổng tiền',  style: s)),
        Expanded(flex: 2, child: Text('Trạng thái', style: s,
            textAlign: TextAlign.center)),
      ])
          : Row(children: [
        Expanded(flex: 2, child: Text('Mã đơn',     style: s)),
        Expanded(flex: 2, child: Text('Nguồn',      style: s)),
        Expanded(flex: 2, child: Text('Thời gian',  style: s)),
        Expanded(flex: 2, child: Text('Tổng tiền',  style: s)),
        Expanded(flex: 2, child: Text('Thanh toán', style: s)),
        Expanded(flex: 2, child: Text('Trạng thái', style: s,
            textAlign: TextAlign.center)),
      ]),
    );
  }

  Widget _orderRow(PosRecentOrderModel o,
      {bool isNarrow = false, required Color secondary}) {
    final src     = _srcColor(o.orderSource);
    final sc      = statusColor(o.status);
    final pmLabel = _pmLabel(o.paymentMethod);

    return Container(
      color:   src.withOpacity(0.04),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
      child: isNarrow
          ? Row(children: [
        Expanded(flex: 3,
            child: OrderIdCell(
                code: o.orderCode, color: src, fontSize: 11)),
        Expanded(flex: 3, child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(_srcIcon(o.orderSource), size: 11, color: src),
              const SizedBox(width: 3),
              Flexible(child: Text(_srcLabel(o.orderSource),
                  style: TextStyle(
                      fontSize: 11, color: src,
                      fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis)),
            ]),
            Text(fmtDate(o.createdAt),
                style: TextStyle(fontSize: 10,
                    color: src.withOpacity(0.65))),
          ],
        )),
        Expanded(flex: 3, child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(fmtCurrency(o.finalAmount),
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700, color: src)),
            StatusBadge(label: pmLabel, color: src),
          ],
        )),
        Expanded(flex: 2, child: Center(
            child: StatusBadge(
                label: statusLabel(o.status), color: sc))),
      ])
          : Row(children: [
        Expanded(flex: 2,
            child: OrderIdCell(
                code: o.orderCode, color: src, fontSize: 12)),
        Expanded(flex: 2, child: Row(children: [
          Icon(_srcIcon(o.orderSource), size: 13, color: src),
          const SizedBox(width: 4),
          Flexible(child: Text(_srcLabel(o.orderSource),
              style: TextStyle(
                  fontSize: 11, color: src,
                  fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis)),
        ])),
        Expanded(flex: 2, child: Text(fmtDate(o.createdAt),
            style: TextStyle(fontSize: 11,
                color: src.withOpacity(0.75)))),
        Expanded(flex: 2, child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(fmtCurrency(o.finalAmount),
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700, color: src)),
            if (o.totalAmount != o.finalAmount)
              Text('Gốc: ${fmtCurrency(o.totalAmount)}',
                  style: TextStyle(
                      fontSize: 10,
                      color: src.withOpacity(0.55),
                      decoration: TextDecoration.lineThrough)),
          ],
        )),
        Expanded(flex: 2,
            child: StatusBadge(label: pmLabel, color: src)),
        Expanded(flex: 2, child: Center(
            child: StatusBadge(
                label: statusLabel(o.status), color: sc))),
      ]),
    );
  }

  // ── Error ─────────────────────────────────────────────────────
  Widget _buildError(String error) {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
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
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════════
// FILTER DEFINITIONS
// ══════════════════════════════════════════════════════════════════

class _FilterDef {
  final String value;
  final String label;
  final Color  color;
  final List<_FilterDef>? children;
  const _FilterDef({
    required this.value,
    required this.label,
    required this.color,
    this.children,
  });
}

const List<_FilterDef> _kPosChartFilters = [
  _FilterDef(value: 'ALL',           label: 'Tất cả',  color: Color(0xFF6366F1)),
  _FilterDef(
    value:    'OFFLINE_GROUP',
    label:    'Offline',
    color:    Color(0xFF2563EB),
    children: [
      _FilterDef(value: 'TAKE_AWAY', label: 'Take Away', color: Color(0xFF2563EB)),
      _FilterDef(value: 'DINE_IN',   label: 'Dine In',   color: Color(0xFF0891B2)),
    ],
  ),
  _FilterDef(
    value:    'APP_GROUP',
    label:    'App',
    color:    Color(0xFF059669),
    children: [
      _FilterDef(value: 'SHOPEE_FOOD', label: 'Shopee', color: Color(0xFFEE4D2D)),
      _FilterDef(value: 'GRAB_FOOD',   label: 'Grab',   color: Color(0xFF00B14F)),
    ],
  ),
  _FilterDef(
    value:    'CAT_GROUP',
    label:    'Loại',
    color:    Color(0xFFF59E0B),
    children: [
      _FilterDef(value: 'CAT_HOT',   label: 'Nóng',  color: Color(0xFFEF4444)),
      _FilterDef(value: 'CAT_COLD',  label: 'Lạnh',  color: Color(0xFF0EA5E9)),
      _FilterDef(value: 'CAT_COMBO', label: 'Combo', color: Color(0xFF8B5CF6)),
    ],
  ),
];

String? _posChartParentOf(String value) {
  for (final f in _kPosChartFilters) {
    if (f.children?.any((c) => c.value == value) == true) return f.value;
  }
  return null;
}

// ══════════════════════════════════════════════════════════════════
// FILTER BAR
// ══════════════════════════════════════════════════════════════════

class _PosChartFilterBar extends StatelessWidget {
  final String  current;
  final bool    isDark;
  final bool    compact;
  final void Function(String) onChanged;

  const _PosChartFilterBar({
    required this.current,
    required this.isDark,
    required this.onChanged,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final parentGroup  = _posChartParentOf(current);
    final activeParent = parentGroup ?? current;
    final activeGroup  = _kPosChartFilters
        .where((f) => f.value == activeParent && f.children != null)
        .firstOrNull;

    if (compact) {
      // Single scrollable row: groups + divider + children
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: [
          // Group chips
          ..._kPosChartFilters.map((f) {
            final isActive = f.value == activeParent;
            return Padding(
              padding: const EdgeInsets.only(right: 5),
              child: _PosFilterChip(
                label:    f.label,
                color:    f.color,
                isActive: isActive,
                isDark:   isDark,
                onTap: () => f.children == null
                    ? onChanged('ALL')
                    : onChanged(f.children!.first.value),
              ),
            );
          }),
          // Divider + child chips when group active
          if (activeGroup != null) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Container(
                width: 1, height: 20,
                color: (isDark ? Colors.white : Colors.black)
                    .withOpacity(0.15),
              ),
            ),
            ...activeGroup.children!.map((c) {
              final isActive = current == c.value;
              return Padding(
                padding: const EdgeInsets.only(right: 5),
                child: _PosFilterChip(
                  label:    c.label,
                  color:    c.color,
                  isActive: isActive,
                  isDark:   isDark,
                  isChild:  true,
                  onTap:    () => onChanged(c.value),
                ),
              );
            }),
          ],
        ]),
      );
    }

    // Two-row layout (non-compact)
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: _kPosChartFilters.map((f) {
            final isActive = f.value == activeParent;
            return Padding(
              padding: const EdgeInsets.only(right: 6),
              child: _PosFilterChip(
                label:    f.label,
                color:    f.color,
                isActive: isActive,
                isDark:   isDark,
                onTap: () => f.children == null
                    ? onChanged('ALL')
                    : onChanged(f.children!.first.value),
              ),
            );
          }).toList(),
        ),
      ),
      if (activeGroup != null) ...[
        const SizedBox(height: 6),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: activeGroup.children!.map((c) {
              final isActive = current == c.value;
              return Padding(
                padding: const EdgeInsets.only(right: 6),
                child: _PosFilterChip(
                  label:    c.label,
                  color:    c.color,
                  isActive: isActive,
                  isDark:   isDark,
                  isChild:  true,
                  onTap:    () => onChanged(c.value),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    ]);
  }
}

// ══════════════════════════════════════════════════════════════════
// FILTER CHIP
// ══════════════════════════════════════════════════════════════════

class _PosFilterChip extends StatelessWidget {
  final String       label;
  final Color        color;
  final bool         isActive;
  final bool         isDark;
  final bool         isChild;
  final VoidCallback onTap;

  const _PosFilterChip({
    required this.label,
    required this.color,
    required this.isActive,
    required this.isDark,
    required this.onTap,
    this.isChild = false,
  });

  @override
  Widget build(BuildContext context) {
    final bg     = isActive ? color : Colors.transparent;
    final border = isActive ? color : color.withOpacity(0.4);
    final fg     = isActive ? Colors.white : color;
    final size   = isChild  ? 11.0 : 12.0;
    final hPad   = isChild  ? 10.0 : 12.0;
    final vPad   = isChild  ?  5.0 :  6.0;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: EdgeInsets.symmetric(horizontal: hPad, vertical: vPad),
        decoration: BoxDecoration(
          color:        bg,
          borderRadius: BorderRadius.circular(20),
          border:       Border.all(color: border, width: 1.5),
        ),
        child: Text(label,
            style: TextStyle(
              fontSize:   size,
              fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
              color:      fg,
            )),
      ),
    );
  }
}