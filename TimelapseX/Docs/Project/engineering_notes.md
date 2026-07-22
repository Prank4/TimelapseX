# Engineering Notes — TimelapseX

## Purpose
Implementation notes and handoff history for the current project snapshot.

## Current Decisions
- iOS 26.0+ only.
- SwiftUI app with a three-tab shell: Camera, Gallery, and Settings.
- No on-screen shutter button; capture is triggered by the hardware volume buttons, matching the Apple Camera app pattern.
- Exactly one active session exists at a time.
- Captures are stored locally first; Photos is only involved during Save and export flows.
- Lens changes automatically drop exposure, focus, and white balance locks back to continuous mode.

## Implementation Notes
- Keep capture sequencing per session, with numbering reset when a new session starts.
- Keep capture tied to volume-button presses so the UI stays uncluttered.
- Keep grid overlay UI-only so it never changes the saved JPEG output.
- Save should batch all frames into the session's Photos album in one atomic pass.
- Timelapse export should reuse the saved session's existing album instead of creating a second one.

## Handoff Notes
- Check that permission text and captions stay aligned with the deferred Photos authorization flow.
- Preserve the distinction between active, saved, and discarded sessions when wiring Gallery actions.
- Keep the project docs in sync with `MVP_SCOPE.md`, `DATA_MODEL.md`, and `TASKS.md` when scope changes.
- Swift file headers should always use `Created by Prank`; do not introduce other author names in new or edited files.

## 0.4.1 — Camera and Gallery Hotfix
- Approach summary: Added a persisted successful-capture timestamp and a tested five-minute rotation policy, with deadline scheduling in the camera view model and a legacy frame-date fallback. Added a Core Motion camera level overlay, promoted Gallery to its own tab, and added confirmed multi-select frame deletion with storage validation before removal.
- Files modified/added:
  - `Package.swift` and `TimelapseXTests/SessionRotationPolicyTests.swift` — isolated Swift Testing regression coverage for the inactivity boundary.
  - `TimelapseX/Data/Session/SessionRotationPolicy.swift`, `SessionRecord.swift`, and `SessionStore.swift` — inactivity policy, timestamp persistence, legacy fallback, rotation API, and validated batch deletion.
  - `TimelapseX/Features/Camera/CameraViewModel.swift`, `CameraLevelView.swift`, and `CameraTabView.swift` — deadline scheduling and live level presentation.
  - `TimelapseX/AppRoot/AppTab.swift`, `Features/ContentView.swift`, `Features/Gallery/GalleryView.swift`, and `Features/Settings/SettingsView.swift` — dedicated Gallery tab.
  - `TimelapseX/Features/Gallery/SessionDetailView.swift` — multi-select UI, confirmation, and batch delete action.
  - `TimelapseX/Docs/Project/TASKS.md`, `DATA_MODEL.md`, and `MVP_SCOPE.md` — source-of-truth updates.
- Possible breakpoints: Core Motion values require a real device; simulator builds cannot verify physical level accuracy. Long-running main-queue timers may be delayed while iOS suspends the app, but overdue rotation is rechecked on resume/relaunch and before capture.
- Edge cases: Empty sessions do not auto-rotate; legacy populated sessions use the newest JPEG modification date; an in-flight capture delays deadline handling; selected URLs are all validated as session-owned JPGs before batch removal; deleting frames invalidates an existing timelapse export.
- Suggested manual tests: Capture one frame and wait five minutes to confirm a closed session and fresh active session appear; relaunch just before/after the deadline; capture continuously to confirm the deadline keeps extending; rotate a real device to confirm the level turns yellow within one degree; select several Gallery frames, cancel once, then confirm batch deletion and verify the remaining count and exported-video invalidation.

## 0.4.2 — Gallery Stability and Density Hotfix
- Approach summary: Replaced gallery-time full-resolution JPEG decoding with a serialized ImageIO downsampler, bounded the full-screen pager to the current and adjacent frames, discarded off-screen thumbnail state, moved the pager undo banner clear of the delete button, added per-thumbnail sequence badges, and added a persistent two-to-eight-column pinch gesture.
- Files modified/added:
  - `Package.swift`, `TimelapseXTests/GalleryImageLoaderTests.swift`, and `TimelapseXTests/GalleryGridLayoutPolicyTests.swift` — regression coverage for decoded pixel bounds, invalid files, non-upscaling, pinch direction, and grid limits.
  - `TimelapseX/Features/Gallery/GalleryImageLoader.swift` — serialized, cancellation-aware ImageIO thumbnail decoding without a second in-memory cache.
  - `TimelapseX/Features/Gallery/GalleryGridLayoutPolicy.swift` — tested two-to-eight-column pinch mapping.
  - `TimelapseX/Features/Gallery/GalleryView.swift` — downsampled session thumbnails and first-existing-frame fallback.
  - `TimelapseX/Features/Gallery/SessionDetailView.swift` — downsampled grid/pager images, bounded pager residency, thumbnail numbering, pinch density, and undo-banner placement.
  - `TimelapseX/Docs/Project/TASKS.md` and `MVP_SCOPE.md` — source-of-truth updates.
