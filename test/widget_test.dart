import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unebil/main.dart';
import 'package:unebil/models/app_language.dart';
import 'package:unebil/models/app_theme_mode.dart';
import 'package:unebil/models/interface_language.dart';
import 'package:unebil/models/notification_interval.dart';
import 'package:unebil/models/notification_length.dart';
import 'package:unebil/screens/settings_screen.dart';
import 'package:unebil/widgets/facts_check_segmented_control.dart';
import 'package:unebil/widgets/responsive_segmented_control.dart';

import 'app_controller_test.dart';

void main() {
  testWidgets('asks for the interface language on first launch', (
    tester,
  ) async {
    final controller = await createController(selectInterfaceLanguage: false);

    await tester.pumpWidget(UneBilApp(controller: controller));

    expect(find.text('Қазақша'), findsOneWidget);
    expect(find.text('English'), findsOneWidget);
    expect(find.text('Русский'), findsOneWidget);

    await tester.tap(find.text('Русский'));
    await tester.pumpAndSettle();

    expect(controller.settings.interfaceLanguage, InterfaceLanguage.ru);
    expect(controller.settings.language, AppLanguage.ru);
    expect(find.text('Добавь первую тему'), findsOneWidget);
  });

  testWidgets('home screen shows empty state', (tester) async {
    final controller = await createController();

    await tester.pumpWidget(UneBilApp(controller: controller));

    expect(find.text('Добавь первую тему'), findsOneWidget);
    expect(find.text('Добавить тему'), findsOneWidget);
    final control = tester.widget<FactsCheckSegmentedControl>(
      find.byType(FactsCheckSegmentedControl),
    );
    expect(control.selected, HomeLearningMode.facts);
  });

  testWidgets('switches from Facts to the localized empty Check state', (
    tester,
  ) async {
    final controller = await createController();
    await tester.pumpWidget(UneBilApp(controller: controller));

    await tester.tap(find.text('Проверка'));
    await tester.pumpAndSettle();

    expect(find.text('Нет фактов для проверки'), findsOneWidget);
    expect(find.text('Перейти к фактам'), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsNothing);
  });

  testWidgets('completes recall, reveal, and self-assessment flow', (
    tester,
  ) async {
    final controller = await createController();
    await controller.addTopic('Космос');
    final fact = controller.facts.single;
    await tester.pumpWidget(UneBilApp(controller: controller));

    await tester.tap(find.text('Проверка'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Космос'));
    await tester.pumpAndSettle();

    expect(find.text('Напиши всё, что помнишь об этом факте.'), findsOneWidget);
    expect(find.text(fact.body), findsNothing);
    await tester.enterText(
      find.byKey(const ValueKey('recallTextField')),
      'Мой ответ',
    );
    await tester.tap(find.byKey(const ValueKey('showFactButton')));
    await tester.pumpAndSettle();

    expect(find.text(fact.body), findsOneWidget);
    expect(find.text('Мой ответ'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('rememberedButton')));
    await tester.pumpAndSettle();

    expect(find.text('Проверка завершена'), findsOneWidget);
    expect(controller.facts.single.timesChecked, 1);
    expect(controller.facts.single.lastRecallText, 'Мой ответ');
    expect(controller.facts.single.isRead, isTrue);
  });

  testWidgets('fact menu toggles read state and mark all clears unread', (
    tester,
  ) async {
    final controller = await createController();
    await controller.addTopic('Космос');
    await tester.pumpWidget(UneBilApp(controller: controller));
    await tester.tap(find.text('Космос'));
    await tester.pumpAndSettle();

    expect(find.text('Отметить всё прочитанным'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Отметить прочитанным'));
    await tester.pumpAndSettle();
    expect(controller.facts.single.isRead, isTrue);

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Отметить непрочитанным'));
    await tester.pumpAndSettle();
    expect(controller.facts.single.isRead, isFalse);

    await tester.tap(find.text('Отметить всё прочитанным'));
    await tester.pumpAndSettle();
    expect(controller.unreadCountForTopic(controller.topics.single.id), 0);
  });

  testWidgets('Facts and Check render in light and dark themes', (
    tester,
  ) async {
    final controller = await createController();
    await controller.addTopic('Космос');
    await controller.updateThemeMode(AppThemeMode.light);
    await tester.pumpWidget(UneBilApp(controller: controller));
    expect(
      Theme.of(
        tester.element(find.byType(FactsCheckSegmentedControl)),
      ).brightness,
      Brightness.light,
    );

    await controller.updateThemeMode(AppThemeMode.dark);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Проверка'));
    await tester.pumpAndSettle();
    expect(
      Theme.of(tester.element(find.text('Готово к проверке'))).brightness,
      Brightness.dark,
    );
    expect(tester.takeException(), isNull);
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

  testWidgets('turns a topic off without deleting its facts', (tester) async {
    final controller = await createController();
    await controller.addTopic('История');
    final factCount = controller.facts.length;

    await tester.pumpWidget(UneBilApp(controller: controller));
    await tester.tap(find.byType(Switch).first);
    await tester.pumpAndSettle();

    expect(controller.topics.single.enabled, isFalse);
    expect(controller.facts, hasLength(factCount));
    expect(find.textContaining('уведомления выключены'), findsOneWidget);

    await tester.tap(find.byType(Switch).first);
    await tester.pumpAndSettle();
    expect(controller.topics.single.enabled, isTrue);
  });

  testWidgets('keeps interface and fact languages independent', (tester) async {
    final controller = await createController();

    await tester.pumpWidget(UneBilApp(controller: controller));
    await tester.tap(find.byIcon(Icons.tune));
    await tester.pumpAndSettle();

    await tester.tap(
      find.descendant(
        of: find.byType(ResponsiveSegmentedControl<InterfaceLanguage>),
        matching: find.text('Қазақша'),
      ),
    );
    await tester.pumpAndSettle();

    expect(controller.settings.interfaceLanguage, InterfaceLanguage.kk);
    expect(controller.settings.language, AppLanguage.ru);
    expect(find.text('Баптаулар'), findsOneWidget);

    await tester.tap(
      find.descendant(
        of: find.byType(ResponsiveSegmentedControl<AppLanguage>),
        matching: find.text('Қазақша'),
      ),
    );
    await tester.scrollUntilVisible(
      find.text('Толық'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Толық'));
    await tester.pumpAndSettle();

    expect(controller.settings.language, AppLanguage.kk);
    expect(controller.settings.length, NotificationLength.detailed);
  });

  testWidgets('segments stay equal and single-line on a 320dp screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = await createController();

    await tester.pumpWidget(UneBilApp(controller: controller));
    await tester.tap(find.byIcon(Icons.tune));
    await tester.pumpAndSettle();

    final control = find.byType(ResponsiveSegmentedControl<InterfaceLanguage>);
    final items = find.descendant(of: control, matching: find.byType(InkWell));
    expect(items, findsNWidgets(3));
    final widths = items.evaluate().map(
      (element) => tester
          .getSize(
            find.byElementPredicate(
              (candidate) => identical(candidate, element),
            ),
          )
          .width,
    );
    expect(widths.toSet(), hasLength(1));

    _expectLabelsStayOnOneLine(tester, control, const <String>[
      'Қазақша',
      'English',
      'Русский',
    ]);
    _expectLabelsStayOnOneLine(
      tester,
      find.byType(ResponsiveSegmentedControl<NotificationLength>),
      const <String>['Коротко', 'Средне', 'Подробно'],
    );
    _expectLabelsStayOnOneLine(
      tester,
      find.byType(ResponsiveSegmentedControl<AppThemeMode>),
      const <String>['Системная', 'Светлая', 'Тёмная'],
    );

    await controller.updateInterfaceLanguage(InterfaceLanguage.en);
    await tester.pumpAndSettle();
    _expectLabelsStayOnOneLine(
      tester,
      find.byType(ResponsiveSegmentedControl<NotificationLength>),
      const <String>['Short', 'Medium', 'Detailed'],
    );

    await controller.updateInterfaceLanguage(InterfaceLanguage.kk);
    await tester.pumpAndSettle();
    _expectLabelsStayOnOneLine(
      tester,
      find.byType(ResponsiveSegmentedControl<NotificationLength>),
      const <String>['Қысқа', 'Орташа', 'Толық'],
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('changes the theme immediately from localized settings', (
    tester,
  ) async {
    final controller = await createController();

    await tester.pumpWidget(UneBilApp(controller: controller));
    await tester.tap(find.byIcon(Icons.tune));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Тёмная'));
    await tester.pumpAndSettle();

    expect(controller.settings.themeMode, AppThemeMode.dark);
    expect(
      Theme.of(tester.element(find.text('Настройки'))).brightness,
      Brightness.dark,
    );
  });

  test('adds hours to a time and wraps after midnight', () {
    expect(
      addHoursToTimeOfDay(const TimeOfDay(hour: 22, minute: 45), 3),
      const TimeOfDay(hour: 1, minute: 45),
    );
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

void _expectLabelsStayOnOneLine(
  WidgetTester tester,
  Finder control,
  List<String> labels,
) {
  for (final label in labels) {
    final finder = find.descendant(of: control, matching: find.text(label));
    final text = tester.widget<Text>(finder);
    expect(text.maxLines, 1, reason: label);
    expect(text.softWrap, isFalse, reason: label);
    expect(text.overflow, TextOverflow.ellipsis, reason: label);
  }
}
