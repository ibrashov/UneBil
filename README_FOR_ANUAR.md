# UneBil: подробное объяснение проекта для Ануара

Этот файл написан как карта проекта. Его цель: чтобы ты открыл код, понимал, что где находится, и мог спокойно менять приложение без страха сломать все сразу.

## 1. Что делает приложение

UneBil - это Flutter-приложение для Android. Идея такая:

1. Пользователь добавляет темы, которые ему интересны.
2. Пользователь выбирает язык фактов: русский, казахский или английский.
3. Пользователь выбирает длину уведомления: коротко, средне или подробно.
4. Пользователь выбирает точное время уведомлений.
5. Приложение получает обучающие факты через backend.
6. Факты сохраняются на телефоне.
7. Android показывает локальные уведомления в выбранное время.

Главная фишка: телефон не просто забирает внимание, а каждый день дает маленький полезный факт по теме, которую человек сам выбрал.

## 2. Как проект работает внутри

Главный поток данных:

```txt
main.dart
  -> создает AppController
  -> AppController загружает темы/настройки/факты из StorageService
  -> HomeScreen показывает список тем
  -> пользователь добавляет тему
  -> AppController.addTopic()
  -> AiClient просит backend создать факт
  -> backend /api/generate-facts возвращает facts
  -> AppController сохраняет LearningFact
  -> NotificationScheduler пересоздает уведомления
```

Самое важное:

- `AppController` - мозг Flutter-приложения.
- `StorageService` - хранит данные на телефоне.
- `AiClient` - ходит в backend за фактами.
- `NotificationScheduler` - планирует Android-уведомления.
- `backend/src/app.js` - принимает запросы от приложения и генерирует факты.

## 3. Команды, которые тебе нужны чаще всего

Запустить backend:

```sh
cd backend
npm start
```

Запустить приложение на Android emulator:

```sh
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:3000
```

Проверить Flutter-код:

```sh
dart analyze
flutter test
```

Собрать debug APK:

```sh
flutter build apk --debug
```

APK появится здесь:

```txt
build/app/outputs/flutter-apk/app-debug.apk
```

Проверить backend:

```sh
cd backend
npm test
```

Важно: если `flutter analyze` падает из-за пути с кириллицей или пробелом, используй:

```sh
dart analyze
```

В этом проекте `dart analyze` уже работает нормально.

## 4. Что можно менять, если хочешь новую фичу

### Изменить цвета приложения

Файл:

```txt
lib/main.dart
```

Ищи:

```dart
colorScheme: ColorScheme.fromSeed(
  seedColor: const Color(0xFF2563EB),
)
```

Меняешь `0xFF2563EB` на другой цвет.

### Изменить языки

Flutter:

```txt
lib/models/app_language.dart
```

Backend:

```txt
backend/src/app.js
```

Во Flutter добавляешь новое значение в `enum AppLanguage`. В backend добавляешь код языка в `languages`.

### Изменить длину уведомлений

Flutter:

```txt
lib/models/notification_length.dart
```

Backend:

```txt
backend/src/app.js
```

Во Flutter меняешь `targetWords`. В backend меняешь `lengthModes`.

### Изменить время уведомления по умолчанию

Файл:

```txt
lib/models/app_settings.dart
```

Ищи:

```dart
NotificationTime(hour: 9, minute: 0)
```

Например, чтобы по умолчанию было 18:30:

```dart
NotificationTime(hour: 18, minute: 30)
```

### Изменить backend URL по умолчанию

Файл:

```txt
lib/services/ai_client.dart
```

Ищи:

```dart
defaultValue: 'http://10.0.2.2:3000'
```

Но лучше не менять код, а запускать так:

```sh
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:3000
```

Для физического телефона вместо `10.0.2.2` нужно поставить IP твоего компьютера в Wi-Fi сети.

### Изменить текст mock-фактов

Flutter fallback:

```txt
lib/services/ai_client.dart
```

Backend mock:

```txt
backend/src/app.js
```

Ищи функции:

```txt
_mockFacts
makeMockFacts
```

### Изменить prompt для настоящего ИИ

Файл:

```txt
backend/src/app.js
```

