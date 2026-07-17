//
//  SettingsView.swift
//  TimelapseX
//
//  Created by Prank on 02/07/26.
//

import AVFoundation
import Photos
import SwiftUI

struct SettingsView: View {
    @ObservedObject var store: SessionStore
    @ObservedObject private var settingsStore = CameraSettingsStore.shared
    @State private var sessionActionError: String?

    var body: some View {
        NavigationStack {
            List {
                Section("Permissions") {
                    permissionRow(
                        title: "Camera",
                        status: cameraPermissionText,
                        isDenied: settingsStore.cameraPermissionStatus == .denied
                    )
                    permissionRow(
                        title: "Photos",
                        status: photosPermissionText,
                        isDenied: settingsStore.photosPermissionStatus == .denied
                    )
                }

                Section("Lens & Grid") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Lens Override")
                            .font(.subheadline)
                        Picker("Lens Override", selection: $settingsStore.lensOverride) {
                            Text("Auto").tag(LensOverride.auto)
                            Text("Wide").tag(LensOverride.wide)
                            if settingsStore.isUltraWideSupported {
                                Text("Ultra-Wide").tag(LensOverride.ultraWide)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                    .padding(.vertical, 4)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Grid Overlay")
                            .font(.subheadline)
                        Picker("Grid Overlay", selection: $settingsStore.gridOverlay) {
                            Text("Off").tag(GridOverlay.off)
                            Text("Thirds").tag(GridOverlay.ruleOfThirds)
                            Text("Cross").tag(GridOverlay.centerCross)
                        }
                        .pickerStyle(.segmented)
                    }
                    .padding(.vertical, 4)
                }

                Section("Capture Options") {
                    VStack(alignment: .leading, spacing: 8) {
                        Toggle("Timed Capture", isOn: $settingsStore.intervalCaptureEnabled)
                        Text("After the next manual frame, the camera will keep capturing every \(formattedInterval(settingsStore.intervalCaptureSeconds)).")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Slider(
                            value: $settingsStore.intervalCaptureSeconds,
                            in: CameraSettingsStore.minimumIntervalCaptureSeconds...CameraSettingsStore.maximumIntervalCaptureSeconds,
                            step: 0.01
                        )
                        .disabled(!settingsStore.intervalCaptureEnabled)
                    }
                    .padding(.vertical, 4)

                    VStack(alignment: .leading, spacing: 4) {
                        Toggle("Quality Mode", isOn: Binding(
                            get: { settingsStore.qualityMode == .bestQuality },
                            set: { settingsStore.qualityMode = $0 ? .bestQuality : .fastestCapture }
                        ))
                        Text("Fastest Capture reduces processing time at the expense of maximum resolution.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)

                    VStack(alignment: .leading, spacing: 4) {
                        Toggle("Focus & Exposure Lock", isOn: $settingsStore.exposureFocusLocked)
                        Text("Locks the current focus and exposure levels to prevent auto-adjustments between shots.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)

                    VStack(alignment: .leading, spacing: 4) {
                        Toggle("White Balance Lock", isOn: $settingsStore.whiteBalanceLocked)
                        Text("Locks the current white balance to prevent color shifting during timelapse capture.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }

                Section("Session") {
                    VStack(alignment: .leading, spacing: 8) {
                        Toggle(
                            "Auto-Start New Session",
                            isOn: $settingsStore.automaticSessionRotationEnabled
                        )
                        Text(
                            "Create a new session after \(formattedInactivityMinutes(settingsStore.sessionInactivityMinutes)) without a successful capture. Empty sessions are not replaced."
                        )
                        .font(.caption)
                        .foregroundStyle(.secondary)

                        Slider(
                            value: $settingsStore.sessionInactivityMinutes,
                            in: SessionRotationPolicy.minimumInactivityMinutes...SessionRotationPolicy.maximumInactivityMinutes,
                            step: SessionRotationPolicy.inactivityMinuteStep
                        )
                        .disabled(!settingsStore.automaticSessionRotationEnabled)

                        HStack {
                            Text("5 min")
                            Spacer()
                            Text("60 min")
                        }
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)

                    statusRow(title: "Active Session", value: store.activeSession.id)
                    statusRow(title: "Next Frame", value: "\(store.activeSession.nextSequence)")
                    statusRow(title: "Stored Frames", value: "\(store.activeSession.frameCount)")
                    Button {
                        startNewSession()
                    } label: {
                        Label("Start New Session", systemImage: "plus.circle")
                    }
                }
            }
            .navigationTitle("Settings")
            .toolbar(.visible, for: .tabBar)
            .onAppear {
                settingsStore.refreshPermissions()
            }
            .alert("Session Error", isPresented: Binding(get: { sessionActionError != nil }, set: { if !$0 { sessionActionError = nil } })) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(sessionActionError ?? "")
            }
        }
    }

    // MARK: - Helpers

    private var cameraPermissionText: String {
        switch settingsStore.cameraPermissionStatus {
        case .authorized:    return "Authorized"
        case .denied:        return "Denied (Tap to Open Settings)"
        case .restricted:    return "Restricted"
        case .notDetermined: return "Not Determined"
        @unknown default:    return "Unknown"
        }
    }

    private var photosPermissionText: String {
        switch settingsStore.photosPermissionStatus {
        case .authorized, .limited: return "Authorized"
        case .denied:               return "Denied (Tap to Open Settings)"
        case .restricted:           return "Restricted"
        case .notDetermined:        return "Deferred until Save"
        @unknown default:           return "Unknown"
        }
    }

    @ViewBuilder
    private func permissionRow(title: String, status: String, isDenied: Bool) -> some View {
        if isDenied {
            Button(action: openSettings) {
                HStack {
                    Text(title)
                        .foregroundStyle(.primary)
                    Spacer()
                    Text(status)
                        .foregroundStyle(.red)
                    Image(systemName: "chevron.right")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        } else {
            HStack {
                Text(title)
                Spacer()
                Text(status)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }

    private func startNewSession() {
        do {
            try store.startNewSession()
        } catch {
            sessionActionError = error.localizedDescription
        }
    }

    private func statusRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .foregroundStyle(.secondary)
        }
    }

    private func formattedInterval(_ seconds: Double) -> String {
        if seconds < 1 {
            return "\(Int((seconds * 1000).rounded())) ms"
        }
        return "\(String(format: "%.2f", seconds)) s"
    }

    private func formattedInactivityMinutes(_ minutes: Double) -> String {
        "\(Int(SessionRotationPolicy.clampedInactivityMinutes(minutes))) minutes"
    }
}
