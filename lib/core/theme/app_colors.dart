import 'package:flutter/material.dart';

/// The UneBil brand palette.
///
/// Screen widgets should normally consume these colors through the active
/// [ColorScheme]. Keeping the source palette here prevents small variations
/// from spreading through the application.
abstract final class AppColors {
  static const primaryTeal = Color(0xFF0E3D3B);
  static const deepTeal = Color(0xFF0A2F2E);
  static const mintAccent = Color(0xFF8FCBBE);
  static const softMint = Color(0xFFD8EEE8);

  static const lightBackground = Color(0xFFF6F7F5);
  static const lightSurface = Color(0xFFEEF2F0);
  static const lightElevatedSurface = Color(0xFFFFFFFF);
  static const lightOutline = Color(0xFFC7D5D0);
  static const lightText = Color(0xFF163332);
  static const lightMutedText = Color(0xFF526B67);

  static const darkBackground = Color(0xFF0D1616);
  static const darkSurface = Color(0xFF132121);
  static const darkElevatedSurface = Color(0xFF18302F);
  static const darkOutline = Color(0xFF4E6662);
  static const darkText = Color(0xFFE7F0ED);
  static const darkMutedText = Color(0xFFAFC3BE);
  static const darkPrimaryContainer = Color(0xFF22413E);
  static const darkSecondaryContainer = Color(0xFF294B47);

  static const lightError = Color(0xFFBA1A1A);
  static const lightErrorContainer = Color(0xFFFFDAD6);
  static const darkError = Color(0xFFFFB4AB);
  static const darkErrorContainer = Color(0xFF93000A);
}
