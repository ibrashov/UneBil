import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unebil/main.dart';
import 'package:unebil/models/app_language.dart';
import 'package:unebil/models/app_theme_mode.dart';
import 'package:unebil/models/interface_language.dart';
import 'package:unebil/models/notification_interval.dart';
import 'package:unebil/models/notification_length.dart';
import 'package:unebil/screens/settings_screen.dart';
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
