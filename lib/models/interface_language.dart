enum InterfaceLanguage {
  kk('kk', 'Қазақша'),
  en('en', 'English'),
  ru('ru', 'Русский');

  const InterfaceLanguage(this.code, this.label);

  final String code;
  final String label;

  static InterfaceLanguage? tryFromCode(String? code) {
    for (final language in InterfaceLanguage.values) {
      if (language.code == code) {
        return language;
      }
    }
    return null;
  }
}
