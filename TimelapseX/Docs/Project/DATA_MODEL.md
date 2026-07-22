# Data Model — TimelapseX

## Purpose
Document the persisted project state, derived values, and storage layout.

## 1. `Session`
Everything is scoped to a session. Exactly one session is active at a time. A new session is created automatically on cold app launch and again immediately after the previous session is finalized.

The app-facing term is **Album**. Internal `SessionRecord`, `SessionStore`, `Sessions/`, and `session.json` names remain unchanged for backward-compatible storage.

| Field | Type | Notes |
|---|---|---|
| `id` | `String` | Timestamp-based identifier, e.g. `2026-07-02_14-30-05`. Also used for the session folder name. |
| `createdAt` | `Date` | Session creation date and time. |
| `status` | enum `.active` / `.saved` / `.discarded` | Only one session may be `.active` at once. |
| `folderURL` | `URL` | `Application Support/Sessions/{id}/`. |
| `nextSequence` | `Int` | Per-session frame counter, starting at `1` and stored in `session.json`. |
| `frameCount` | `Int` | Derived from the number of frame files in the folder. |
| `photosAlbumIdentifier` | `String?` | `PHAssetCollection.localIdentifier`, set after a successful Save. |
| `lastCaptureAt` | `Date?` | Timestamp of the latest successful frame, used to rotate populated sessions after the configured idle duration. |
| `frameDurationOverrides` | `[String: Double]` | Optional per-frame durations keyed by filename. Values are clamped to 0.5–5.0 seconds in 0.5-second steps. Missing keys inherit the session's global duration. |
| `wasMerged` | `Bool` | Backward-compatible flag shown as a Merged badge on source albums after they have contributed to a merged album. |

`session.json` stores `{ "id", "createdAt", "status", "nextSequence", "lastCaptureAt", "frameDurationSeconds", "frameDurationOverrides", "wasMerged" }` plus optional Photos metadata.

A populated active session closes automatically after the configured capture-idle duration and a fresh active session is created. The feature defaults on at five minutes and supports 5–60 minutes in five-minute steps. Empty active sessions are never rotated by inactivity. Legacy sessions without `lastCaptureAt` use the newest frame file's modification date.

## 2. `CapturedFrame`
In-memory only; the image file is the durable record.

| Field | Type | Notes |
|---|---|---|
| `sequenceNumber` | `Int` | Taken from the active session's `nextSequence`. |
| `filename` | `String` | `IMG_{sequenceNumber:06d}.jpg`. |
| `capturedAt` | `Date` | Hardware volume-button press-down timestamp for EXIF and logs. |
| `localURL` | `URL` | `Sessions/{sessionId}/{filename}`. |
| `imageData` | `Data` | Transient, kept only long enough to write to disk. |

No Photos write happens at capture time. Photos only enters the flow when a session is explicitly saved.
The capture trigger is the hardware volume buttons, not an in-app shutter button.

A photo imported through the system Photos picker is normalized to JPEG and stored as `IMG_000000.jpg`, which sorts before captured frames. If another photo is imported, the previous lead frame is preserved as `IMG_000000_{UUID}.jpg` and the new selection takes the `IMG_000000.jpg` first position. Imported frames are local session frames and do not create capture-log entries.

## 3. `CameraConfiguration`
Derived from device capabilities plus the current settings store.

| Field | Type | Notes |
|---|---|---|
| `selectedDeviceType` | `AVCaptureDevice.DeviceType` | Auto probes ultra-wide first, then wide. Forced options use the chosen lens directly. |
| `selectedFormat` | `AVCaptureDevice.Format` | Largest supported `maxPhotoDimensions` on the selected device. |
| `photoQualityPrioritization` | `AVCapturePhotoOutput.QualityPrioritization` | `.quality` or `.speed`, derived from the quality mode. |
| `exposureMode` | `AVCaptureDevice.ExposureMode` | Continuous by default, locked when exposure lock is enabled. |
| `focusMode` | `AVCaptureDevice.FocusMode` | Continuous by default, locked when focus lock is enabled. |
| `whiteBalanceMode` | `AVCaptureDevice.WhiteBalanceMode` | Continuous by default, locked when white balance lock is enabled. |
| `orientationLock` | enum `.portrait` | Fixed. |
| `levelAngleDegrees` | `Double?` | Live roll derived from Core Motion gravity and displayed only on the camera preview. |
| `videoZoomFactor` | `Double` | Pinch zoom applied directly to the active capture device; constrained to device capability and an app ceiling of 10× so preview and captured photo share the same crop. |

Changing `lensOverride` while any lock is enabled should drop those locks back to continuous, because the values do not transfer across physical cameras.

