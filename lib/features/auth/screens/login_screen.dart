// lib/features/auth/screens/login_screen.dart

import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../shared/widgets/app_toast.dart';
import '../controller/auth_controller.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _formKey   = GlobalKey<FormState>();
  final _userCtrl  = TextEditingController();
  final _passCtrl  = TextEditingController();
  final _userFocus = FocusNode();
  final _passFocus = FocusNode();

  bool _rememberMe = false;
  bool _isLoading  = false;

  late AnimationController _entryCtrl;
  late Animation<double>   _fadeAnim;
  late Animation<Offset>   _slideAnim;

  @override
  void initState() {
    super.initState();
    _entryCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnim  = CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.04),
      end:   Offset.zero,
    ).animate(CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOutCubic));
    _entryCtrl.forward();
  }

  @override
  void dispose() {
    _userCtrl.dispose();
    _passCtrl.dispose();
    _userFocus.dispose();
    _passFocus.dispose();
    _entryCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _isLoading = true);

    final err = await ref.read(authControllerProvider.notifier).login(
      username:   _userCtrl.text.trim(),
      password:   _passCtrl.text,
      rememberMe: _rememberMe,
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (err != null) {
      AppToast.error(context, err);
      return;
    }
    final role = ref.read(authControllerProvider).role;
    context.go('/welcome', extra: role);
  }

  @override
  Widget build(BuildContext context) {
    final size        = MediaQuery.sizeOf(context);
    final isLandscape = size.width > size.height;
    final isWide      = isLandscape && size.width >= 600;

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        body: FadeTransition(
          opacity: _fadeAnim,
          child: SlideTransition(
            position: _slideAnim,
            child: isWide ? _buildTablet() : _buildMobile(),
          ),
        ),
      ),
    );
  }

  Widget _buildTablet() => Row(
    children: [
      Expanded(
        flex: 45,
        child: _FormPane(
          formKey: _formKey, userCtrl: _userCtrl, passCtrl: _passCtrl,
          userFocus: _userFocus, passFocus: _passFocus,
          rememberMe: _rememberMe, isLoading: _isLoading, isTablet: true,
          onRememberChanged: (v) => setState(() => _rememberMe = v),
          onLogin: _login,
        ),
      ),
      // ── RepaintBoundary: BlobPanel không repaint khi form setState
      Expanded(flex: 55, child: RepaintBoundary(child: _BlobPanel())),
    ],
  );

  Widget _buildMobile() => _FormPane(
    formKey: _formKey, userCtrl: _userCtrl, passCtrl: _passCtrl,
    userFocus: _userFocus, passFocus: _passFocus,
    rememberMe: _rememberMe, isLoading: _isLoading, isTablet: false,
    onRememberChanged: (v) => setState(() => _rememberMe = v),
    onLogin: _login,
  );
}

