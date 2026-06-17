import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Driver brand — black/dark gray
  static const Color orange = Color(0xFF2D2D2D);       // primary (replaces orange)
  static const Color orangeLight = Color(0xFF3D3D3D);  // primary light
  static const Color orangeDark = Color(0xFF000000);   // primary dark / true black
  static const Color green = Color(0xFF02BA26);
  static const Color greenDark = Color(0xFF106C2F);
  static const Color red = Color(0xFFEF4444);
  static const Color yellow = Color(0xFFFFC107);

  // Dark surfaces
  static const Color darkBg = Color(0xFF000000);
  static const Color darkSurface = Color(0xFF1A1A1A);
  static const Color darkCard = Color(0xFF2D2D2D);
  static const Color darkBorder = Color(0x22FFFFFF);
  static const Color darkText = Color(0xFFFFFFFF);
  static const Color darkSubText = Color(0xFF888888);

  // Light surfaces
  static const Color lightBg = Color(0xFFF4F4F4);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightCard = Color(0xFFFFFFFF);
  static const Color lightBorder = Color(0xFFE0E0E0);
  static const Color lightText = Color(0xFF000000);
  static const Color lightSubText = Color(0xFF555555);

  // Tints (now based on dark gray)
  static const Color orangeTintDark = Color(0x182D2D2D);
  static const Color orangeTintLight = Color(0x102D2D2D);
  static const Color greenTintDark = Color(0x12026B26);
  static const Color greenTintLight = Color(0x0F02BA26);

  static List<BoxShadow> orangeGlow = [
    BoxShadow(
      color: orange.withValues(alpha: 0.35),
      blurRadius: 24,
      offset: const Offset(0, 8),
    ),
  ];

  static List<BoxShadow> greenGlow = [
    BoxShadow(
      color: green.withValues(alpha: 0.35),
      blurRadius: 24,
      offset: const Offset(0, 8),
    ),
  ];
}
