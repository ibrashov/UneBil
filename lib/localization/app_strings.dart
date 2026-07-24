import '../models/app_time_zone.dart';
import '../models/interface_language.dart';
import '../models/notification_interval.dart';
import '../models/notification_length.dart';

class AppStrings {
  const AppStrings(this.language);

  final InterfaceLanguage language;

  String get settings => _pick('Баптаулар', 'Settings', 'Настройки');
  String get interfaceLanguage =>
      _pick('Қолданба тілі', 'App language', 'Язык приложения');
  String get factLanguage =>
      _pick('Фактілер тілі', 'Fact language', 'Язык фактов');
  String get factLanguageHint => _pick(
    'Бұл тіл тек жаңа фактілерді жасауға қолданылады.',
    'This language is used only to generate new facts.',
    'Этот язык используется только для генерации новых фактов.',
  );
  String get timeZone => _pick('Уақыт белдеуі', 'Time zone', 'Часовой пояс');
  String get country => _pick('Ел', 'Country', 'Страна');
  String get notificationLength =>
      _pick('Факт ұзындығы', 'Fact length', 'Длина факта');
  String aboutWords(int count) =>
      _pick('Шамамен $count сөз', 'About $count words', 'Около $count слов');
  String get notificationTimes =>
      _pick('Хабарландыру уақыты', 'Notification times', 'Время уведомлений');
  String get noNotificationTimes => _pick(
    'Хабарландырулар жоспарланбаған',
    'No notifications scheduled',
    'Уведомления не запланированы',
  );
  String get deleteTime => _pick('Уақытты жою', 'Delete time', 'Удалить время');
  String get customTimesHint => _pick(
    'Бұл уақыттар тақырып аралығының орнына қолданылады.',
    'These times are used instead of each topic interval.',
    'Эти часы используются вместо интервала темы.',
  );
  String get addTime => _pick('Уақыт қосу', 'Add time', 'Добавить время');
  String get scheduleTest =>
      _pick('Кестені тексеру', 'Schedule test', 'Проверка расписания');
  String get scheduleFactIn15Seconds => _pick(
    'Фактіні 15 секундтан кейін жоспарлау',
    'Schedule a fact in 15 seconds',
    'Запланировать факт через 15 секунд',
  );
  String get afterHowManyHours => _pick(
    'Неше сағаттан кейін?',
    'After how many hours?',
    'Через сколько часов?',
  );
  String get chooseNotificationDelay => _pick(
    'Хабарландыруға дейінгі аралықты таңдаңыз',
    'Choose the delay before the notification',
    'Выбери интервал до уведомления',
  );
  String hoursShort(int hours) =>
      _pick('+$hours сағ', '+$hours h', '+$hours ч');
  String get chooseTime =>
      _pick('Уақытты таңдаңыз', 'Choose time', 'Выбери время');
  String get cancel => _pick('Бас тарту', 'Cancel', 'Отмена');
  String get done => _pick('Дайын', 'Done', 'Готово');
  String get testScheduled => _pick(
    'Факт 15 секундтан кейін жоспарланды. Қолданбаны жауып, күтіңіз.',
    'A fact was scheduled in 15 seconds. Close the app and wait.',
    'Факт запланирован через 15 секунд. Закрой приложение и подожди.',
  );
  String get testFailed => _pick(
    'Сынақ хабарландыруын көрсету мүмкін болмады.',
    'Could not show the test notification.',
    'Не удалось показать тестовое уведомление.',
  );