- Possible breakpoints: A 3,072-pixel full-screen preview is display-oriented and intentionally does not expose every source pixel; exporting and saving continue to use original JPEGs. ImageIO decoding remains synchronous within its actor, so a damaged or unusually slow file can delay later gallery loads without blocking the main thread.
- Edge cases: Canceled off-screen requests are skipped before decode; invalid images remain placeholders; small images are never upscaled; deleted first frames no longer leave a blank session thumbnail; pinch density is clamped and persisted from two through eight columns.
- Suggested manual tests: Rapidly scroll a long session from beginning to end several times while watching memory in Instruments, rapidly swipe forward and backward in full-screen mode, delete and undo to confirm the banner sits above the trash button, verify thumbnail numbers stay aligned after deletion, and pinch in/out to confirm two-through-eight-column layouts persist after reopening the session.
- Follow-up layout fix: Gallery tiles now enforce square bounds before clipping, use matching eight-point row/column spacing, and draw a one-point system separator around all four sides. Verify at every pinch density that loaded images remain inside their own cells and every neighboring pair has a visible gap/divider.
- Gallery edge alignment: Removed the grid's outer leading and trailing inset while preserving the internal eight-point spacing and tile borders.
- Timelapse duration preview: Timing settings now show a live estimated output duration calculated from the current on-disk frame count and clamped time-per-image value. Verify the estimate updates while typing and sliding, including sub-second, minute, and hour formats.
- Photos import and timing range: Gallery session menus now use the system Photos picker to normalize one selected image to JPEG and place it at index 1 without overwriting earlier imports. Timing removed free-form input and now uses a 0.01–0.10 second slider in 0.01-second steps; existing out-of-range stored values clamp on load. Verify repeated imports remain before captured frames, the newest is first, exported video invalidates, and the live duration estimate updates at every slider step.

## 0.4.3 — Per-Frame Timelapse Duration Overrides
- Approach summary: Added filename-keyed duration overrides persisted in `session.json`, a tested timing policy for global fallback and cumulative presentation times, full-screen frame duration controls, grid override badges, reset-to-global behavior, override-aware estimates, and exporter session timing that ends at the calculated total duration.
- Files modified/added:
  - `TimelapseX/Data/Session/FrameDurationPolicy.swift` and `TimelapseXTests/FrameDurationPolicyTests.swift` — pure timing rules and regression coverage for fallback, override, reset, 0.5–5.0-second clamping/steps, totals, and presentation timestamps.
  - `TimelapseX/Data/Session/SessionRecord.swift` and `SessionStore.swift` — backward-compatible override persistence, update API, deletion cleanup, undo support path, and imported-frame rename preservation.
  - `TimelapseX/Features/Gallery/SessionDetailView.swift` — clock badges, full-screen per-frame slider/reset UI, override count, and override-aware estimated duration.
  - `TimelapseX/Features/Gallery/TimelapseExporter.swift` — cumulative per-frame presentation times and an explicit export end time.
  - `Package.swift` and project documentation — test target and source-of-truth updates.
- Possible breakpoints: AVAssetWriter duration should be verified on a real device/player because per-frame H.264 sample presentation can be rendered differently by third-party players; the writer now explicitly ends its session at the calculated total to preserve the last frame's hold duration.
- Edge cases: Legacy sessions decode with no overrides; reset removes the filename key; deleted-frame undo restores its override; batch deletion removes overrides; repeated lead-photo imports move an existing override with the archived frame; stale override keys are ignored by estimates because only current frame filenames are summed.
- Suggested manual tests: Give the first/middle/last frames different durations, verify clock badges and override count, reset one to global, relaunch and verify persistence, compare the displayed estimate to the sum, export and inspect frame transitions and final duration, delete/undo an overridden frame, and import a new lead frame over an overridden imported frame.

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
- Suggested manual tests: Clean build and run on device/simulator. Switch between Camera and Settings tabs. Confirm volume-button hardware trigger captures frames and logs them properly to `Sessions/`.

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

