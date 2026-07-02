# Engineering Notes — TimelapseX

## Purpose
Implementation notes and handoff history for the current project snapshot.

## Current Decisions
- iOS 26.0+ only.
- SwiftUI app with a two-tab shell: Camera and Settings.
- No on-screen shutter button; capture is triggered by the hardware volume-up button, matching the Apple Camera app pattern.
- Exactly one active session exists at a time.
- Captures are stored locally first; Photos is only involved during Save and export flows.
- Lens changes automatically drop exposure, focus, and white balance locks back to continuous mode.

## Implementation Notes
- Keep capture sequencing per session, with numbering reset when a new session starts.
- Keep capture tied to volume-up press so the UI stays uncluttered.
- Keep grid overlay UI-only so it never changes the saved JPEG output.
- Save should batch all frames into the session's Photos album in one atomic pass.
- Timelapse export should reuse the saved session's existing album instead of creating a second one.

## Handoff Notes
- Check that permission text and captions stay aligned with the deferred Photos authorization flow.
- Preserve the distinction between active, saved, and discarded sessions when wiring Gallery actions.
- Keep the project docs in sync with `MVP_SCOPE.md`, `DATA_MODEL.md`, and `TASKS.md` when scope changes.
- Swift file headers should always use `Created by Prank`; do not introduce other author names in new or edited files.

## 0.0.x Implementation Notes
- Approach summary: scaffolded the camera core with a session store, local JPEG writes, append-only capture logging, and a SwiftUI tab shell that requests camera access on first launch.
- Files modified: `TimelapseX/Features/Camera/CameraCore.swift`, `TimelapseX/Features/ContentView.swift`, `TimelapseX.xcodeproj/project.pbxproj`.
- Possible breakpoints: camera startup on devices without a back camera, photo settings APIs on future SDKs, and any write failures under `Application Support/Sessions`.
- Edge cases: first-launch permission denial, no simulator camera hardware, and a pre-existing session folder with a malformed `session.json`.
- Suggested manual tests: launch on device, confirm the camera prompt appears, take one photo, verify `Sessions/{id}/IMG_000001.jpg`, `session.json`, and `capture_log.txt`, then switch tabs to confirm the tab bar remains visible in Settings.

## 0.0.0 — Architecture Realignment Refactor
- Approach summary: refactored the codebase to comply with the project's architecture principles (MVVM, file isolation, feature structure), extracting types from monolithic files `CameraCore.swift` and `ContentView.swift` into dedicated, single-responsibility files under `Data/Session/`, `AppRoot/`, and `Features/Camera/`.
- Files modified:
  - `TimelapseX/Features/ContentView.swift`
  - `TimelapseX/Features/Camera/CameraCore.swift` (deleted)
  - `TimelapseX/AppRoot/AppTab.swift`
  - `TimelapseX/Data/Session/SessionStatus.swift`
  - `TimelapseX/Data/Session/SessionRecord.swift`
  - `TimelapseX/Data/Session/CaptureLogEntry.swift`
  - `TimelapseX/Data/Session/SessionStore.swift`
  - `TimelapseX/Features/Camera/CameraViewModel.swift`
  - `TimelapseX/Features/Camera/CameraPreviewView.swift`
  - `TimelapseX/Features/Camera/CameraTabView.swift`
  - `TimelapseX/Features/Camera/VolumeButtonCaptureView.swift`
- Possible breakpoints: Missing framework imports (e.g. `Combine`, `AVFoundation`) in the newly split files. (Verified all imports are correct and compiles clean).
- Edge cases: Missing compiler references in Xcode project. (Synchronized automatically due to `PBXFileSystemSynchronizedRootGroup`).
- Suggested manual tests: Clean build and run on device/simulator. Switch between Camera and Settings tabs. Confirm volume-up hardware trigger captures frames and logs them properly to `Sessions/`.