Ищи функцию:

```txt
generateFactsWithOpenAI
```

Там есть `system` и `user` messages. Это инструкция для ИИ.

### Добавить новый экран

1. Создай файл в `lib/screens/`, например `profile_screen.dart`.
2. Сделай там `StatelessWidget` или `StatefulWidget`.
3. Открой экран через `Navigator.of(context).push(...)`.
4. Пример навигации уже есть в:

```txt
lib/screens/home_screen.dart
```

Ищи переход в `SettingsScreen` или `TopicDetailScreen`.

## 5. Главные Flutter-файлы

### `lib/main.dart`

Это вход в приложение.

Что делает:

- вызывает `WidgetsFlutterBinding.ensureInitialized()`;
- открывает `SharedPreferences`;
- создает `StorageService`;
- создает `AiClient`;
- создает `NotificationScheduler`;
- создает `AppController`;
- загружает данные через `controller.load()`;
- запускает `UneBilApp`.

Самый важный кусок:

```dart
final controller = AppController(
  StorageService(prefs),
  AiClient(),
  NotificationScheduler(),
);
await controller.load();
runApp(UneBilApp(controller: controller));
```

Простыми словами: приложение сначала подготавливает все сервисы, потом показывает UI.

Еще тут находится тема приложения:

```dart
ThemeData(
  useMaterial3: true,
  colorScheme: ColorScheme.fromSeed(...),
)
```

Если хочешь поменять внешний стиль, чаще всего начинай отсюда.

## 6. Модели данных `lib/models/`

Модели - это простые классы, которые описывают данные приложения.

### `lib/models/app_language.dart`

Описывает языки приложения:

```dart
enum AppLanguage {
  ru('ru', 'Русский'),
  kk('kk', 'Қазақша'),
  en('en', 'English');
}
```

У каждого языка есть:

- `code` - короткий код для backend: `ru`, `kk`, `en`;
- `label` - текст, который видит пользователь.

Функция `fromCode` нужна, чтобы восстановить язык из сохраненных настроек.

Если добавляешь новый язык, меняешь этот файл и backend.

### `lib/models/notification_length.dart`

Описывает длину уведомления:

```dart
short('short', 'Коротко', 20)
medium('medium', 'Средне', 40)
detailed('detailed', 'Подробно', 70)
```

У каждого режима есть:

- `id` - код для backend;
- `label` - текст в UI;
- `targetWords` - примерное количество слов.

Если хочешь сделать уведомления длиннее или короче, меняй числа здесь.

### `lib/models/notification_time.dart`

Описывает одно время уведомления.

Например:

```dart
NotificationTime(hour: 9, minute: 0)
```

Это значит 09:00.

Важные части:

- `toJson()` - превращает время в формат для сохранения;
- `fromJson()` - читает время из сохраненных данных;
- `label` - делает красивый текст `09:00`;
- `compareTo()` - помогает сортировать время.

### `lib/models/app_settings.dart`

Описывает все настройки приложения:

- выбранный язык;
- выбранная длина уведомлений;
- список времен уведомлений.

Настройки по умолчанию:

```dart
static const defaultSettings = AppSettings(
  language: AppLanguage.ru,
  length: NotificationLength.medium,
  notificationTimes: [
    NotificationTime(hour: 9, minute: 0),
  ],
);
```

Если пользователь запускает приложение первый раз, используются эти настройки.

### `lib/models/topic.dart`

Описывает тему пользователя.

Поля:

- `id` - уникальный идентификатор темы;
- `title` - название темы, например `Космос`;
- `enabled` - включены ли уведомления для этой темы;
- `createdAt` - дата создания.

Методы:

- `toJson()` - сохранить тему;
- `fromJson()` - загрузить тему;
- `copyWith()` - создать измененную копию темы.

Почему используется `copyWith`: так удобнее менять только одно поле, например `enabled`, не переписывая весь объект.

### `lib/models/learning_fact.dart`

Тут два класса.

`GeneratedFact` - это факт, который пришел от backend:

- `title`;
- `body`.

`LearningFact` - это факт, который приложение уже сохранило на телефоне:

