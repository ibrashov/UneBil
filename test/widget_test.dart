import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unebil/main.dart';
import 'package:unebil/models/notification_interval.dart';
import 'package:unebil/screens/settings_screen.dart';

import 'app_controller_test.dart';

void main() {
  testWidgets('home screen shows empty state', (tester) async {
    final controller = await createController();

    await tester.pumpWidget(UneBilApp(controller: controller));

    expect(find.text('Добавь первую тему'), findsOneWidget);
    expect(find.text('Добавить тему'), findsOneWidget);
  });

  testWidgets('adds a topic from the home screen', (tester) async {
    final controller = await createController();

    await tester.pumpWidget(UneBilApp(controller: controller));
    await tester.tap(find.text('Добавить тему'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Космос');
    await tester.tap(find.text('Добавить').last);
    await tester.pumpAndSettle();

    expect(find.text('Космос'), findsOneWidget);
    expect(controller.topics.single.title, 'Космос');
  });

  testWidgets('changes language and length settings', (tester) async {
    final controller = await createController();

    await tester.pumpWidget(UneBilApp(controller: controller));
    await tester.tap(find.byIcon(Icons.tune));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Қазақша'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Подробно'));
    await tester.pumpAndSettle();

    expect(controller.settings.language.label, 'Қазақша');
    expect(controller.settings.length.targetWords, 70);
  });

  test('adds hours to a time and wraps after midnight', () {
    expect(
      addHoursToTimeOfDay(const TimeOfDay(hour: 22, minute: 45), 3),
      const TimeOfDay(hour: 1, minute: 45),
    );
  });

  testWidgets('chooses an interval before opening the time picker', (
    tester,
  ) async {
    final controller = await createController();

    await tester.pumpWidget(UneBilApp(controller: controller));
    await tester.tap(find.byIcon(Icons.tune));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Добавить время'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Добавить время'));
    await tester.pumpAndSettle();

    expect(find.text('Через сколько часов?'), findsOneWidget);
    expect(find.text('+1 ч'), findsOneWidget);
    expect(find.text('+2 ч'), findsOneWidget);
    expect(find.text('+3 ч'), findsOneWidget);

    await tester.tap(find.text('+2 ч'));
    await tester.pumpAndSettle();

    expect(find.text('Выбери время'), findsOneWidget);
    expect(find.text('Отмена'), findsOneWidget);
    expect(find.text('Готово'), findsOneWidget);
  });

  testWidgets('changes interval on topic screen and shows fact schedule', (
    tester,
  ) async {
    final controller = await createController();
    await controller.addTopic('Космос');

    await tester.pumpWidget(UneBilApp(controller: controller));
    await tester.tap(find.text('Космос'));
    await tester.pumpAndSettle();

    expect(find.text('Как часто показывать уведомления'), findsOneWidget);
    expect(find.textContaining('Следующее уведомление:'), findsOneWidget);

    await tester.tap(find.text('Каждые 2 часа').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Каждый час').last);
    await tester.pumpAndSettle();

    expect(
      controller.topics.single.notificationInterval,
      NotificationInterval.hourly,
    );
  });
}
