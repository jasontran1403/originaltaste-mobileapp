// lib/features/pos/widgets/_pos_form_helpers.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:originaltaste/services/pos_service.dart';
import 'package:originaltaste/shared/widgets/network_image_viewer.dart';

Color posSurface(bool d) => d ? const Color(0xFF1E293B) : Colors.white;
Color posBg(bool d)      => d ? const Color(0xFF0F172A) : const Color(0xFFF4F6FA);
Color posDivider(bool d) => d ? const Color(0xFF2D3F55) : const Color(0xFFEAECF0);
Color posTxtPri(bool d)  => d ? Colors.white : const Color(0xFF111827);
Color posTxtSec(bool d)  => d ? const Color(0xFF94A3B8) : const Color(0xFF6B7280);

class PosFormHelpers {
  PosFormHelpers._();

  static Widget handle(bool isDark) => Center(child: Container(
    margin: const EdgeInsets.symmetric(vertical: 12),
    width: 36, height: 4,
    decoration: BoxDecoration(
      color: posTxtSec(isDark).withOpacity(0.3),
      borderRadius: BorderRadius.circular(2),
    ),
  ));

  static Widget titleRow({required bool isDark, required IconData icon, required String label}) =>
      Builder(builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        return Row(children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(color: cs.primary.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, size: 18, color: cs.primary),
          ),
          const SizedBox(width: 10),
          Text(label, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800,
              color: posTxtPri(isDark))),
        ]);
      });

  static Widget saveButton({required String label, required bool saving, required VoidCallback onTap}) =>
      SizedBox(width: double.infinity, height: 52,
          child: ElevatedButton(
            onPressed: saving ? null : onTap,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF6B2C),
              foregroundColor: Colors.white,
              disabledBackgroundColor: const Color(0xFFFF6B2C).withOpacity(0.5),
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: saving
                ? const SizedBox(width: 20, height: 20,
                child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                : Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          ));

  static void showError(BuildContext ctx, Object e) =>
      ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
        content: Text('Lỗi: $e'),
        backgroundColor: Theme.of(ctx).colorScheme.error,
      ));

  static Widget sectionLabel(String text, bool isDark) => Padding(
    padding: const EdgeInsets.only(bottom: 8, top: 4),
    child: Builder(builder: (ctx) {
      final cs = Theme.of(ctx).colorScheme;
      return Row(children: [
        Container(width: 3, height: 14,
            decoration: BoxDecoration(color: cs.primary, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 7),
        Text(text, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
            color: posTxtSec(isDark), letterSpacing: 0.4)),
      ]);
    }),
  );

  static Widget infoBox(String text, bool isDark) => Builder(builder: (ctx) {
    final cs = Theme.of(ctx).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.primary.withOpacity(0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: cs.primary.withOpacity(0.2)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(Icons.info_outline_rounded, size: 14, color: cs.primary),
        const SizedBox(width: 7),
        Expanded(child: Text(text, style: TextStyle(fontSize: 12,
            color: cs.primary.withOpacity(0.85)))),
      ]),
    );
  });

  static Future<File?> pickImage() async {
    final p = ImagePicker();
    final x = await p.pickImage(source: ImageSource.gallery,
        maxWidth: 800, maxHeight: 800, imageQuality: 85);
    return x != null ? File(x.path) : null;
  }
}

// ── PosFormField ─────────────────────────────────────────────

class PosFormField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? hint, helperText, suffixText;
  final bool isDark, readOnly;
  final TextInputType keyboardType;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onChanged;
  final int? maxLines;
  final VoidCallback? onTap;

  const PosFormField({super.key, required this.controller, required this.label,
    required this.isDark, this.hint, this.helperText, this.suffixText,
    this.keyboardType = TextInputType.text, this.validator, this.onChanged,
    this.maxLines = 1, this.readOnly = false, this.onTap});

  @override
  Widget build(BuildContext ctx) {
    final cs = Theme.of(ctx).colorScheme;
    return TextFormField(
      controller: controller, keyboardType: keyboardType,
      readOnly: readOnly, onTap: onTap, maxLines: maxLines, validator: validator,
      onChanged: onChanged,
      style: TextStyle(fontSize: 14, color: posTxtPri(isDark), fontWeight: FontWeight.w500),
      decoration: InputDecoration(
        labelText: label, hintText: hint, helperText: helperText, suffixText: suffixText,
        filled: true, fillColor: posBg(isDark),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: posDivider(isDark))),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: posDivider(isDark))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: cs.primary, width: 1.5)),
        errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: cs.error)),
        labelStyle: TextStyle(fontSize: 13, color: posTxtSec(isDark)),
        hintStyle: TextStyle(fontSize: 13, color: posTxtSec(isDark).withOpacity(0.6)),
      ),
    );
  }
}

// ── PosImagePicker ────────────────────────────────────────────
// Dùng NetworkImageViewer cho existingUrl để đảm bảo URL đúng
// (tự thêm /images/ nếu thiếu, thêm ngrok header, v.v.)

class PosImagePicker extends StatelessWidget {
  final File?   imageFile;
  final String? existingUrl;
  final VoidCallback  onPick;
  final VoidCallback? onRemove;

  const PosImagePicker({
    super.key,
    this.imageFile,
    this.existingUrl,
    required this.onPick,
    this.onRemove,
  });

