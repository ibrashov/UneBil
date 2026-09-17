# UneBil

UneBil is a Flutter app for Android and iOS that turns phone time into small learning moments.
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

The app defaults to the public backend `https://unebil.onrender.com`.
Use `--dart-define=API_BASE_URL=...` to override it for local development.

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

## iPhone and App Store

The iOS project is in `ios/`. Building and signing an iPhone application
requires macOS, Xcode, and an Apple Developer account; it cannot be completed
on Windows.

On a Mac, install the current stable Flutter and Xcode, then run:

```sh
flutter pub get
dart run flutter_launcher_icons
open ios/Runner.xcworkspace
```

In Xcode, select the `Runner` target, choose your Apple development team, and
confirm that the bundle identifier `com.ibrashov.unebil` is available in your
account. Test notifications and fact generation on a physical iPhone before
uploading the first build to TestFlight.

Create the App Store archive with:

```sh
flutter build ipa --release \
  --dart-define=API_BASE_URL=https://unebil.onrender.com
```

The IPA is written to `build/ios/ipa/`. Detailed Russian instructions and the
App Store checklist are in [`IOS_RELEASE_RU.md`](IOS_RELEASE_RU.md).

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

Use Node.js 24 LTS (minimum 22.16). `npm start` and
`node backend/src/server.js` both load `backend/.env` regardless of the working
directory. Environment variables already set by the host take precedence.

Without an AI API key, the backend returns `503` and the app shows an error. It never
saves a placeholder as a learning fact. For an isolated backend test only, mock
responses can be enabled explicitly with `ALLOW_MOCK_FACTS=true`; the Flutter app
still rejects responses marked as `source: mock`.

To use Inception generation, create `backend/.env` based on `backend/.env.example`:

```sh
AI_PROVIDER=inception
INCEPTION_API_KEY=your_key_here
INCEPTION_MODEL=mercury-2
npm start
```

Restart the backend after changing `.env` or files under `backend/src`, because
`npm start` does not use watch mode. Use `npm run dev` while editing the backend.

Cerebras and OpenAI-compatible generation remain available through the settings
in `.env.example`. HTTP 402 means the selected provider has no usable billing/quota;
restarting cannot fix that. Configure another funded/available provider instead.

Run backend tests:

```sh
cd backend
npm test
```

### Verify the actual AI connection

`/health` checks the HTTP server. `/ready` checks provider configuration without
calling the AI; it does **not** prove that credentials or quota are valid.
This command makes a real 10-fact request and exits with a failure if generation fails:

```powershell
cd backend
npm run check:ai -- --local
# Test a running deployment instead:
npm run check:ai -- https://unebil.onrender.com
# Optional: test English, Russian and Kazakh (three provider requests):
npm run check:ai -- --local --all-languages
```

### Render deployment

Deploy `render.yaml` as a Blueprint, or use these Web Service settings:

- Root directory: `backend`
- Build: `npm ci`; start: `npm start`; Node: `24`
- Health check: `/health`
- Environment: `AI_PROVIDER=inception`, `INCEPTION_MODEL=mercury-2`, and your
  `INCEPTION_API_KEY`. The local `.env` is ignored by Git and is **not uploaded**.

Use the public HTTPS service URL without `:3000`, `:10000`, `/health`, or `/api`.
The backend already binds to `0.0.0.0` and Render's `PORT`.
Render's free service sleeps after 15 idle minutes and can take about a minute
to start ([Render documentation](https://render.com/docs/free)). The Android
client waits for `/health` on `*.onrender.com` for up to 90 seconds before its
separate 70-second generation request. It does not automatically retry generation.

After deploying, build the phone app with the actual address:

```powershell
.\scripts\Build-PhoneApk.ps1 -ApiBaseUrl https://unebil.onrender.com
```

The script checks health and generates one real fact before building. A plain
`flutter build apk` uses `https://unebil.onrender.com` by default.
For a working local Wi-Fi alternative, keep `npm start` running and execute
`.\scripts\Build-PhoneApk.ps1` without an address.

See [ISSUES.md](ISSUES.md) for the investigated failures and remaining limitations.