// ══════════════════════════════════════════════════════════════
// FORM PANE
// ══════════════════════════════════════════════════════════════
class _FormPane extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController userCtrl, passCtrl;
  final FocusNode userFocus, passFocus;
  final bool rememberMe, isLoading, isTablet;
  final void Function(bool) onRememberChanged;
  final VoidCallback onLogin;

  const _FormPane({
    required this.formKey,
    required this.userCtrl, required this.passCtrl,
    required this.userFocus, required this.passFocus,
    required this.rememberMe, required this.isLoading,
    required this.isTablet,
    required this.onRememberChanged, required this.onLogin,
  });

  @override
  Widget build(BuildContext context) {
    final cs     = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hPad   = isTablet ? 52.0 : 28.0;

    final textPrimary   = cs.onSurface;
    final textSecondary = cs.onSurface.withOpacity(0.45);
    final fillColor     = isDark
        ? Colors.white.withOpacity(0.06)
        : Colors.black.withOpacity(0.05);
    final borderColor   = cs.onSurface.withOpacity(isDark ? 0.12 : 0.13);
    final primary       = cs.primary;

    return Container(
      color: cs.surface,
      child: SafeArea(
        child: isTablet
            ? _tabletLayout(context, hPad, textPrimary, textSecondary,
            fillColor, borderColor, primary, cs)
            : _mobileLayout(context, hPad, textPrimary, textSecondary,
            fillColor, borderColor, primary, cs),
      ),
    );
  }

  Widget _tabletLayout(
      BuildContext ctx, double hPad,
      Color tp, Color ts, Color fill, Color border, Color primary, ColorScheme cs,
      ) {
    return LayoutBuilder(builder: (context, constraints) {
      final availableH = constraints.maxHeight;
      return SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: availableH),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: hPad),
            child: Form(
              key: formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(height: availableH * 0.20),
                  ..._formContent(ctx, tp, ts, fill, border, primary, cs),
                  SizedBox(height: availableH * 0.10),
                ],
              ),
            ),
          ),
        ),
      );
    });
  }

  Widget _mobileLayout(
      BuildContext ctx, double hPad,
      Color tp, Color ts, Color fill, Color border, Color primary, ColorScheme cs,
      ) {
    return LayoutBuilder(builder: (context, constraints) {
      final availableH = constraints.maxHeight;
      return SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: availableH),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: hPad),
            child: Form(
              key: formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(height: availableH * 0.18),
                  ..._formContent(ctx, tp, ts, fill, border, primary, cs),
                  SizedBox(height: availableH * 0.10),
                ],
              ),
            ),
          ),
        ),
      );
    });
  }

  List<Widget> _formContent(
      BuildContext ctx,
      Color tp, Color ts, Color fill, Color border, Color primary, ColorScheme cs,
      ) =>
      [
        const Text('👋', style: TextStyle(fontSize: 26)),
        const SizedBox(height: 8),
        Text(
          'Chào mừng bạn đến với\nOriginal Taste',
          style: TextStyle(
            fontSize: 26, fontWeight: FontWeight.w800,
            color: tp, height: 1.15, letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 24),

        _Field(
          controller: userCtrl, focusNode: userFocus,
          label: 'Tên đăng nhập', hint: 'Nhập tên đăng nhập',
          textInputAction: TextInputAction.next,
          onSubmitted: (_) => FocusScope.of(ctx).requestFocus(passFocus),
          validator: (v) =>
          (v?.trim().isEmpty ?? true) ? 'Vui lòng nhập tên đăng nhập' : null,
          tp: tp, ts: ts, fill: fill, border: border, primary: primary,
        ),
        const SizedBox(height: 10),

        _PassField(
          controller: passCtrl, focusNode: passFocus,
          onSubmitted: (_) => onLogin(),
          validator: (v) =>
          (v?.isEmpty ?? true) ? 'Vui lòng nhập mật khẩu' : null,
          tp: tp, ts: ts, fill: fill, border: border, primary: primary,
        ),
        const SizedBox(height: 8),

        GestureDetector(
          onTap: () {},
          child: Text('Quên mật khẩu?',
              style: TextStyle(fontSize: 13, color: ts)),
        ),
        const SizedBox(height: 16),

        GestureDetector(
          onTap: () => onRememberChanged(!rememberMe),
          child: Row(children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              width: 18, height: 18,
              decoration: BoxDecoration(
                color: rememberMe ? primary : Colors.transparent,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: rememberMe ? primary : border,
                  width: 1.5,
                ),
              ),
              child: rememberMe
                  ? Icon(Icons.check_rounded, color: cs.onPrimary, size: 12)
                  : null,
            ),
            const SizedBox(width: 8),
            Text('Ghi nhớ đăng nhập',
                style: TextStyle(fontSize: 13, color: ts)),
          ]),
        ),
        const SizedBox(height: 22),

        _LoginBtn(
          isLoading: isLoading, onPressed: onLogin,
          primary: primary, onPrimary: cs.onPrimary,
        ),
      ];
}

// ══════════════════════════════════════════════════════════════
// BLOB PANEL — StatefulWidget để cache dot picture
// ══════════════════════════════════════════════════════════════
class _BlobPanel extends StatefulWidget {
  @override
  State<_BlobPanel> createState() => _BlobPanelState();
}

class _BlobPanelState extends State<_BlobPanel> {
  // Cache dot picture theo size — tránh vẽ lại hàng trăm circle mỗi frame
  ui.Picture? _dotPicture;
  Size        _dotPictureSize = Size.zero;
  Color       _dotPictureColor = Colors.transparent;

  ui.Picture _buildDotPicture(Size size, Color color) {
    final recorder = ui.PictureRecorder();
    final canvas   = Canvas(recorder);
    final paint    = Paint()..color = color..style = PaintingStyle.fill;
    const gap      = 13.0;
    for (double x = 0; x < size.width; x += gap) {
      for (double y = 0; y < size.height; y += gap) {
        canvas.drawCircle(Offset(x, y), 1.3, paint);
      }
    }
    return recorder.endRecording();
  }