## 0.0.0 — Tab Bar Visibility Fix
- Approach summary: Added `.toolbar(.visible, for: .tabBar)` modifier to the `List` inside the `NavigationStack` of the `settingsTab` in `ContentView.swift`. (Placing the modifier directly on the `NavigationStack` container is ignored by SwiftUI, so it was moved onto the child view to ensure the tab bar remains always visible when switching away from the auto-hiding Camera view).

## 0.1.x — Gallery and Save
- Approach summary: Added a Gallery section to the Settings tab backed by `GalleryView` + `SessionDetailView`. Introduced `PhotosSaveAction` for the Photos `.addOnly` permission request and atomic batch-add. Extended `SessionStore` with `allSessions`, `saveSession`, `discardSession`, and `rotateToNewSession`. Extracted the Settings tab body into `SettingsView` and wired `ContentView` to use it.
- Files modified/added:
  - `TimelapseX/Data/Session/SessionStore.swift` — added `allSessions`, lifecycle mutations, fixed `PersistedSession` to round-trip `photosAlbumIdentifier`.
  - `TimelapseX/Features/Gallery/GalleryView.swift` (new) — session list with lazy thumbnails.
  - `TimelapseX/Features/Gallery/SessionDetailView.swift` (new) — thumbnail grid and Save/Discard action bar.
  - `TimelapseX/Features/Gallery/PhotosSaveAction.swift` (new) — Photos permission + batch album write.
  - `TimelapseX/Features/Settings/SettingsView.swift` (new) — Settings tab extracted from ContentView.
  - `TimelapseX/Features/ContentView.swift` — swapped inline `settingsTab` for `SettingsView`.
- Possible breakpoints: `NSPhotoLibraryAddUsageDescription` must be present in the Xcode target's Info tab for the Photos permission sheet to appear; the app will crash at runtime without it. The `performChanges` album-add relies on fetching the collection by its placeholder identifier in the same change block — if Photos defers index updates, the asset add may silently no-op; smoke-test on device.
- Edge cases: Session folder deleted between `allSessions` load and `SessionDetailView` open (handled by empty-state guard). Discard of the active session immediately rotates to a new one — confirm a fresh active session appears after navigating back.
- Suggested manual tests: Build and run. Capture frames. Open Settings → Gallery row, verify thumbnail and frame count. Tap the row, verify thumbnail grid. Tap Save, confirm Photos permission sheet appears, confirm album exists in Photos, confirm "Saved" badge appears. Navigate back and confirm a new active session is shown. Capture again, open detail, Discard, confirm alert, confirm session disappears and a new active session starts. Verify tab bar is always visible throughout all navigation.

## 0.2.x — Settings
- Approach summary: Created `CameraSettingsStore` implementing enums, synchronization with `UserDefaults`, and permissions/foreground listeners. Observed settings changes in `CameraViewModel` to live-configure input device changes and lock modes dynamically. Added custom `GridOverlayView` rendering rule of thirds or center cross grid lines and integrated it into the camera preview. Expanded `SettingsView` with controls, captions, and links.
- Files modified/added:
  - `TimelapseX/Data/Settings/CameraSettingsStore.swift` (new) — settings store managing user preferences and permissions.
  - `TimelapseX/Features/Camera/GridOverlayView.swift` (new) — overlay view showing thirds grid or crosshairs.
  - `TimelapseX/Features/Camera/CameraViewModel.swift` — observed settings store and applied device setup/locks.
  - `TimelapseX/Features/Camera/CameraTabView.swift` — overlayed GridOverlayView on preview.
  - `TimelapseX/Features/Settings/SettingsView.swift` — controls, segmented selectors, and toggles with captions.
- Possible breakpoints: Live swap of device input can fail if hardware is restricted or unavailable (safe-guarded in `bestCameraDevice`).
- Edge cases: Changing lens override drops both locks dynamically in store and reflects in the UI (verified lock flags set to false).
- Suggested manual tests: Toggle Lens Override, verify changes live without restarting. Toggle Grid Overlay, verify grid lines appear on preview screen. Test locking/unlocking Focus & Exposure and White Balance lock. Open denied permission rows to verify they deep link to the System Settings app.
