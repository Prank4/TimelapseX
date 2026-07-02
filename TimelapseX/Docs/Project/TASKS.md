# Tasks — TimelapseX

## Overview
Versioned roadmap for the first release train. Patch versions are reserved for bug fixes only.

See `MVP_SCOPE.md`, `DATA_MODEL.md`, and `ENGINEERING_NOTES.md` for the decisions behind each item.

## 0.0.x — Camera Core
- [ ] Camera session: widest available lens, max photo dimensions, `.quality` prioritization, flash off, continuous AF/AE/AWB.
- [ ] Full-screen preview with portrait locked.
- [ ] Shutter trigger on `.began`, with an `isCapturing` guard for single-shot behavior.
- [ ] `Session` model: auto-create an active session on launch; per-session folder and sequence counter in `session.json`.
- [ ] Save each capture locally only in `Sessions/{id}/IMG_xxxxxx.jpg`.
- [ ] Per-session capture log in `capture_log.txt`.
- [ ] `isIdleTimerDisabled = true` while the camera session is active.
- [ ] Camera permission prompt on first launch; Photos permission is deferred to 0.1.x.
- [ ] Bottom tab bar shell for Camera and Settings, auto-hide on Camera and stay visible on Settings.

## 0.1.x — Gallery and Save
- [ ] Gallery section inside Settings: list sessions with thumbnail, frame count, and date.
- [ ] Session detail view: thumbnail grid for that session's frames.
- [ ] Save action: create a Photos album named from the session timestamp, batch-add all frames in one `performChanges` call, request `.addOnly` permission at this point, mark the session `.saved`, and store the album identifier.
- [ ] Discard action with confirmation: delete the session folder entirely, with no Photos interaction.
- [ ] Auto-create a new active session immediately after Save or Discard.

## 0.2.x — Settings
- [ ] Permissions status rows for Camera and Photos, read-only and linking out to Settings if denied.
- [ ] Lens override segmented control: Auto, Wide, Ultra-Wide; live-applies without restart.
- [ ] Quality mode toggle: Best Quality or Fastest Capture; live-applies without restart.
- [ ] Grid overlay segmented control: Off, Rule of Thirds, Center Cross; preview-only.
- [ ] Exposure and Focus Lock toggle, live-locking and unlocking device exposure and focus.
- [ ] White Balance Lock toggle, live-locking and unlocking device white balance.
- [ ] Lens-change interaction: auto-drop both locks to continuous when lens override changes, and reflect that in the UI.
- [ ] One-line caption under each non-obvious toggle.

## 0.3.x — Timelapse Export
- [ ] "Create Timelapse" action from a saved session's detail view.
- [ ] FPS selector segmented control: 12, 24, 30, or 60, defaulting to 24.
- [ ] `AVAssetWriter` pipeline that assembles session frames into `timelapse.mp4` at native resolution.
- [ ] Add the resulting video into the session's existing Photos album, not a new album.
- [ ] If the session is not yet saved, prompt to save first instead of allowing export.

## Validation
Run after 0.0.x and again after 0.3.x.

- [ ] Real Bluetooth remote and real printer trigger: confirm latency and single-shot behavior.
- [ ] Multi-hour soak test: verify per-session numbering, no memory growth, and idle timer behavior.
- [ ] Frame count on disk equals log success count and expected shutter presses for a full session.
- [ ] Save flow: confirm the album contains exactly the session's frames, with no partial or duplicate uploads after a forced-quit retry.
- [ ] Timelapse export: spot-check frame ordering and FPS timing against the source session.
