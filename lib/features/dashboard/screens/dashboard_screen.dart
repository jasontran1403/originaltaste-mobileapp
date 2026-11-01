// lib/features/dashboard/screens/dashboard_screen.dart

import 'dart:io';

import 'package:dio/dio.dart';
import 'package:file_saver/file_saver.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/enums/user_role.dart';
import '../../../data/models/dashboard/dashboard_period.dart';
import '../../../data/storage/session_storage.dart';
import '../../../features/auth/controller/auth_controller.dart';
import '../../../services/file_helper.dart';
import '../../../shared/widgets/dashboard_pos_content.dart';
import '../../../shared/widgets/dashboard_shared_widgets.dart';
import '../../../shared/widgets/dashboard_vehicle_dropdown.dart';
import '../controller/dashboard_controller.dart';
import '../widgets/dashboard_restaurant_content.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen>
    with WidgetsBindingObserver {

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(dashboardControllerProvider.notifier).reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    final role         = ref.watch(authControllerProvider).role ?? UserRole.admin;
    final ctrl         = ref.watch(dashboardControllerProvider);
    final notifier     = ref.read(dashboardControllerProvider.notifier);
    final isSuperAdmin = role == UserRole.superAdmin;

    return Scaffold(
      body: Column(children: [
        const SizedBox(height: 40),
        _TopBar(
          ctrl:         ctrl,
          notifier:     notifier,
          isSuperAdmin: isSuperAdmin,
        ),
        const Divider(height: 0),
        Expanded(child: _buildContent(ctrl)),
      ]),
    );
  }

  Widget _buildContent(DashboardState ctrl) {
    return switch (ctrl.mode) {
      DashboardMode.pos       => const DashboardPosContent(),
      DashboardMode.wholesale => const DashboardRestaurantContent(),
      DashboardMode.retail    => const DashboardRestaurantContent(),
    };
  }
}

// ══════════════════════════════════════════════════════════════════
// TOP BAR
// ══════════════════════════════════════════════════════════════════

class _TopBar extends ConsumerStatefulWidget {
  final DashboardState      ctrl;
  final DashboardController notifier;
  final bool                isSuperAdmin;

  const _TopBar({
    required this.ctrl,
    required this.notifier,
    required this.isSuperAdmin,
  });

  @override
  ConsumerState<_TopBar> createState() => _TopBarState();
}

class _TopBarState extends ConsumerState<_TopBar> {
  bool _isExporting    = false;
  bool _isExportingIng = false;

  // ── Tính khoảng ngày thực tế ──────────────────────────────────
  (DateTime, DateTime) _resolveRange() {
    final ctrl = widget.ctrl;
    final now  = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    return switch (ctrl.period) {
      DashboardPeriod.today => (
      today,
      DateTime(now.year, now.month, now.day, 23, 59, 59),
      ),
      DashboardPeriod.days7 => (
      today.subtract(const Duration(days: 6)),
      DateTime(now.year, now.month, now.day, 23, 59, 59),
      ),
      DashboardPeriod.days28 => (
      today.subtract(const Duration(days: 27)),
      DateTime(now.year, now.month, now.day, 23, 59, 59),
      ),
      DashboardPeriod.days30 => (
      today.subtract(const Duration(days: 29)),
      DateTime(now.year, now.month, now.day, 23, 59, 59),
      ),
      DashboardPeriod.months3 => (
      DateTime(now.year, now.month - 3, 1),
      DateTime(now.year, now.month, now.day, 23, 59, 59),
      ),
      DashboardPeriod.months6 => (
      DateTime(now.year, now.month - 6, 1),
      DateTime(now.year, now.month, now.day, 23, 59, 59),
      ),
      DashboardPeriod.year => (
      DateTime(now.year, now.month - 11, 1),
      DateTime(now.year, now.month, now.day, 23, 59, 59),
      ),
      DashboardPeriod.custom => (
      ctrl.customFrom ?? today,
      ctrl.customTo ?? DateTime(now.year, now.month, now.day, 23, 59, 59),
      ),
    };
  }