## 0.3.x — Timelapse Export
- Approach summary: Created `TimelapseExporter` utilizing the `AVAssetWriter` and `AVAssetWriterInputPixelBufferAdaptor` video processing pipeline to convert session JPEGs to Photos-compatible H.264 `timelapse.mp4` files. Timelapse creation now works directly from the app session frames; saving original photos or the exported video to Photos is a separate manual action.
- Files modified/added:
  - `TimelapseX/Features/Gallery/TimelapseExporter.swift` (new) — background thread video compiler and Photos album injector.
  - `TimelapseX/Features/Gallery/SessionDetailView.swift` — added timing controls, linear progress feedback, manual Photos save actions, and export/save result alerts.
- Possible breakpoints: Conversion of large source photos into pixel buffers can consume significant transient memory, so the default export is bounded to a 4K video frame and work runs in `Task.detached`.
- Edge cases: Empty sessions or missing file URLs (guarded and exits with friendly error description).
- Suggested manual tests: Open an active session with frames, click "Create Timelapse", verify export completes without saving original photos first, then manually save the video to Photos. Verify progress feedback works and Photos receives the H.264 video.

## 0.0.0 — Concurrency & Photos Save Crash Fix
- Approach summary: Resolved Photos save crash and video export 3302 error on iOS 27 beta.
  1. Stripped custom album creation logic entirely. Now saves all captured frames directly to the user's primary Camera Roll (All Photos) using a synchronous `performChangesAndWait` loop inside a detached task (`Task.detached`), avoiding main actor deadlock completely.
  2. Bypassed PhotoKit `.video` resource import for the exported video to resolve the persistent `invalidResource` error 3302. `TimelapseExporter` now compiles the timelapse video to the session's local folder (`session.folderURL/timelapse.mp4`), and manual video saving uses the system Camera Roll video saver after a compatibility check.
  3. Integrated a native SwiftUI `ShareLink` inside `SessionDetailView`'s export section which appears once the video file is present on disk.
  4. Resolved sandbox share restrictions where the system share sheet (`sharingd` daemon) lacks access to private app folders (like `Library/Application Support`). We copy the video file to the system temporary directory (`NSTemporaryDirectory()`) right before sharing, allowing the user to successfully save it to Photos or Files.
  5. Fixed all remaining Swift Concurrency warnings by marking computed properties in `SessionRecord` and `SessionStore`, and stateless utility methods in `TimelapseExporter`, as `nonisolated`.
- Files modified:
  - `TimelapseX/Features/Gallery/PhotosSaveAction.swift`
  - `TimelapseX/Features/Gallery/TimelapseExporter.swift`
  - `TimelapseX/Features/Gallery/SessionDetailView.swift`
  - `TimelapseX/Data/Session/SessionRecord.swift`
  - `TimelapseX/Data/Session/SessionStore.swift`
- Possible breakpoints: None. All Swift Concurrency compiler warnings are now resolved.
- Edge cases: Real device sandbox permissions under iOS 27 beta debugger attach.
- Suggested manual tests: Build and run. Capture frames, open Gallery, click "Save to Photos". Export timelapse, verify "Success" alert, verify "Share Timelapse" button appears, click it and select "Save Video", then verify the video is successfully saved to your Photos library.

## 0.4.x — Gallery Delete, Timelapse Settings, and Capture Hotfix
- Approach summary: Added a confirmed session delete action directly in `SessionDetailView`, expanded timelapse export with resolution and quality settings, and updated volume-button capture so both volume-up and volume-down trigger with a shorter reset window between presses.
- Files modified:
  - `TimelapseX/Features/Gallery/SessionDetailView.swift`
  - `TimelapseX/Features/Gallery/TimelapseExporter.swift`
  - `TimelapseX/Features/Camera/VolumeButtonCaptureView.swift`
  - `TimelapseX/Features/Camera/CameraTabView.swift`
  - `TimelapseX/Docs/Project/TASKS.md`
  - `TimelapseX/Docs/Project/DATA_MODEL.md`
  - `TimelapseX/Docs/Project/MVP_SCOPE.md`
- Possible breakpoints: Volume-button interception still depends on the hidden `MPVolumeView` and real device audio-session behavior, so simulator validation is limited.
- Edge cases: Deleting the active session rotates immediately to a fresh session via `SessionStore.discardSession`; export resolution never upscales beyond the source image size.
- Suggested manual tests: Capture with volume-up and volume-down on device, rapidly press/release both buttons, delete active and saved sessions from detail, export the same session at Native/1080p/720p and High/Standard/Compact quality, then verify the resulting `timelapse.mp4` dimensions and share/save flow.

