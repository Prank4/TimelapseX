//
//  SessionStore.swift
//  TimelapseX
//
//  Created by Prank on 02/07/26.
//

import Foundation
import Combine

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