- `id`;
- `topicId`;
- `topicTitle`;
- `title`;
- `body`;
- `language`;
- `length`;
- `createdAt`.

Разница важна: backend не знает внутренний `id` темы в приложении. Поэтому сначала приходит простой `GeneratedFact`, а потом Flutter превращает его в полноценный `LearningFact`.

## 7. Сервисы `lib/services/`

Сервисы - это код, который выполняет работу: сохранить данные, сходить в backend, запланировать уведомления.

### `lib/services/app_controller.dart`

Это самый важный файл Flutter-части.

`AppController` - центр управления приложением.

Он хранит:

- `_topics` - список тем;
- `_facts` - список сохраненных фактов;
- `_settings` - настройки;
- `_loading` - идет ли загрузка;
- `_generatingTopicId` - для какой темы сейчас генерируется факт;
- `_lastError` - последняя ошибка.

Главные методы:

```dart
load()
```

Загружает темы, факты, настройки и запускает уведомления.

```dart
addTopic(String title)
```

Добавляет новую тему, сохраняет ее и сразу пытается сгенерировать факт.

```dart
renameTopic(String topicId, String title)
```

Переименовывает тему и обновляет сохраненные факты этой темы.

```dart
toggleTopic(String topicId, bool enabled)
```

Включает или выключает уведомления для темы.

```dart
deleteTopic(String topicId)
```

Удаляет тему и все факты этой темы.

```dart
updateLanguage(...)
updateLength(...)
addNotificationTime(...)
removeNotificationTime(...)
```

Меняют настройки.

```dart
generateFactsForTopic(...)
```

Просит `FactGenerator` создать факты, сохраняет их и обновляет уведомления.

Очень важная идея: после почти каждого изменения вызывается `_rescheduleNotifications()`. Это значит, что уведомления всегда соответствуют текущим темам и настройкам.

### `lib/services/storage_service.dart`

Отвечает за локальное хранение данных на телефоне.

Используется пакет:

```txt
shared_preferences
```

Что хранит:

- темы под ключом `unebil.topics`;
- факты под ключом `unebil.facts`;
- настройки под ключом `unebil.settings`.

Главные методы:

```dart
loadTopics()
saveTopics(...)
loadFacts()
saveFacts(...)
loadSettings()
saveSettings(...)
```

Если данные повреждены или пустые, сервис не падает, а возвращает пустой список или настройки по умолчанию.

Если добавишь новое поле в модель, нужно обновить `toJson()` и `fromJson()` в модели.

### `lib/services/fact_generator.dart`

Это интерфейс.

```dart
abstract class FactGenerator {
  Future<List<GeneratedFact>> generateFacts(...)
}
```

Зачем он нужен:

- приложение не зависит напрямую от `AiClient`;
- в тестах можно поставить fake-генератор;
- потом можно заменить backend, не переписывая `AppController`.

### `lib/services/ai_client.dart`

Это клиент, который отправляет запрос в backend.

Backend URL берется отсюда:

```dart
const String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://10.0.2.2:3000',
)
```

Что значит `10.0.2.2`: это специальный адрес Android emulator, который ведет на `localhost` твоего компьютера.

Главный метод:

```dart
generateFacts(...)
```

Он отправляет:

```json
{
  "topic": "space",
  "language": "ru",
  "lengthMode": "short",
  "count": 5
}
```

Если backend не отвечает, приложение не ломается. Оно возвращает fallback mock-факты из `_mockFacts`.

Это сделано, чтобы приложение можно было тестировать даже без интернета или backend.

### `lib/services/notification_scheduler.dart`

Отвечает за уведомления.

Используются пакеты:

- `flutter_local_notifications`;
- `timezone`;
- `flutter_timezone`.

Главные вещи:

```dart
initialize()
```

Запрашивает разрешения на уведомления и exact alarm.

```dart
scheduleDailyFacts(...)
```

Удаляет старые запланированные уведомления и создает новые по текущим настройкам.

```dart
_nextInstanceOf(...)
```

Считает ближайшее будущее время. Например, если сейчас 10:00, а уведомление стоит на 09:00, то оно запланирует 09:00 завтра.

