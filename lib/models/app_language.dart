enum AppLanguage {
  ru('ru', 'Русский'),
  kk('kk', 'Қазақша'),
  en('en', 'English');

  const AppLanguage(this.code, this.label);

  final String code;
  final String label;

  static AppLanguage fromCode(String? code) {
    return AppLanguage.values.firstWhere(
      (language) => language.code == code,
      orElse: () => AppLanguage.ru,
    );
  }
}