  @override
  Widget build(BuildContext ctx) {
    final isDark = Theme.of(ctx).brightness == Brightness.dark;
    final cs     = Theme.of(ctx).colorScheme;
    final hasImg = imageFile != null
        || (existingUrl != null && existingUrl!.isNotEmpty);

    return GestureDetector(
      onTap: onPick,
      child: Container(
        height: 140,
        width:  double.infinity,
        decoration: BoxDecoration(
          color:        posBg(isDark),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: hasImg ? cs.primary.withOpacity(0.4) : posDivider(isDark),
            width: hasImg ? 1.5 : 1,
          ),
        ),
        child: hasImg
            ? Stack(children: [
          // ── Ảnh ──────────────────────────────────────
          ClipRRect(
            borderRadius: BorderRadius.circular(13),
            child: imageFile != null
            // Ảnh mới chọn từ gallery → dùng Image.file
                ? Image.file(imageFile!,
                width: double.infinity, height: 140,
                fit: BoxFit.cover)
            // Ảnh từ server → dùng NetworkImageViewer
            // (tự build URL đúng + ngrok header + shimmer)
                : NetworkImageViewer(
              imageUrl:    existingUrl,
              width:       double.infinity,
              height:      140,
              fit:         BoxFit.cover,
              forceRefresh: false,
            ),
          ),

          // ── Nút edit (góc phải) ───────────────────────
          Positioned(
            right: 8, top: 8,
            child: GestureDetector(
              onTap: onPick,
              child: _overlay(Icons.edit_rounded),
            ),
          ),

          // ── Nút xóa (góc trái) ────────────────────────
          if (onRemove != null)
            Positioned(
              left: 8, top: 8,
              child: GestureDetector(
                onTap: onRemove,
                child: _overlay(Icons.close_rounded),
              ),
            ),
        ])
            : Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.add_photo_alternate_outlined,
              size: 30, color: posTxtSec(isDark).withOpacity(0.5)),
          const SizedBox(height: 8),
          Text('Chọn ảnh từ thư viện',
              style: TextStyle(fontSize: 12, color: posTxtSec(isDark))),
        ]),
      ),
    );
  }

  Widget _overlay(IconData icon) => Container(
    padding: const EdgeInsets.all(7),
    decoration: BoxDecoration(
      color:        Colors.black.withOpacity(0.55),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Icon(icon, size: 14, color: Colors.white),
  );
}

// ── PosSegmentControl ─────────────────────────────────────────

class PosSegmentControl extends StatelessWidget {
  final List<String>   options;
  final List<IconData?> icons;
  final int    selected;
  final bool   isDark;
  final ValueChanged<int> onChanged;
  const PosSegmentControl({super.key, required this.options, required this.icons,
    required this.selected, required this.isDark, required this.onChanged});

  @override
  Widget build(BuildContext ctx) {
    final cs = Theme.of(ctx).colorScheme;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: posBg(isDark),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: posDivider(isDark))),
      child: Row(children: List.generate(options.length, (i) {
        final sel = selected == i;
        return Expanded(child: GestureDetector(
          onTap: () => onChanged(i),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(vertical: 9),
            decoration: BoxDecoration(
              color:        sel ? cs.primary : Colors.transparent,
              borderRadius: BorderRadius.circular(9),
            ),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              if (icons[i] != null) ...[
                Icon(icons[i]!, size: 14, color: sel ? Colors.white : posTxtSec(isDark)),
                const SizedBox(width: 5),
              ],
              Text(options[i], style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                  color: sel ? Colors.white : posTxtSec(isDark))),
            ]),
          ),
        ));
      })),
    );
  }
}

// ── PosNumberField ────────────────────────────────────────────

class PosNumberField extends StatefulWidget {
  final String label;
  final int value, min, max;
  final bool isDark;
  final ValueChanged<int> onChanged;
  const PosNumberField({super.key, required this.label, required this.value,
    required this.isDark, required this.onChanged, this.min = 0, this.max = 999});

  @override
  State<PosNumberField> createState() => _PosNumberFieldState();
}

class _PosNumberFieldState extends State<PosNumberField> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.value.toString());
  }

  @override
  void didUpdateWidget(PosNumberField old) {
    super.didUpdateWidget(old);
    if (old.value != widget.value) _ctrl.text = widget.value.toString();
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  void _update(int v) {
    final c = v.clamp(widget.min, widget.max);
    _ctrl.text = c.toString();
    widget.onChanged(c);
  }

  @override
  Widget build(BuildContext ctx) {
    final cs = Theme.of(ctx).colorScheme;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(widget.label, style: TextStyle(fontSize: 12,
          color: posTxtSec(widget.isDark), fontWeight: FontWeight.w600)),
      const SizedBox(height: 6),
      Container(
        decoration: BoxDecoration(color: posBg(widget.isDark),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: posDivider(widget.isDark))),
        child: Row(children: [
          _NBtn(icon: Icons.remove, isDark: widget.isDark,
              onTap: () => _update(widget.value - 1)),
          Expanded(child: TextField(
            controller: _ctrl, textAlign: TextAlign.center,
            keyboardType: TextInputType.number,
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700,
                color: posTxtPri(widget.isDark)),
            decoration: const InputDecoration(border: InputBorder.none, isDense: true,
                contentPadding: EdgeInsets.symmetric(vertical: 10)),
            onChanged: (v) { final n = int.tryParse(v); if (n != null) _update(n); },
          )),
          _NBtn(icon: Icons.add, isDark: widget.isDark,
              onTap: () => _update(widget.value + 1)),
        ]),
      ),
    ]);
  }
}

class _NBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool isDark;
  const _NBtn({required this.icon, required this.onTap, required this.isDark});
  @override
  Widget build(BuildContext ctx) {
    final cs = Theme.of(ctx).colorScheme;
    return GestureDetector(onTap: onTap,
        child: Padding(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Icon(icon, size: 18, color: cs.primary)));
  }
}