// lib/features/auth/screens/welcome_screen.dart

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/enums/nav_item.dart';
import '../../../core/enums/user_role.dart';

class WelcomeScreen extends StatefulWidget {
  final UserRole role;
  const WelcomeScreen({super.key, required this.role});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with TickerProviderStateMixin {

  late AnimationController _entryCtrl;
  late AnimationController _pulseCtrl;
  late AnimationController _floatCtrl;
  late AnimationController _foodImgCtrl;
  late AnimationController _exitCtrl;

  late Animation<double> _logoScale;
  late Animation<double> _logoOpacity;
  late Animation<Offset> _textSlide;
  late Animation<double> _textOpacity;
  late Animation<double> _badgeOffset;
  late Animation<double> _pulse;
  late Animation<double> _exitFade;

  late _RoleTheme _theme;

  @override
  void initState() {
    super.initState();
    _theme = _RoleTheme.forRole(widget.role);

    _entryCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
    _logoScale = Tween<double>(begin: 0.3, end: 1.0).animate(
        CurvedAnimation(parent: _entryCtrl, curve: Curves.elasticOut));
    _logoOpacity = Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(parent: _entryCtrl, curve: const Interval(0.0, 0.5, curve: Curves.easeOut)));
    _textSlide = Tween<Offset>(begin: const Offset(0, 0.4), end: Offset.zero).animate(
        CurvedAnimation(parent: _entryCtrl, curve: const Interval(0.3, 1.0, curve: Curves.easeOut)));
    _textOpacity = Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(parent: _entryCtrl, curve: const Interval(0.3, 0.9, curve: Curves.easeOut)));
    _badgeOffset = Tween<double>(begin: 16, end: 0).animate(
        CurvedAnimation(parent: _entryCtrl, curve: const Interval(0.5, 1.0, curve: Curves.easeOut)));

    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat(reverse: true);
    _pulse = Tween<double>(begin: 0.95, end: 1.08).animate(
        CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));

    _floatCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 6))..repeat();
    _foodImgCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 4))..repeat();

    _exitCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _exitFade = Tween<double>(begin: 1, end: 0).animate(
        CurvedAnimation(parent: _exitCtrl, curve: Curves.easeIn));

    _start();
  }

  Future<void> _start() async {
    await _entryCtrl.forward();
    await Future.delayed(AppConstants.welcomeDuration);
    _pulseCtrl.stop();
    _floatCtrl.stop();
    _foodImgCtrl.stop();
    await _exitCtrl.forward();
    if (mounted) context.go(widget.role.homeRoute);
  }

  @override
  void dispose() {
    _entryCtrl.dispose();
    _pulseCtrl.dispose();
    _floatCtrl.dispose();
    _foodImgCtrl.dispose();
    _exitCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: _theme.bgDark,
      body: AnimatedBuilder(
        animation: Listenable.merge([_entryCtrl, _pulseCtrl, _floatCtrl, _foodImgCtrl, _exitCtrl]),
        builder: (context, _) {
          return Opacity(
            opacity: _exitFade.value,
            child: Stack(
              children: [
                // ── Gradient bg ──
                _GradientBg(theme: _theme, size: size),

                // ── Floating bg icons ──
                ..._FloatingIcons.build(
                  icons: _theme.bgIcons,
                  floatValue: _floatCtrl.value,
                  accentColor: _theme.accentColor,
                  size: size,
                ),

                // ── Static decorations ──
                ..._buildBgDecorations(size),

                // ── Main content ──
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ScaleTransition(
                        scale: _logoScale,
                        child: FadeTransition(
                          opacity: _logoOpacity,
                          child: ScaleTransition(
                            scale: _pulse,
                            child: Container(
                              width: 104, height: 104,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [_theme.accentColor, _theme.accentDark],
                                ),
                                border: Border.all(color: Colors.white.withOpacity(0.2), width: 2),
                                boxShadow: [BoxShadow(
                                  color: _theme.accentColor.withOpacity(0.4),
                                  blurRadius: 32, spreadRadius: 4,
                                )],
                              ),
                              child: Icon(_theme.icon, size: 52, color: Colors.white),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 32),

                      SlideTransition(
                        position: _textSlide,
                        child: FadeTransition(
                          opacity: _textOpacity,
                          child: Column(
                            children: [
                              Text('Xin chào!', style: TextStyle(
                                fontSize: 14, color: Colors.white.withOpacity(0.6),
                                fontWeight: FontWeight.w400, letterSpacing: 3,
                              )),
                              const SizedBox(height: 8),
                              Text(_theme.title, style: const TextStyle(
                                fontSize: 28, color: Colors.white,
                                fontWeight: FontWeight.w800, letterSpacing: 0.3, height: 1.15,
                              ), textAlign: TextAlign.center),
                              const SizedBox(height: 14),
                              Transform.translate(
                                offset: Offset(0, _badgeOffset.value),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(24),
                                    border: Border.all(color: Colors.white.withOpacity(0.22), width: 1),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        width: 5, height: 5,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: _theme.accentLight,
                                          boxShadow: [BoxShadow(
                                            color: _theme.accentLight.withOpacity(0.8),
                                            blurRadius: 6,
                                          )],
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(_theme.subtitle, style: TextStyle(
                                        fontSize: 11, color: Colors.white.withOpacity(0.85),
                                        fontWeight: FontWeight.w600, letterSpacing: 2,
                                      )),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 52),

                      FadeTransition(
                        opacity: _textOpacity,
                        child: const _BounceLoopText(
                          text: 'Original Taste',
                          color: Colors.white,
                          opacity: 0.55,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  List<Widget> _buildBgDecorations(Size size) {
    return [
      Positioned(
        top: -size.height * 0.1, right: -size.width * 0.15,
        child: Container(
          width: size.width * 0.6, height: size.width * 0.6,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(colors: [
              _theme.accentColor.withOpacity(0.14), Colors.transparent,
            ]),
          ),
        ),
      ),
      Positioned(
        bottom: -size.height * 0.08, left: -size.width * 0.1,
        child: Container(
          width: size.width * 0.48, height: size.width * 0.48,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(colors: [
              _theme.accentDark.withOpacity(0.14), Colors.transparent,
            ]),
          ),
        ),
      ),
      Positioned(
        top: size.height * 0.13, left: size.width * 0.09,
        child: Container(
          width: 10, height: 10,
          decoration: BoxDecoration(shape: BoxShape.circle,
              color: _theme.accentLight.withOpacity(0.4)),
        ),
      ),
      Positioned(
        bottom: size.height * 0.2, right: size.width * 0.11,
        child: Container(
          width: 7, height: 7,
          decoration: BoxDecoration(shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.2)),
        ),
      ),
    ];
  }
}

// ══════════════════════════════════════════════════════════════
// POS FOOD BG
// ══════════════════════════════════════════════════════════════

class _PosFoodBg {
  static List<Widget> build({
    required Size size,
    required double floatValue,
    required Color bgColor,
  }) {
    final isLandscape = size.width > size.height;
    if (!isLandscape) return [];

    // Circle size tăng 15%
    final circleSize = size.height * 0.65;

    // Bên trái: sang phải 10%, xuống dưới 5%
    final leftOffset = -(circleSize * 0.30) + (circleSize * 0.25);
    final leftTop    = size.height * 0.30 + (size.height * 0.05);

    // Bên phải: sang trái 10%, xuống dưới 5%
    final rightOffset = -(circleSize * 0.30) + (circleSize * 0.25);
    final rightTop    = -(circleSize * 0.15) + (size.height * 0.05);

    final dy1 = math.sin(floatValue * math.pi * 2) * 8.0;
    final dy2 = math.sin((floatValue + 0.5) * math.pi * 2) * 7.0;
    final dx1 = math.cos(floatValue * math.pi * 2 * 0.5) * 5.0;
    final dx2 = math.cos((floatValue + 0.3) * math.pi * 2 * 0.5) * 4.0;

    return [
      Positioned(
        left: leftOffset, top: leftTop,
        child: _FoodCircle(
          circleSize: circleSize,
          imagePath: 'assets/images/pos/menu1.png',
          bgColor: bgColor,
          floatDx: dx1, floatDy: dy1,
        ),
      ),
      Positioned(
        right: rightOffset, top: rightTop,
        child: _FoodCircle(
          circleSize: circleSize,
          imagePath: 'assets/images/pos/menu2.png',
          bgColor: bgColor,
          floatDx: dx2, floatDy: dy2,
        ),
      ),
    ];
  }
}

// ── Food circle: bg circle + image clipped inside ─────────────
// ── Food Circle: Vòng tròn kính mờ + ảnh gốc + fade mép ─────────────
class _FoodCircle extends StatelessWidget {
  final double circleSize;
  final String imagePath;
  final Color bgColor;
  final double floatDx;
  final double floatDy;

  const _FoodCircle({
    required this.circleSize,
    required this.imagePath,
    required this.bgColor,
    required this.floatDx,
    required this.floatDy,
  });

  @override
  Widget build(BuildContext context) {
    // Tăng kích thước frame một chút để có viền đẹp
    final frameSize = circleSize * 1.08;

    return Transform.translate(
      offset: Offset(floatDx, floatDy),
      child: SizedBox(
        width: frameSize,
        height: frameSize,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // 1. Vòng tròn kính mờ (Glassmorphism)
            Container(
              width: frameSize,
              height: frameSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.08),
                border: Border.all(
                  color: Colors.white.withOpacity(0.25),
                  width: 2.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.25),
                    blurRadius: 30,
                    spreadRadius: -8,
                  ),
                  BoxShadow(
                    color: Colors.white.withOpacity(0.1),
                    blurRadius: 20,
                    spreadRadius: -10,
                  ),
                ],
              ),
            ),

            // 2. Ảnh gốc (không bo tròn) + fade mép
            SizedBox(
              width: circleSize,
              height: circleSize * 0.85,   // giữ tỷ lệ gốc của ảnh
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20), // bo nhẹ để đẹp
                child: Stack(
                  children: [
                    Image.asset(
                      imagePath,
                      width: circleSize,
                      height: circleSize * 0.85,
                      fit: BoxFit.cover,
                      alignment: Alignment.center,
                    ),

                    // Fade dần ra mép (vignette effect)
                    Container(
                      decoration: BoxDecoration(
                        gradient: RadialGradient(
                          colors: [
                            Colors.transparent,
                            Colors.transparent,
                            Colors.black.withOpacity(0.45),
                          ],
                          stops: const [0.75, 0.92, 1.0],
                          center: Alignment.center,
                          radius: 0.95,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// FLOATING BG ICONS
// ══════════════════════════════════════════════════════════════

class _FloatConfig {
  final IconData icon;
  final double x, y, size, phase, amplitude;
  const _FloatConfig({
    required this.icon, required this.x, required this.y,
    required this.size, required this.phase, required this.amplitude,
  });
}

class _FloatingIcons {
  static List<Widget> build({
    required List<_FloatConfig> icons,
    required double floatValue,
    required Color accentColor,
    required Size size,
  }) {
    return icons.map((cfg) {
      final angle = (floatValue + cfg.phase) * math.pi * 2;
      final dy = math.sin(angle) * cfg.amplitude;
      final dx = math.cos(angle * 0.7) * (cfg.amplitude * 0.4);
      return Positioned(
        left: size.width  * cfg.x - cfg.size / 2,
        top:  size.height * cfg.y - cfg.size / 2 + dy,
        child: Transform.translate(
          offset: Offset(dx, 0),
          child: Icon(cfg.icon, size: cfg.size, color: accentColor.withOpacity(0.13)),
        ),
      );
    }).toList();
  }
}

// ══════════════════════════════════════════════════════════════
// BOUNCE LOOP TEXT
// ══════════════════════════════════════════════════════════════

class _BounceLoopText extends StatefulWidget {
  final String text;
  final Color color;
  final double opacity;
  const _BounceLoopText({required this.text, required this.color, required this.opacity});

  @override
  State<_BounceLoopText> createState() => _BounceLoopTextState();
}

class _BounceLoopTextState extends State<_BounceLoopText>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  static const int _msPerChar = 80, _bounceDuration = 400, _pauseAfter = 700;
  late final int _totalMs;

  @override
  void initState() {
    super.initState();
    _totalMs = widget.text.length * _msPerChar + _bounceDuration + _pauseAfter;
    _ctrl = AnimationController(vsync: this, duration: Duration(milliseconds: _totalMs))..repeat();
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final chars = widget.text.characters.toList();
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        final nowMs = _ctrl.value * _totalMs;
        return Wrap(
          alignment: WrapAlignment.center,
          children: List.generate(chars.length, (i) {
            final char = chars[i];
            if (char == ' ') return const SizedBox(width: 5);
            final startMs = i * _msPerChar.toDouble();
            final endMs   = startMs + _bounceDuration;
            double dy = 0.0;
            if (nowMs >= startMs && nowMs <= endMs) {
              dy = math.sin((nowMs - startMs) / _bounceDuration * math.pi);
            }
            return Transform.translate(
              offset: Offset(0, -dy * 9),
              child: Text(char, style: TextStyle(
                fontSize: 15, fontWeight: FontWeight.w500, letterSpacing: 0.3,
                color: widget.color.withOpacity(widget.opacity + dy * 0.3),
                height: 1.0,
              )),
            );
          }),
        );
      },
    );
  }
}

// ══════════════════════════════════════════════════════════════
// GRADIENT BACKGROUND
// ══════════════════════════════════════════════════════════════

class _GradientBg extends StatelessWidget {
  final _RoleTheme theme;
  final Size size;
  const _GradientBg({required this.theme, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size.width, height: size.height,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [theme.bgDark, theme.bgMid, theme.bgDark],
          stops: const [0.0, 0.5, 1.0],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// ROLE THEME
// ══════════════════════════════════════════════════════════════

class _RoleTheme {
  final Color bgDark, bgMid, accentColor, accentDark, accentLight;
  final IconData icon;
  final String title, subtitle;
  final List<_FloatConfig> bgIcons;

  const _RoleTheme({
    required this.bgDark, required this.bgMid,
    required this.accentColor, required this.accentDark, required this.accentLight,
    required this.icon, required this.title, required this.subtitle,
    required this.bgIcons,
  });

  static _RoleTheme forRole(UserRole role) {
    switch (role) {
      case UserRole.superAdmin:
        return _RoleTheme(
          bgDark: const Color(0xFF12005E), bgMid: const Color(0xFF1A0080),
          accentColor: const Color(0xFFD4AF37), accentDark: const Color(0xFF9C7A00),
          accentLight: const Color(0xFFFFF0A0),
          icon: Icons.shield_rounded, title: 'Super Admin', subtitle: 'HỆ THỐNG CẤP CAO',
          bgIcons: const [
            _FloatConfig(icon: Icons.shield_rounded,          x: 0.1,  y: 0.12, size: 38, phase: 0.0,  amplitude: 10),
            _FloatConfig(icon: Icons.admin_panel_settings,    x: 0.85, y: 0.18, size: 30, phase: 0.2,  amplitude: 14),
            _FloatConfig(icon: Icons.manage_accounts_rounded, x: 0.15, y: 0.75, size: 32, phase: 0.4,  amplitude: 12),
            _FloatConfig(icon: Icons.analytics_rounded,       x: 0.78, y: 0.7,  size: 36, phase: 0.6,  amplitude: 8),
            _FloatConfig(icon: Icons.security_rounded,        x: 0.5,  y: 0.1,  size: 24, phase: 0.1,  amplitude: 16),
            _FloatConfig(icon: Icons.verified_rounded,        x: 0.92, y: 0.45, size: 28, phase: 0.35, amplitude: 11),
            _FloatConfig(icon: Icons.hub_rounded,             x: 0.05, y: 0.45, size: 26, phase: 0.7,  amplitude: 13),
            _FloatConfig(icon: Icons.show_chart_rounded,      x: 0.6,  y: 0.88, size: 30, phase: 0.55, amplitude: 9),
          ],
        );
      case UserRole.admin:
        return _RoleTheme(
          bgDark: const Color(0xFF1A1A2E), bgMid: const Color(0xFF16213E),
          accentColor: const Color(0xFF6C63FF), accentDark: const Color(0xFF3D35B5),
          accentLight: const Color(0xFFB8B5FF),
          icon: Icons.admin_panel_settings_rounded, title: 'Admin Dashboard', subtitle: 'QUẢN TRỊ HỆ THỐNG',
          bgIcons: const [
            _FloatConfig(icon: Icons.dashboard_rounded,       x: 0.1,  y: 0.12, size: 34, phase: 0.0,  amplitude: 10),
            _FloatConfig(icon: Icons.people_alt_rounded,      x: 0.82, y: 0.2,  size: 30, phase: 0.25, amplitude: 14),
            _FloatConfig(icon: Icons.bar_chart_rounded,       x: 0.12, y: 0.72, size: 32, phase: 0.5,  amplitude: 12),
            _FloatConfig(icon: Icons.settings_rounded,        x: 0.8,  y: 0.68, size: 28, phase: 0.15, amplitude: 9),
            _FloatConfig(icon: Icons.assignment_rounded,      x: 0.5,  y: 0.08, size: 24, phase: 0.4,  amplitude: 16),
            _FloatConfig(icon: Icons.business_center_rounded, x: 0.9,  y: 0.42, size: 26, phase: 0.6,  amplitude: 11),
            _FloatConfig(icon: Icons.manage_accounts_rounded, x: 0.05, y: 0.42, size: 28, phase: 0.75, amplitude: 13),
            _FloatConfig(icon: Icons.notifications_rounded,   x: 0.62, y: 0.86, size: 26, phase: 0.3,  amplitude: 8),
          ],
        );
      case UserRole.pos:
        return _RoleTheme(
          bgDark: const Color(0xFFE65100), bgMid: const Color(0xFFBF360C),
          accentColor: const Color(0xFFFF8A65), accentDark: const Color(0xFF8B2500),
          accentLight: const Color(0xFFFFCCBC),
          icon: Icons.point_of_sale_rounded, title: 'POS Bán Hàng', subtitle: 'ĐIỂM BÁN HÀNG',
          bgIcons: const [
            _FloatConfig(icon: Icons.restaurant_menu_rounded, x: 0.1,  y: 0.12, size: 36, phase: 0.0,  amplitude: 12),
            _FloatConfig(icon: Icons.fastfood_rounded,        x: 0.82, y: 0.18, size: 32, phase: 0.2,  amplitude: 10),
            _FloatConfig(icon: Icons.local_pizza_rounded,     x: 0.15, y: 0.72, size: 30, phase: 0.45, amplitude: 14),
            _FloatConfig(icon: Icons.coffee_rounded,          x: 0.78, y: 0.7,  size: 28, phase: 0.6,  amplitude: 9),
            _FloatConfig(icon: Icons.lunch_dining_rounded,    x: 0.5,  y: 0.08, size: 26, phase: 0.1,  amplitude: 16),
            _FloatConfig(icon: Icons.local_drink_rounded,     x: 0.9,  y: 0.44, size: 24, phase: 0.35, amplitude: 11),
            _FloatConfig(icon: Icons.receipt_rounded,         x: 0.05, y: 0.44, size: 28, phase: 0.7,  amplitude: 13),
            _FloatConfig(icon: Icons.shopping_bag_rounded,    x: 0.6,  y: 0.87, size: 26, phase: 0.55, amplitude: 8),
          ],
        );
      case UserRole.seller:
        return _RoleTheme(
          bgDark: const Color(0xFF1B5E20), bgMid: const Color(0xFF2E7D32),
          accentColor: const Color(0xFF66BB6A), accentDark: const Color(0xFF1B5E20),
          accentLight: const Color(0xFFC8E6C9),
          icon: Icons.storefront_rounded, title: 'Seller Portal', subtitle: 'QUẢN LÝ CỬA HÀNG',
          bgIcons: const [
            _FloatConfig(icon: Icons.restaurant_rounded,      x: 0.1,  y: 0.12, size: 36, phase: 0.0,  amplitude: 12),
            _FloatConfig(icon: Icons.set_meal_rounded,        x: 0.82, y: 0.2,  size: 30, phase: 0.2,  amplitude: 10),
            _FloatConfig(icon: Icons.soup_kitchen_rounded,    x: 0.15, y: 0.72, size: 32, phase: 0.45, amplitude: 14),
            _FloatConfig(icon: Icons.ramen_dining_rounded,    x: 0.78, y: 0.68, size: 28, phase: 0.6,  amplitude: 9),
            _FloatConfig(icon: Icons.cake_rounded,            x: 0.5,  y: 0.08, size: 26, phase: 0.1,  amplitude: 16),
            _FloatConfig(icon: Icons.emoji_food_beverage,     x: 0.9,  y: 0.44, size: 24, phase: 0.35, amplitude: 11),
            _FloatConfig(icon: Icons.store_rounded,           x: 0.05, y: 0.44, size: 28, phase: 0.7,  amplitude: 13),
            _FloatConfig(icon: Icons.local_offer_rounded,     x: 0.62, y: 0.86, size: 26, phase: 0.55, amplitude: 8),
          ],
        );
      case UserRole.accountant:
        return _RoleTheme(
          bgDark: const Color(0xFF0D47A1), bgMid: const Color(0xFF1565C0),
          accentColor: const Color(0xFF42A5F5), accentDark: const Color(0xFF0D47A1),
          accentLight: const Color(0xFFBBDEFB),
          icon: Icons.account_balance_rounded, title: 'Kế Toán', subtitle: 'QUẢN LÝ TÀI CHÍNH',
          bgIcons: const [
            _FloatConfig(icon: Icons.calculate_rounded,           x: 0.1,  y: 0.12, size: 36, phase: 0.0,  amplitude: 10),
            _FloatConfig(icon: Icons.attach_money_rounded,        x: 0.82, y: 0.18, size: 32, phase: 0.2,  amplitude: 14),
            _FloatConfig(icon: Icons.receipt_long_rounded,        x: 0.15, y: 0.72, size: 30, phase: 0.45, amplitude: 12),
            _FloatConfig(icon: Icons.pie_chart_rounded,           x: 0.78, y: 0.7,  size: 28, phase: 0.6,  amplitude: 9),
            _FloatConfig(icon: Icons.account_balance_wallet,      x: 0.5,  y: 0.08, size: 26, phase: 0.1,  amplitude: 16),
            _FloatConfig(icon: Icons.trending_up_rounded,         x: 0.9,  y: 0.44, size: 24, phase: 0.35, amplitude: 11),
            _FloatConfig(icon: Icons.savings_rounded,             x: 0.05, y: 0.44, size: 28, phase: 0.7,  amplitude: 13),
            _FloatConfig(icon: Icons.currency_exchange_rounded,   x: 0.62, y: 0.87, size: 26, phase: 0.55, amplitude: 8),
          ],
        );
      case UserRole.warehouse:
        return _RoleTheme(
          bgDark: const Color(0xFF4A148C), bgMid: const Color(0xFF6A1B9A),
          accentColor: const Color(0xFFBA68C8), accentDark: const Color(0xFF4A148C),
          accentLight: const Color(0xFFE1BEE7),
          icon: Icons.warehouse_rounded, title: 'Kho Hàng', subtitle: 'QUẢN LÝ KHO',
          bgIcons: const [
            _FloatConfig(icon: Icons.inventory_2_rounded,         x: 0.1,  y: 0.12, size: 36, phase: 0.0,  amplitude: 10),
            _FloatConfig(icon: Icons.local_shipping_rounded,      x: 0.82, y: 0.18, size: 32, phase: 0.2,  amplitude: 14),
            _FloatConfig(icon: Icons.precision_manufacturing_rounded, x: 0.15, y: 0.72, size: 30, phase: 0.45, amplitude: 12),
            _FloatConfig(icon: Icons.qr_code_scanner_rounded,     x: 0.78, y: 0.7,  size: 28, phase: 0.6,  amplitude: 9),
            _FloatConfig(icon: Icons.category_rounded,            x: 0.5,  y: 0.08, size: 26, phase: 0.1,  amplitude: 16),
            _FloatConfig(icon: Icons.move_to_inbox_rounded,       x: 0.9,  y: 0.44, size: 24, phase: 0.35, amplitude: 11),
            _FloatConfig(icon: Icons.view_module_rounded,         x: 0.05, y: 0.44, size: 28, phase: 0.7,  amplitude: 13),
            _FloatConfig(icon: Icons.inventory_rounded,           x: 0.62, y: 0.87, size: 26, phase: 0.55, amplitude: 8),
          ],
        );
      case UserRole.shipper:
        return _RoleTheme(
          bgDark: const Color(0xFF006064), bgMid: const Color(0xFF00838F),
          accentColor: const Color(0xFF4DD0E1), accentDark: const Color(0xFF006064),
          accentLight: const Color(0xFFB2EBF2),
          icon: Icons.delivery_dining_rounded, title: 'Giao Hàng', subtitle: 'QUẢN LÝ VẬN CHUYỂN',
          bgIcons: const [
            _FloatConfig(icon: Icons.delivery_dining_rounded,     x: 0.1,  y: 0.12, size: 36, phase: 0.0,  amplitude: 12),
            _FloatConfig(icon: Icons.local_shipping_rounded,      x: 0.82, y: 0.18, size: 32, phase: 0.2,  amplitude: 10),
            _FloatConfig(icon: Icons.map_rounded,                 x: 0.15, y: 0.72, size: 30, phase: 0.45, amplitude: 14),
            _FloatConfig(icon: Icons.pin_drop_rounded,            x: 0.78, y: 0.7,  size: 28, phase: 0.6,  amplitude: 9),
            _FloatConfig(icon: Icons.route_rounded,               x: 0.5,  y: 0.08, size: 26, phase: 0.1,  amplitude: 16),
            _FloatConfig(icon: Icons.two_wheeler_rounded,         x: 0.9,  y: 0.44, size: 24, phase: 0.35, amplitude: 11),
            _FloatConfig(icon: Icons.checklist_rounded,           x: 0.05, y: 0.44, size: 28, phase: 0.7,  amplitude: 13),
            _FloatConfig(icon: Icons.speed_rounded,               x: 0.62, y: 0.87, size: 26, phase: 0.55, amplitude: 8),
          ],
        );
      default:
        return _RoleTheme(
          bgDark: const Color(0xFF263238), bgMid: const Color(0xFF37474F),
          accentColor: const Color(0xFF90A4AE), accentDark: const Color(0xFF263238),
          accentLight: const Color(0xFFECEFF1),
          icon: Icons.restaurant_rounded, title: 'Original Taste', subtitle: 'CHÀO MỪNG',
          bgIcons: const [
            _FloatConfig(icon: Icons.restaurant_menu_rounded, x: 0.1,  y: 0.12, size: 34, phase: 0.0,  amplitude: 12),
            _FloatConfig(icon: Icons.fastfood_rounded,        x: 0.82, y: 0.2,  size: 28, phase: 0.3,  amplitude: 10),
            _FloatConfig(icon: Icons.local_pizza_rounded,     x: 0.15, y: 0.72, size: 30, phase: 0.55, amplitude: 14),
            _FloatConfig(icon: Icons.coffee_rounded,          x: 0.78, y: 0.68, size: 26, phase: 0.7,  amplitude: 9),
          ],
        );
    }
  }
}