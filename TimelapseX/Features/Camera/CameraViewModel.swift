//
//  CameraViewModel.swift
//  TimelapseX
//
//  Created by Prank on 02/07/26.
//

import AVFoundation
import Combine
import SwiftUI

final class CameraViewModel: NSObject, ObservableObject {
    @Published private(set) var authorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)
    @Published private(set) var isRunning = false
    @Published private(set) var isCapturing = false
    @Published private(set) var statusMessage = "Ready"

    let sessionStore: SessionStore
    let captureSession = AVCaptureSession()

    private let sessionQueue = DispatchQueue(label: "TimelapseX.Camera.SessionQueue")
    private let photoOutput = AVCapturePhotoOutput()
    private var pendingCaptureTimestamp: Date?
    private var configured = false

    init(sessionStore: SessionStore = SessionStore()) {
        self.sessionStore = sessionStore
        super.init()
    }

    func refreshAuthorizationStatus() {
        authorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)
    }

    func requestCameraPermissionIfNeeded() {
        refreshAuthorizationStatus()
        guard authorizationStatus == .notDetermined else {
            if authorizationStatus == .authorized {
                startSession()
            }
            return
        }

        Task {
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            await MainActor.run {
                self.refreshAuthorizationStatus()
                if granted {
                    self.startSession()
                } else {
                    self.statusMessage = "Camera access denied"
                }
            }
        }
    }

    func startSession() {
        guard authorizationStatus == .authorized else { return }

        sessionQueue.async { [weak self] in
            guard let self else { return }
            if !self.configured {
                self.configureSession()
            }

            guard !self.captureSession.isRunning else { return }
            self.captureSession.startRunning()
            Task { @MainActor in
                self.isRunning = true
                self.statusMessage = "Camera active"
            }
        }
    }

    func stopSession() {
        sessionQueue.async { [weak self] in
            guard let self, self.captureSession.isRunning else { return }
            self.captureSession.stopRunning()
            Task { @MainActor in
                self.isRunning = false
            }
        }
    }

    func captureStillImage() {
        guard authorizationStatus == .authorized else {
            statusMessage = "Camera permission required"
            requestCameraPermissionIfNeeded()
            return
        }

        guard !isCapturing else { return }
        isCapturing = true
        pendingCaptureTimestamp = Date()

        let settings = AVCapturePhotoSettings()
        settings.flashMode = .off
        settings.isHighResolutionPhotoEnabled = true
        settings.photoQualityPrioritization = .quality
        settings.maxPhotoDimensions = photoOutput.maxPhotoDimensions

        photoOutput.capturePhoto(with: settings, delegate: self)
    }

    private func configureSession() {
        captureSession.beginConfiguration()
        captureSession.sessionPreset = .photo

        do {
            let device = try bestCameraDevice()
            let input = try AVCaptureDeviceInput(device: device)

            if captureSession.canAddInput(input) {
                captureSession.addInput(input)
            }

            if captureSession.canAddOutput(photoOutput) {
                captureSession.addOutput(photoOutput)
            }

            try device.lockForConfiguration()
            defer { device.unlockForConfiguration() }
            device.focusMode = .continuousAutoFocus
            device.exposureMode = .continuousAutoExposure
            device.whiteBalanceMode = .continuousAutoWhiteBalance

            if let format = largestPhotoFormat(for: device) {
                device.activeFormat = format
            }

            photoOutput.isHighResolutionCaptureEnabled = true
            photoOutput.maxPhotoQualityPrioritization = .quality
            configured = true
        } catch {
            Task { @MainActor in
                self.statusMessage = error.localizedDescription
            }
        }

        captureSession.commitConfiguration()
    }

    private func bestCameraDevice() throws -> AVCaptureDevice {
        let preferredTypes: [AVCaptureDevice.DeviceType] = [
            .builtInUltraWideCamera,
            .builtInWideAngleCamera
        ]

        for deviceType in preferredTypes {
            if let device = AVCaptureDevice.default(deviceType, for: .video, position: .back) {
                return device
            }
        }

        throw NSError(domain: "TimelapseX.Camera", code: 1, userInfo: [NSLocalizedDescriptionKey: "No back camera available"])
    }

    private func largestPhotoFormat(for device: AVCaptureDevice) -> AVCaptureDevice.Format? {
        device.formats.max { lhs, rhs in
            let lhsDimensions = CMVideoFormatDescriptionGetDimensions(lhs.formatDescription)
            let rhsDimensions = CMVideoFormatDescriptionGetDimensions(rhs.formatDescription)
            let lhsPixels = Int(lhsDimensions.width) * Int(lhsDimensions.height)
            let rhsPixels = Int(rhsDimensions.width) * Int(rhsDimensions.height)
            return lhsPixels < rhsPixels
        }
    }
}

extension CameraViewModel: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        let captureTimestamp = pendingCaptureTimestamp ?? Date()
        pendingCaptureTimestamp = nil

        if let error {
            do {
                try sessionStore.noteCaptureFailure(
                    sequenceNumber: sessionStore.activeSession.nextSequence,
                    capturedAt: captureTimestamp,
                    errorDescription: error.localizedDescription
                )
            } catch {
                Task { @MainActor in
                    self.statusMessage = error.localizedDescription
                }
            }
            return
        }

        guard let imageData = photo.fileDataRepresentation() else {
            do {
                try sessionStore.noteCaptureFailure(
                    sequenceNumber: sessionStore.activeSession.nextSequence,
                    capturedAt: captureTimestamp,
                    errorDescription: "Unable to extract JPEG data"
                )
            } catch {
                Task { @MainActor in
                    self.statusMessage = error.localizedDescription
                }
            }
            return
        }

        do {
            try sessionStore.noteCaptureSuccess(
                sequenceNumber: sessionStore.activeSession.nextSequence,
                capturedAt: captureTimestamp,
                imageData: imageData
            )
            Task { @MainActor in
                self.statusMessage = "Saved frame \(self.sessionStore.activeSession.nextSequence - 1)"
            }
        } catch {
            Task { @MainActor in
                self.statusMessage = error.localizedDescription
            }
        }
    }

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishCaptureFor resolvedSettings: AVCaptureResolvedPhotoSettings, error: Error?) {
        Task { @MainActor in
            self.isCapturing = false
            if let error {
                self.statusMessage = error.localizedDescription
            }
        }
    }
}
