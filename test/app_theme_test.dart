import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unebil/core/theme/app_colors.dart';
import 'package:unebil/core/theme/app_theme.dart';
import 'package:unebil/models/app_theme_mode.dart';

void main() {
  test('light theme uses the UneBil brand palette and soft geometry', () {
    final theme = AppTheme.light;

    expect(theme.useMaterial3, isTrue);
    expect(theme.scaffoldBackgroundColor, AppColors.lightBackground);
    expect(theme.colorScheme.primary, AppColors.primaryTeal);
    expect(theme.colorScheme.primaryContainer, AppColors.softMint);
    expect(theme.colorScheme.onSurface, AppColors.lightText);
    expect(theme.colorScheme.error, AppColors.lightError);
    expect(theme.cardTheme.color, AppColors.lightSurface);
  });

  test('dark theme uses UneBil surfaces instead of pure black', () {
    final theme = AppTheme.dark;

    expect(theme.useMaterial3, isTrue);
    expect(theme.scaffoldBackgroundColor, AppColors.darkBackground);
    expect(theme.colorScheme.primary, AppColors.mintAccent);
    expect(theme.colorScheme.surface, AppColors.darkSurface);
    expect(
      theme.colorScheme.surfaceContainerHigh,
      AppColors.darkElevatedSurface,
    );
    expect(theme.colorScheme.onSurface, AppColors.darkText);
    expect(theme.colorScheme.error, AppColors.darkError);
    expect(theme.scaffoldBackgroundColor, isNot(Colors.black));
  });

  test('theme modes map to Material theme modes', () {
    expect(AppThemeMode.system.materialThemeMode, ThemeMode.system);
    expect(AppThemeMode.light.materialThemeMode, ThemeMode.light);
    expect(AppThemeMode.dark.materialThemeMode, ThemeMode.dark);
  });

  test('system bars use readable icons for each brightness', () {
    final light = AppTheme.systemUiOverlayStyle(Brightness.light);
    final dark = AppTheme.systemUiOverlayStyle(Brightness.dark);

    expect(light.statusBarColor, AppColors.lightBackground);
    expect(light.statusBarIconBrightness, Brightness.dark);
    expect(light.systemNavigationBarIconBrightness, Brightness.dark);
    expect(dark.statusBarColor, AppColors.darkBackground);
    expect(dark.statusBarIconBrightness, Brightness.light);
    expect(dark.systemNavigationBarIconBrightness, Brightness.light);
    expect(light, isA<SystemUiOverlayStyle>());
  });
}
