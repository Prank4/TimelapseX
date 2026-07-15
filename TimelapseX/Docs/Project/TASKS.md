# Tasks — TimelapseX

## Overview
Versioned roadmap for the first release train. Patch versions are reserved for bug fixes only.

See `MVP_SCOPE.md`, `DATA_MODEL.md`, and `ENGINEERING_NOTES.md` for the decisions behind each item.

## 0.0.x — Camera Core
- [ ] Camera session: widest available lens, max photo dimensions, `.quality` prioritization, flash off, continuous AF/AE/AWB.
- [ ] Full-screen preview with portrait locked.
- [ ] Capture on volume-button press, with an `isCapturing` guard for single-shot behavior.
- [ ] No on-screen shutter button; follow the Apple Camera app hardware-button capture pattern.
- [ ] `Session` model: auto-create an active session on launch; per-session folder and sequence counter in `session.json`.
- [ ] Save each capture locally only in `Sessions/{id}/IMG_xxxxxx.jpg`.
- [ ] Per-session capture log in `capture_log.txt`.
- [ ] `isIdleTimerDisabled = true` while the camera session is active.
- [ ] Camera permission prompt on first launch; Photos permission is deferred to 0.1.x.
- [ ] Bottom tab bar shell for Camera and Settings, auto-hide on Camera and stay visible on Settings.

## 0.1.x — Gallery and Save
- [x] Gallery section inside Settings: list sessions with thumbnail, frame count, and date.
- [x] Session detail view: thumbnail grid for that session's frames.
- [x] Save action: create a Photos album named from the session timestamp, batch-add all frames in one `performChanges` call, request `.addOnly` permission at this point, mark the session `.saved`, and store the album identifier.
- [x] Discard action with confirmation: delete the session folder entirely, with no Photos interaction.
- [x] Auto-create a new active session immediately after Save or Discard.

## 0.2.x — Settings
- [x] Permissions status rows for Camera and Photos, read-only and linking out to Settings if denied.
- [x] Lens override segmented control: Auto, Wide, Ultra-Wide; live-applies without restart.
- [x] Quality mode toggle: Best Quality or Fastest Capture; live-applies without restart.
- [x] Grid overlay segmented control: Off, Rule of Thirds, Center Cross; preview-only.
- [x] Exposure and Focus Lock toggle, live-locking and unlocking device exposure and focus.
- [x] White Balance Lock toggle, live-locking and unlocking device white balance.
- [x] Lens-change interaction: auto-drop both locks to continuous when lens override changes, and reflect that in the UI.
- [x] One-line caption under each non-obvious toggle.

## 0.3.x — Timelapse Export
- [x] "Create Timelapse" action from a saved session's detail view.
- [x] FPS selector segmented control: 12, 24, 30, or 60, defaulting to 24.
- [x] `AVAssetWriter` pipeline that assembles session frames into a Photos-compatible `timelapse.mp4`.
- [x] Add the resulting video into the session's existing Photos album, not a new album.
- [x] If the session is not yet saved, prompt to save first instead of allowing export.

## 0.4.x — Gallery Delete, Timelapse Settings, and Capture Hotfix
- [x] Gallery session delete from the session detail view, with confirmation.
- [x] More timelapse settings beyond FPS.
- [x] Volume-down button also captures images.
- [x] Capture should fire again immediately after button release, with no re-trigger delay between presses.

## Hotfixes
- [ ] Fix Save to Photos so saved sessions reliably appear in Photos again.
- [x] Rotate a populated active session after five minutes without a successful capture.
- [x] Add a live camera level indicator.
- [x] Support selecting and deleting multiple gallery photos together.
- [x] Move Gallery from Settings into its own tab.
- [x] Prevent Gallery memory crashes by downsampling and bounding concurrent image decoding.
- [x] Move the full-screen undo banner above the delete control.
- [x] Show sequence numbers on Gallery thumbnails.
- [x] Support pinch-controlled Gallery density from two through eight images per row.

## Validation
Run after 0.0.x and again after 0.4.x.

- [ ] Real Bluetooth remote and real printer trigger: confirm latency and single-shot behavior.
- [ ] Volume-button capture trigger: confirm the app captures on press and does not require a shutter button.
- [ ] Multi-hour soak test: verify per-session numbering, no memory growth, and idle timer behavior.
- [ ] Frame count on disk equals log success count and expected shutter presses for a full session.
- [ ] Save flow: confirm the album contains exactly the session's frames, with no partial or duplicate uploads after a forced-quit retry.
- [ ] Timelapse export: spot-check frame ordering and FPS timing against the source session.