## 0.4.3 — Photos Import Presentation Hotfix
- Approach summary: Replaced the `PhotosPicker` embedded directly in the session actions `Menu` with a normal menu button that triggers screen-level `.photosPicker` presentation. The menu/picker presentation collision could dismiss the menu without ever presenting Photos, leaving the import callback with no selection.
- Files modified:
  - `TimelapseX/Features/Gallery/SessionDetailView.swift`
  - `TimelapseX/Docs/Shared/RULES.md`
  - `TimelapseX/Docs/Project/engineering_notes.md`
- Possible breakpoints: The picker still depends on PhotosUI being available and the selected asset being transferable as image data.
- Edge cases: Cancelling the picker leaves the session unchanged; repeated imports preserve the previous first frame under a unique filename.
- Suggested manual tests: Open a gallery session, choose **Import Photo as First Frame**, select an image, confirm the success alert and new frame 1, then repeat and confirm both imported images remain in the session.

## 0.4.4 — Configurable Automatic Session Rotation
- Approach summary: Added persisted Settings controls for automatic inactivity rotation, with a default-on toggle and a 5–60 minute slider in five-minute steps. Rotation bounds, clamping, disabled behavior, and minute conversion live in `SessionRotationPolicy`; `CameraViewModel` immediately cancels and reschedules its deadline whenever either setting changes.
- Files modified:
  - `TimelapseX/Data/Session/SessionRotationPolicy.swift`, `SessionStore.swift`, and `TimelapseXTests/SessionRotationPolicyTests.swift` — tested policy and enabled/interval lifecycle parameters.
  - `TimelapseX/Data/Settings/CameraSettingsStore.swift` — persisted toggle and inactivity duration.
  - `TimelapseX/Features/Settings/SettingsView.swift` — toggle, explanatory caption, and stepped slider.
  - `TimelapseX/Features/Camera/CameraViewModel.swift` — live rescheduling and duration-aware status messages.
  - Project documentation — configurable behavior and learned slider-policy rule.
- Possible breakpoints: Deadline execution still depends on the app process running; background suspension can delay the work item until the app resumes.
- Edge cases: Disabling cancels a pending deadline; enabling after the selected duration has already elapsed rotates immediately; empty sessions never rotate; legacy populated sessions continue using the newest frame modification date when no capture timestamp exists.
- Suggested manual tests: Capture one frame, switch the toggle off past the selected deadline and confirm no rotation, turn it on and confirm immediate rotation, then test 5- and 10-minute selections and verify a new capture restarts the countdown.

## 0.5.0 — Album Terminology, Merge, and Multi-Delete
- Approach summary: Changed all user-facing Session language to Album without renaming the backward-compatible storage schema. Gallery selection can now create a new closed album by copying selected source frames in modification-date order, assigning sequential filenames, remapping explicit duration overrides, and marking every original with a Merged badge. The same selection mode supports confirmed batch deletion.
- Files modified/added:
  - `TimelapseX/Data/Session/AlbumMergePolicy.swift` and `TimelapseXTests/AlbumMergePolicyTests.swift` — deterministic chronological ordering, tie breakers, and sequential output names.
  - `SessionRecord.swift` and `SessionStore.swift` — backward-compatible `wasMerged` persistence, copy/rollback merge transaction, timestamp preservation, override remapping, and staged multi-album deletion.
  - `GalleryView.swift` — album multi-select, Merge/Delete action bar, confirmations, results, and Merged source badge.
  - `SettingsView.swift`, `CameraViewModel.swift`, `CameraTabView.swift`, `SessionDetailView.swift`, and `PhotosSaveAction.swift` — app-facing Album terminology.
  - `Package.swift` and project documentation — policy test wiring and source-of-truth updates.
- Possible breakpoints: File modification dates are the durable chronology available for legacy and imported frames; external file restoration that rewrites these dates can alter merge order. Very large merges temporarily require enough free storage for a complete copy because originals are intentionally retained.
- Edge cases: Equal timestamps sort by source album ID and filename; repeated merges are allowed and keep the Merged tag; active source albums remain active; deleting an active selected album creates a replacement; empty selections and fewer than two merge sources are rejected; an all-empty merge is rejected.
- Suggested manual tests: Create interleaved photos across three albums, merge them, confirm source badges and source preservation, compare merged ordering to capture times, verify duration override badges, export the merged album, merge an already-merged source again, batch-delete tagged originals, and batch-delete a selection containing the active album.

