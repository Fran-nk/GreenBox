import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

/// GreenBox Typography System
/// Fonts: Poppins (headings), PT Sans Caption (body), PT Mono (data), Oswald (values)
class AppTextStyles {
  AppTextStyles._();

  // ── Greeting / Headings ──
  static TextStyle greeting = GoogleFonts.poppins(
    fontSize: 28,
    fontWeight: FontWeight.w400,
    color: AppColors.textPrimary,
  );

  static TextStyle alertSubtitle = GoogleFonts.poppins(
    fontSize: 16,
    fontWeight: FontWeight.w300,
    color: AppColors.textPrimary,
  );

  static TextStyle alertBold = GoogleFonts.poppins(
    fontSize: 16,
    fontWeight: FontWeight.w700,
    color: AppColors.alertRed,
  );

  // ── Plant Names ──
  static TextStyle plantScientific = GoogleFonts.ptSansCaption(
    fontSize: 20,
    fontWeight: FontWeight.w400,
    color: AppColors.textOnDark,
  );

  static TextStyle plantCommon = GoogleFonts.ptSansCaption(
    fontSize: 40,
    fontWeight: FontWeight.w700,
    color: AppColors.textOnDark,
  );

  // ── Sensor Values ──
  static TextStyle sensorLabel = GoogleFonts.ptMono(
    fontSize: 15,
    fontWeight: FontWeight.w400,
    color: AppColors.textOnDark,
  );

  static TextStyle sensorValue = GoogleFonts.oswald(
    fontSize: 35,
    fontWeight: FontWeight.w400,
    color: AppColors.textOnDark,
  );

  static TextStyle sensorUnit = GoogleFonts.oswald(
    fontSize: 15,
    fontWeight: FontWeight.w400,
    color: AppColors.textOnDark,
  );

  // ── Timeline / Growth Stages ──
  static TextStyle timeInfo = GoogleFonts.ptSansCaption(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: AppColors.textOnDark,
  );

  static TextStyle timeInfoBold = GoogleFonts.ptSansCaption(
    fontSize: 12,
    fontWeight: FontWeight.w700,
    color: AppColors.textOnDark,
  );

  // ── Tab Labels ──
  static TextStyle tabActive = GoogleFonts.ptSansCaption(
    fontSize: 20,
    fontWeight: FontWeight.w700,
    color: AppColors.textOnDark,
  );

  static TextStyle tabInactive = GoogleFonts.ptSansCaption(
    fontSize: 20,
    fontWeight: FontWeight.w400,
    color: AppColors.textPrimary,
  );

  // ── Chart Labels ──
  static TextStyle chartLabel = GoogleFonts.ptSansCaption(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
  );

  static TextStyle chartFilter = GoogleFonts.ptSansCaption(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: AppColors.textPrimary,
  );
}
