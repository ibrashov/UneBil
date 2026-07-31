enum AppTimeZone {
  device('device', 'Device time', null),
  kazakhstan('kazakhstan', 'Kazakhstan', 'Asia/Almaty'),
  china('china', 'China', 'Asia/Shanghai'),
  spain('spain', 'Spain', 'Europe/Madrid');

  const AppTimeZone(this.id, this.label, this.locationName);

  final String id;
  final String label;

  /// IANA timezone name used by the timezone package.
  /// `null` means that the IANA zone reported by the device is used.
  final String? locationName;

  static AppTimeZone fromId(String? id) {
    return AppTimeZone.values.firstWhere(
      (timeZone) => timeZone.id == id,
      orElse: () => AppTimeZone.device,
    );
  }
}
