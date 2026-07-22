//
//  CameraTabView.swift
//  TimelapseX
//
//  Created by Prank on 02/07/26.
//

import SwiftUI
import AVFoundation
import UIKit

struct CameraTabView: View {
    @ObservedObject var cameraViewModel: CameraViewModel
    @State private var pinchStartingZoomFactor: Double?

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.black.ignoresSafeArea()

            if cameraViewModel.authorizationStatus == .authorized {
                #if targetEnvironment(simulator)
                Color.black.ignoresSafeArea()
                    .task {
                        cameraViewModel.startSession()
                        UIApplication.shared.isIdleTimerDisabled = true
                    }
                #else
                CameraPreviewView(session: cameraViewModel.captureSession)
                    .ignoresSafeArea()
                    .simultaneousGesture(cameraZoomGesture)
                    .overlay {
                        ZStack {
                            GridOverlayView(type: cameraViewModel.settingsStore.gridOverlay)
                                .ignoresSafeArea()

                            CameraLevelView(angleDegrees: cameraViewModel.levelAngleDegrees)

                            VStack {
                                HStack {
                                    Spacer()
                                    Text(String(format: "%.1f×", cameraViewModel.zoomFactor))
                                        .font(.caption.weight(.semibold))
                                        .monospacedDigit()
                                        .foregroundStyle(.white)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .background(.black.opacity(0.42), in: Capsule())
                                }
                                Spacer()
                            }
                            .padding(.horizontal, 20)
                            .padding(.top, 18)
                        }
                        .allowsHitTesting(false)
                    }
                    .task {
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
                #endif
            } else {
                Color.black.ignoresSafeArea()
                permissionPrompt
            }

            cameraBottomOverlay
                .padding(.horizontal, 20)
                .padding(.bottom, 28)
        }
        .background(Color.black)
        .onAppear {
            cameraViewModel.refreshLatestFrameURL()
        }
    }

    private var permissionPrompt: some View {
        VStack(spacing: 12) {
            Image(systemName: "camera.fill")
                .font(.system(size: 42, weight: .semibold))
            Text("Camera access is required to start an album.")
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

    private var cameraBottomOverlay: some View {
        VStack(spacing: 12) {
            Text(cameraViewModel.statusMessage)
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.85))
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(.black.opacity(0.28), in: Capsule())

            HStack(spacing: 12) {
                if cameraViewModel.settingsStore.latestPhotoPreviewEnabled,
                   cameraViewModel.isLatestFramePreviewVisible {
                    CameraLastThumbnailView(url: cameraViewModel.latestFrameURL)
                        .transition(.opacity.combined(with: .scale(scale: 0.92)))
                }

                Spacer(minLength: 0)

                HStack(spacing: 8) {
                    Image(systemName: "speaker.wave.2.fill")
                    Text("Press Volume Up or Down to Capture")
                }
                .font(.footnote.weight(.medium))
                .foregroundStyle(.white)
                .padding(.vertical, 12)
                .padding(.horizontal, 16)
                .background(.white.opacity(0.14), in: Capsule())
            }
        }
        .animation(.easeInOut(duration: 0.2), value: cameraViewModel.isLatestFramePreviewVisible)
    }

    private var cameraZoomGesture: some Gesture {
        MagnifyGesture(minimumScaleDelta: 0.01)
            .onChanged { value in
                let startingZoom = pinchStartingZoomFactor ?? cameraViewModel.zoomFactor
                if pinchStartingZoomFactor == nil {
                    pinchStartingZoomFactor = startingZoom
                }
                cameraViewModel.setZoomFactor(
                    startingZoom * Double(value.magnification)
                )
            }
            .onEnded { _ in
                pinchStartingZoomFactor = nil
            }
    }
}

private struct CameraLastThumbnailView: View {
    let url: URL?

    @State private var image: UIImage?

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(.black.opacity(0.4))
                    .overlay {
                        Image(systemName: "photo")
                            .foregroundStyle(.white.opacity(0.65))
                    }
            }
        }
        .frame(width: thumbnailSize.width, height: thumbnailSize.height)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(.white.opacity(0.85), lineWidth: 1.5)
        }
        .shadow(color: .black.opacity(0.35), radius: 4, y: 2)
        .accessibilityLabel(url == nil ? "No captured photo yet" : "Latest captured photo")
        .task(id: url) {
            image = nil
            guard let url,
                  let loaded = await GalleryImageLoader.shared.loadImage(
                    at: url,
                    maxPixelSize: 360
                  ),
                  !Task.isCancelled else { return }
            image = UIImage(cgImage: loaded)
        }
        .onDisappear {
            image = nil
        }
    }

    private var thumbnailSize: CGSize {
        guard let image, image.size.width > 0, image.size.height > 0 else {
            return CGSize(width: 90, height: 120)
        }
        let aspectRatio = image.size.width / image.size.height
        if aspectRatio >= 1 {
            return CGSize(width: 120, height: 120 / aspectRatio)
        }
        return CGSize(width: 120 * aspectRatio, height: 120)
    }
}
