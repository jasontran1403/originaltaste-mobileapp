// lib/main.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'app/router/app_router.dart';
import 'app/theme/app_theme.dart';
import 'app/theme/theme_controller.dart';
import 'data/network/dio_client.dart';
import 'features/auth/controller/auth_controller.dart';
import 'shared/widgets/session_expired_toast.dart';
import 'core/network/slow_api_interceptor.dart';
import 'core/speed_test/speed_test_overlay.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await initializeDateFormatting('vi', null);

  // ── Orientation: portrait + landscape ────────────────────────
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  // ── Init DioClient ────────────────────────────────────────────
  DioClient.instance.init();

  // Container gốc: dùng chung cho app + handler token-expired.
  final container = ProviderContainer();

  DioClient.instance.addInterceptor(SlowApiInterceptor(container));

  // ── Token hết hạn / thiếu Authorization (401/403/923) ─────────
  // Áp dụng CHUNG cho mọi API cần JWT. Nhiều API có thể cùng 401 một lúc →
  // SessionExpiredToast tự chống trùng, chỉ hiện MỘT toast.
  DioClient.instance.setOnTokenExpired(() async {
    final overlay = rootNavigatorKey.currentState?.overlay;

    // Chưa có overlay (hiếm) → clear + để router lo.
    if (overlay == null) {
      await container.read(authControllerProvider.notifier).logout();
      final c = rootNavigatorKey.currentContext;
      if (c != null && c.mounted) c.go('/login');
      return;
    }

    SessionExpiredToast.show(
      overlay,
      onResolve: () async {
        // Ẩn toast (hết 5s hoặc click) → clear storage + về login.
        await container.read(authControllerProvider.notifier).logout();
        final c = rootNavigatorKey.currentContext;
        if (c != null && c.mounted) c.go('/login');
      },
    );
  });

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const OriginalTasteApp(),
    ),
  );
}

class OriginalTasteApp extends ConsumerWidget {
  const OriginalTasteApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router    = ref.watch(routerProvider);
    final themeMode = ref.watch(themeControllerProvider);

    return MaterialApp.router(
      title:            'Original Taste',
      debugShowCheckedModeBanner: false,
      theme:      AppTheme.light,
      darkTheme:  AppTheme.dark,
      themeMode:  themeMode,
      routerConfig: router,
      builder: (context, child) {
        return SpeedTestOverlay(
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}