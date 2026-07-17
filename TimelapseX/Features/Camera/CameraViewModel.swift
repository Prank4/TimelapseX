//
//  CameraViewModel.swift
//  TimelapseX
//
//  Created by Prank on 02/07/26.
//

import AVFoundation
import Combine
import CoreMotion
import SwiftUI

final class CameraViewModel: NSObject, ObservableObject {
    @Published private(set) var authorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)
    @Published private(set) var isRunning = false
    @Published private(set) var isCapturing = false
    @Published private(set) var statusMessage = "Ready"
    @Published private(set) var levelAngleDegrees: Double?

    let sessionStore: SessionStore
    let settingsStore = CameraSettingsStore.shared
    let captureSession = AVCaptureSession()

    private let sessionQueue = DispatchQueue(label: "TimelapseX.Camera.SessionQueue")
    private let photoOutput = AVCapturePhotoOutput()
    private let motionManager = CMMotionManager()
    private let motionQueue: OperationQueue = {
        let queue = OperationQueue()
        queue.name = "TimelapseX.Camera.LevelQueue"
        queue.qualityOfService = .userInteractive
        queue.maxConcurrentOperationCount = 1
        return queue
    }()
    private var pendingCaptureTimestamp: Date?
    private var intervalCaptureTask: Task<Void, Never>?
    private var inactivityRotationWorkItem: DispatchWorkItem?
    private var configured = false
    private var cancellables = Set<AnyCancellable>()

    init(sessionStore: SessionStore = SessionStore()) {
        self.sessionStore = sessionStore
        super.init()

        settingsStore.$lensOverride
            .dropFirst()
            .sink { [weak self] _ in
                self?.updateDeviceInput()
            }
            .store(in: &cancellables)

        Publishers.CombineLatest(settingsStore.$exposureFocusLocked, settingsStore.$whiteBalanceLocked)
            .dropFirst()
            .sink { [weak self] _, _ in
                self?.applyLocks()
            }
            .store(in: &cancellables)

        settingsStore.$intervalCaptureEnabled
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isEnabled in
                if !isEnabled {
                    self?.stopIntervalCapture()
                    self?.statusMessage = "Timed capture stopped"
                }
            }
            .store(in: &cancellables)

        settingsStore.$intervalCaptureSeconds
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self, self.intervalCaptureTask != nil else { return }
                self.startIntervalCapture()
            }
            .store(in: &cancellables)

        Publishers.CombineLatest(
            settingsStore.$automaticSessionRotationEnabled,
            settingsStore.$sessionInactivityMinutes
        )
        .dropFirst()
        .receive(on: DispatchQueue.main)
        .sink { [weak self] _, _ in
            self?.scheduleInactivityRotation()
        }
        .store(in: &cancellables)

        DispatchQueue.main.async { [weak self] in
            self?.scheduleInactivityRotation()
        }
    }

    deinit {
        intervalCaptureTask?.cancel()
        inactivityRotationWorkItem?.cancel()
        motionManager.stopDeviceMotionUpdates()
    }

    func refreshAuthorizationStatus() {
        let currentStatus = AVCaptureDevice.authorizationStatus(for: .video)
        if authorizationStatus != currentStatus {
            authorizationStatus = currentStatus
        }
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
        startLevelerUpdates()

        #if targetEnvironment(simulator)
        isRunning = false
        statusMessage = "Camera preview unavailable in Simulator"
        #else
        sessionQueue.async { [weak self] in
            guard let self else { return }
            if !self.configured {
                guard self.configureSession() else { return }
            }

            guard !self.captureSession.isRunning else { return }
            self.captureSession.startRunning()
            Task { @MainActor in
                self.isRunning = true
                self.statusMessage = "Camera active"
            }
        }
        #endif
    }

    func stopSession() {
        stopIntervalCapture()
        stopLevelerUpdates()
        sessionQueue.async { [weak self] in
            guard let self, self.captureSession.isRunning else { return }
            self.captureSession.stopRunning()
            Task { @MainActor in
                self.isRunning = false
            }
        }
    }

    func captureStillImage() {
        requestCapture(shouldStartIntervalCapture: true)
    }

    private func requestCapture(shouldStartIntervalCapture: Bool) {
        guard authorizationStatus == .authorized else {
            statusMessage = "Camera permission required"
            requestCameraPermissionIfNeeded()
            return
        }

        #if targetEnvironment(simulator)
        statusMessage = "Capture unavailable in Simulator"
        #else
        do {
            if try sessionStore.rotateActiveSessionIfInactive(
                isEnabled: settingsStore.automaticSessionRotationEnabled,
                inactivityInterval: automaticSessionRotationInterval
            ) {
                statusMessage = automaticSessionRotationStatusMessage
            }
        } catch {
            statusMessage = error.localizedDescription
            return
        }

        guard shouldStartIntervalCapture || settingsStore.intervalCaptureEnabled else {
            stopIntervalCapture()
            return
        }

        if shouldStartIntervalCapture && settingsStore.intervalCaptureEnabled {
            startIntervalCapture()
        }

        guard !isCapturing else {
            return
        }

        isCapturing = true
        pendingCaptureTimestamp = Date()

        let settings = AVCapturePhotoSettings()
        settings.flashMode = .off
        settings.photoQualityPrioritization = (settingsStore.qualityMode == .bestQuality) ? .quality : .speed
        settings.maxPhotoDimensions = photoOutput.maxPhotoDimensions

        photoOutput.capturePhoto(with: settings, delegate: self)
        #endif
    }

    private func startIntervalCapture() {
        intervalCaptureTask?.cancel()

        guard settingsStore.intervalCaptureEnabled else {
            intervalCaptureTask = nil
            return
        }

        intervalCaptureTask = Task { [weak self] in
            while !Task.isCancelled {
                let intervalSeconds = await MainActor.run {
                    self?.settingsStore.intervalCaptureSeconds ?? 2.0
                }
                let nanoseconds = UInt64(intervalSeconds * 1_000_000_000)
                try? await Task.sleep(nanoseconds: nanoseconds)
                guard !Task.isCancelled else { break }

                await MainActor.run {
                    guard self?.settingsStore.intervalCaptureEnabled == true else {
                        self?.stopIntervalCapture()
                        return
                    }
                    self?.requestCapture(shouldStartIntervalCapture: false)
                }
            }
        }
    }

    private func stopIntervalCapture() {
        intervalCaptureTask?.cancel()
        intervalCaptureTask = nil
    }

    private func scheduleInactivityRotation() {
        inactivityRotationWorkItem?.cancel()
        inactivityRotationWorkItem = nil

        do {
            if try sessionStore.rotateActiveSessionIfInactive(
                isEnabled: settingsStore.automaticSessionRotationEnabled,
                inactivityInterval: automaticSessionRotationInterval
            ) {
                statusMessage = automaticSessionRotationStatusMessage
                return
            }
        } catch {
            statusMessage = error.localizedDescription
            return
        }

        guard let deadline = sessionStore.activeSessionInactivityDeadline(
            isEnabled: settingsStore.automaticSessionRotationEnabled,
            inactivityInterval: automaticSessionRotationInterval
        ) else { return }
        let workItem = DispatchWorkItem { [weak self] in
            self?.handleInactivityDeadline()
        }
        inactivityRotationWorkItem = workItem
        DispatchQueue.main.asyncAfter(
            deadline: .now() + max(0, deadline.timeIntervalSinceNow),
            execute: workItem
        )
    }

    private func handleInactivityDeadline() {
        if isCapturing {
            let workItem = DispatchWorkItem { [weak self] in
                self?.handleInactivityDeadline()
            }
            inactivityRotationWorkItem = workItem
            DispatchQueue.main.asyncAfter(deadline: .now() + 1, execute: workItem)
            return
        }

        scheduleInactivityRotation()
    }

    private var automaticSessionRotationInterval: TimeInterval {
        SessionRotationPolicy.inactivityIntervalSeconds(
            minutes: settingsStore.sessionInactivityMinutes
        )
    }

    private var automaticSessionRotationStatusMessage: String {
        let minutes = Int(SessionRotationPolicy.clampedInactivityMinutes(
            settingsStore.sessionInactivityMinutes
        ))
        return "New session started after \(minutes) minutes of inactivity"
    }

    private func startLevelerUpdates() {
        guard motionManager.isDeviceMotionAvailable,
              !motionManager.isDeviceMotionActive else { return }

        motionManager.deviceMotionUpdateInterval = 1.0 / 30.0
        motionManager.startDeviceMotionUpdates(to: motionQueue) { [weak self] motion, _ in
            guard let self, let gravity = motion?.gravity else { return }
            let angle = atan2(gravity.x, -gravity.y) * 180 / .pi
            DispatchQueue.main.async {
                self.levelAngleDegrees = angle
            }
        }
    }

    private func stopLevelerUpdates() {
        motionManager.stopDeviceMotionUpdates()
        levelAngleDegrees = nil
    }

    private func configureSession() -> Bool {
        captureSession.beginConfiguration()
        defer { captureSession.commitConfiguration() }

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
            
            applyDeviceSettings(device)

            if let format = largestPhotoFormat(for: device) {
                device.activeFormat = format
            }

            photoOutput.maxPhotoQualityPrioritization = .quality
            configured = true
            return true
        } catch {
            Task { @MainActor in
                self.statusMessage = error.localizedDescription
            }
            return false
        }
    }

    private func bestCameraDevice() throws -> AVCaptureDevice {
        let lens = settingsStore.lensOverride
        let preferredTypes: [AVCaptureDevice.DeviceType]
        switch lens {
        case .auto:
            preferredTypes = [.builtInUltraWideCamera, .builtInWideAngleCamera]
        case .wide:
            preferredTypes = [.builtInWideAngleCamera]
        case .ultraWide:
            preferredTypes = [.builtInUltraWideCamera]
        }

        for deviceType in preferredTypes {
            if let device = AVCaptureDevice.default(deviceType, for: .video, position: .back) {
                return device
            }
        }

        throw NSError(
            domain: "TimelapseX.Camera",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: "No back camera available for \(lens.displayName)"]
        )
    }

    func updateDeviceInput() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            self.captureSession.beginConfiguration()
            defer { self.captureSession.commitConfiguration() }

            // Remove current input
            if let currentInput = self.captureSession.inputs.first as? AVCaptureDeviceInput {
                self.captureSession.removeInput(currentInput)
            }

            do {
                let device = try self.bestCameraDevice()
                let input = try AVCaptureDeviceInput(device: device)

                if self.captureSession.canAddInput(input) {
                    self.captureSession.addInput(input)
                } else {
                    throw NSError(domain: "TimelapseX.Camera", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to add device input"])
                }

                try device.lockForConfiguration()
                defer { device.unlockForConfiguration() }

                self.applyDeviceSettings(device)

                if let format = self.largestPhotoFormat(for: device) {
                    device.activeFormat = format
                }
            } catch {
                Task { @MainActor in
                    self.statusMessage = error.localizedDescription
                }
            }
        }
    }

    func applyLocks() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            guard let device = (self.captureSession.inputs.first as? AVCaptureDeviceInput)?.device else { return }
            do {
                try device.lockForConfiguration()
                defer { device.unlockForConfiguration() }

                self.applyDeviceSettings(device)
            } catch {
                Task { @MainActor in
                    self.statusMessage = error.localizedDescription
                }
            }
        }
    }

    private func applyDeviceSettings(_ device: AVCaptureDevice) {
        let isExposureFocusLocked = settingsStore.exposureFocusLocked
        let isWhiteBalanceLocked = settingsStore.whiteBalanceLocked

        // Exposure
        if isExposureFocusLocked {
            if device.isExposureModeSupported(.locked) {
                device.exposureMode = .locked
            }
        } else {
            if device.isExposureModeSupported(.continuousAutoExposure) {
                device.exposureMode = .continuousAutoExposure
            }
        }

        // Focus
        if isExposureFocusLocked {
            if device.isFocusModeSupported(.locked) {
                device.focusMode = .locked
            }
        } else {
            if device.isFocusModeSupported(.continuousAutoFocus) {
                device.focusMode = .continuousAutoFocus
            }
        }

        // White Balance
        if isWhiteBalanceLocked {
            if device.isWhiteBalanceModeSupported(.locked) {
                device.whiteBalanceMode = .locked
            }
        } else {
            if device.isWhiteBalanceModeSupported(.continuousAutoWhiteBalance) {
                device.whiteBalanceMode = .continuousAutoWhiteBalance
            }
        }
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
                self.scheduleInactivityRotation()
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