```dart
_notificationDetails
```

Настройки Android-канала уведомлений.

`NoopNotificationScheduler` нужен для тестов. Он ничего не планирует, чтобы тесты работали без Android.

## 8. Экраны `lib/screens/`

Экраны - это UI приложения.

### `lib/screens/home_screen.dart`

Главный экран.

Показывает:

- верхнюю панель `UneBil`;
- кнопку настроек;
- краткую карточку настроек;
- пустое состояние, если тем нет;
- список тем, если они есть;
- кнопку добавления темы.

Важные виджеты внутри файла:

```dart
HomeScreen
```

Главный экран, слушает `AppController` через `AnimatedBuilder`.

```dart
_HomeContent
```

Решает, показывать пустое состояние или список тем.

```dart
_SettingsSummary
```

Показывает язык, длину и времена уведомлений.

```dart
_EmptyTopics
```

Красивое состояние, когда еще нет тем.

```dart
_TopicTile
```

Одна карточка темы со switch, меню редактирования и удаления.

```dart
_showTopicDialog
_TopicDialog
```

Dialog для добавления или переименования темы.

Если хочешь изменить главный экран, чаще всего работаешь именно здесь.

### `lib/screens/topic_detail_screen.dart`

Экран одной темы.

Показывает:

- название темы;
- текущий язык и длину факта;
- кнопку `Сгенерировать факт`;
- список сохраненных фактов по этой теме;
- ошибку, если генерация не удалась.

Важные части:

```dart
TopicDetailScreen
```

Находит тему по `topicId`, берет факты через `controller.factsForTopic(topic.id)`.

```dart
_TopicHeader
```

Верхняя карточка темы и кнопка генерации.

```dart
_ErrorBanner
```

Показывает ошибку.

```dart
_NoFactsYet
```

Показывает состояние, когда фактов пока нет.

Если хочешь изменить страницу генерации фактов, работай здесь.

### `lib/screens/settings_screen.dart`

Экран настроек.

Показывает:

- выбор языка;
- выбор длины уведомлений;
- список времен уведомлений;
- кнопку добавления времени.

Важные части:

```dart
SegmentedButton<AppLanguage>
```

Переключатель языка.

```dart
SegmentedButton<NotificationLength>
```

Переключатель длины.

```dart
showTimePicker(...)
```

Стандартный Flutter picker времени.

Если хочешь добавить новые настройки, добавляй карточку в этот экран и метод в `AppController`.

## 9. Backend-файлы

Backend нужен, чтобы API-ключ ИИ не лежал внутри мобильного приложения.

Если положить API-ключ прямо во Flutter, любой человек сможет достать его из APK. Поэтому приложение отправляет запрос на backend, а backend уже обращается к ИИ.

### `backend/package.json`

Описание Node-проекта.

Важные части:

```json
"scripts": {
  "start": "node src/server.js",
  "dev": "node --watch src/server.js",
  "test": "node --test"
}
```

Команды:

- `npm start` - запустить backend;
- `npm run dev` - запустить backend с авто-перезапуском;
- `npm test` - запустить тесты.

Зависимость:

```json
"express": "^5.1.0"
```

Express нужен для HTTP API.

### `backend/package-lock.json`

Фиксирует точные версии Node-зависимостей.

Его обычно не редактируют руками.

Он нужен, чтобы у тебя и у другого разработчика установились одинаковые версии пакетов.

### `backend/.env.example`

Пример переменных окружения:

```txt
PORT=3000
OPENAI_API_KEY=
AI_MODEL=gpt-4.1-mini
```

Чтобы подключить настоящий ИИ:

1. создай файл `backend/.env`;
2. добавь туда ключ;
3. запускай backend.

Файл `.env` не должен попадать в git, потому что там секретный ключ.

### `backend/src/server.js`

Точка запуска backend.

Код:

