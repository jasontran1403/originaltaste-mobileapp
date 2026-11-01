// lib/features/settings/screens/settings_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/theme_controller.dart';
import '../../auth/controller/auth_controller.dart';
import '../../../shared/widgets/app_toast.dart';
import '../../../core/constants/api_constants.dart';
import '../../../data/storage/session_storage.dart';
import 'package:dio/dio.dart';
import 'package:originaltaste/services/pos_printer_service.dart';
import 'change_password_screen.dart';
import 'printer_test_screen.dart';

class _VersionInfo {
  final String currentVersion;
  final int    currentBuild;
  final String latestVersion;
  final int    latestBuild;
  final String message;

  const _VersionInfo({
    required this.currentVersion,
    required this.currentBuild,
    required this.latestVersion,
    required this.latestBuild,
    this.message = '',
  });

  String get currentDisplay => '$currentVersion($currentBuild)';
  String get latestDisplay  => '$latestVersion($latestBuild)';
  bool get isMajorUpdate    =>
      message.contains('Major update:') || message.contains('quan trọng');
  String get majorMessage   =>
      isMajorUpdate ? message.replaceFirst('Major update:', '').trim() : message;
}

final _versionInfoProvider = FutureProvider<_VersionInfo?>((ref) async {
  String currentVersion = '';
  int    currentBuild   = 0;
  try {
    final packageInfo = await PackageInfo.fromPlatform();
    currentVersion = packageInfo.version.isNotEmpty
        ? packageInfo.version : currentVersion;
    currentBuild = int.tryParse(packageInfo.buildNumber) ?? currentBuild;
  } catch (e) {
    print('[VERSION] PackageInfo error (cần rebuild): $e');
  }

  try {
    final token = await SessionStorage.getAccessToken();
    final dio = Dio(BaseOptions(
      baseUrl: ApiConstants.baseUrl,
      connectTimeout: const Duration(seconds: 8),
      receiveTimeout: const Duration(seconds: 8),
      headers: {
        if (token != null) 'Authorization': 'Bearer $token',
      },
    ));

    final resp = await dio.get(
      '/api/auth/fetch-version',
      queryParameters: {
        'platform': 'ios',
        'version': currentVersion,
        'build':   currentBuild,
      },
    );
    final data = resp.data?['data'];

    return _VersionInfo(
      currentVersion: currentVersion,
      currentBuild:   currentBuild,
      latestVersion:  data?['latestVersion'] ?? currentVersion,
      latestBuild:    data?['latestBuild']   ?? currentBuild,
      message:        data?['message']       ?? '',
    );
  } catch (e) {
    print('[VERSION] API error: $e');
    return _VersionInfo(
      currentVersion: currentVersion,
      currentBuild:   currentBuild,
      latestVersion:  currentVersion,
      latestBuild:    currentBuild,
      message:        '',
    );
  }
});