  // ── Date Range Badge ──────────────────────────────────────────
  Widget _buildDateRangeBadge() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final secondary = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final border = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final (from, to) = _resolveRange();
    final fmt = DateFormat('dd/MM/yyyy');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: border),
        color: (isDark ? Colors.white : Colors.black).withOpacity(0.04),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.date_range_outlined,
              size: 12, color: secondary),
          const SizedBox(width: 5),
          Text(
            '${fmt.format(from)} → ${fmt.format(to)}',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isDark
                  ? AppColors.darkTextPrimary.withOpacity(0.8)
                  : AppColors.lightTextPrimary.withOpacity(0.75),
            ),
          ),
        ],
      ),
    );
  }

  // ── Export đơn hàng (giữ nguyên logic cũ) ────────────────────
  Future<void> _exportOrders() async {
    if (_isExporting) return;
    setState(() => _isExporting = true);

    try {
      final ctrl = widget.ctrl;
      final params = <String, dynamic>{
        'period': _periodStr(ctrl.period),
      };

      if (ctrl.period == DashboardPeriod.custom) {
        if (ctrl.customFrom != null) params['fromTs'] = ctrl.customFrom!.millisecondsSinceEpoch;
        if (ctrl.customTo   != null) params['toTs']   = ctrl.customTo!.millisecondsSinceEpoch;
      }

      final token = await SessionStorage.getAccessToken();
      final dio = Dio(BaseOptions(
        baseUrl:        ApiConstants.baseUrl,
        receiveTimeout: const Duration(seconds: 90),
        connectTimeout: const Duration(seconds: 15),
        headers: {if (token != null) 'Authorization': 'Bearer $token'},
      ));

      if (widget.isSuperAdmin) {
        String endpoint = '/api/superadmin/dashboard/pos/export';
        if (ctrl.mode == DashboardMode.wholesale || ctrl.mode == DashboardMode.retail) {
          endpoint = '/api/superadmin/dashboard/restaurant/export';
          params['mode'] = ctrl.mode == DashboardMode.wholesale ? 'wholesale' : 'retail';
        }
        if (ctrl.mode == DashboardMode.pos && ctrl.selectedVehicle != null) {
          params['storeId'] = ctrl.selectedVehicle!.id;
        }

        final response = await dio.get(endpoint, queryParameters: params);
        if (response.statusCode == 200) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Row(children: [
              Icon(Icons.telegram, color: Colors.white, size: 18),
              SizedBox(width: 8),
              Expanded(child: Text('Báo cáo đang được tạo và gửi vào Telegram...')),
            ]),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ));
        }
      } else {
        final response = await dio.get(
          '/api/admin/dashboard/pos/export',
          queryParameters: params,
          options: Options(responseType: ResponseType.bytes),
        );
        if (response.statusCode == 200) {
          await saveFile(
            response: response,
            context:  context,
            fallbackName: 'pos_orders_report',
          );
        } else {
          _snackError('Lỗi server: ${response.statusCode}');
        }
      }
    } on DioException catch (e) {
      _snackError('Lỗi tải file: ${e.message}');
    } catch (e) {
      _snackError('Lỗi export: $e');
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  // ── Export nguyên liệu ────────────────────────────────────────
  Future<void> _exportIngredients() async {
    if (_isExportingIng) return;
    setState(() => _isExportingIng = true);

    try {
      final ctrl   = widget.ctrl;
      final params = <String, dynamic>{
        'period': _periodStr(ctrl.period),
      };

      if (ctrl.period == DashboardPeriod.custom) {
        if (ctrl.customFrom != null) params['fromTs'] = ctrl.customFrom!.millisecondsSinceEpoch;
        if (ctrl.customTo   != null) params['toTs']   = ctrl.customTo!.millisecondsSinceEpoch;
      }
      if (ctrl.mode == DashboardMode.wholesale || ctrl.mode == DashboardMode.retail) {
        params['mode'] = ctrl.mode == DashboardMode.wholesale ? 'wholesale' : 'retail';
      }

      final token = await SessionStorage.getAccessToken();
      final dio = Dio(BaseOptions(
        baseUrl:        ApiConstants.baseUrl,
        receiveTimeout: const Duration(seconds: 90),
        connectTimeout: const Duration(seconds: 15),
        headers: {if (token != null) 'Authorization': 'Bearer $token'},
      ));

      final response = await dio.get(
        '/api/superadmin/dashboard/restaurant/export-ingredients',
        queryParameters: params,
      );
      if (response.statusCode == 200 && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Row(children: [
            Icon(Icons.telegram, color: Colors.white, size: 18),
            SizedBox(width: 8),
            Expanded(child: Text('Báo cáo nguyên liệu đang được gửi vào Telegram...')),
          ]),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } on DioException catch (e) {
      _snackError('Lỗi export nguyên liệu: ${e.message}');
    } catch (e) {
      _snackError('Lỗi export nguyên liệu: $e');
    } finally {
      if (mounted) setState(() => _isExportingIng = false);
    }
  }

  // ── Nút Export ────────────────────────────────────────────────
  Widget _buildExportButton() {
    final isDark  = Theme.of(context).brightness == Brightness.dark;
    final primary = isDark ? AppColors.primary : AppColors.primaryDark;
    final ctrl    = widget.ctrl;

    final isRestaurantMode =
        ctrl.mode == DashboardMode.wholesale ||
            ctrl.mode == DashboardMode.retail;

    final isBusy = _isExporting || _isExportingIng;

    if (!isRestaurantMode) {
      final icon = widget.isSuperAdmin
          ? Icons.send_outlined
          : Icons.file_download_outlined;

      return SizedBox(
        height: 32,
        child: isBusy
            ? _loadingBtn(primary)
            : OutlinedButton.icon(
          icon:  Icon(icon, size: 15, color: primary),
          label: Text('Export',
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

    return SizedBox(
      height: 32,
      child: isBusy
          ? _loadingBtn(primary)
          : MenuAnchor(
        style: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(
              isDark ? AppColors.darkCard : Colors.white),
          shape: WidgetStatePropertyAll(RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10))),
          elevation: const WidgetStatePropertyAll(4),
        ),
        menuChildren: [
          MenuItemButton(
            leadingIcon: Icon(
              widget.isSuperAdmin
                  ? Icons.send_outlined
                  : Icons.file_download_outlined,
              size: 16, color: primary,
            ),
            onPressed: _isExporting ? null : _exportOrders,
            child: Row(children: [
              Text('Export đơn hàng',
                  style: TextStyle(
                      fontSize: 13,
                      color: isDark
                          ? AppColors.darkTextPrimary
                          : AppColors.lightTextPrimary)),
              if (_isExporting) ...[
                const SizedBox(width: 8),
                SizedBox(
                  width: 12, height: 12,
                  child: CircularProgressIndicator(
                      strokeWidth: 1.5, color: primary),
                ),
              ],
            ]),
          ),
          MenuItemButton(
            leadingIcon: Icon(Icons.science_outlined,
                size: 16, color: primary),
            onPressed: _isExportingIng ? null : _exportIngredients,
            child: Row(children: [
              Text('Export nguyên liệu',
                  style: TextStyle(
                      fontSize: 13,
                      color: isDark
                          ? AppColors.darkTextPrimary
                          : AppColors.lightTextPrimary)),
              if (_isExportingIng) ...[
                const SizedBox(width: 8),
                SizedBox(
                  width: 12, height: 12,
                  child: CircularProgressIndicator(
                      strokeWidth: 1.5, color: primary),
                ),
              ],
            ]),
          ),
        ],
        builder: (_, menuCtrl, __) => OutlinedButton.icon(
          icon:  Icon(Icons.file_download_outlined,
              size: 15, color: primary),
          label: Row(mainAxisSize: MainAxisSize.min, children: [
            Text('Export',
                style: TextStyle(fontSize: 11, color: primary,
                    fontWeight: FontWeight.w600)),
            const SizedBox(width: 2),
            Icon(Icons.arrow_drop_down_rounded,
                size: 16, color: primary),
          ]),
          style: OutlinedButton.styleFrom(
            side:    BorderSide(color: primary.withOpacity(0.5)),
            padding: const EdgeInsets.symmetric(horizontal: 10),
            shape:   RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8)),
          ),
          onPressed: menuCtrl.open,
        ),
      ),
    );
  }

  Widget _loadingBtn(Color primary) => OutlinedButton.icon(
    icon: SizedBox(
        width: 13, height: 13,
        child: CircularProgressIndicator(strokeWidth: 2, color: primary)),
    label: Text('Đang tạo...',
        style: TextStyle(fontSize: 11, color: primary)),
    style: OutlinedButton.styleFrom(
      side:    BorderSide(color: primary.withOpacity(0.3)),
      padding: const EdgeInsets.symmetric(horizontal: 10),
      shape:   RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
    onPressed: null,
  );

  void _snackError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content:         Text(msg),
      backgroundColor: Colors.red.shade700,
      behavior:        SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

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

  // ══════════════════════════════════════════════════════════════
  // BUILD — layout chính
  // ══════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final ctrl = widget.ctrl;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.isSuperAdmin) ...[
            // ── Row 1: Mode toggle + Vehicle + Date Range Badge ──
            Wrap(
              spacing: 12,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                DashboardModeToggle(
                  selected:  ctrl.mode.index,
                  onChanged: (i) =>
                      widget.notifier.setMode(DashboardMode.values[i]),
                ),
                if (ctrl.mode == DashboardMode.pos)
                  const DashboardVehicleDropdown(),
                _buildDateRangeBadge(),     // ← Date range ở đây
              ],
            ),
            const SizedBox(height: 12),
          ] else ...[
            // ── Non-SuperAdmin: Date range badge riêng 1 dòng ───
            _buildDateRangeBadge(),
            const SizedBox(height: 10),
          ],
          // ── Row 2: Period filter + Export ──────────────────────
          Row(children: [
            Expanded(
              child: DashboardPeriodFilter(
                selected:   ctrl.period,
                customFrom: ctrl.customFrom,
                customTo:   ctrl.customTo,
                onSelect:   (p) => widget.notifier.setPeriod(p),
                onCustom: (from, to) => widget.notifier.setPeriod(
                  DashboardPeriod.custom,
                  from: from,
                  to:   to,
                ),
                rollingWindow: ctrl.rollingWindow,
                onRollingSelect: (widget.isSuperAdmin &&
                    ctrl.mode == DashboardMode.pos)
                    ? (w) => widget.notifier.setRollingWindow(w)
                    : null,
              ),
            ),
            const SizedBox(width: 8),
            _buildExportButton(),
          ]),
        ],
      ),
    );
  }
}
