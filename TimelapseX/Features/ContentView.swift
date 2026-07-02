//
//  ContentView.swift
//  TimelapseX
//
//  Created by Prank on 02/07/26.
//

import AVFoundation
import MediaPlayer
import SwiftUI
import UIKit

struct ContentView: View {
    @StateObject private var cameraViewModel = CameraViewModel()
    @State private var selectedTab: AppTab = .camera

    var body: some View {
        TabView(selection: $selectedTab) {
            cameraTab
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
        .toolbar(selectedTab == .camera ? .hidden : .visible, for: .tabBar)
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

    private var cameraTab: some View {
        ZStack(alignment: .bottom) {
            if cameraViewModel.authorizationStatus == .authorized {
                CameraPreviewView(session: cameraViewModel.captureSession)
                    .ignoresSafeArea()
                    .onAppear {
                        cameraViewModel.startSession()
                        UIApplication.shared.isIdleTimerDisabled = true
                    }
                    .onDisappear {
                        cameraViewModel.stopSession()
                    }
                VolumeButtonCaptureView {
                    cameraViewModel.captureStillImage()
                }
                .frame(width: 0, height: 0)
                .allowsHitTesting(false)
            } else {
                Color.black.ignoresSafeArea()
                permissionPrompt
            }

            cameraStatusAndHint
                .padding(.horizontal, 20)
                .padding(.bottom, 28)
        }
        .background(Color.black)
    }

    private var permissionPrompt: some View {
        VStack(spacing: 12) {
            Image(systemName: "camera.fill")
                .font(.system(size: 42, weight: .semibold))
            Text("Camera access is required to start a session.")
                .multilineTextAlignment(.center)
            Button("Allow Camera Access") {
                cameraViewModel.requestCameraPermissionIfNeeded()
            }
            .buttonStyle(.borderedProminent)
        }
        .foregroundStyle(.white)
        .padding(28)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var cameraStatusAndHint: some View {
        VStack(spacing: 12) {
            Text(cameraViewModel.statusMessage)
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.85))
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 12)

            HStack(spacing: 8) {
                Image(systemName: "speaker.wave.2.fill")
                Text("Press Volume Up to Capture")
            }
            .font(.footnote.weight(.medium))
            .foregroundStyle(.white)
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .background(.white.opacity(0.14), in: Capsule())
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

struct VolumeButtonCaptureView: UIViewRepresentable {
    let onVolumeUp: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onVolumeUp: onVolumeUp)
    }

    func makeUIView(context: Context) -> UIView {
        let containerView = UIView(frame: .zero)
        context.coordinator.attach(to: containerView)
        return containerView
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.onVolumeUp = onVolumeUp
    }

    static func dismantleUIView(_ uiView: UIView, coordinator: Coordinator) {
        coordinator.detach()
    }

    final class Coordinator {
        var onVolumeUp: () -> Void
        private let audioSession = AVAudioSession.sharedInstance()
        private var observation: NSKeyValueObservation?
        private weak var volumeSlider: UISlider?
        private let targetVolume: Float = 0.5
        private var originalVolume: Float = 0.5
        private var isResettingVolume = false

        init(onVolumeUp: @escaping () -> Void) {
            self.onVolumeUp = onVolumeUp
        }

        func attach(to containerView: UIView) {
            let volumeView = MPVolumeView(frame: .zero)
            volumeView.frame = CGRect(x: -1000, y: -1000, width: 1, height: 1)
            volumeView.alpha = 0.0001
            volumeView.showsVolumeSlider = true
            containerView.addSubview(volumeView)

            volumeSlider = volumeView.subviews.compactMap { $0 as? UISlider }.first
            originalVolume = audioSession.outputVolume

            do {
                try audioSession.setCategory(.ambient, mode: .default, options: [.mixWithOthers])
                try audioSession.setActive(true)
            } catch {
                return
            }

            observation = audioSession.observe(\.outputVolume, options: [.old, .new]) { [weak self] _, change in
                guard let self else { return }
                guard !self.isResettingVolume else {
                    self.isResettingVolume = false
                    return
                }

                guard let newVolume = change.newValue, let oldVolume = change.oldValue else {
                    return
                }

                if newVolume > oldVolume {
                    DispatchQueue.main.async {
                        self.onVolumeUp()
                    }
                }

                self.restoreTargetVolume()
            }

            restoreTargetVolume()
        }

        func detach() {
            observation = nil
            restoreOriginalVolume()
            try? audioSession.setActive(false, options: .notifyOthersOnDeactivation)
        }

        private func restoreTargetVolume() {
            setVolume(targetVolume)
        }

        private func restoreOriginalVolume() {
            setVolume(originalVolume)
        }

        private func setVolume(_ value: Float) {
            DispatchQueue.main.async {
                guard let volumeSlider = self.volumeSlider else { return }
                self.isResettingVolume = true
                volumeSlider.setValue(value, animated: false)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    self.isResettingVolume = false
                }
            }
        }
    }
}