## 4. `CaptureLogEntry`
Append-only, one entry per capture attempt, stored per session.

| Field | Type | Notes |
|---|---|---|
| `timestamp` | `Date` | ISO 8601. |
| `sequenceNumber` | `Int` | Matches `CapturedFrame.sequenceNumber`. |
| `outcome` | enum `.success` / `.captureFailed` | No per-frame Photos failure case. |
| `errorDescription` | `String?` | Present only when capture fails. |

## 5. `CameraSettingsStore`
Persisted `ObservableObject` backed by `UserDefaults`.

| Field | Type | Storage key | Notes |
|---|---|---|---|
| `lensOverride` | enum `.auto` / `.wide` / `.ultraWide` | `settings.lensOverride` | Default `.auto`; ultra-wide is only shown when supported. |
| `qualityMode` | enum `.bestQuality` / `.fastestCapture` | `settings.qualityMode` | Default `.bestQuality`. |
| `gridOverlay` | enum `.off` / `.ruleOfThirds` / `.centerCross` | `settings.gridOverlay` | Preview-only overlay, never baked into saved JPEGs. |
| `exposureFocusLocked` | `Bool` | `settings.exposureFocusLocked` | Default `false`. |
| `whiteBalanceLocked` | `Bool` | `settings.whiteBalanceLocked` | Default `false`. |
| `latestPhotoPreviewEnabled` | `Bool` | `settings.latestPhotoPreviewEnabled` | Default `true`; controls the recent-photo overlay on Camera. |
| `latestPhotoPreviewDurationSeconds` | `Double` | `settings.latestPhotoPreviewDurationSeconds` | Default `30`; clamped to 30–300 seconds in 30-second steps. |
| `automaticSessionRotationEnabled` | `Bool` | `settings.automaticSessionRotationEnabled` | Default `true`; controls inactivity-based session creation. |
| `sessionInactivityMinutes` | `Double` | `settings.sessionInactivityMinutes` | Default `5`; clamped to 5–60 minutes in five-minute steps. |
| `cameraPermissionStatus` | computed | — | Read live from `AVCaptureDevice.authorizationStatus(for: .video)`. |
| `photosPermissionStatus` | computed | — | Read live from `PHPhotoLibrary.authorizationStatus(for: .addOnly)`. |

## 6. `TimelapseExportRequest`
In-memory per export operation.

| Field | Type | Notes |
|---|---|---|
| `sessionId` | `String` | The session whose frames will be compiled. |
| `fps` | `Int` | Segmented control choice: 12, 24, 30, or 60. |
| `frameDurationOverrides` | `[String: Double]` | Per-frame hold durations. Export presentation times are cumulative and use an override when present, otherwise the global frame duration. |
| `resolution` | enum `.native` / `.hd1080` / `.hd720` | Maximum output long edge. Never upscales beyond source dimensions. |
| `quality` | enum `.high` / `.standard` / `.compact` | Maps to the H.264 average bitrate used by `AVAssetWriter`. |
| `outputURL` | `URL` | `Sessions/{sessionId}/timelapse.mp4`. |
| `photosAssetIdentifier` | `String?` | Set when the source session is already saved. |

## 7. Storage Layout
```
Application Support/
└── Sessions/
    ├── 2026-07-02_14-30-05/
    │   ├── session.json
    │   ├── capture_log.txt
    │   ├── IMG_000001.jpg
    │   ├── IMG_000002.jpg
    │   └── timelapse.mp4
    └── 2026-07-03_09-15-22/
        └── ...
```

The `Sessions/` tree should be excluded from backups.

Deleting a frame removes its duration override; undo restores both the image and its override. When a new Photos import takes `IMG_000000.jpg`, any override belonging to the previous lead frame moves with its archived filename.

## 8. Album Merge
- Selecting two or more albums creates a new closed album and leaves every source album unchanged.
- Source frames are ordered by file modification date, then album ID and filename for deterministic ties.
- Files are copied and renamed sequentially as `IMG_000001.jpg`, `IMG_000002.jpg`, and so on, making Gallery and timelapse export use the same chronology.
- Copied files retain their chronological modification timestamp, and filename-keyed duration overrides are remapped to the new filenames.
- The merged album uses the first chronological source album's global frame duration. Existing explicit per-frame overrides remain explicit.
- Source records are persisted with `wasMerged = true`; this is only a cleanup tag and does not link or delete them.
- Batch album deletion stages selected folders in a hidden local directory before final removal so a move failure can restore the originals. Deleting the active album creates a fresh active album.

## 8. Not Modeled
- Cross-session aggregation or search.
- User-editable session names.
- A global frame counter shared across sessions.
