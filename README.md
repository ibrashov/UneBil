# UneBil

UneBil is an Android-first Flutter MVP that turns phone time into small learning moments.
Users add topics they are curious about, choose the language and notification length, set exact daily times, and receive short learning facts as local notifications.

For a detailed Russian explanation of every important file, read:

```txt
README_FOR_ANUAR.md
```

## Features

- Add, rename, disable, and delete learning topics.
- Generate facts for any topic through a backend AI proxy.
- Choose fact language: Russian, Kazakh, or English.
- Choose notification length: short, medium, or detailed.
- Schedule local daily notifications at exact times.
- Store topics, settings, and cached facts locally on the phone.

## Flutter App

Install Flutter dependencies:

```sh
flutter pub get
```

Run on an Android emulator with the local backend:

```sh
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:3000
```

For a physical Android device, replace `10.0.2.2` with your computer's LAN IP address.

Run checks:

```sh
dart analyze
flutter test
flutter build apk --debug
```

The debug APK is created at:

```txt
build/app/outputs/flutter-apk/app-debug.apk
```

## Backend

The backend lives in `backend/` and exposes:

```txt
POST /api/generate-facts
```

Install and run:

```sh
cd backend
npm install
npm start
```

Without `OPENAI_API_KEY`, the backend returns deterministic mock facts so the app can be tested locally.

To use AI generation, create environment variables based on `backend/.env.example`:

```sh
set OPENAI_API_KEY=your_key_here
set AI_MODEL=gpt-4.1-mini
npm start
```

Run backend tests:

```sh
cd backend
npm test
```
