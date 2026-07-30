import 'package:flutter/material.dart';

/// Temporary neutral brand palette.
///
/// Keep color decisions here so the experimental appearance can be replaced
/// without changing individual screens.
abstract final class AppColors {
  static const lightPrimary = Color(0xFF4058A6);
  static const lightBackground = Color(0xFFF6F7F9);
  static const lightSurface = Color(0xFFFFFFFF);
  static const lightSurfaceVariant = Color(0xFFEEF0F5);
  static const lightOutline = Color(0xFFD9DCE5);
  static const lightText = Color(0xFF1B1D24);
  static const lightMutedText = Color(0xFF5F6472);

  static const darkPrimary = Color(0xFFAEBEFF);
  static const darkBackground = Color(0xFF121318);
  static const darkSurface = Color(0xFF1A1C22);
  static const darkSurfaceVariant = Color(0xFF252832);
  static const darkOutline = Color(0xFF3B3F4B);
  static const darkText = Color(0xFFF1F1F5);
  static const darkMutedText = Color(0xFFB8BBC6);
}
