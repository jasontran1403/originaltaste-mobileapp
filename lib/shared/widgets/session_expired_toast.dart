// lib/shared/widgets/session_expired_toast.dart
//
// Toast báo "Phiên đăng nhập đã hết hạn":
//  • Nằm góc PHẢI TRÊN màn hình.
//  • Có thanh timer đếm ngược 5s ở dưới.
//  • Hết 5s HOẶC click vào toast → gọi onResolve (clear storage + về login).
//  • Chống trùng: nhiều API cùng 401 một lúc chỉ hiện MỘT toast.
//  • Sau khi resolve sẽ "suppress" cho tới khi gọi reset() (lúc login lại),
//    tránh các request rơi rớt (vd logout, thiếu header) bật lại toast.

import 'package:flutter/material.dart';
import '../../app/theme/app_colors.dart';

class SessionExpiredToast {
  SessionExpiredToast._();

  static OverlayEntry? _entry;
  static bool _suppressed = false;

  /// Hiện toast (nếu chưa hiện & chưa bị suppress).
  /// Truyền thẳng [OverlayState] (lấy từ NavigatorState.overlay) — KHÔNG dùng
  /// Overlay.of(navigatorContext) vì context của Navigator không có Overlay
  /// tổ tiên (Overlay nằm bên trong Navigator) → sẽ ném "No Overlay widget".
  static void show(
      OverlayState overlay, {
        required Future<void> Function() onResolve,
        Duration duration = const Duration(seconds: 5),
      }) {
    if (_suppressed || _entry != null) return;

    final brightness = Theme.of(overlay.context).brightness;

    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _SessionExpiredCard(
        brightness: brightness,
        duration: duration,
        onResolve: () async {
          // Gỡ overlay + suppress TRƯỚC khi chạy onResolve, để logout POST
          // (nếu 401) không bật lại toast mới.
          _remove();
          _suppressed = true;
          await onResolve();
        },
      ),
    );
    _entry = entry;
    overlay.insert(entry);
  }

  static void _remove() {
    _entry?.remove();
    _entry = null;
  }

  /// Gọi khi ĐĂNG NHẬP LẠI thành công để cho phép toast hoạt động lại.
  static void reset() {
    _remove();
    _suppressed = false;
  }
}

class _SessionExpiredCard extends StatefulWidget {
  final Brightness brightness;
  final Duration duration;
  final Future<void> Function() onResolve;

  const _SessionExpiredCard({
    required this.brightness,
    required this.duration,
    required this.onResolve,
  });

  @override
  State<_SessionExpiredCard> createState() => _SessionExpiredCardState();
}

class _SessionExpiredCardState extends State<_SessionExpiredCard>
    with TickerProviderStateMixin {
  late final AnimationController _countdown; // 0→1 trong `duration`
  late final AnimationController _enter;     // hiệu ứng xuất hiện
  late final Animation<Offset> _slide;
  late final Animation<double> _fade;
  bool _resolved = false;

  @override
  void initState() {
    super.initState();

    _enter = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    );
    _slide = Tween<Offset>(
      begin: const Offset(0.25, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _enter, curve: Curves.easeOutCubic));
    _fade = CurvedAnimation(parent: _enter, curve: Curves.easeOut);
    _enter.forward();

    _countdown = AnimationController(vsync: this, duration: widget.duration)
      ..addStatusListener((s) {
        if (s == AnimationStatus.completed) _resolve();
      })
      ..forward();
  }

  Future<void> _resolve() async {
    if (_resolved) return;
    _resolved = true;
    await widget.onResolve();
  }

  @override
  void dispose() {
    _countdown.dispose();
    _enter.dispose();
    super.dispose();
  }

  bool get _isDark => widget.brightness == Brightness.dark;
  Color get _bg => _isDark ? const Color(0xFF2C2C2E) : Colors.white;
  Color get _text => _isDark ? const Color(0xFFF2F2F7) : const Color(0xFF1C1C1E);
  Color get _sub => _isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
  Color get _accent => AppColors.error;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final top = media.padding.top + 12;

    return Positioned(
      top: top,
      right: 16,
      child: SlideTransition(
        position: _slide,
        child: FadeTransition(
          opacity: _fade,
          child: Material(
            color: Colors.transparent,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _resolve, // click để ẩn ngay + về login
              child: Container(
                width: 320,
                decoration: BoxDecoration(
                  color: _bg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _accent.withOpacity(_isDark ? 0.5 : 0.3)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(_isDark ? 0.4 : 0.12),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                      child: Row(
                        children: [
                          Icon(Icons.lock_clock_rounded, color: _accent, size: 22),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Phiên đăng nhập đã hết hạn',
                                  style: TextStyle(
                                    color: _text,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Nhấn để đăng nhập lại',
                                  style: TextStyle(color: _sub, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Số giây còn lại
                          AnimatedBuilder(
                            animation: _countdown,
                            builder: (_, __) {
                              final remain = (widget.duration.inMilliseconds *
                                  (1 - _countdown.value) /
                                  1000)
                                  .ceil()
                                  .clamp(0, widget.duration.inSeconds);
                              return Container(
                                width: 24,
                                height: 24,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: _accent.withOpacity(0.12),
                                  shape: BoxShape.circle,
                                ),
                                child: Text(
                                  '$remain',
                                  style: TextStyle(
                                    color: _accent,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    // Thanh timer đếm ngược
                    ClipRRect(
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(12),
                        bottomRight: Radius.circular(12),
                      ),
                      child: AnimatedBuilder(
                        animation: _countdown,
                        builder: (_, __) => LinearProgressIndicator(
                          value: 1 - _countdown.value, // đầy → rỗng
                          minHeight: 4,
                          backgroundColor: _accent.withOpacity(0.12),
                          valueColor: AlwaysStoppedAnimation(_accent),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}