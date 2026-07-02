import AVFoundation
import Combine
import CoreMedia
import SwiftUI
import UIKit

enum AppTab: Hashable {
    case camera
    case settings
}

enum SessionStatus: String, Codable {
    case active
    case saved
    case discarded
}

struct SessionRecord: Codable, Identifiable, Equatable {
    let id: String
    let createdAt: Date
    var status: SessionStatus
    var nextSequence: Int
    var photosAlbumIdentifier: String?

    var folderName: String { id }
    var folderURL: URL { Self.sessionsDirectory.appendingPathComponent(folderName, isDirectory: true) }
    var sessionJSONURL: URL { folderURL.appendingPathComponent("session.json") }
    var captureLogURL: URL { folderURL.appendingPathComponent("capture_log.txt") }

    var frameCount: Int {
        let contents = (try? FileManager.default.contentsOfDirectory(
            at: folderURL,
            includingPropertiesForKeys: nil
        )) ?? []

        return contents.filter { $0.lastPathComponent.hasPrefix("IMG_") && $0.pathExtension.lowercased() == "jpg" }.count
    }

    static var sessionsDirectory: URL {
        SessionStore.sharedSessionsDirectory
    }
}

struct CaptureLogEntry: Codable {
    let timestamp: Date
    let sequenceNumber: Int
    let outcome: CaptureOutcome
    let errorDescription: String?

    enum CaptureOutcome: String, Codable {
        case success
        case captureFailed
    }
}

final class SessionStore: ObservableObject {
    static let sharedSessionsDirectory = FileManager.default
        .urls(for: .applicationSupportDirectory, in: .userDomainMask)
        .first!
        .appendingPathComponent("Sessions", isDirectory: true)

    @Published private(set) var activeSession: SessionRecord
    @Published private(set) var lastWriteErrorMessage: String?

    private let fileManager: FileManager
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
        self.encoder = JSONEncoder()
        self.decoder = JSONDecoder()
        self.encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        self.encoder.dateEncodingStrategy = .iso8601
        self.decoder.dateDecodingStrategy = .iso8601

        do {
            try Self.prepareSessionsDirectory(using: fileManager)
            self.activeSession = try Self.loadActiveSession(using: fileManager, decoder: decoder)
            try Self.ensureSessionFolder(self.activeSession, using: fileManager)
            try Self.persistSession(self.activeSession, using: fileManager, encoder: encoder)
        } catch {
            self.activeSession = Self.makeNewSession()
            self.lastWriteErrorMessage = error.localizedDescription
            try? Self.prepareSessionsDirectory(using: fileManager)
            try? Self.ensureSessionFolder(self.activeSession, using: fileManager)
            try? Self.persistSession(self.activeSession, using: fileManager, encoder: encoder)
        }
    }

    func noteCaptureSuccess(sequenceNumber: Int, capturedAt: Date, imageData: Data) throws {
        try writeCapture(sequenceNumber: sequenceNumber, capturedAt: capturedAt, imageData: imageData, outcome: .success, errorDescription: nil)
    }

    func noteCaptureFailure(sequenceNumber: Int, capturedAt: Date, errorDescription: String) throws {
        try writeCapture(sequenceNumber: sequenceNumber, capturedAt: capturedAt, imageData: nil, outcome: .captureFailed, errorDescription: errorDescription)
    }

    private func writeCapture(sequenceNumber: Int, capturedAt: Date, imageData: Data?, outcome: CaptureLogEntry.CaptureOutcome, errorDescription: String?) throws {
        try Self.ensureSessionFolder(activeSession, using: fileManager)

        if let imageData {
            try imageData.write(to: captureURL(for: sequenceNumber))
        }

        let logEntry = CaptureLogEntry(
            timestamp: capturedAt,
            sequenceNumber: sequenceNumber,
            outcome: outcome,
            errorDescription: errorDescription
        )

        let logLine = Self.logLine(for: logEntry)
        if fileManager.fileExists(atPath: activeSession.captureLogURL.path) {
            let handle = try FileHandle(forWritingTo: activeSession.captureLogURL)
            try handle.seekToEnd()
            try handle.write(contentsOf: Data(logLine.utf8))
            try handle.close()
        } else {
            try Data(logLine.utf8).write(to: activeSession.captureLogURL, options: .atomic)
        }

        activeSession.nextSequence += 1
        try Self.persistSession(activeSession, using: fileManager, encoder: encoder)
    }

    func captureURL(for sequenceNumber: Int) -> URL {
        activeSession.folderURL.appendingPathComponent(String(format: "IMG_%06d.jpg", sequenceNumber))
    }

    private static func prepareSessionsDirectory(using fileManager: FileManager) throws {
        try fileManager.createDirectory(
            at: sharedSessionsDirectory,
            withIntermediateDirectories: true
        )
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        var sessionsDirectory = sharedSessionsDirectory
        try sessionsDirectory.setResourceValues(values)
    }

    private static func ensureSessionFolder(_ session: SessionRecord, using fileManager: FileManager) throws {
        try fileManager.createDirectory(
            at: session.folderURL,
            withIntermediateDirectories: true
        )
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        var folderURL = session.folderURL
        try folderURL.setResourceValues(values)
    }

    private static func loadActiveSession(using fileManager: FileManager, decoder: JSONDecoder) throws -> SessionRecord {
        let sessions = try fileManager.contentsOfDirectory(
            at: sharedSessionsDirectory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )

        for folderURL in sessions.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
            let sessionJSONURL = folderURL.appendingPathComponent("session.json")
            guard fileManager.fileExists(atPath: sessionJSONURL.path) else { continue }
            let data = try Data(contentsOf: sessionJSONURL)
            let session = try decoder.decode(SessionRecord.self, from: data)
            if session.status == .active {
                return session
            }
        }

        return makeNewSession()
    }

    private static func persistSession(_ session: SessionRecord, using fileManager: FileManager, encoder: JSONEncoder) throws {
        let persisted = PersistedSession(
            id: session.id,
            createdAt: session.createdAt,
            status: session.status,
            nextSequence: session.nextSequence
        )
        let data = try encoder.encode(persisted)
        try data.write(to: session.sessionJSONURL, options: .atomic)
    }

    private static func makeNewSession() -> SessionRecord {
        let createdAt = Date()
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"

        return SessionRecord(
            id: formatter.string(from: createdAt),
            createdAt: createdAt,
            status: .active,
            nextSequence: 1,
            photosAlbumIdentifier: nil
        )
    }

    private static func logLine(for entry: CaptureLogEntry) -> String {
        let formatter = ISO8601DateFormatter()
        let errorPart = entry.errorDescription ?? ""
        return "\(formatter.string(from: entry.timestamp)) |\t\(entry.sequenceNumber) |\t\(entry.outcome.rawValue) |\t\(errorPart)\n"
    }
}

private struct PersistedSession: Codable {
    let id: String
    let createdAt: Date
    let status: SessionStatus
    let nextSequence: Int
}

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

struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewUIView {
        let view = PreviewUIView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        view.previewLayer.connection?.videoOrientation = .portrait
        return view
    }

    func updateUIView(_ uiView: PreviewUIView, context: Context) {
        uiView.previewLayer.session = session
        uiView.previewLayer.connection?.videoOrientation = .portrait
    }
}

final class PreviewUIView: UIView {
    override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }

    var previewLayer: AVCaptureVideoPreviewLayer {
        layer as! AVCaptureVideoPreviewLayer
    }
}
