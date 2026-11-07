import 'package:flutter/material.dart';

import '../models/user_profile.dart';

/// Design tokens mirrored from the Dekad_Kad Figma file
/// (Color / Profile Mode / Dimension variable collections).
abstract final class DekadColors {
  static const ink900 = Color(0xFF0F1222);
  static const ink600 = Color(0xFF4A4F66);
  static const ink400 = Color(0xFF8A8FA6);
  static const ink200 = Color(0xFFC9CCD9);
  static const line = Color(0xFFE6E8F0);
  static const surface = Color(0xFFFFFFFF);
  static const canvas = Color(0xFFF5F6FA);

  static const ai = Color(0xFF7C4DFF);
  static const aiSoft = Color(0xFFF1EBFF);
  static const success = Color(0xFF16A34A);
  static const successSoft = Color(0xFFE6F6EC);

  static const pro = Color(0xFF3D4BFF);
  static const proSoft = Color(0xFFE8EAFF);
  static const personal = Color(0xFFFF6B4A);
  static const personalSoft = Color(0xFFFFEDE7);

  /// The "accent" variable: follows the active profile mode.
  static Color accent(ProfileMode mode) =>
      mode == ProfileMode.professional ? pro : personal;

  /// The "accent-soft" variable.
  static Color accentSoft(ProfileMode mode) =>
      mode == ProfileMode.professional ? proSoft : personalSoft;
}

abstract final class DekadRadius {
  static const sm = 10.0;
  static const md = 16.0;
  static const lg = 24.0;
  static const card = 28.0;
}

/// Text styles from the Figma type ramp (Plus Jakarta Sans).
abstract final class DekadText {
  static const _family = 'PlusJakartaSans';

  static const display = TextStyle(
    fontFamily: _family,
    fontSize: 32,
    fontWeight: FontWeight.w800,
    height: 38 / 32,
    letterSpacing: -1,
    color: DekadColors.ink900,
  );
  static const h1 = TextStyle(
    fontFamily: _family,
    fontSize: 24,
    fontWeight: FontWeight.w700,
    height: 30 / 24,
    letterSpacing: -0.5,
    color: DekadColors.ink900,
  );
  static const h2 = TextStyle(
    fontFamily: _family,
    fontSize: 18,
    fontWeight: FontWeight.w700,
    height: 24 / 18,
    letterSpacing: -0.2,
    color: DekadColors.ink900,
  );
  static const body = TextStyle(
    fontFamily: _family,
    fontSize: 15,
    fontWeight: FontWeight.w400,
    height: 22 / 15,
    color: DekadColors.ink900,
  );
  static const bodyStrong = TextStyle(
    fontFamily: _family,
    fontSize: 15,
    fontWeight: FontWeight.w600,
    height: 22 / 15,
    color: DekadColors.ink900,
  );
  static const label = TextStyle(
    fontFamily: _family,
    fontSize: 13,
    fontWeight: FontWeight.w600,
    height: 18 / 13,
    color: DekadColors.ink900,
  );
  static const caption = TextStyle(
    fontFamily: _family,
    fontSize: 12,
    fontWeight: FontWeight.w500,
    height: 16 / 12,
    letterSpacing: 0.2,
    color: DekadColors.ink400,
  );
  static const overline = TextStyle(
    fontFamily: _family,
    fontSize: 11,
    fontWeight: FontWeight.w700,
    height: 14 / 11,
    letterSpacing: 1,
    color: DekadColors.ink400,
  );
}

/// Figma effect style "Elevation/Card".
const cardShadow = [
  BoxShadow(color: Color(0x140F1222), offset: Offset(0, 8), blurRadius: 24),
];

/// Figma effect style "Elevation/Raised".
const raisedShadow = [
  BoxShadow(color: Color(0x1A0F1222), offset: Offset(0, 2), blurRadius: 6),
];

ThemeData buildDekadTheme() {
  final base = ThemeData(
    useMaterial3: true,
    fontFamily: 'PlusJakartaSans',
    colorScheme: ColorScheme.fromSeed(
      seedColor: DekadColors.pro,
      primary: DekadColors.pro,
      surface: DekadColors.surface,
    ),
    scaffoldBackgroundColor: DekadColors.canvas,
  );
  return base.copyWith(
    appBarTheme: const AppBarTheme(
      backgroundColor: DekadColors.canvas,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      foregroundColor: DekadColors.ink900,
      titleTextStyle: DekadText.h2,
    ),
    snackBarTheme: const SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: DekadColors.ink900,
      contentTextStyle: TextStyle(
        fontFamily: 'PlusJakartaSans',
        fontSize: 14,
        color: DekadColors.surface,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: DekadColors.surface,
      labelStyle: DekadText.caption,
      hintStyle: DekadText.body.copyWith(color: DekadColors.ink400),
      contentPadding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(DekadRadius.md),
        borderSide: const BorderSide(color: DekadColors.line, width: 1.5),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(DekadRadius.md),
        borderSide: const BorderSide(color: DekadColors.line, width: 1.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(DekadRadius.md),
        borderSide: const BorderSide(color: DekadColors.pro, width: 2),
      ),
    ),
  );
}
