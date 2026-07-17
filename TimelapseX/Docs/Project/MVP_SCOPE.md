# MVP Scope — TimelapseX

## Purpose
Define the first shippable slice of the app and make the non-goals explicit.

## Scope
- iOS 26.0+ only, with no back-compat branching.
- A Camera tab that captures one photo per hardware volume-button press with minimal latency.
- No on-screen shutter button; capture follows the Apple Camera app pattern.
- A dedicated Gallery tab for session browsing and a Settings tab for permissions and camera controls.
- Session-based local storage with one active session at a time.
- Gallery review with Save and Discard actions, multi-select photo deletion, numbered thumbnails, and a persistent pinch-adjustable grid density.
- A live camera level indicator and configurable automatic session rotation after 5–60 capture-idle minutes.
- Timelapse export from a saved session.
- Timelapse export controls for FPS, resolution, and output quality.
- Per-frame duration overrides with global fallback, reflected in duration estimates and export timing.

## Goals
- Keep the capture path simple and predictable during long print runs.
- Keep capture tied to the hardware volume buttons so the UI stays uncluttered.
- Make the session lifecycle obvious: capture locally, then save or discard.
- Keep preview aids and live camera settings separate from saved output.
- Avoid unnecessary Photos prompts until the user explicitly saves a session.

## Non-Goals
- Burst, continuous, or video-mode capture.
- Bluetooth pairing or remote management code.
- Session renaming, searching, or cross-session aggregation.
- Background capture support.
- Timelapse timeline editing features.
- Trimming, music, overlays, or "hold last frame" export options.