```js
import app from './app.js';

const port = Number(process.env.PORT || 3000);

app.listen(port, () => {
  console.log(`UneBil backend listening on http://localhost:${port}`);
});
```

Простыми словами: берет Express app из `app.js` и запускает сервер на порту `3000`.

### `backend/src/app.js`

Главный backend-файл.

Что внутри:

```js
app.get('/health', ...)
```

Проверка, что backend живой.

```js
app.post('/api/generate-facts', ...)
```

Главный API endpoint для Flutter.

Он делает:

1. проверяет request body;
2. если нет `OPENAI_API_KEY`, возвращает mock-факты;
3. если ключ есть, отправляет запрос в OpenAI API;
4. возвращает JSON с массивом `facts`.

Функция:

```js
validateGenerateFactsRequest(body)
```

Проверяет:

- `topic` от 2 до 80 символов;
- `language` только `ru`, `kk`, `en`;
- `lengthMode` только `short`, `medium`, `detailed`;
- `count` от 1 до 8.

Функция:

```js
makeMockFacts(...)
```

Создает тестовые факты без настоящего ИИ.

Функция:

```js
generateFactsWithOpenAI(...)
```

Отправляет запрос в OpenAI Chat Completions API.

Если хочешь поменять стиль ответа ИИ, редактируй `messages` внутри этой функции.

### `backend/test/generate-facts.test.js`

Тесты backend.

Проверяют:

- валидный запрос возвращает mock-факты без API-ключа;
- неправильный язык возвращает `400`;
- неправильная длина возвращает `400`.

Запуск:

```sh
cd backend
npm test
```

## 10. Тесты Flutter

### `test/app_controller_test.dart`

Unit-тесты бизнес-логики.

Проверяют:

- что режимы длины имеют правильные значения `20`, `40`, `70`;
- что можно добавить, выключить и удалить тему;
- что настройки сохраняются и загружаются.

В этом файле есть fake-классы:

```dart
FakeFactGenerator
RecordingScheduler
```

Они нужны, чтобы тесты не ходили в интернет и не создавали настоящие Android-уведомления.

### `test/widget_test.dart`

Widget-тесты UI.

Проверяют:

- главный экран показывает пустое состояние;
- пользователь может добавить тему через dialog;
- пользователь может поменять язык и длину в настройках.

Если меняешь текст кнопок или UI, эти тесты могут сломаться. Тогда нужно обновить тесты под новый текст.

## 11. Конфигурация Flutter

### `pubspec.yaml`

Главный файл Flutter-проекта.

Тут указаны:

- имя проекта;
- описание;
- версия;
- Dart SDK;
- зависимости;
- dev-зависимости;
- настройка Material Icons.

Главные зависимости:

```yaml
http
shared_preferences
flutter_local_notifications
timezone
flutter_timezone
uuid
```

Что они делают:

- `http` - отправлять запросы в backend;
- `shared_preferences` - хранить данные на телефоне;
- `flutter_local_notifications` - показывать уведомления;
- `timezone` - правильно считать время;
- `flutter_timezone` - узнать timezone устройства;
- `uuid` - создавать уникальные id.

Если хочешь добавить новый Flutter-пакет:

```sh
flutter pub add package_name
```

### `pubspec.lock`

Фиксирует точные версии Flutter/Dart пакетов.

Не редактируй руками.

Обновляется автоматически после:

```sh
flutter pub get
flutter pub add ...
```

### `analysis_options.yaml`

Настройки анализатора Dart.

Сейчас используется:

```yaml
include: package:flutter_lints/flutter.yaml
```

Это набор правил, который помогает писать более чистый Dart-код.

Проверка:

```sh
dart analyze
```

### `.metadata`

Служебный файл Flutter.

Он говорит Flutter SDK:

- какой версией Flutter создан проект;
- какие платформы есть;
- что это app.

Не редактируй руками.

### `.gitignore`

Говорит git, какие файлы не надо сохранять.

Например:

- `build/`;
- `.dart_tool/`;
- `backend/node_modules/`;
- `backend/.env`;
- `*.log`;
- IDE-файлы.

Это важно, чтобы в GitHub не попали тяжелые сборки, временные файлы и секретные ключи.

### `.flutter-plugins-dependencies`

Служебный файл Flutter, где перечислены plugin-зависимости.

Не редактируй руками.

Обновляется Flutter-командами.

### `unebil.iml`

Файл IDE, созданный IntelliJ/Android Studio.

Не важен для логики приложения.

Обычно не редактируется руками.

### `flutter_01.log`

Лог ошибки Flutter tool.

Он появился, когда `flutter analyze` упал из-за бага tooling/пути.

Файл уже игнорируется через `*.log`, его не надо коммитить.

## 12. Android-файлы

Большинство файлов в `android/` созданы Flutter автоматически. Их трогают редко.

### `android/settings.gradle.kts`

Подключает Flutter Gradle plugin и Android app module.

Важное:

```kotlin
include(":app")
```

Это говорит Gradle, что есть модуль приложения `app`.

Обычно не редактируется.

### `android/build.gradle.kts`

Общий Gradle build-файл для Android-проекта.

Он задает repositories:

```kotlin
google()
mavenCentral()
```

И настраивает директории сборки.

Обычно не редактируется.

### `android/gradle.properties`

Настройки Gradle.

Важное:

```properties
android.useAndroidX=true
android.overridePathCheck=true
```

`android.overridePathCheck=true` добавлен потому, что путь проекта содержит кириллицу. Без этого Android build на Windows ругался.

### `android/gradle/wrapper/gradle-wrapper.properties`

Указывает, какую версию Gradle использовать.

Не редактируй, если специально не обновляешь Gradle.

### `android/gradlew`

Скрипт запуска Gradle для macOS/Linux.

Для Windows обычно используется `gradlew.bat`.

### `android/gradlew.bat`

Скрипт запуска Gradle для Windows.

Flutter сам использует его при сборке Android.

### `android/local.properties`

Локальные пути на твоем компьютере, например путь к Flutter SDK.

Не коммить, не редактируй без необходимости.

У другого разработчика этот файл будет свой.

### `android/.gitignore`

Git ignore внутри Android-папки.

Исключает локальные Android/Gradle файлы.

### `android/unebil_android.iml`

IDE-файл Android Studio/IntelliJ.

Не влияет на код приложения.

### `android/app/build.gradle.kts`

Очень важный Android build-файл модуля app.

Тут указано:

```kotlin
namespace = "com.ibrashov.unebil"
applicationId = "com.ibrashov.unebil"
```

`applicationId` - уникальный id Android-приложения.

Тут включен desugaring:

```kotlin
isCoreLibraryDesugaringEnabled = true
coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
```

Это нужно для `flutter_local_notifications`.

Если убрать, Android build упадет.

### `android/app/src/main/AndroidManifest.xml`

Главный Android manifest.

Тут указаны разрешения:

```xml
POST_NOTIFICATIONS
RECEIVE_BOOT_COMPLETED
SCHEDULE_EXACT_ALARM
```

Что они делают:

- `POST_NOTIFICATIONS` - разрешение показывать уведомления на Android 13+;
- `RECEIVE_BOOT_COMPLETED` - восстановление уведомлений после перезагрузки;
- `SCHEDULE_EXACT_ALARM` - точные уведомления по времени.

Тут задано имя приложения:

```xml
android:label="UneBil"
```

Тут разрешен HTTP для локального backend:

```xml
android:usesCleartextTraffic="true"
```

Для production лучше использовать HTTPS.

Тут добавлены receivers для уведомлений:

```xml
ScheduledNotificationReceiver
ScheduledNotificationBootReceiver
```

Они нужны пакету `flutter_local_notifications`.

### `android/app/src/debug/AndroidManifest.xml`

Manifest только для debug-сборки.

Обычно Flutter использует его для debug-особенностей.

Редко нужно менять.

### `android/app/src/profile/AndroidManifest.xml`

Manifest для profile-сборки.

Profile нужен для измерения производительности.

Редко нужно менять.

### `android/app/src/main/kotlin/com/ibrashov/unebil/MainActivity.kt`

Главная Android Activity.

Код обычно такой:

```kotlin
class MainActivity : FlutterActivity()
```

Она запускает Flutter внутри Android.

Для обычного Flutter UI ее почти никогда не надо менять.

### `android/app/src/main/res/drawable/launch_background.xml`

Фон splash screen до запуска Flutter UI.

Если хочешь поменять стартовый экран, можно начать отсюда.

### `android/app/src/main/res/drawable-v21/launch_background.xml`

Версия launch background для Android API 21+.

Похожа на обычный `drawable/launch_background.xml`.

### `android/app/src/main/res/values/styles.xml`

Стили Android для запуска Activity.

Flutter использует их до того, как отрисует свой UI.

### `android/app/src/main/res/values-night/styles.xml`

Темная версия Android launch styles.

Работает, когда устройство в dark mode.

### `android/app/src/main/res/mipmap-mdpi/ic_launcher.png`

Иконка приложения для mdpi экранов.

### `android/app/src/main/res/mipmap-hdpi/ic_launcher.png`

Иконка приложения для hdpi экранов.

### `android/app/src/main/res/mipmap-xhdpi/ic_launcher.png`

Иконка приложения для xhdpi экранов.

### `android/app/src/main/res/mipmap-xxhdpi/ic_launcher.png`

Иконка приложения для xxhdpi экранов.

### `android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png`

Иконка приложения для xxxhdpi экранов.

Если хочешь заменить иконку приложения, лучше использовать пакет `flutter_launcher_icons`, а не менять png руками.

## 13. Сгенерированные и временные папки

Эти папки есть в проекте, но их не надо читать как исходный код.

### `.git/`

Внутренние данные Git.

Не редактировать руками.

### `.dart_tool/`

Служебные файлы Dart/Flutter.

Создаются автоматически.

### `build/`

Результаты сборки.

Например APK лежит здесь:

```txt
build/app/outputs/flutter-apk/app-debug.apk
```

Не редактировать руками.

### `backend/node_modules/`

Установленные Node-пакеты.

Создаются командой:

```sh
npm install
```

Не коммитить и не редактировать руками.

### `.idea/`

Настройки IDE.

Не важны для логики приложения.

### `.agents/`

Служебная папка рабочего окружения/агентов.

Не относится к самому приложению.

## 14. Как добавить новую настройку

Пример: хочешь добавить настройку `Включить/выключить авто-генерацию`.

Шаги:

1. Добавить поле в `AppSettings`.
2. Обновить `toJson()` и `fromJson()` в `app_settings.dart`.
3. Добавить метод в `AppController`, например `updateAutoGenerate(bool value)`.
4. Добавить UI в `SettingsScreen`.
5. Если настройка влияет на уведомления, вызвать `_rescheduleNotifications()`.
6. Добавить тест в `test/app_controller_test.dart`.

## 15. Как добавить новое поле в тему

Пример: хочешь хранить цвет темы.

Шаги:

1. Добавить поле в `Topic`.
2. Обновить constructor.
3. Обновить `fromJson()`.
4. Обновить `toJson()`.
5. Обновить `copyWith()`.
6. Обновить UI в `HomeScreen`.
7. Обновить тесты.

Важно: старые пользователи уже могут иметь сохраненные темы без нового поля. Поэтому в `fromJson()` нужно давать default value.

Пример:

```dart
color: json['color'] as String? ?? '#2563EB'
```

## 16. Как работает сохранение

Когда пользователь добавляет тему:

```txt
HomeScreen
  -> controller.addTopic(title)
  -> _topics обновляется
  -> StorageService.saveTopics(_topics)
  -> generateFactsForTopic(...)
  -> StorageService.saveFacts(_facts)
  -> NotificationScheduler.scheduleDailyFacts(...)