  String get topic => _pick('Тақырып', 'Topic', 'Тема');
  String get homeSlogan => _pick(
    'Бүгін шағын қадамдармен үйренеміз',
    'Learning in small steps today',
    'Сегодня учим маленькими шагами',
  );
  String get addFirstTopic => _pick(
    'Алғашқы тақырыпты қосыңыз',
    'Add your first topic',
    'Добавь первую тему',
  );
  String get emptyTopicsBody => _pick(
    'Көптен бері түсінгіңіз келген нәрсені жазыңыз: ғарыш, бизнес, тарих, ағылшын тілі немесе кез келген басқа идея.',
    'Enter something you have always wanted to understand: space, business, history, English, or any other idea.',
    'Напиши то, что давно хотел понять: космос, бизнес, история, английский или любую другую идею.',
  );
  String get addTopic => _pick('Тақырып қосу', 'Add topic', 'Добавить тему');
  String factsCount(int count) =>
      _pick('$count факт', '$count facts', '$count фактов');
  String get notificationsOff => _pick(
    'хабарландырулар өшірулі',
    'notifications are off',
    'уведомления выключены',
  );
  String get editTopicAndInterval => _pick(
    'Тақырып пен аралықты өзгерту',
    'Edit topic and interval',
    'Изменить тему и интервал',
  );
  String get delete => _pick('Жою', 'Delete', 'Удалить');
  String get newTopic => _pick('Жаңа тақырып', 'New topic', 'Новая тема');
  String get save => _pick('Сақтау', 'Save', 'Сохранить');
  String get add => _pick('Қосу', 'Add', 'Добавить');
  String get topicExample =>
      _pick('Мысалы: ғарыш', 'For example: space', 'Например: космос');

  String get topicDeleted =>
      _pick('Тақырып жойылды', 'Topic was deleted', 'Тема удалена');
  String get notificationFrequency => _pick(
    'Хабарландыруларды қаншалықты жиі көрсету керек',
    'How often to show notifications',
    'Как часто показывать уведомления',
  );
  String get generating =>
      _pick('Жасалуда...', 'Generating...', 'Генерируем...');
  String get generateFact =>
      _pick('Факт жасау', 'Generate fact', 'Сгенерировать факт');
  String get factAdded => _pick(
    'Дайын: факт қосылды.',
    'Done: fact added.',
    'Готово: факт добавлен.',
  );
  String get emptyBackendResponse => _pick(
    'Backend бос жауап қайтарды.',
    'The backend returned an empty response.',
    'Backend вернул пустой ответ.',
  );
  String get topicNotificationsOff => _pick(
    'Тақырып хабарландырулары өшірулі',
    'Notifications for this topic are off',
    'Уведомления для темы выключены',
  );
  String get notInUpcomingSchedule => _pick(
    'Әзірге жақын кестеге кірмейді',
    'Not in the upcoming schedule yet',
    'Пока не входит в ближайшее расписание',
  );
  String nextNotification(String value, String zone) => _pick(
    'Келесі хабарландыру: $value ($zone)',
    'Next notification: $value ($zone)',
    'Следующее уведомление: $value ($zone)',
  );
  String get noFactsYet =>
      _pick('Әзірге фактілер жоқ', 'No facts yet', 'Пока нет фактов');
  String get noFactsBody => _pick(
    'Хабарландыруларға фактілер дайындау үшін жасау түймесін басыңыз.',
    'Tap the generate button to prepare facts for notifications.',
    'Нажми кнопку генерации, чтобы подготовить факты для уведомлений.',
  );

  String get intervalSelector => _pick(
    'Хабарландыру аралығы',
    'Notification interval',
    'Интервал уведомлений',
  );

  String intervalLabel(NotificationInterval interval) {
    return switch (interval) {
      NotificationInterval.hourly => _pick(
        'Әр сағат сайын',
        'Every hour',
        'Каждый час',
      ),
      NotificationInterval.everyTwoHours => _pick(
        'Әр 2 сағат сайын',
        'Every 2 hours',
        'Каждые 2 часа',
      ),
      NotificationInterval.everyThreeHours => _pick(
        'Әр 3 сағат сайын',
        'Every 3 hours',
        'Каждые 3 часа',
      ),
    };
  }

  String lengthLabel(NotificationLength length) {
    return switch (length) {
      NotificationLength.short => _pick('Қысқа', 'Short', 'Коротко'),
      NotificationLength.medium => _pick('Орташа', 'Medium', 'Средне'),
      NotificationLength.detailed => _pick('Толық', 'Detailed', 'Подробно'),
    };
  }

