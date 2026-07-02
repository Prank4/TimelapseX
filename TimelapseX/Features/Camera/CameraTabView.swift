//
//  CameraTabView.swift
//  TimelapseX
//
//  Created by Prank on 02/07/26.
//

import SwiftUI
import AVFoundation

struct CameraTabView: View {
    @ObservedObject var cameraViewModel: CameraViewModel
    @State private var showTabBar = false

    var body: some View {
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

            if showTabBar {
                cameraStatusAndHint
                    .padding(.horizontal, 20)
                    .padding(.bottom, 28)
            }
        }
        .background(Color.black)
        .toolbar(showTabBar ? .visible : .hidden, for: .tabBar)
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.easeInOut) {
                showTabBar = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                withAnimation(.easeInOut) {
                    showTabBar = false
                }
            }
        }
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
}
