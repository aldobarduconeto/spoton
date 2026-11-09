import 'package:flutter/material.dart';

class AppColors {
  AppColors._();
  // Backgrounds
  static const Color background = Color(0xFF0D1020);
  static const Color surface = Color(0xFF101626);
  static const Color surfaceSecondary = Color(0xFF171F33);
  static const Color surfaceElevated = Color(0xFF1E2940);
  // Brand
  static const Color primary = Color(0xFF7957FF);
  static const Color secondary = Color(0xFFB55AFF);
  static const Color accent = Color(0xFFC7FF73);
  // Gradients
  static const Color gradientStart = Color(0xFFC7FF73);
  static const Color gradientMiddle = Color(0xFF7957FF);
  static const Color gradientEnd = Color(0xFFB55AFF);
  // Text
  static const Color textPrimary = Color(0xFFF4F7FF);
  static const Color textSecondary = Color(0xFFA3AEC2);
  static const Color textDisabled = Color(0xFF626D82);
  // Borders and dividers
  static const Color border = Color(0xFF273249);
  static const Color divider = Color(0xFF202A3D);
  // States
  static const Color success = Color(0xFF35D39A);
  static const Color warning = Color(0xFFFFC857);
  static const Color error = Color(0xFFFF5D73);
  static const Color info = Color(0xFFC7FF73);
  // Components
  static const Color icon = Color(0xFFA3AEC2);
  static const Color iconActive = Color(0xFFC7FF73);
  static const Color overlay = Color(0x99000000);
  // Brand gradient
  static const LinearGradient brandGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [gradientStart, gradientMiddle, gradientEnd],
  );
}
