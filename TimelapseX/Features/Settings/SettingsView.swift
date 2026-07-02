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
    @StateObject private var settingsStore = CameraSettingsStore.shared

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
                    statusRow(title: "Active Session", value: store.activeSession.id)
                    statusRow(title: "Next Frame", value: "\(store.activeSession.nextSequence)")
                    statusRow(title: "Stored Frames", value: "\(store.activeSession.frameCount)")
                }

                Section("Gallery") {
                    GalleryView(store: store)
                }
            }
            .navigationTitle("Settings")
            .toolbar(.visible, for: .tabBar)
            .onAppear {
                settingsStore.refreshPermissions()
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

    private func statusRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .foregroundStyle(.secondary)
        }
    }
}
