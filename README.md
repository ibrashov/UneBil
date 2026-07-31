# UneBil

UneBil is an Android-first Flutter MVP that turns phone time into small learning moments.
Users add topics they are curious about, choose the language and notification length, select a per-topic notification interval, and receive short learning facts as local notifications.

For a detailed Russian explanation of every important file, read:

```txt
README_FOR_ANUAR.md
```

## Features

- Add, rename, disable, and delete learning topics.
- Generate facts for any topic through a backend AI proxy.
- Choose fact language: Russian, Kazakh, or English.
- Choose notification length: short, medium, or detailed.
- Choose a per-topic interval: every 1, 2, or 3 hours.
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

For a physical Android device on the same Wi-Fi as the computer, use the
dedicated build script. It detects the computer LAN IP, verifies the backend,
and embeds the correct address in the APK:

```powershell
.\scripts\Build-PhoneApk.ps1
```

The generated file is `UneBil-phone-release.apk`. A LAN address works only while
the computer and backend are running and the phone is connected to the same
Wi-Fi. It cannot be reached over 4G/5G. For access from any network, deploy the
backend at a public HTTPS URL and pass that URL to the same script:

```powershell
.\scripts\Build-PhoneApk.ps1 -ApiBaseUrl https://your-backend.example.com
```

Detailed Russian instructions: [`PHONE_BACKEND_RU.md`](PHONE_BACKEND_RU.md).

Run checks:

```sh
dart analyze
flutter test
flutter build apk --debug --dart-define=API_BASE_URL=http://10.0.2.2:3000
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

Without an AI API key, the backend returns `503` and the app shows an error. It never
saves a placeholder as a learning fact. For an isolated backend test only, mock
responses can be enabled explicitly with `ALLOW_MOCK_FACTS=true`; the Flutter app
still rejects responses marked as `source: mock`.

To use Cerebras AI generation, create `backend/.env` based on `backend/.env.example`:

```sh
AI_PROVIDER=cerebras
CEREBRAS_API_KEY=your_key_here
CEREBRAS_MODEL=gemma-4-31b
npm start
```

Restart the backend after changing `.env` or files under `backend/src`, because
`npm start` does not use watch mode. Use `npm run dev` while editing the backend.

OpenAI-compatible generation is still available with `AI_PROVIDER=openai` and `OPENAI_API_KEY`.

Run backend tests:

```sh
cd backend
npm test
```
