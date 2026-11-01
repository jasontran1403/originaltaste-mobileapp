// lib/features/dashboard/widgets/dashboard_vehicle_dropdown.dart
//
// Dùng PopupMenuButton — Flutter built-in, không có Overlay thủ công
// → không bao giờ gặp semantics/parentDataDirty crash
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/theme/app_colors.dart';
import '../../../data/models/dashboard/dashboard_vehicle_model.dart';
import '../../features/dashboard/controller/dashboard_controller.dart';

class DashboardVehicleDropdown extends ConsumerStatefulWidget {
  const DashboardVehicleDropdown({super.key});

  @override
  ConsumerState<DashboardVehicleDropdown> createState() => _DashboardVehicleDropdownState();
}

class _DashboardVehicleDropdownState extends ConsumerState<DashboardVehicleDropdown> {
  final TextEditingController _searchCtrl = TextEditingController();
  final FocusNode _searchFocus = FocusNode();

  @override
  void dispose() {
    _searchCtrl.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  void _onClose() {
    _searchCtrl.clear();
    // Reset TỨC THÌ (không qua debounce 600ms) để lần mở kế tiếp không bị
    // dính trạng thái vehicleSearching=true còn sót → tránh kẹt skeleton.
    ref.read(dashboardControllerProvider.notifier).resetVehicleSearch();
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = ref.watch(dashboardControllerProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = isDark ? AppColors.primary : AppColors.primaryDark;
    final border = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final cardBg = isDark ? AppColors.darkCard : AppColors.lightCard;
    final secondary = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    return PopupMenuButton<PosVehicle>(
      offset: const Offset(0, 38),
      color: cardBg,
      elevation: 6,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: border),
      ),
      constraints: const BoxConstraints(minWidth: 230, maxWidth: 230, minHeight: 230, maxHeight: 300),
      onOpened: () => _searchFocus.requestFocus(),
      onCanceled: _onClose,
      onSelected: (v) {
        ref.read(dashboardControllerProvider.notifier).selectVehicle(v);
        _onClose();
      },
      itemBuilder: (_) => [
        PopupMenuItem<PosVehicle>(
          enabled: false,
          padding: EdgeInsets.zero,
          child: _SearchBox(
            ctrl: ctrl,
            searchCtrl: _searchCtrl,
            searchFocus: _searchFocus,
            primary: primary,
            secondary: secondary,
            border: border,
            onChanged: (q) {
              ref.read(dashboardControllerProvider.notifier).onVehicleSearchChanged(q);
            },
          ),
        ),
        PopupMenuItem<PosVehicle>(
          enabled: false,
          padding: EdgeInsets.zero,
          height: 1,
          child: Divider(height: 1, color: border.withOpacity(0.5)),
        ),
        if (ctrl.vehicleSearching || ctrl.vehiclesLoading) ...[
          for (int i = 0; i < 3; i++)
            PopupMenuItem<PosVehicle>(
              enabled: false,
              padding: EdgeInsets.zero,
              child: _SkeletonRow(secondary: secondary),
            ),
        ] else if (ctrl.filteredVehicles.isEmpty) ...[
          PopupMenuItem<PosVehicle>(
            enabled: false,
            padding: EdgeInsets.zero,
            child: _EmptyVehicle(
              secondary: secondary,
              primary: primary,
              // Chỉ hiện nút "Thử lại" khi danh sách gốc rỗng (lỗi tải),
              // không hiện khi chỉ là kết quả tìm kiếm không khớp.
              showRetry: ctrl.vehicles.isEmpty,
              onRetry: () => ref
                  .read(dashboardControllerProvider.notifier)
                  .loadVehicles(),
            ),
          ),
        ] else ...[
          for (final v in ctrl.filteredVehicles)
            PopupMenuItem<PosVehicle>(
              value: v,
              padding: EdgeInsets.zero,
              child: _VehicleRow(
                vehicle: v,
                selected: ctrl.selectedVehicle,
                primary: primary,
                secondary: secondary,
              ),
            ),
        ],
      ],
      child: Container(
        height: 34,
        constraints: const BoxConstraints(minWidth: 120, maxWidth: 175),
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: border),
        ),
        child: Row(children: [
          Icon(Icons.directions_car_outlined, size: 15, color: secondary),
          const SizedBox(width: 6),
          Expanded(
            child: ctrl.vehiclesLoading
                ? const Center(child: SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 1.5, color: AppColors.primary)))
                : Text(
              ctrl.selectedVehicle?.name ?? 'Chọn xe',
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: ctrl.selectedVehicle != null ? null : secondary,
              ),
            ),
          ),
          Icon(Icons.arrow_drop_down, size: 18, color: secondary),
        ]),
      ),
    );
  }
}

