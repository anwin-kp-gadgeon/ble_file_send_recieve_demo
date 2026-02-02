import 'package:flutter/material.dart';

class AppColors {
  // Primary & Secondary
  static const Color primary = Color(0xFF2563EB); // Royal Blue
  static const Color secondary = Color(0xFF10B981); // Emerald

  // Backgrounds & Surfaces
  static const Color background = Color(0xFFF8FAFC); // Slate-50
  static const Color surface = Colors.white;
  static const Color cardBorder = Color(0xFFE2E8F0);

  // Text Colors
  static const Color textPrimary = Color(0xFF1E293B); // Slate-800
  static const Color textSecondary = Color(0xFF64748B); // Slate-500
  static const Color textLight = Colors.white;

  // Status Colors
  static const Color success = Color(0xFF10B981);
  static const Color warning = Colors.amber;
  static const Color error = Colors.red;
  static const Color shadow = Colors.black;
  static final Color neutralGrey = Colors.grey.shade200;
  static final Color neutralGreyDark = Colors.grey.shade600;

  // Opacities/Overlays can be handled with .withValues() in code or defined here if fixed
  static const Color warningBackground = Color(
    0x1AFFC107,
  ); // Amber with low opacity approximation
  static const Color warningBorder = Color(
    0x4DFFC107,
  ); // Amber with medium opacity
}
