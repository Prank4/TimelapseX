//
//  SessionStore.swift
//  TimelapseX
//
//  Created by Prank on 02/07/26.
//

import Foundation
import Combine

final class SessionStore: ObservableObject {
    nonisolated static let sharedSessionsDirectory = FileManager.default
        .urls(for: .applicationSupportDirectory, in: .userDomainMask)
        .first!
        .appendingPathComponent("Sessions", isDirectory: true)

    @Published private(set) var activeSession: SessionRecord
    @Published private(set) var allSessions: [SessionRecord] = []
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

        self.allSessions = (try? Self.loadAllSessions(using: fileManager, decoder: decoder)) ?? []
    }

    // MARK: - Capture

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
        if outcome == .success {
            activeSession.lastCaptureAt = capturedAt
        }
        try Self.persistSession(activeSession, using: fileManager, encoder: encoder)
        refreshAllSessions()
    }

    func captureURL(for sequenceNumber: Int) -> URL {
        activeSession.folderURL.appendingPathComponent(String(format: "IMG_%06d.jpg", sequenceNumber))
    }

    // MARK: - Session Lifecycle

    /// Marks `session` as `.saved`, stores the Photos album identifier, persists the record,
    /// and immediately rotates to a fresh active session.
    func saveSession(_ session: SessionRecord, albumIdentifier: String) throws {
        var updated = session
        updated.status = .saved
        updated.photosAlbumIdentifier = albumIdentifier
        try Self.persistSession(updated, using: fileManager, encoder: encoder)
        if updated.id == activeSession.id {
            try rotateToNewSession()
        } else {
            refreshAllSessions()
        }
    }

    /// Deletes the session folder from disk. If it was the active session, rotates to a new one.
    func discardSession(_ session: SessionRecord) throws {
        if fileManager.fileExists(atPath: session.folderURL.path) {
            try fileManager.removeItem(at: session.folderURL)
        }
        if session.id == activeSession.id {
            try rotateToNewSession()
        } else {
            refreshAllSessions()
        }
    }

    func startNewSession() throws {
        var current = activeSession
        current.status = .closed
        try Self.persistSession(current, using: fileManager, encoder: encoder)
        try rotateToNewSession()
    }

    @discardableResult
    func rotateActiveSessionIfInactive(
        now: Date = Date(),
        inactivityInterval: TimeInterval = SessionRotationPolicy.inactivityInterval
    ) throws -> Bool {
        let frameCount = activeSession.frameCount
        let lastCaptureAt = activeSession.lastCaptureAt ?? mostRecentFrameDate(in: activeSession)
        guard SessionRotationPolicy.shouldRotate(
            frameCount: frameCount,
            lastCaptureAt: lastCaptureAt,
            now: now,
            inactivityInterval: inactivityInterval
        ) else {
            return false
        }

        try startNewSession()
        return true
    }

    func activeSessionInactivityDeadline(
        inactivityInterval: TimeInterval = SessionRotationPolicy.inactivityInterval
    ) -> Date? {
        SessionRotationPolicy.deadline(
            frameCount: activeSession.frameCount,
            lastCaptureAt: activeSession.lastCaptureAt ?? mostRecentFrameDate(in: activeSession),
            inactivityInterval: inactivityInterval
        )
    }

    func updateFrameDurationSeconds(_ duration: Double, for session: SessionRecord) throws {
        var updated = session
        updated.frameDurationSeconds = SessionRecord.clampedFrameDuration(duration)
        try Self.persistSession(updated, using: fileManager, encoder: encoder)

        if updated.id == activeSession.id {
            activeSession = updated
        }

        refreshAllSessions()
    }

    func deleteFrame(at url: URL, in session: SessionRecord) throws {
        try deleteFrames(at: [url], in: session)
    }

    func deleteFrames(at urls: [URL], in session: SessionRecord) throws {
        let uniqueURLs = Array(Set(urls))
        guard !uniqueURLs.isEmpty else { return }

        for url in uniqueURLs {
            try validateFrameURL(url, in: session)
        }

        for url in uniqueURLs {
            try fileManager.removeItem(at: url)
        }
        refreshAllSessions()
    }

    private func validateFrameURL(_ url: URL, in session: SessionRecord) throws {
        let frameFolder = url.deletingLastPathComponent().standardizedFileURL
        let sessionFolder = session.folderURL.standardizedFileURL
        guard frameFolder == sessionFolder else {
            throw NSError(
                domain: "TimelapseX.SessionStore",
                code: 201,
                userInfo: [NSLocalizedDescriptionKey: "This frame does not belong to the selected session."]
            )
        }
        guard url.lastPathComponent.hasPrefix("IMG_"), url.pathExtension.lowercased() == "jpg" else {
            throw NSError(
                domain: "TimelapseX.SessionStore",
                code: 202,
                userInfo: [NSLocalizedDescriptionKey: "Only captured JPG frames can be deleted."]
            )
        }
        guard fileManager.fileExists(atPath: url.path) else {
            throw NSError(
                domain: "TimelapseX.SessionStore",
                code: 203,
                userInfo: [NSLocalizedDescriptionKey: "This frame no longer exists on disk."]
            )
        }
    }

    /// Creates a new active session, persists it, and refreshes `allSessions`.
    func rotateToNewSession() throws {
        let newSession = Self.makeNewSession()
        try Self.prepareSessionsDirectory(using: fileManager)
        try Self.ensureSessionFolder(newSession, using: fileManager)
        try Self.persistSession(newSession, using: fileManager, encoder: encoder)
        activeSession = newSession
        refreshAllSessions()
    }

    // MARK: - Private helpers

    private func refreshAllSessions() {
        allSessions = (try? Self.loadAllSessions(using: fileManager, decoder: decoder)) ?? []
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

    static func loadAllSessions(using fileManager: FileManager, decoder: JSONDecoder) throws -> [SessionRecord] {
        let contents = try fileManager.contentsOfDirectory(
            at: sharedSessionsDirectory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )

        var sessions: [SessionRecord] = []
        for folderURL in contents {
            let sessionJSONURL = folderURL.appendingPathComponent("session.json")
            guard fileManager.fileExists(atPath: sessionJSONURL.path) else { continue }
            guard let data = try? Data(contentsOf: sessionJSONURL),
                  let session = try? decoder.decode(SessionRecord.self, from: data) else { continue }
            sessions.append(session)
        }

        return sessions.sorted { $0.createdAt > $1.createdAt }
    }

    private static func persistSession(_ session: SessionRecord, using fileManager: FileManager, encoder: JSONEncoder) throws {
        let persisted = PersistedSession(
            id: session.id,
            createdAt: session.createdAt,
            status: session.status,
            nextSequence: session.nextSequence,
            photosAlbumIdentifier: session.photosAlbumIdentifier,
            frameDurationSeconds: session.frameDurationSeconds,
            lastCaptureAt: session.lastCaptureAt
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
            photosAlbumIdentifier: nil,
            lastCaptureAt: nil
        )
    }

    private func mostRecentFrameDate(in session: SessionRecord) -> Date? {
        let frameURLs = (try? fileManager.contentsOfDirectory(
            at: session.folderURL,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        )) ?? []

        return frameURLs
            .filter { $0.lastPathComponent.hasPrefix("IMG_") && $0.pathExtension.lowercased() == "jpg" }
            .compactMap { try? $0.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate }
            .max()
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
    let photosAlbumIdentifier: String?
    let frameDurationSeconds: Double?
    let lastCaptureAt: Date?
}
