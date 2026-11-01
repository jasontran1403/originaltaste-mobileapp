// lib/app/theme/app_colors.dart

import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // ── Brand ─────────────────────────────────────────────────────
  static const primary   = Color(0xFF4ADE80); // xanh lá như navbar
  static const primaryDark = Color(0xFF22C55E);

  // ── Dark theme ────────────────────────────────────────────────
  static const darkBg        = Color(0xFF0A0A0A);
  static const darkSurface   = Color(0xFF141414);
  static const darkCard      = Color(0xFF1C1C1C);
  static const darkNavbar    = Color(0xFF111111);
  static const darkBorder    = Color(0xFF2A2A2A);
  static const darkTextPrimary   = Color(0xFFFFFFFF);
  static const darkTextSecondary = Color(0xFF9CA3AF);
  static const darkTextHint      = Color(0xFF4B5563);
  static const darkIcon      = Color(0xFF6B7280);
  static const darkIconActive = Color(0xFF4ADE80);

  // ── Light theme ───────────────────────────────────────────────
  static const lightBg        = Color(0xFFF9FAFB);
  static const lightSurface   = Color(0xFFFFFFFF);
  static const lightCard      = Color(0xFFFFFFFF);
  static const lightNavbar    = Color(0xFFFFFFFF);
  static const lightBorder    = Color(0xFFE5E7EB);
  static const lightTextPrimary   = Color(0xFF111827);
  static const lightTextSecondary = Color(0xFF6B7280);
  static const lightTextHint      = Color(0xFF9CA3AF);
  static const lightIcon      = Color(0xFF9CA3AF);
  static const lightIconActive = Color(0xFF16A34A);

  // ── Status ────────────────────────────────────────────────────
  static const success = Color(0xFF4ADE80);
  static const warning = Color(0xFFFBBF24);
  static const error   = Color(0xFFF87171);
  static const info    = Color(0xFF60A5FA);
}
