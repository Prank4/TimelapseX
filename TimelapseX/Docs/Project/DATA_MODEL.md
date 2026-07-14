# Data Model — TimelapseX

## Purpose
Document the persisted project state, derived values, and storage layout.

## 1. `Session`
Everything is scoped to a session. Exactly one session is active at a time. A new session is created automatically on cold app launch and again immediately after the previous session is finalized.

| Field | Type | Notes |
|---|---|---|
| `id` | `String` | Timestamp-based identifier, e.g. `2026-07-02_14-30-05`. Also used for the session folder name. |
| `createdAt` | `Date` | Session creation date and time. |
| `status` | enum `.active` / `.saved` / `.discarded` | Only one session may be `.active` at once. |
| `folderURL` | `URL` | `Application Support/Sessions/{id}/`. |
| `nextSequence` | `Int` | Per-session frame counter, starting at `1` and stored in `session.json`. |
| `frameCount` | `Int` | Derived from the number of frame files in the folder. |
| `photosAlbumIdentifier` | `String?` | `PHAssetCollection.localIdentifier`, set after a successful Save. |

`session.json` stores `{ "id", "createdAt", "status", "nextSequence" }`.

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
| `cameraPermissionStatus` | computed | — | Read live from `AVCaptureDevice.authorizationStatus(for: .video)`. |
| `photosPermissionStatus` | computed | — | Read live from `PHPhotoLibrary.authorizationStatus(for: .addOnly)`. |

## 6. `TimelapseExportRequest`
In-memory per export operation.

| Field | Type | Notes |
|---|---|---|
| `sessionId` | `String` | The session whose frames will be compiled. |
| `fps` | `Int` | Segmented control choice: 12, 24, 30, or 60. |
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

## 8. Not Modeled
- Cross-session aggregation or search.
- User-editable session names.
- A global frame counter shared across sessions.
