// lib/features/settings/screens/change_password_screen.dart

import 'package:flutter/material.dart';
import '../../../shared/widgets/app_toast.dart';
import '../../../app/theme/app_colors.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _formKey       = GlobalKey<FormState>();
  final _newPassCtrl   = TextEditingController();
  final _confirmCtrl   = TextEditingController();

  bool _obscureNew     = true;
  bool _obscureConfirm = true;
  bool _loading        = false;

  @override
  void dispose() {
    _newPassCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_newPassCtrl.text != _confirmCtrl.text) {
      AppToast.error(context, 'Mật khẩu không trùng khớp');
      return;
    }

    setState(() => _loading = true);
    await Future.delayed(const Duration(milliseconds: 600)); // TODO: gọi API
    if (!mounted) return;
    setState(() => _loading = false);

    AppToast.success(context, 'Đổi mật khẩu thành công');
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Đổi mật khẩu'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 8),
                _buildHeader(isDark),
                const SizedBox(height: 32),

                // Mật khẩu mới
                _PasswordField(
                  controller:  _newPassCtrl,
                  label:       'Mật khẩu mới',
                  hint:        'Nhập mật khẩu mới',
                  obscure:     _obscureNew,
                  isDark:      isDark,
                  onToggle:    () => setState(() => _obscureNew = !_obscureNew),
                  validator:   (v) {
                    if (v == null || v.isEmpty) return 'Vui lòng nhập mật khẩu mới';
                    if (v.length < 6) return 'Mật khẩu phải ít nhất 6 ký tự';
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Xác nhận mật khẩu
                _PasswordField(
                  controller:  _confirmCtrl,
                  label:       'Xác nhận mật khẩu',
                  hint:        'Nhập lại mật khẩu mới',
                  obscure:     _obscureConfirm,
                  isDark:      isDark,
                  onToggle:    () => setState(() => _obscureConfirm = !_obscureConfirm),
                  validator:   (v) {
                    if (v == null || v.isEmpty) return 'Vui lòng xác nhận mật khẩu';
                    return null;
                  },
                ),
                const SizedBox(height: 32),

                // Nút xác nhận
                FilledButton(
                  onPressed: _loading ? null : _submit,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: _loading
                      ? const SizedBox(
                      width: 20, height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                      : const Text('Xác nhận',
                      style: TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
    return Column(
      children: [
        Container(
          width: 64, height: 64,
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.12),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.lock_reset_rounded,
              color: AppColors.primary, size: 32),
        ),
        const SizedBox(height: 14),
        Text('Đổi mật khẩu',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        Text('Nhập mật khẩu mới cho tài khoản của bạn',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

// ── Admin change password screen ──────────────────────────────────────────────

class ChangeAdminPasswordScreen extends StatefulWidget {
  const ChangeAdminPasswordScreen({super.key});

  @override
  State<ChangeAdminPasswordScreen> createState() =>
      _ChangeAdminPasswordScreenState();
}

class _ChangeAdminPasswordScreenState
    extends State<ChangeAdminPasswordScreen> {
  final _formKey      = GlobalKey<FormState>();
  final _oldCtrl      = TextEditingController();
  final _newCtrl      = TextEditingController();
  final _confirmCtrl  = TextEditingController();

  bool _obscureOld     = true;
  bool _obscureNew     = true;
  bool _obscureConfirm = true;
  bool _loading        = false;

  // Hardcode để test — thay bằng API sau
  static const _fakeOldPassword = '123456';

  @override
  void dispose() {
    _oldCtrl.dispose();
    _newCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final oldPass     = _oldCtrl.text;
    final newPass     = _newCtrl.text;
    final confirmPass = _confirmCtrl.text;

    // TH1: Mật khẩu cũ sai
    if (oldPass != _fakeOldPassword) {
      AppToast.error(context, 'Mật khẩu cũ không đúng');
      return;
    }

    // TH2: Mật khẩu cũ trùng mật khẩu mới
    if (oldPass == newPass) {
      AppToast.error(context, 'Mật khẩu mới không được giống mật khẩu cũ');
      return;
    }

    // TH3: Mật khẩu mới không khớp xác nhận
    if (newPass != confirmPass) {
      AppToast.error(context, 'Mật khẩu xác nhận không trùng khớp');
      return;
    }

    setState(() => _loading = true);
    await Future.delayed(const Duration(milliseconds: 600)); // TODO: gọi API
    if (!mounted) return;
    setState(() => _loading = false);

    AppToast.success(context, 'Đổi mật khẩu quản lý thành công');
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Đổi mật khẩu quản lý'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 8),
                _buildHeader(isDark),
                const SizedBox(height: 32),

                // Mật khẩu cũ
                _PasswordField(
                  controller: _oldCtrl,
                  label:      'Mật khẩu cũ',
                  hint:       'Nhập mật khẩu hiện tại',
                  obscure:    _obscureOld,
                  isDark:     isDark,
                  onToggle:   () => setState(() => _obscureOld = !_obscureOld),
                  validator:  (v) {
                    if (v == null || v.isEmpty) return 'Vui lòng nhập mật khẩu cũ';
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Mật khẩu mới
                _PasswordField(
                  controller: _newCtrl,
                  label:      'Mật khẩu mới',
                  hint:       'Nhập mật khẩu mới',
                  obscure:    _obscureNew,
                  isDark:     isDark,
                  onToggle:   () => setState(() => _obscureNew = !_obscureNew),
                  validator:  (v) {
                    if (v == null || v.isEmpty) return 'Vui lòng nhập mật khẩu mới';
                    if (v.length < 6) return 'Mật khẩu phải ít nhất 6 ký tự';
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Xác nhận mật khẩu mới
                _PasswordField(
                  controller: _confirmCtrl,
                  label:      'Xác nhận mật khẩu mới',
                  hint:       'Nhập lại mật khẩu mới',
                  obscure:    _obscureConfirm,
                  isDark:     isDark,
                  onToggle:   () => setState(() => _obscureConfirm = !_obscureConfirm),
                  validator:  (v) {
                    if (v == null || v.isEmpty) return 'Vui lòng xác nhận mật khẩu';
                    return null;
                  },
                ),
                const SizedBox(height: 32),

                FilledButton(
                  onPressed: _loading ? null : _submit,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: _loading
                      ? const SizedBox(
                      width: 20, height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                      : const Text('Xác nhận',
                      style: TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
    return Column(
      children: [
        Container(
          width: 64, height: 64,
          decoration: BoxDecoration(
            color: Colors.orange.withOpacity(0.12),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.admin_panel_settings_rounded,
              color: Colors.orange, size: 32),
        ),
        const SizedBox(height: 14),
        Text('Đổi mật khẩu quản lý',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        Text('Chỉ dành cho tài khoản quản trị viên',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

// ── Shared password field widget ──────────────────────────────────────────────

class _PasswordField extends StatelessWidget {
  final TextEditingController controller;
  final String                label;
  final String                hint;
  final bool                  obscure;
  final bool                  isDark;
  final VoidCallback          onToggle;
  final String? Function(String?)? validator;

  const _PasswordField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.obscure,
    required this.isDark,
    required this.onToggle,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    final cs     = Theme.of(context).colorScheme;
    final txtSec = isDark
        ? const Color(0xFF94A3B8)
        : const Color(0xFF64748B);
    final border = isDark
        ? const Color(0xFF334155)
        : const Color(0xFFE2E8F0);
    final bg     = isDark
        ? const Color(0xFF1E293B)
        : const Color(0xFFF8FAFC);

    return TextFormField(
      controller:    controller,
      obscureText:   obscure,
      validator:     validator,
      style: TextStyle(
          fontSize: 15,
          color: isDark ? Colors.white : const Color(0xFF0F172A),
          fontWeight: FontWeight.w500),
      decoration: InputDecoration(
        labelText:   label,
        hintText:    hint,
        hintStyle:   TextStyle(
            color: txtSec.withOpacity(0.5), fontWeight: FontWeight.w400),
        prefixIcon:  Icon(Icons.lock_outline_rounded, size: 20, color: txtSec),
        suffixIcon:  IconButton(
          onPressed: onToggle,
          icon: Icon(
            obscure
                ? Icons.visibility_off_outlined
                : Icons.visibility_outlined,
            size: 20, color: txtSec,
          ),
        ),
        filled:          true,
        fillColor:       bg,
        labelStyle:      TextStyle(fontSize: 13, color: txtSec),
        contentPadding:  const EdgeInsets.symmetric(
            horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: border)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: border)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: cs.primary, width: 1.5)),
        errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Colors.red)),
        focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Colors.red, width: 1.5)),
      ),
    );
  }
}