## 0.5.1 — Camera Latest-Photo Thumbnail
- Approach summary: Added a persistent 60-point thumbnail at the bottom-left of the camera overlay. A successful capture publishes its saved frame URL immediately; reopening Camera performs a cancellable background scan across local albums and selects the newest frame by modification date. The existing bounded gallery decoder supplies the small preview without loading full-resolution JPEGs.
- Files modified:
  - `TimelapseX/Features/Camera/CameraViewModel.swift` — latest-frame URL state, background restoration, scan/capture race cancellation, and immediate successful-capture updates.
  - `TimelapseX/Features/Camera/CameraTabView.swift` — bottom-left thumbnail with placeholder, border, accessibility label, and bounded image loading.
  - `TimelapseX/Data/Session/AlbumMergePolicy.swift` and `TimelapseXTests/AlbumMergePolicyTests.swift` — tested newest-frame selection.
  - Project documentation — scope, task, and detached optional-result rule.
- Possible breakpoints: Legacy or externally restored files with rewritten modification dates can change which image is selected after relaunch; successful in-app captures update directly and do not depend on the scan.
- Edge cases: With no photos, the thumbnail remains as a placeholder; automatic album rotation does not clear the previous thumbnail; a slow restoration scan is cancelled before a newer capture publishes; deleted or invalid images remain placeholders through the bounded loader.
- Suggested manual tests: Launch with no albums, capture one photo, capture several more quickly, switch to Gallery and back, force-quit and relaunch, trigger automatic album rotation, and verify the bottom-left thumbnail always shows the latest available image without covering the capture hint.

## 0.5.2 — Capture-Accurate Camera Framing
- Approach summary: Changed `AVCaptureVideoPreviewLayer.videoGravity` from `.resizeAspectFill` to `.resizeAspect` during both preview creation and updates. The old fill mode cropped the live feed to the tall screen, making it appear zoomed compared with the full-sensor JPEG; aspect-fit displays the complete captured field of view. Preview orientation now uses the supported 90-degree `videoRotationAngle` API instead of deprecated `videoOrientation`.
- Files modified: `TimelapseX/Features/Camera/CameraPreviewView.swift`, project tasks, engineering notes, and the shared learned rule.
- Possible breakpoints: Black letterboxing is expected when the photo sensor and device screen have different aspect ratios. Filling those bars would necessarily crop the preview or require cropping the saved photo.
- Edge cases: Lens switching reapplies aspect-fit in `updateUIView`; portrait orientation remains unchanged; grid and level overlays remain UI-only.
- Suggested manual tests: Place distinct objects near all four preview edges, capture with Auto/Wide/Ultra-Wide where available, and compare the saved image in full-screen Gallery. Every saved edge should have been visible in the preview, allowing only tiny stabilization or device-format tolerances.

## 0.5.3 — Configurable Photo Preview and Capture-Aligned Zoom
- Approach summary: Added default-on persisted latest-photo preview settings with a 30–300 second slider in 30-second steps. Camera previews now time out, restart after every successful capture, render up to 120 points while preserving image aspect ratio, and remain memory-bounded. Added pinch zoom backed by `AVCaptureDevice.videoZoomFactor`, with tested device/app clamping and an on-screen factor badge; physical lens changes reset zoom to 1×.
- Files modified/added:
  - `TimelapseX/Data/Settings/CameraControlPolicy.swift` and `TimelapseXTests/CameraControlPolicyTests.swift` — preview-duration and zoom bounds, stepping, and pinch math.
  - `CameraSettingsStore.swift` and `SettingsView.swift` — persisted preview toggle/duration and Settings UI.
  - `CameraViewModel.swift` — preview visibility timer and direct active-device zoom application.
  - `CameraTabView.swift` — aspect-preserving doubled thumbnail, pinch gesture, and zoom badge.
  - `Package.swift` and project documentation — test target wiring and source-of-truth updates.
- Possible breakpoints: Real camera zoom is unavailable in Simulator. Some devices expose large digital zoom ranges; the app deliberately caps interaction at 10×. Landscape source thumbnails can require more horizontal space, so the capture hint may compress on narrow devices.
- Edge cases: Disabling preview cancels its timer immediately; changing duration restarts a visible preview; no-photo restoration remains hidden; rapid captures cancel prior timers; zoom is clamped to both device and app limits; switching Auto/Wide/Ultra-Wide resets zoom and republishes the new range.
- Suggested manual tests: Toggle preview off/on, test 30-second and 5-minute endpoints, capture portrait and landscape images and verify thumbnail shape/size, rapidly capture several frames and confirm timer reset, pinch on each lens, capture at 1×/2×/maximum, and compare preview edges against saved photos.
