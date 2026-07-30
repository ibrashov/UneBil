enum AppThemeMode {
  system('system'),
  light('light'),
  dark('dark');

  const AppThemeMode(this.id);

  final String id;

  static AppThemeMode fromId(String? id) {
    return AppThemeMode.values.firstWhere(
      (mode) => mode.id == id,
      orElse: () => AppThemeMode.system,
    );
  }
}
