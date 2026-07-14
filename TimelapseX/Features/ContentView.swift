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

            SettingsView(store: cameraViewModel.sessionStore)
                .tag(AppTab.settings)
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
        }
        .onAppear {
            syncIdleTimer()
            if selectedTab == .camera {
                Task { @MainActor in
                    cameraViewModel.requestCameraPermissionIfNeeded()
                }
            }
        }
        .onChange(of: selectedTab) { _, newValue in
            syncIdleTimer()
            if newValue == .camera {
                Task { @MainActor in
                    cameraViewModel.requestCameraPermissionIfNeeded()
                }
            } else {
                cameraViewModel.stopSession()
                UIApplication.shared.isIdleTimerDisabled = false
            }
        }
    }

    private func syncIdleTimer() {
        UIApplication.shared.isIdleTimerDisabled = selectedTab == .camera
    }
}
