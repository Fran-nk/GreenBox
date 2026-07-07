import 'package:flutter/material.dart';

/// GreenBox Design System Colors
/// Derived from Figma design tokens
class AppColors {
  AppColors._();

  // ── Primary Palette ──
  static const Color primary = Color(0xFF94DF1B);       // Green accent
  static const Color primaryDark = Color(0xFF9FEC24);    // Neon green
  static const Color background = Color(0xFFEEEEEE);    // App background
  static const Color surface = Color(0xFFFFFFFF);        // Cards surface
  static const Color darkSurface = Color(0xFF1F1F1F);   // Dark cards

  // ── Sensor Card Colors ──
  static const Color phBlue = Color(0xFF0E9CFF);        // PH sensor
  static const Color ceYellow = Color(0xFFCEA82C);      // CE sensor
  static const Color luzGreen = Color(0xFFB9C127);      // Light sensor
  static const Color humedadTeal = Color(0xFF27B9C1);   // Humidity sensor

  // ── Chart Colors ──
  static const Color barNormal = Color(0xFF94DF1B);     // Normal range
  static const Color barWarning = Color(0xFFDF691B);     // Warning range

  // ── Alert Colors ──
  static const Color alertRed = Color(0xFFDF281B);      // Critical alert
  static const Color alertOrange = Color(0xFFDF691B);   // Warning
  static const Color statusGood = Color(0xFF27C174);    // Status OK

  // ── Neutrals ──
  static const Color textPrimary = Color(0xFF000000);
  static const Color textSecondary = Color(0xFF333333);
  static const Color textOnDark = Color(0xFFFFFFFF);
  static const Color divider = Color(0xFFDDDDDD);
  static const Color darkOverlay = Color(0xDE1F1F1F);   // 87% opacity dark
}
