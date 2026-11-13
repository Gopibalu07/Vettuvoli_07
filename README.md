# VettuVoli

Offline noise removal for creators, students and vloggers. Record or import audio/video, remove background noise **entirely on the device** (FFmpeg, no internet, no cloud), compare Before/After, then share or save.

## Get an APK (pick one)

### A. No local setup: build in the cloud (GitHub)
1. Create a new GitHub repo and push this folder to it (`main` branch).
2. Open the repo's **Actions** tab -> **Build Android APK** -> **Run workflow**.
3. When it finishes, download the **vettuvoli-apk** artifact, unzip, copy `app-release.apk` to your phone and install it (allow "install unknown apps").

### B. Build locally
1. Install Flutter (stable), Android Studio / Android SDK and JDK 17.
2. From this folder:
   ```bash
   bash tool/setup_platforms.sh        # creates android/ + ios/, applies permissions, runs pub get
   flutter run                          # debug on a connected phone
   flutter build apk --release          # -> build/app/outputs/flutter-apk/app-release.apk
   ```
3. iOS: same script, then open `ios/` on a Mac and sign with your Apple ID (`flutter build ios`).

`tool/setup_platforms.sh` does what Phase 1 listed by hand: `minSdk 24`, `RECORD_AUDIO` permission, iOS 14 target and `NSMicrophoneUsageDescription`.

## Project layout

```
lib/
  main.dart, app.dart
  core/            theme, router, constants, errors, utils, shared widgets, providers
  data/            models (Recording), SQLite database, repository
  services/        recorder, ffmpeg (noise reduction), storage, share, player, permissions
  features/
    dashboard/     home screen + recordings list
    record/        record screen + controller + level meter
    processing/    import -> clean -> save pipeline (ProcessingController)
    preview/       Before/After player, level picker, share/save
test/              unit tests
tool/              platform setup scripts
```

## How the noise removal works (`lib/services/ffmpeg_service.dart`)

`highpass 80 Hz` -> `afftdn` (FFT denoise) -> `agate` -> `lowpass 16 kHz` -> `loudnorm -16 LUFS`, written as AAC `.m4a`. Three strengths (Light / Standard / Strong) change the denoise depth, noise floor and gate threshold. Video files are handled with `-vn` (audio extracted).

## Known limits

- Built with `ffmpeg_kit_flutter_new` (community fork; the original FFmpegKit is retired). It adds noticeable size to the APK.
- `afftdn` is a classic DSP denoiser: great on steady noise (fans, hum, hiss, AC), weaker on changing noise like traffic or other voices. An ML model (e.g. `arnndn`) could be added later.
- Release APKs from the CI workflow are signed with the debug key. Create a proper keystore before publishing to the Play Store.
