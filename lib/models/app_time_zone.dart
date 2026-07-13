enum AppTimeZone {
  kazakhstan('kazakhstan', 'Kazakhstan', 'Asia/Almaty'),
  china('china', 'China', 'Asia/Shanghai'),
  spain('spain', 'Spain', 'Europe/Madrid');

  const AppTimeZone(this.id, this.label, this.locationName);

  final String id;
  final String label;

  /// IANA timezone name used by the timezone package.
  final String locationName;

  static AppTimeZone fromId(String? id) {
    return AppTimeZone.values.firstWhere(
      (timeZone) => timeZone.id == id,
      orElse: () => AppTimeZone.kazakhstan,
    );
  }
}
