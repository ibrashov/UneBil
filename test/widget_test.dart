import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unebil/main.dart';
import 'package:unebil/models/notification_interval.dart';

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
