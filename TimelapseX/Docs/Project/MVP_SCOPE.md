# MVP Scope — TimelapseX

## Purpose
Define the first shippable slice of the app and make the non-goals explicit.

## Scope
- iOS 26.0+ only, with no back-compat branching.
- A Camera tab that captures one photo per shutter press with minimal latency.
- A Settings tab that exposes permissions, camera controls, and the Gallery section.
- Session-based local storage with one active session at a time.
- Gallery review with Save and Discard actions.
- Timelapse export from a saved session.

## Goals
- Keep the capture path simple and predictable during long print runs.
- Make the session lifecycle obvious: capture locally, then save or discard.
- Keep preview aids and live camera settings separate from saved output.
- Avoid unnecessary Photos prompts until the user explicitly saves a session.

## Non-Goals
- Burst, continuous, or video-mode capture.
- Bluetooth pairing or remote management code.
- Session renaming, searching, or cross-session aggregation.
- Background capture support.
- Timelapse editing features beyond FPS selection.
- Trimming, music, overlays, or "hold last frame" export options.
- Extra export quality or resolution settings.
