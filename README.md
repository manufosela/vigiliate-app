# Vigiliate · Flutter wrapper

Native Android (and soon iOS) wrapper for the [Vigiliate](https://vigiliate.web.app) medical diary PWA. The web app is a fully offline-first tracker for auto-immune encephalitis and myasthenia gravis (daily logs, episodes, analytics, medical report). This Flutter shell adds what a browser cannot give:

- **Native Google Sign-In** (via `google_sign_in`) exposed to the web app through a JavaScript bridge.
- **Exact local notifications** for medication reminders (`flutter_local_notifications` + `timezone`), surviving reboots and Doze.
- **Distribution via Google Play** with the standard WebView experience (`PopScope`, `SystemChrome` dark theme, status/navigation bar colors matching the PWA).

The PWA itself lives in its own repo — this project only ships the shell.

## Stack

- Flutter `^3.5.3` (Dart)
- `webview_flutter` — WebView of `https://vigiliate.web.app`
- `google_sign_in` — native OAuth
- `flutter_local_notifications` + `timezone` — scheduled reminders
- `flutter_launcher_icons` — adaptive icon generation

## JavaScript bridge

On `onPageFinished` the WebView injects:

```js
window.__vigiliate_native = true;
window.__vigiliate_native_state = {
  notificationsGranted: true | false | null,
  exactAlarmsGranted:   true | false | null,
};
// null means "not asked yet" (pre-Android 13 or init not run)
window.dispatchEvent(new CustomEvent('vigiliate-bridge-ready', {
  detail: window.__vigiliate_native_state
}));
```

The PWA sends messages via `window.VigiliateBridge.postMessage(JSON.stringify(payload))` with these `type`s:

| Type | Payload | Native behavior |
|---|---|---|
| `google-sign-in` | — | Opens Google Sign-In, replies by calling `window.__vigiliate_onNativeAuth({idToken, accessToken})` or `null` if cancelled/failed |
| `google-sign-out` | — | Signs out of Google |
| `schedule-alarms` | `{slots: [{time: "HH:mm", meds: "..."}]}` | Cancels existing alarms and schedules new ones (exact, daily, surviving reboot) |
| `cancel-alarms` | — | Cancels all scheduled reminders |
| `query-notification-permission` | — | Re-reads the runtime permissions (notifications + exact alarms). Replies via `window.__vigiliate_onPermissionStatus({notifications, exactAlarms})` where each field is `true \| false \| null`. Useful after sending the user to System Settings. |

## Project layout

```
lib/
  main.dart           — bootstrap + system UI + NotificationService.init
  app.dart            — MaterialApp + WebViewScreen + bridge plumbing
  google_auth.dart    — GoogleSignIn wrapper
  notifications.dart  — scheduled reminders + bridge message dispatch
android/              — Android config (signing, Firebase, AndroidManifest)
ios/                  — iOS scaffold (not yet fully configured)
assets/icon.png       — adaptive launcher icon source (1a1614 background)
screenshots/          — Play Store screenshots and feature graphic
test/widget_test.dart — Flutter tests
```

## Getting started

### Prerequisites
- Flutter 3.5.3+ on the `stable` channel (`flutter --version`)
- Android SDK with `compileSdk 34`, `minSdk 26`
- For release builds: a keystore and Firebase project credentials (see below)

### Install dependencies
```bash
flutter pub get
```

### Run in debug
```bash
flutter run
```

### Run tests
```bash
flutter test
```

### Lint / analyze
```bash
flutter analyze
```

## Secrets and per-environment files

These files **are not in the repo** (see `.gitignore`) and must be placed locally after cloning:

| Path | Source | Purpose |
|---|---|---|
| `android/app/google-services.json` | Firebase console → Project settings → Android app → Download | Firebase config (used by `com.google.gms.google-services` Gradle plugin) |
| `android/key.properties` | Created manually (see template below) | Release keystore credentials |
| `ios/Runner/GoogleService-Info.plist` | Firebase console → iOS app (once iOS target is configured) | Firebase config for iOS |

### `android/key.properties` template

```properties
storePassword=xxxxxxxx
keyPassword=xxxxxxxx
keyAlias=upload
storeFile=/absolute/path/to/upload-keystore.jks
```

The keystore file itself (`*.jks`) is also ignored; keep it in a safe location outside the repo.

## Build release

### App Bundle for Play Store (recommended)
```bash
flutter build appbundle --release
# → build/app/outputs/bundle/release/app-release.aab
```

### APKs split per ABI (smaller downloads for direct install)
```bash
flutter build apk --release --split-per-abi
# → build/app/outputs/flutter-apk/
#     app-armeabi-v7a-release.apk  (~13 MB, older 32-bit devices)
#     app-arm64-v8a-release.apk    (~16 MB, modern ARM 64 phones — the common case)
#     app-x86_64-release.apk       (~17 MB, emulators / Chromebooks)
```

The fat universal APK (`flutter build apk --release` without `--split-per-abi`) is ~43 MB. Use splits whenever you distribute outside Google Play. Inside Play you don't need this — the App Bundle (`appbundle` target) already performs the split on Google's side so each user downloads only their ABI.

### Debug APK
```bash
flutter build apk --debug
# or simply: flutter run
```

### Versioning policy

Version is declared in `pubspec.yaml` as `version: <versionName>+<versionCode>`. Rules:

- **`versionCode`** (the number after `+`) is **monotonically increasing**; Play Console rejects any bundle with a `versionCode` equal or lower than one previously uploaded to that track.
- **`versionName`** follows [semver](https://semver.org): `MAJOR.MINOR.PATCH`.
  - `PATCH` → bug fix / small UX polish / infra task (wrapper hardening, lints, proguard)
  - `MINOR` → new capability exposed to the PWA (new bridge type, new permission)
  - `MAJOR` → breaking change for users or PWA contract
- Always bump `versionCode` when you bump `versionName` — even for the smallest patch. Confirm against Play Console → Internal release history before bumping.

Current: `1.0.1+2` (first post-launch release; adds runtime permission handling, WebView UX, hardened lints and tests).

## Android manifest notes

Declared permissions (`android/app/src/main/AndroidManifest.xml`):

- `INTERNET` — required by the WebView
- `POST_NOTIFICATIONS` — Android 13+ runtime permission for notifications
- `SCHEDULE_EXACT_ALARM` + `USE_EXACT_ALARM` — exact-time medication alarms
- `RECEIVE_BOOT_COMPLETED` — reschedule alarms after reboot
- `VIBRATE`, `WAKE_LOCK` — alarm delivery

`SCHEDULE_EXACT_ALARM` in Android 14+ requires a runtime opt-in. The app requests it automatically on startup via `flutter_local_notifications`' `requestExactAlarmsPermission()` and, if denied, falls back to `AndroidScheduleMode.inexactAllowWhileIdle` (reminders may drift by a few minutes). The PWA is notified of the state through `exactAlarmsGranted` in `window.__vigiliate_native_state`.

## Crash reporting

Crashlytics is wired in `lib/main.dart`:

- Framework errors → `FirebaseCrashlytics.instance.recordFlutterFatalError`
- Async / out-of-tree errors → `PlatformDispatcher.instance.onError`
- Zone-level escapes → `runZonedGuarded`
- Collection is **disabled in debug** (`kDebugMode`) so local runs don't pollute the dashboard

Reports show up at <https://console.firebase.google.com/project/_/crashlytics>. The first crash after a release can take a few minutes to appear.

## Planning Game tracking

This project is tracked in the Planning Game (`Vigiliate` project), under epic `VGI-PCS-0007 — App móvil nativa (Flutter wrapper)`.

## Links

- PWA: <https://vigiliate.web.app>
- Play Store: (approved, link TBD)
- Parent PWA repo: <https://github.com/manufosela/vigiliate>
