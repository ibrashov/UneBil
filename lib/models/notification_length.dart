enum NotificationLength {
  short('short', 'Коротко', 20),
  medium('medium', 'Средне', 40),
  detailed('detailed', 'Подробно', 70);

  const NotificationLength(this.id, this.label, this.targetWords);

  final String id;
  final String label;
  final int targetWords;

  static NotificationLength fromId(String? id) {
    return NotificationLength.values.firstWhere(
      (length) => length.id == id,
      orElse: () => NotificationLength.medium,
    );
  }
}