// ── Search box (stateless — state nằm trong controller) ───────────

class _SearchBox extends StatelessWidget {
  final DashboardState        ctrl;
  final TextEditingController searchCtrl;
  final FocusNode             searchFocus;
  final Color                 primary;
  final Color                 secondary;
  final Color                 border;
  final ValueChanged<String>  onChanged;

  const _SearchBox({
    required this.ctrl,
    required this.searchCtrl,
    required this.searchFocus,
    required this.primary,
    required this.secondary,
    required this.border,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: TextField(
        controller: searchCtrl,
        focusNode:  searchFocus,
        autofocus:  true,
        style: const TextStyle(fontSize: 12),
        decoration: InputDecoration(
          hintText: 'Tìm xe...',
          prefixIcon: SizedBox(
            width: 32,
            child: Center(
              child: ctrl.vehicleSearching
                  ? SizedBox(
                  width: 14, height: 14,
                  child: CircularProgressIndicator(
                      strokeWidth: 1.5, color: primary))
                  : Icon(Icons.search, size: 16, color: secondary),
            ),
          ),
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
              horizontal: 10, vertical: 8),
        ),
        onChanged: onChanged,
      ),
    );
  }
}

// ── Skeleton row ──────────────────────────────────────────────────

class _SkeletonRow extends StatelessWidget {
  final Color secondary;
  const _SkeletonRow({required this.secondary});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      child: Row(children: [
        Container(
          width: 28, height: 28,
          decoration: BoxDecoration(
            color:        secondary.withOpacity(0.12),
            borderRadius: BorderRadius.circular(5),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 10,
              decoration: BoxDecoration(
                color:        secondary.withOpacity(0.12),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 5),
            Container(
              height: 8, width: 100,
              decoration: BoxDecoration(
                color:        secondary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ],
        )),
      ]),
    );
  }
}

// ── Empty ─────────────────────────────────────────────────────────

class _EmptyVehicle extends StatelessWidget {
  final Color secondary;
  final Color primary;
  final bool showRetry;
  final VoidCallback? onRetry;

  const _EmptyVehicle({
    required this.secondary,
    this.primary = const Color(0xFF16A34A),
    this.showRetry = false,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(
          showRetry ? Icons.cloud_off_rounded : Icons.search_off,
          size: 28,
          color: secondary.withOpacity(0.4),
        ),
        const SizedBox(height: 6),
        Text(
          showRetry ? 'Chưa tải được danh sách xe' : 'Không tìm thấy xe',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, color: secondary),
        ),
        if (showRetry && onRetry != null) ...[
          const SizedBox(height: 10),
          InkWell(
            onTap: onRetry,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.refresh_rounded, size: 15, color: primary),
                const SizedBox(width: 5),
                Text('Thử lại',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: primary)),
              ]),
            ),
          ),
        ],
      ]),
    );
  }
}

// ── Vehicle row ───────────────────────────────────────────────────

class _VehicleRow extends StatelessWidget {
  final PosVehicle  vehicle;
  final PosVehicle? selected;
  final Color       primary;
  final Color       secondary;

  const _VehicleRow({
    required this.vehicle,
    required this.selected,
    required this.primary,
    required this.secondary,
  });

  @override
  Widget build(BuildContext context) {
    final isSel = selected?.id == vehicle.id;
    return Container(
      color:   isSel ? primary.withOpacity(0.10) : null,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      child: Row(children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(5),
          child: vehicle.avatarUrl != null
              ? Image.network(
            vehicle.avatarUrl!,
            width: 28, height: 28, fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _placeholder(),
          )
              : _placeholder(),
        ),
        const SizedBox(width: 8),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              vehicle.name,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize:   12,
                fontWeight: isSel ? FontWeight.w700 : FontWeight.w500,
                color:      isSel ? primary : null,
              ),
            ),
            if (vehicle.address != null)
              Text(
                vehicle.address!,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 10, color: secondary),
              ),
          ],
        )),
        if (isSel) Icon(Icons.check_circle, size: 15, color: primary),
      ]),
    );
  }

  Widget _placeholder() => Container(
    width: 28, height: 28,
    decoration: BoxDecoration(
      color:        primary.withOpacity(0.1),
      borderRadius: BorderRadius.circular(5),
    ),
    child: Icon(Icons.directions_car_outlined, size: 16, color: primary),
  );
}