  String timeZoneLabel(AppTimeZone timeZone) {
    return switch (timeZone) {
      AppTimeZone.kazakhstan => _pick('Қазақстан', 'Kazakhstan', 'Казахстан'),
      AppTimeZone.china => _pick('Қытай', 'China', 'Китай'),
      AppTimeZone.spain => _pick('Испания', 'Spain', 'Испания'),
    };
  }

  String get notificationsPermissionDenied => _pick(
    'UneBil хабарландыруларына тыйым салынған. Оларды Android баптауларында рұқсат етіңіз.',
    'Notifications are disabled for UneBil. Enable them in Android settings.',
    'Уведомления запрещены для UneBil. Разреши их в настройках Android.',
  );
  String get testScheduleError => _pick(
    'Сынақ фактісін жоспарлау мүмкін болмады. Android хабарландырулары мен дәл оятқыштарға рұқсатты тексеріңіз.',
    'Could not schedule the test fact. Check Android notifications and exact alarm permission.',
    'Не удалось запланировать тестовый факт. Проверь уведомления и разрешение точных будильников Android.',
  );
  String get duplicateFactsError => _pick(
    'AI жаңа факт жасай алмады: барлық нұсқа тарихта бар.',
    'AI could not create a new fact: every result is already in the history.',
    'AI не смог создать новый факт: все варианты уже есть в истории.',
  );
  String get genericGenerationError => _pick(
    'Фактіні алу мүмкін болмады. Backend-ті іске қосыңыз немесе AI кілтін тексеріңіз.',
    'Could not get a fact. Start the backend or check the AI key.',
    'Не удалось получить факт. Запусти backend или проверь AI-ключ.',
  );

  String localizeGenerationError(String message) {
    if (language == InterfaceLanguage.ru) {
      return message;
    }
    if (message.contains('API_BASE_URL')) {
      return _pick(
        'API_BASE_URL орнатылмаған. Қолданбаны backend мекенжайымен іске қосыңыз.',
        'API_BASE_URL is not set. Start the app with the backend address.',
        message,
      );
    }
    if (message.contains('минутный лимит')) {
      return _pick(
        'AI минуттық шегіне жетті. Бір минуттай күтіп, қайта көріңіз.',
        'The AI minute limit was reached. Wait about a minute and try again.',
        message,
      );
    }
    if (message.contains('mock-режиме')) {
      return _pick(
        'Backend mock режимінде жұмыс істеп тұр: AI кілті жүктелмеген. Backend-ті қайта іске қосып, .env файлын тексеріңіз.',
        'The backend is running in mock mode: the AI key is not loaded. Restart the backend and check .env.',
        message,
      );
    }
    if (message.contains('недоступен')) {
      return _pick(
        'Backend қолжетімсіз. Backend-ті іске қосыңыз немесе API мекенжайын тексеріңіз.',
        'The backend is unavailable. Start it or check the API address.',
        message,
      );
    }
    if (message.contains('только уже известные')) {
      return _pick(
        'Backend тек бұрыннан белгілі фактілерді қайтарды.',
        'The backend returned only facts that are already known.',
        message,
      );
    }
    if (message.contains('пустой список') ||
        message.contains('без списка фактов') ||
        message.contains('не в формате JSON')) {
      return emptyBackendResponse;
    }
    if (message.startsWith('Backend вернул ошибку')) {
      return _pick(
        message.replaceFirst(
          'Backend вернул ошибку',
          'Backend қатені қайтарды',
        ),
        message.replaceFirst(
          'Backend вернул ошибку',
          'The backend returned error',
        ),
        message,
      );
    }
    if (message.contains('AI не смог создать новый факт')) {
      return duplicateFactsError;
    }
    return genericGenerationError;
  }

  String _pick(String kk, String en, String ru) {
    return switch (language) {
      InterfaceLanguage.kk => kk,
      InterfaceLanguage.en => en,
      InterfaceLanguage.ru => ru,
    };
  }
}