// ══════════════════════════════════════════════════════════════════════════════
// SETTINGS SCREEN
// ══════════════════════════════════════════════════════════════════════════════

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark       = Theme.of(context).brightness == Brightness.dark;
    final themeCtrl    = ref.watch(themeControllerProvider.notifier);
    final authState    = ref.watch(authControllerProvider);
    final versionAsync = ref.watch(_versionInfoProvider);

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Cài đặt', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 4),
              Text('Tuỳ chỉnh ứng dụng',
                  style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 28),

              // ── Profile card ───────────────────────────────────────
              _SettingsCard(
                isDark: isDark,
                child: Row(children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: AppColors.primary.withOpacity(0.2),
                    child: const Icon(Icons.person_rounded,
                        color: AppColors.primary, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(authState.fullName ?? '---',
                          style: Theme.of(context).textTheme.titleMedium),
                      Text(
                        authState.role?.rawValue ?? '',
                        style: Theme.of(context)
                            .textTheme.bodySmall
                            ?.copyWith(color: AppColors.primary),
                      ),
                    ],
                  )),
                ]),
              ),
              const SizedBox(height: 16),

              // ── Theme toggle ───────────────────────────────────────
              _SettingsCard(
                isDark: isDark,
                child: Row(children: [
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 350),
                    transitionBuilder: (child, anim) => RotationTransition(
                      turns: anim,
                      child: FadeTransition(opacity: anim, child: child),
                    ),
                    child: Icon(
                      isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                      key: ValueKey(isDark),
                      color: isDark ? AppColors.primary : Colors.amber,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(child: Text(
                    isDark ? 'Chế độ tối' : 'Chế độ sáng',
                    style: Theme.of(context).textTheme.bodyLarge,
                  )),
                  _AnimatedThemeToggle(
                    isDark: isDark,
                    onToggle: () => themeCtrl.toggle(),
                  ),
                ]),
              ),
              const SizedBox(height: 16),

              // ── Nhóm bảo mật ───────────────────────────────────────
              _SectionLabel(label: 'Bảo mật', isDark: isDark),
              const SizedBox(height: 8),

              // Dòng 1: Đổi mật khẩu
              _SettingsCard(
                isDark: isDark,
                child: _SettingsRow(
                  icon:    Icons.lock_reset_rounded,
                  iconBg:  AppColors.primary.withOpacity(0.12),
                  iconColor: AppColors.primary,
                  label:   'Đổi mật khẩu',
                  subtitle: 'Thay đổi mật khẩu tài khoản',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const ChangePasswordScreen()),
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // Dòng 2: Đổi mật khẩu quản lý
              _SettingsCard(
                isDark: isDark,
                child: _SettingsRow(
                  icon:     Icons.admin_panel_settings_rounded,
                  iconBg:   Colors.orange.withOpacity(0.12),
                  iconColor: Colors.orange,
                  label:    'Đổi mật khẩu quản lý',
                  subtitle:  'Chỉ dành cho quản trị viên',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const ChangeAdminPasswordScreen()),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // ── Nhóm máy in ────────────────────────────────────────
              _SectionLabel(label: 'Máy in', isDark: isDark),
              const SizedBox(height: 8),

              // Dòng 3: Test máy in
              _SettingsCard(
                isDark: isDark,
                child: _SettingsRow(
                  icon:     Icons.print_rounded,
                  iconBg:   Colors.teal.withOpacity(0.12),
                  iconColor: Colors.teal,
                  label:    'Test máy in',
                  subtitle:  PrinterConfig.isConnected
                      ? 'Đã kết nối: ${PrinterConfig.savedIp}'
                      : 'Chưa kết nối — nhấn để thiết lập',
                  trailingWidget: PrinterConfig.isConnected
                      ? Container(
                    width: 8, height: 8,
                    decoration: const BoxDecoration(
                        color: Colors.green, shape: BoxShape.circle),
                  )
                      : null,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const PrinterTestScreen()),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // ── Version card ───────────────────────────────────────
              _SettingsCard(
                isDark: isDark,
                child: versionAsync.when(
                  loading: () => Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _VersionRow(
                        isDark: isDark, context: context,
                        icon:    Icons.phone_android_rounded,
                        label:   'Phiên bản hiện tại',
                        value:   '...',
                        loading: true,
                      ),
                      const SizedBox(height: 12),
                      Divider(height: 1,
                          color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                      const SizedBox(height: 12),
                      _VersionRow(
                        isDark: isDark, context: context,
                        icon:    Icons.cloud_download_outlined,
                        label:   'Phiên bản mới nhất',
                        value:   '...',
                        loading: true,
                      ),
                    ],
                  ),
                  error: (e, __) {
                    print('[VERSION] provider error: $e');
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _VersionRow(
                          isDark: isDark, context: context,
                          icon:  Icons.phone_android_rounded,
                          label: 'Phiên bản hiện tại',
                          value: 'Lỗi tải',
                        ),
                        const SizedBox(height: 12),
                        Divider(height: 1,
                            color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                        const SizedBox(height: 12),
                        _VersionRow(
                          isDark: isDark, context: context,
                          icon:  Icons.cloud_off_outlined,
                          label: 'Phiên bản mới nhất',
                          value: 'Không xác định',
                        ),
                      ],
                    );
                  },
                  data: (info) {
                    if (info == null) {
                      return _VersionRow(
                        isDark: isDark, context: context,
                        icon:  Icons.phone_android_rounded,
                        label: 'Phiên bản',
                        value: 'Không thể tải',
                      );
                    }
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _VersionRow(
                          isDark: isDark, context: context,
                          icon:  Icons.phone_android_rounded,
                          label: 'Phiên bản hiện tại',
                          value: info.currentDisplay,
                        ),
                        const SizedBox(height: 12),
                        Divider(height: 1,
                            color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                        const SizedBox(height: 12),
                        _VersionRow(
                          isDark:     isDark,
                          context:    context,
                          icon:       Icons.cloud_done_outlined,
                          label:      'Phiên bản mới nhất',
                          value:      info.latestDisplay,
                          subMessage: info.message.isNotEmpty ? info.majorMessage : null,
                          subIsRed:   info.isMajorUpdate,
                        ),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),

              // ── Logout ─────────────────────────────────────────────
              _SettingsCard(
                isDark: isDark,
                child: InkWell(
                  onTap: () => _confirmLogout(context, ref),
                  borderRadius: BorderRadius.circular(12),
                  child: Row(children: [
                    Icon(Icons.logout_rounded, color: AppColors.error, size: 22),
                    const SizedBox(width: 14),
                    Text('Đăng xuất',
                        style: Theme.of(context).textTheme.bodyLarge
                            ?.copyWith(color: AppColors.error)),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmLogout(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? AppColors.darkCard : AppColors.lightCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title:   const Text('Đăng xuất'),
        content: const Text('Bạn có chắc chắn muốn đăng xuất?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Huỷ'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              minimumSize: const Size(80, 36),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              await ref.read(authControllerProvider.notifier).logout();
              if (context.mounted) {
                AppToast.success(context, 'Đã đăng xuất');
                context.go('/login');
              }
            },
            child: const Text('Đăng xuất'),
          ),
        ],
      ),
    );
  }
}

// ── Section label ─────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String label;
  final bool   isDark;
  const _SectionLabel({required this.label, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
          color: isDark
              ? const Color(0xFF64748B)
              : const Color(0xFF94A3B8),
        ),
      ),
    );
  }
}

