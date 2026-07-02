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

