//
//  SettingsView.swift
//  TimelapseX
//
//  Created by Prank on 02/07/26.
//

import AVFoundation
import SwiftUI

struct SettingsView: View {
    @ObservedObject var store: SessionStore

    var body: some View {
        NavigationStack {
            List {
                Section("Permissions") {
                    statusRow(title: "Camera", value: cameraPermissionText)
                    statusRow(title: "Photos", value: "Deferred until Save")
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
        }
    }

    // MARK: - Helpers

    private var cameraPermissionText: String {
        permissionText(for: AVCaptureDevice.authorizationStatus(for: .video))
    }

    private func statusRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .foregroundStyle(.secondary)
        }
    }

    private func permissionText(for status: AVAuthorizationStatus) -> String {
        switch status {
        case .authorized:    return "Authorized"
        case .denied:        return "Denied"
        case .restricted:    return "Restricted"
        case .notDetermined: return "Not Determined"
        @unknown default:    return "Unknown"
        }
    }
}
