# YT Stream Player

An educational, open-source Flutter application demonstrating audio streaming
architecture using `youtube_explode_dart` for public metadata/stream
resolution and `just_audio` for playback.

## Project Structure

```
lib/
  main.dart
  models/
    track_model.dart
  services/
    youtube_service.dart
    audio_player_service.dart
  widgets/
    song_tile.dart
    bottom_player.dart
android/
  ... standard Gradle project (Kotlin, AGP 8.1, Gradle 8.4)
.github/workflows/build.yml
```

## Running Locally

1. Install the Flutter SDK (stable channel, 3.24.x or newer):
   https://docs.flutter.dev/get-started/install
2. From the project root:
   ```
   flutter pub get
   flutter run
   ```

## Building via GitHub Actions (no local Flutter install needed)

This repo includes `.github/workflows/build.yml`, which:

1. Checks out the repo.
2. Installs JDK 17 and the Flutter SDK on the runner.
3. Runs `flutter pub get`, `flutter analyze`, and `flutter test`.
4. Builds a release APK (`flutter build apk --release`) and per-ABI APKs.
5. Uploads the resulting `.apk` files as a downloadable workflow artifact
   named `app-release-apks`.

### To use it:

1. Push this project to a GitHub repository (root of the repo must contain
   `pubspec.yaml`, exactly as in this zip).
2. Go to the repo's **Actions** tab — the workflow runs automatically on
   push to `main`/`master`, or trigger it manually via
   **Run workflow** (workflow_dispatch).
3. Once the run finishes, open it and download the **app-release-apks**
   artifact from the Summary page. It contains:
   - `app-release.apk` (universal)
   - `app-arm64-v8a-release.apk`
   - `app-armeabi-v7a-release.apk`
   - `app-x86_64-release.apk`

### Signing (optional)

The workflow builds an **unsigned-by-default debug-signed** release APK
(`signingConfig signingConfigs.debug` is set in `android/app/build.gradle`
so the build succeeds out of the box). For a Play Store-ready signed build,
replace that line with your own release `signingConfig`, add your keystore
as a GitHub Actions secret, and decode it in a workflow step before the
build step.

## Important Notes

- `youtube_explode_dart` parses YouTube's public web player responses
  without an official API key. This is inherently fragile — YouTube can
  change internal endpoints at any time and break stream resolution.
- This project is for **educational purposes only**. Review YouTube's
  Terms of Service before any non-educational use.
- Background/lock-screen media-notification controls are not wired up in
  this version (no `audio_service` dependency) — audio session
  configuration (`audio_session`) is present so playback correctly
  requests audio focus, but there is no persistent foreground-service
  notification. Adding `audio_service` with a `BaseAudioHandler` is a
  natural next step if you need OS-level media controls.
