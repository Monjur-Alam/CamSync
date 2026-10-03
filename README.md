# Misurl

Misurl is a field camera for batches that cannot afford a dropped connection. You frame the shot on the live view, keep every capture on the phone, and the sync engine uploads one image at a time to the CamSync API. A failed call stays in the queue and goes out again when the link is stable, including after the app has been closed.

The camera screen and the upload manager follow the Task 2 mock: live view with zoom, focus, and batch shutter on one side, and the dark upload queue on the other.

## Project structure

The app is a layered Flutter client.

- `lib/ui` paints the camera and the upload manager.
- `lib/bloc` holds `CameraCubit` and `SyncCubit`.
- `lib/data` stores the queue in SQLite, compresses oversized JPEGs, and calls the HTTP API.
- `lib/service` is the sync engine shared by the open app and the background worker.

`CameraCubit` owns the preview, pinch zoom, the 1x–5x slider, the 0.5 / 1x / 2 chips, tap-to-focus, flash, and the shutter. `SyncCubit` watches connectivity, probes `GET /api/v1/health`, and asks `SyncEngine` to drain the queue. The engine claims one row, posts it to `POST /api/v1/images`, and writes the result back. `200` and `201` (including a duplicate retry) mark the capture synced. Network errors, `500`, `503`, and retryable `400`s stay pending. `401`, `413`, and `415` stop that file. On startup the engine also calls `GET /api/v1/batches/{batch_id}` so a capture that already landed is not sent as if it were new.

Android WorkManager runs the same engine about every 15 minutes, and again soon after a capture or when the radio returns, so the queue keeps moving with the app closed.

## Generative AI

Cursor, using Grok 4.7, drafted this client from the assessment PDF and the CamSync API README. The prompt that drove the implementation was: build the Task 2 Flutter camera and sync engine against `https://munjuralam.com/camsync`, keep the queue idempotent, and match the supplied camera and upload-manager mock. Follow-up prompts covered the upload status rules (`200`/`201` done, retryable failures stay queued, `401`/`413`/`415` stop), WorkManager draining the same SQLite queue, and pixel-level layout of the live view and upload cards.

## How to run

1. Install Flutter 3.47 or newer and an Android SDK.
2. The API key in `lib/core/config/api_config.dart` must match `config.php` on the host. Rotate that key if this repository is published.
3. From this directory:

```powershell
flutter pub get
flutter run
```

Grant the camera permission when Android asks. Captures land in the app documents folder and show up under Upload Manager. Pause All holds the queue. Start New Upload Batch opens a fresh batch and returns to the live view. The previous batch keeps uploading.

Release APK:

```powershell
flutter build apk --release
```

The APK is `build/app/outputs/flutter-apk/app-release.apk`.

## Screenshots

Shot on a device after `flutter run`:

1. Live view with the shutter, zoom rail, and Upload Batch button.
2. Upload Manager while a batch is syncing, including waiting, retrying, uploading, and synced rows.

Add those images under `docs/` when you capture them on hardware. The layout source is the Task 2 mock: teal live view, `MISURL` watermark, 0.5 / 1x / 2 chips, and the navy upload manager with Stable Link.
