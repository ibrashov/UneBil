# Investigation: AI generation and backend connectivity

## Confirmed causes and fixes

| Finding | Evidence | Resolution |
| --- | --- | --- |
| Previous Cerebras requests could not generate facts | `backend/backend.stderr.log` contains repeated provider HTTP 402 billing/quota failures | Current local Inception configuration works; verified with real API calls. Changing a prompt or restarting Cerebras cannot restore its quota. |
| Local backend was stopped | Nothing listened on `127.0.0.1:3000` during investigation | Started the current server with Inception; `/ready` reports the provider and model. |
| Starting `node backend/src/server.js` from the IDE skipped `.env` | Only the old npm command loaded `.env`, relative to its working directory | Server now loads `backend/.env` relative to its source; host environment variables retain precedence. |
| Render startup competed with generation's 70-second timeout | Free Render can take about a minute to wake | Client waits for a valid `/health` response on `*.onrender.com` for up to 90 seconds, then sends one generation request with a separate 70-second limit. Startup HTML and transient gateway errors are handled. |
| An APK built without a URL could not generate | `API_BASE_URL` previously defaulted to an empty string | After verifying the user's deployment, set the app default to `https://unebil.onrender.com`. Phone build script also embeds the checked URL and verifies a real fact before building. |
| Health checks did not distinguish missing AI configuration | `/health` always returns `ok: true` | Added `/ready` for configuration and `npm run check:ai` for real credentials/quota testing. Render uses `/health` for liveness. |
| Valid multilingual exclusion histories could exceed the HTTP limit | 120 allowed Cyrillic entries exceed 128 KB | Increased JSON limit to 512 KB; added HTTP regression coverage. Oversized/malformed bodies now return safe JSON errors. |
| Inception structured output was disabled | Both Inception config paths set `supportsJsonMode: false` | Enabled JSON mode and verified live batches. Prompt includes the same length limits enforced by validation. |
| Bad JSON and timeouts looked like connection failures | Client caught all unexpected failures as backend unavailable | Separate timeout, invalid-response, URL and HTTP errors; suppress raw proxy HTML. Provider timeouts get a distinct 504 code. |
| Deployment/runtime instructions disagreed | README described Cerebras, Blueprint selected Inception, runtime minimum was too broad | Aligned docs/example/Blueprint with Inception; Node 24 deployment, Node 22.16 minimum, reproducible `npm ci`. |

## Verification

- 23 backend regression tests passed.
- Final `dart analyze`, JavaScript syntax checks, PowerShell parsing and
  `git diff --check` passed. `npm audit --omit=dev` reported zero vulnerabilities.
- 62 Flutter tests passed, including Render startup, no repeated generation,
  UTF-8 responses, mock rejection, provider failures and existing UI behavior.
- Live detailed batch checks returned 10 English, 9 Russian and 10 Kazakh usable
  facts via Inception, in approximately 3.3, 2.6 and 4.4 seconds. One Russian
  candidate failed validation; partial batches are supported intentionally.
- No Android device was connected. APK installation and visual verification on
  the phone remain pending.
- The user supplied the actual deployment: `https://unebil.onrender.com`.
  `/health` returned 200. Live generation returned 10 usable facts in each of
  English, Russian and Kazakh through Inception, in approximately 3.0, 5.1 and
  2.7 seconds. The remote AI configuration works.
- `/` and `/ready` returned 404: the deployed server is still the older version.
  A homepage 404 is not an API connection failure. New backend changes in this
  workspace have not been deployed; Render account/deployment access is still
  unavailable. The APK can use the existing working generation endpoint.
- The earlier Wi-Fi APK is superseded by a new release build targeting the
  verified public Render URL. The computer's local backend is not needed for
  that build. `UneBil-phone-release.apk`: 54,362,609 bytes, modified
  2026-09-15 22:26:25 +05:00; newer than all Dart source. Static analysis and
  all 62 Flutter tests passed again after changing the default URL.

## Other confirmed limitations requiring separate product work

- **Public endpoint has no authentication or request quotas.** Anyone who knows
  the URL can consume provider quota. Before broad distribution, add real user
  authentication and per-user/server limits. A shared key embedded in the APK
  is not durable protection.
- **History retention is capped at 120 facts across all topics.**
  `AppController._generateFactsForTopic` truncates stored history, including
  review/read state. This also limits duplicate detection. Raising/removing that
  product limit requires a storage/retention decision.
- **Notifications have a finite schedule.** Interval mode schedules 12 slots per
  topic and a bounded total queue. There is no background AI refill; reopening
  the app or changing state replenishes the schedule.
- **Malformed stored records are not recovered individually.** One deserialization
  exception can cause `StorageService` to return an empty collection; valid JSON
  with the wrong top-level shape does not set its read-error flag. Backup/recovery
  and schema migration need further work.
- **AI facts are not independently fact-checked.** Structural validation and
  duplicate filtering do not verify truth or source attribution.
- **Android tooling migration remains.** The build succeeds, but reports that
  `flutter_timezone` still applies the legacy Kotlin Gradle plugin and that the
  SDK command-line tools understand an older XML schema. These warnings did not
  cause the generator/connection failure; revisit them when upgrading Flutter.

This is a focused code review and test run, not a guarantee that every defect in
the application has been discovered.

## Render checks

1. Confirm the actual public HTTPS URL, with no port or endpoint suffix.
2. Deploy the current backend with the settings in `render.yaml`.
3. Set `INCEPTION_API_KEY` in Render Environment; local `.env` is not uploaded.
4. Check `/health`, `/ready`, then run `npm run check:ai -- https://YOUR-SERVICE.onrender.com`
   from `backend/`.
5. Build and install an APK using that exact URL.

Reference: [Render free-service startup behavior](https://render.com/docs/free)
and [Render health checks](https://render.com/docs/health-checks).