  @override
  void dispose() {
    _dotPicture?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark  = Theme.of(context).brightness == Brightness.dark;
    final panelBg = isDark ? const Color(0xFF0D0D0D) : const Color(0xFFFEFEFE);
    final dotColor = Colors.white.withOpacity(isDark ? 0.35 : 0.6);

    return SizedBox.expand(
      child: Stack(children: [
        Container(color: panelBg),
        Positioned(top: -30, right: 10,
            child: _Blob(w: 310, h: 290,
                color: const Color(0xFF8B7CF8).withOpacity(isDark ? 0.45 : 0.55),
                r: const [0.62, 0.28, 0.55, 0.72])),
        Positioned(top: 80, right: 60,
            child: _Blob(w: 270, h: 260,
                color: const Color(0xFFFF5FA0).withOpacity(isDark ? 0.45 : 0.55),
                r: const [0.32, 0.68, 0.58, 0.38])),
        Positioned(top: 190, right: 0,
            child: _Blob(w: 210, h: 205,
                color: const Color(0xFFFF9A5C).withOpacity(isDark ? 0.42 : 0.52),
                r: const [0.48, 0.38, 0.65, 0.32])),

        // Dots: dùng CustomPaint với picture cache
        Positioned.fill(
          child: LayoutBuilder(builder: (ctx, constraints) {
            final size = Size(constraints.maxWidth, constraints.maxHeight);
            // Chỉ rebuild picture khi size hoặc màu thay đổi
            if (size != _dotPictureSize || dotColor != _dotPictureColor) {
              _dotPicture?.dispose();
              _dotPicture      = _buildDotPicture(size, dotColor);
              _dotPictureSize  = size;
              _dotPictureColor = dotColor;
            }
            return CustomPaint(
              painter: _CachedDotPainter(picture: _dotPicture!),
            );
          }),
        ),

        Positioned(
          bottom: 32, left: 0, right: 0,
          child: Center(
            child: Text(
              'Cần hỗ trợ? Liên hệ quản trị viên',
              style: TextStyle(
                fontSize: 12,
                color: (isDark ? Colors.white : Colors.black).withOpacity(0.3),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}

// Painter chỉ drawPicture — cực kỳ nhanh, không loop
class _CachedDotPainter extends CustomPainter {
  final ui.Picture picture;
  const _CachedDotPainter({required this.picture});

  @override
  void paint(Canvas canvas, Size size) => canvas.drawPicture(picture);

  @override
  bool shouldRepaint(_CachedDotPainter old) => old.picture != picture;
}

// ══════════════════════════════════════════════════════════════
// BLOB, FIELD WIDGETS — giữ nguyên
// ══════════════════════════════════════════════════════════════
class _Blob extends StatelessWidget {
  final double w, h;
  final Color color;
  final List<double> r;
  const _Blob({required this.w, required this.h, required this.color, required this.r});

  @override
  Widget build(BuildContext context) => Container(
    width: w, height: h,
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.only(
        topLeft:     Radius.circular(w * r[0]),
        topRight:    Radius.circular(w * r[1]),
        bottomRight: Radius.circular(w * r[2]),
        bottomLeft:  Radius.circular(w * r[3]),
      ),
    ),
  );
}

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final String label, hint;
  final TextInputAction textInputAction;
  final void Function(String)? onSubmitted;
  final String? Function(String?)? validator;
  final bool obscureText;
  final Widget? suffixIcon;
  final Color tp, ts, fill, border, primary;

  const _Field({
    required this.controller, required this.focusNode,
    required this.label, required this.hint,
    this.textInputAction = TextInputAction.next,
    this.onSubmitted, this.validator,
    this.obscureText = false, this.suffixIcon,
    required this.tp, required this.ts,
    required this.fill, required this.border, required this.primary,
  });

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label,
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: ts)),
      const SizedBox(height: 5),
      TextFormField(
        controller: controller, focusNode: focusNode,
        obscureText: obscureText, textInputAction: textInputAction,
        onFieldSubmitted: onSubmitted, validator: validator,
        style: TextStyle(color: tp, fontSize: 15),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: ts.withOpacity(0.5)),
          suffixIcon: suffixIcon,
          filled: true, fillColor: fill,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: primary, width: 1.5),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFFF87171)),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFFF87171), width: 1.5),
          ),
          errorStyle: const TextStyle(fontSize: 11, height: 1.2),
        ),
      ),
    ],
  );
}

class _PassField extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final void Function(String)? onSubmitted;
  final String? Function(String?)? validator;
  final Color tp, ts, fill, border, primary;

  const _PassField({
    required this.controller, required this.focusNode,
    this.onSubmitted, this.validator,
    required this.tp, required this.ts,
    required this.fill, required this.border, required this.primary,
  });

  @override
  State<_PassField> createState() => _PassFieldState();
}

class _PassFieldState extends State<_PassField> {
  bool _hide = true;

  @override
  Widget build(BuildContext context) => _Field(
    controller: widget.controller, focusNode: widget.focusNode,
    label: 'Mật khẩu', hint: 'Nhập mật khẩu',
    textInputAction: TextInputAction.done,
    onSubmitted: widget.onSubmitted, validator: widget.validator,
    obscureText: _hide,
    suffixIcon: IconButton(
      icon: Icon(
        _hide ? Icons.visibility_off_outlined : Icons.visibility_outlined,
        size: 18, color: widget.ts,
      ),
      onPressed: () => setState(() => _hide = !_hide),
    ),
    tp: widget.tp, ts: widget.ts,
    fill: widget.fill, border: widget.border, primary: widget.primary,
  );
}

class _LoginBtn extends StatelessWidget {
  final bool isLoading;
  final VoidCallback onPressed;
  final Color primary, onPrimary;

  const _LoginBtn({
    required this.isLoading, required this.onPressed,
    required this.primary, required this.onPrimary,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: isLoading ? null : onPressed,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      width: double.infinity, height: 50,
      decoration: BoxDecoration(
        color: isLoading ? primary.withOpacity(0.7) : primary,
        borderRadius: BorderRadius.circular(8),
        boxShadow: isLoading ? [] : [
          BoxShadow(
            color: primary.withOpacity(0.35),
            blurRadius: 14, offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Center(
        child: isLoading
            ? SizedBox(
          width: 20, height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation(onPrimary),
          ),
        )
            : Text('Đăng nhập',
            style: TextStyle(
              color: onPrimary, fontSize: 15, fontWeight: FontWeight.w700,
            )),
      ),
    ),
  );
}