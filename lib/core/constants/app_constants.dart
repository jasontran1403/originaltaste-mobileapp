// lib/core/constants/app_constants.dart

class AppConstants {
  AppConstants._();

  static const String appName        = 'Original Taste';
  static const String appPackage     = 'com.originaltaste.app';

  // ── Tab transition timing ─────────────────────────────────────
  static const Duration tabLoadingDuration  = Duration(seconds: 1);
  static const Duration skeletonMinDuration = Duration(milliseconds: 600);

  // ── Toast ─────────────────────────────────────────────────────
  static const Duration toastDuration = Duration(milliseconds: 1800);

  // ── Welcome screen ────────────────────────────────────────────
  static const Duration welcomeDuration = Duration(milliseconds: 2800);

  // ── Intro video ───────────────────────────────────────────────
  static const String introVideoPath = 'assets/videos/intro.mp4';

  // ── Assets ───────────────────────────────────────────────────
  static const String logoPath = 'assets/images/logo.png';

  // ── Image cache ───────────────────────────────────────────────
  static const int imageCacheMaxWidth  = 800;
  static const int imageCacheMaxHeight = 800;

  // ── Responsive breakpoints ────────────────────────────────────
  static const double mobileMaxWidth  = 600;
  static const double tabletMaxWidth  = 1024;
}