// ── Settings row ──────────────────────────────────────────────────────────────

class _SettingsRow extends StatelessWidget {
  final IconData   icon;
  final Color      iconBg;
  final Color      iconColor;
  final String     label;
  final String?    subtitle;
  final Widget?    trailingWidget;
  final VoidCallback onTap;

  const _SettingsRow({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.label,
    this.subtitle,
    this.trailingWidget,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Row(
        children: [
          Container(
            width: 38, height: 38,
            decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: Theme.of(context).textTheme.bodyLarge),
                if (subtitle != null)
                  Text(subtitle!,
                      style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          if (trailingWidget != null) ...[
            trailingWidget!,
            const SizedBox(width: 8),
          ],
          Icon(Icons.chevron_right_rounded,
              size: 18,
              color: Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xFF475569)
                  : const Color(0xFFCBD5E1)),
        ],
      ),
    );
  }
}

// ── Version row widget ────────────────────────────────────────────────────────

class _VersionRow extends StatelessWidget {
  final bool      isDark;
  final IconData  icon;
  final String    label;
  final String    value;
  final BuildContext context;
  final bool      loading;
  final String?   subMessage;
  final bool      subIsRed;

  const _VersionRow({
    required this.isDark,
    required this.icon,
    required this.label,
    required this.value,
    required this.context,
    this.loading    = false,
    this.subMessage,
    this.subIsRed   = false,
  });

  @override
  Widget build(BuildContext ctx) {
    final secondary = isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Icon(icon, size: 20, color: AppColors.primary),
          const SizedBox(width: 14),
          Expanded(child: Text(label,
              style: Theme.of(context).textTheme.bodyLarge)),
          if (loading)
            SizedBox(
              width: 14, height: 14,
              child: CircularProgressIndicator(
                  strokeWidth: 1.5, color: secondary),
            )
          else
            Text(value,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: secondary,
                )),
        ]),
        if (subMessage != null && subMessage!.isNotEmpty) ...[
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(left: 34),
            child: Text(
              subMessage!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color:     subIsRed ? AppColors.error : secondary,
                fontStyle: subIsRed ? FontStyle.italic : FontStyle.normal,
                fontSize:  11,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

// ── Settings card ─────────────────────────────────────────────────────────────

class _SettingsCard extends StatelessWidget {
  final bool   isDark;
  final Widget child;
  const _SettingsCard({required this.isDark, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      ),
      child: child,
    );
  }
}

// ── Animated theme toggle ─────────────────────────────────────────────────────

class _AnimatedThemeToggle extends StatefulWidget {
  final bool         isDark;
  final VoidCallback onToggle;
  const _AnimatedThemeToggle({required this.isDark, required this.onToggle});

  @override
  State<_AnimatedThemeToggle> createState() => _AnimatedThemeToggleState();
}

class _AnimatedThemeToggleState extends State<_AnimatedThemeToggle>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double>   _slideAnim;
  late Animation<Color?>   _bgAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
      value: widget.isDark ? 1.0 : 0.0,
    );
    _slideAnim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOutCubic);
    _bgAnim = ColorTween(
      begin: const Color(0xFFE5E7EB),
      end:   AppColors.primary,
    ).animate(_ctrl);
  }

  @override
  void didUpdateWidget(_AnimatedThemeToggle old) {
    super.didUpdateWidget(old);
    if (old.isDark != widget.isDark) {
      widget.isDark ? _ctrl.forward() : _ctrl.reverse();
    }
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onToggle,
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, __) => Container(
          width: 50, height: 28,
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: _bgAnim.value,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Align(
            alignment: Alignment.lerp(
                Alignment.centerLeft, Alignment.centerRight, _slideAnim.value)!,
            child: Container(
              width: 22, height: 22,
              decoration: const BoxDecoration(
                  color: Colors.white, shape: BoxShape.circle),
            ),
          ),
        ),
      ),
    );
  }
}