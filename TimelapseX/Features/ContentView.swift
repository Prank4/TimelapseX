//
//  ContentView.swift
//  TimelapseX
//
//  Created by Prank on 02/07/26.
//

import AVFoundation
import SwiftUI

struct ContentView: View {
    @StateObject private var cameraViewModel = CameraViewModel()
    @State private var selectedTab: AppTab = .camera

    var body: some View {
        TabView(selection: $selectedTab) {
            CameraTabView(cameraViewModel: cameraViewModel)
                .tag(AppTab.camera)
                .tabItem {
                    Label("Camera", systemImage: "camera")
                }

            settingsTab
                .tag(AppTab.settings)
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
        }
        .onAppear {
            syncIdleTimer()
            if selectedTab == .camera {
                cameraViewModel.requestCameraPermissionIfNeeded()
            }
        }
        .onChange(of: selectedTab) { _, newValue in
            syncIdleTimer()
            if newValue == .camera {
                cameraViewModel.requestCameraPermissionIfNeeded()
            } else {
                cameraViewModel.stopSession()
                UIApplication.shared.isIdleTimerDisabled = false
            }
        }
    }

    private var settingsTab: some View {
        NavigationStack {
            List {
                Section("Permissions") {
                    statusRow(title: "Camera", value: permissionText(for: AVCaptureDevice.authorizationStatus(for: .video)))
                    statusRow(title: "Photos", value: "Deferred until Save")
                }

                Section("Session") {
                    statusRow(title: "Active Session", value: cameraViewModel.sessionStore.activeSession.id)
                    statusRow(title: "Next Frame", value: "\(cameraViewModel.sessionStore.activeSession.nextSequence)")
                    statusRow(title: "Stored Frames", value: "\(cameraViewModel.sessionStore.activeSession.frameCount)")
                }
            }
            .navigationTitle("Settings")
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

    private func permissionText(for status: AVAuthorizationStatus) -> String {
        switch status {
        case .authorized:
            return "Authorized"
        case .denied:
            return "Denied"
        case .restricted:
            return "Restricted"
        case .notDetermined:
            return "Not Determined"
        @unknown default:
            return "Unknown"
        }
    }

    private func syncIdleTimer() {
        UIApplication.shared.isIdleTimerDisabled = selectedTab == .camera
    }
}
