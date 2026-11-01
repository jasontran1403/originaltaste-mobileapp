// lib/features/pos/components/pos_passcode_dialog.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:originaltaste/services/pos_service.dart';

/// Mở full-screen passcode, trả về true nếu xác thực thành công
Future<bool> showPosPasscodeDialog(BuildContext context) async {
  final result = await Navigator.of(context, rootNavigator: true).push<bool>(
    PageRouteBuilder(
      opaque: true,
      pageBuilder: (_, __, ___) => const _PasscodeScreen(),
      transitionsBuilder: (_, anim, __, child) =>
          SlideTransition(
            position: Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
                .animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
            child: child,
          ),
      transitionDuration: const Duration(milliseconds: 320),
    ),
  );
  return result == true;
}

class _PasscodeScreen extends StatefulWidget {
  const _PasscodeScreen();

  @override
  State<_PasscodeScreen> createState() => _PasscodeScreenState();
}

class _PasscodeScreenState extends State<_PasscodeScreen> {
  static const _length = 6;
  final _digits = List<String>.filled(_length, '', growable: false);

  bool _loading = false;
  String? _errorText;
  double _shakeOffset = 0;

  int get _filledCount => _digits.where((d) => d.isNotEmpty).length;

  void _handleKey(String key) {
    if (_loading) return;
    if (_errorText != null) setState(() => _errorText = null);

    if (key == 'backspace') {
      for (int i = _length - 1; i >= 0; i--) {
        if (_digits[i].isNotEmpty) {
          setState(() => _digits[i] = '');
          return;
        }
      }
      return;
    }

    for (int i = 0; i < _length; i++) {
      if (_digits[i].isEmpty) {
        setState(() => _digits[i] = key);
        if (i == _length - 1) Future.microtask(_verify);
        return;
      }
    }
  }

  Future<void> _triggerShake(String msg) async {
    setState(() => _errorText = msg);
    for (final off in [10.0, -10.0, 7.0, -5.0, 0.0]) {
      await Future.delayed(const Duration(milliseconds: 65));
      if (mounted) setState(() => _shakeOffset = off);
    }
  }

  Future<void> _verify() async {
    final pin = _digits.join();
    setState(() { _loading = true; _errorText = null; });
    try {
      final ok = await PosService.instance.verifyPosMenuPin(pin);
      if (ok && mounted) Navigator.of(context).pop(true);
    } catch (e) {
      final msg = e.toString().replaceFirst('Exception: ', '');
      setState(() {
        for (int i = 0; i < _length; i++) _digits[i] = '';
        _loading = false;
      });
      _triggerShake(msg);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final safePad = MediaQuery.of(context).padding;

    return Scaffold(
      backgroundColor: cs.surface,
      body: SafeArea(
        child: Column(
          children: [
            // ── Back button ──────────────────────────────────────
            Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.only(left: 8, top: 4),
                child: IconButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  icon: const Icon(Icons.arrow_back_ios_new_rounded),
                  style: IconButton.styleFrom(foregroundColor: cs.onSurface),
                ),
              ),
            ),

            const Spacer(flex: 2),

            // ── Title ────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(children: [
                Text.rich(
                  TextSpan(children: [
                    TextSpan(
                      text: 'Nhập mật khẩu\n',
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                        color: cs.onSurface,
                        height: 1.2,
                      ),
                    ),
                    TextSpan(
                      text: 'để truy cập quản lý',
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w400,
                        fontStyle: FontStyle.italic,
                        color: cs.onSurface,
                        height: 1.2,
                      ),
                    ),
                  ]),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                Text(
                  'Mật khẩu 6 chữ số được cấp bởi quản lý',
                  style: TextStyle(
                    fontSize: 14,
                    color: cs.onSurface.withOpacity(0.5),
                  ),
                  textAlign: TextAlign.center,
                ),
              ]),
            ),

            const SizedBox(height: 36),

            // ── 6 digit boxes ─────────────────────────────────────
            Transform.translate(
              offset: Offset(_shakeOffset, 0),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(_length, (i) {
                    final filled = _digits[i].isNotEmpty;
                    final isActive = !filled &&
                        (i == 0 || _digits[i - 1].isNotEmpty);
                    final hasError = _errorText != null;

                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 5),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 120),
                        width: 44, height: 54,
                        decoration: BoxDecoration(
                          color: filled
                              ? (hasError
                              ? cs.errorContainer.withOpacity(0.3)
                              : cs.primaryContainer.withOpacity(0.25))
                              : isDark
                              ? cs.surfaceContainerHighest
                              : const Color(0xFFF2F2F7),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: hasError
                                ? cs.error
                                : isActive
                                ? cs.primary
                                : filled
                                ? cs.primary.withOpacity(0.5)
                                : Colors.transparent,
                            width: isActive ? 2 : 1.5,
                          ),
                        ),
                        child: Center(
                          child: _loading && filled
                              ? SizedBox(width: 14, height: 14,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: cs.primary))
                              : filled
                              ? Text(
                            _digits[i],
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: hasError ? cs.error : cs.onSurface,
                            ),
                          )
                              : isActive
                              ? Container(width: 2, height: 20,
                              color: cs.primary)
                              : null,
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ),

            // ── Error text ────────────────────────────────────────
            AnimatedSize(
              duration: const Duration(milliseconds: 200),
              child: _errorText != null
                  ? Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(_errorText!,
                    style: TextStyle(
                        color: cs.error,
                        fontSize: 13,
                        fontWeight: FontWeight.w500)),
              )
                  : const SizedBox(height: 12),
            ),

            const Spacer(flex: 3),

            // ── Numpad ────────────────────────────────────────────
            _Numpad(onKey: _handleKey, loading: _loading),

            SizedBox(height: safePad.bottom > 0 ? 8 : 20),
          ],
        ),
      ),
    );
  }
}

// ── Numpad ────────────────────────────────────────────────────────

class _Numpad extends StatelessWidget {
  final void Function(String) onKey;
  final bool loading;

  const _Numpad({required this.onKey, this.loading = false});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final rows = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
      ['', '0', '⌫'],
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: rows.map((row) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: row.map((k) {
                if (k.isEmpty) return const Expanded(child: SizedBox());
                final isBack = k == '⌫';
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 5),
                    child: _NumKey(
                      label: k,
                      isBack: isBack,
                      isDark: isDark,
                      cs: cs,
                      onTap: loading
                          ? null
                          : () => onKey(isBack ? 'backspace' : k),
                    ),
                  ),
                );
              }).toList(),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _NumKey extends StatelessWidget {
  final String label;
  final bool isBack;
  final bool isDark;
  final ColorScheme cs;
  final VoidCallback? onTap;

  const _NumKey({
    required this.label,
    required this.isBack,
    required this.isDark,
    required this.cs,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = isDark
        ? cs.surfaceContainerHighest
        : const Color(0xFFF2F2F7);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        splashColor: cs.primary.withOpacity(0.1),
        highlightColor: cs.primary.withOpacity(0.06),
        child: Ink(
          height: 56,
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Center(
            child: isBack
                ? Icon(Icons.backspace_outlined, size: 22, color: cs.onSurface)
                : Text(label,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w500,
                  color: cs.onSurface,
                )),
          ),
        ),
      ),
    );
  }
}