```

Все сохраняется в `SharedPreferences`.

Это простое локальное хранилище. Для MVP хорошо. Если потом появятся аккаунты и синхронизация, можно будет перейти на Firebase или backend database.

## 17. Как работает генерация фактов

Flutter отправляет запрос:

```txt
AiClient.generateFacts()
  -> POST /api/generate-facts
```

Backend получает:

```json
{
  "topic": "space",
  "language": "en",
  "lengthMode": "short",
  "count": 2
}
```

Backend отвечает:

```json
{
  "facts": [
    {
      "title": "space: fact 1",
      "body": "A useful idea about space..."
    }
  ]
}
```

Flutter превращает это в `LearningFact` и сохраняет.

## 18. Как работает уведомление

Когда меняются темы, факты или настройки:

```txt
AppController
  -> _rescheduleNotifications()
  -> NotificationScheduler.scheduleDailyFacts(...)
```

Scheduler:

1. удаляет старые pending notifications;
2. берет включенные темы;
3. выбирает подходящий факт;
4. считает ближайшее время;
5. планирует Android notification.

Если фактов по теме еще нет, уведомление будет текстом:

```txt
Открой UneBil и сгенерируй новый короткий факт по теме ...
```

## 19. Типичные ошибки и что делать

### Backend не отвечает

Проверь:

```sh
cd backend
npm start
```

Потом:

```sh
curl http://127.0.0.1:3000/health
```

Или в PowerShell:

```powershell
Invoke-WebRequest http://127.0.0.1:3000/health
```

Должно быть:

```json
{"ok":true}
```

### Emulator не видит backend

Для emulator используй:

```txt
http://10.0.2.2:3000
```

Не используй:

```txt
http://localhost:3000
```

Внутри emulator `localhost` означает сам emulator, а не твой компьютер.

### Физический телефон не видит backend

Телефон и компьютер должны быть в одной Wi-Fi сети.

Нужно узнать IP компьютера и запустить так:

```sh
flutter run --dart-define=API_BASE_URL=http://YOUR_COMPUTER_IP:3000
```

### Уведомления не приходят

Проверь:

1. Разрешил ли Android уведомления.
2. Есть ли хотя бы одна включенная тема.
3. Есть ли хотя бы одно время уведомления.
4. Не стоит ли время уже в прошлом: тогда уведомление будет завтра.
5. На некоторых Android нужно отдельно разрешить exact alarms.

### Android build ругается на путь с кириллицей

В проект уже добавлено:

```properties
android.overridePathCheck=true
```

Это в:

```txt
android/gradle.properties
```

### Flutter build просит desugaring

В проект уже добавлено:

```kotlin
isCoreLibraryDesugaringEnabled = true
coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
```

Это в:

```txt
android/app/build.gradle.kts
```

## 20. Что коммитить в GitHub

Коммитить нужно:

- `lib/`;
- `test/`;
- `backend/src/`;
- `backend/test/`;
- `backend/package.json`;
- `backend/package-lock.json`;
- `backend/.env.example`;
- `android/`;
- `pubspec.yaml`;
- `pubspec.lock`;
- `README.md`;
- `README_FOR_ANUAR.md`;
- `.gitignore`;
- `.metadata`;
- `analysis_options.yaml`.

Не коммитить:

- `build/`;
- `.dart_tool/`;
- `backend/node_modules/`;
- `backend/.env`;
- `*.log`;
- `.idea/`;
- `*.iml`.

## 21. Самые важные файлы, если мало времени

Если хочешь быстро понять проект, читай в таком порядке:

1. `README_FOR_ANUAR.md`
2. `lib/main.dart`
3. `lib/services/app_controller.dart`
4. `lib/screens/home_screen.dart`
5. `lib/screens/topic_detail_screen.dart`
6. `lib/screens/settings_screen.dart`
7. `lib/services/ai_client.dart`
8. `backend/src/app.js`
9. `lib/services/notification_scheduler.dart`
10. `lib/services/storage_service.dart`

После этого остальные файлы будут намного понятнее.

## 22. Короткая карта проекта

```txt
UneBil App/
  lib/
    main.dart                    запуск Flutter app
    models/                      классы данных
    services/                    логика, backend, storage, notifications
    screens/                     UI экраны
  backend/
    src/app.js                   Express API
    src/server.js                запуск backend
    test/                        backend tests
  test/                          Flutter tests
  android/                       Android host project
  pubspec.yaml                   Flutter dependencies
  README.md                      короткая инструкция
  README_FOR_ANUAR.md            это подробное объяснение
```

Главное правило: если меняешь данные - смотри `models` и `storage`. Если меняешь поведение - смотри `AppController`. Если меняешь внешний вид - смотри `screens`. Если меняешь ИИ - смотри `AiClient` и `backend/src/app.js`.
