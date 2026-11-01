// lib/shared/widgets/app_toast.dart

import 'package:flutter/material.dart';
import '../../app/theme/app_colors.dart';
import '../../core/constants/app_constants.dart';

enum ToastType { success, warning, error }

class AppToast {
  AppToast._();

  static OverlayEntry? _current;

  static void show(
      BuildContext context,
      String message, {
        ToastType type = ToastType.success,
      }) {
    _dismiss();

    // Capture brightness TRƯỚC khi tạo OverlayEntry.
    // Nếu capture bên trong builder (lazy), context có thể đã deactivated
    // và Theme.of(context) sẽ throw "Looking up a deactivated widget's ancestor".
    final brightness = Theme.of(context).brightness;
    final overlay = Overlay.of(context, rootOverlay: true);

    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (overlayContext) => _ToastWidget(
        message: message,
        type: type,
        brightness: brightness,
        onDismiss: () {
          entry.remove();
          if (_current == entry) _current = null;
        },
      ),
    );
    _current = entry;
    overlay.insert(entry);
  }

  static void success(BuildContext context, String msg) =>
      show(context, msg, type: ToastType.success);

  static void warning(BuildContext context, String msg) =>
      show(context, msg, type: ToastType.warning);

  static void error(BuildContext context, String msg) =>
      show(context, msg, type: ToastType.error);

  static void _dismiss() {
    _current?.remove();
    _current = null;
  }
}

class _ToastWidget extends StatefulWidget {
  final String message;
  final ToastType type;
  final Brightness brightness;
  final VoidCallback onDismiss;

  const _ToastWidget({
    required this.message,
    required this.type,
    required this.brightness,
    required this.onDismiss,
  });

  @override
  State<_ToastWidget> createState() => _ToastWidgetState();
}

class _ToastWidgetState extends State<_ToastWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _opacity;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _opacity = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));

    _ctrl.forward();

    Future.delayed(AppConstants.toastDuration, () {
      if (mounted) {
        _ctrl.reverse().then((_) => widget.onDismiss());
      }
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  bool get _isDark => widget.brightness == Brightness.dark;

  Color get _accentColor => switch (widget.type) {
    ToastType.success => AppColors.success,
    ToastType.warning => AppColors.warning,
    ToastType.error   => AppColors.error,
  };

  IconData get _icon => switch (widget.type) {
    ToastType.success => Icons.check_circle_rounded,
    ToastType.warning => Icons.warning_rounded,
    ToastType.error   => Icons.error_rounded,
  };

  Color get _bgColor => _isDark
      ? const Color(0xFF2C2C2E)
      : const Color(0xFFFFFFFF);

  Color get _textColor => _isDark
      ? const Color(0xFFF2F2F7)
      : const Color(0xFF1C1C1E);

  Color get _borderColor => _accentColor.withOpacity(_isDark ? 0.5 : 0.3);

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top + 12;

    return Positioned(
      top: top,
      left: 16,
      right: 16,
      child: SlideTransition(
        position: _slide,
        child: FadeTransition(
          opacity: _opacity,
          child: Material(
            color: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: _bgColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _borderColor, width: 1),
                boxShadow: [
                  BoxShadow(
                    color: _isDark
                        ? Colors.black.withOpacity(0.4)
                        : Colors.black.withOpacity(0.12),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Icon(_icon, color: _accentColor, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      widget.message,
                      style: TextStyle(
                        color: _textColor,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}