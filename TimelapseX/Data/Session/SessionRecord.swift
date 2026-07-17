//
//  SessionRecord.swift
//  TimelapseX
//
//  Created by Prank on 02/07/26.
//

import Foundation

struct SessionRecord: Codable, Identifiable, Equatable {
    nonisolated static let defaultFrameDurationSeconds = FrameDurationPolicy.defaultGlobalDuration
    nonisolated static let minimumFrameDurationSeconds = FrameDurationPolicy.minimumGlobalDuration
    nonisolated static let maximumFrameDurationSeconds = FrameDurationPolicy.maximumGlobalDuration

    let id: String
    let createdAt: Date
    var status: SessionStatus
    var nextSequence: Int
    var photosAlbumIdentifier: String?
    var frameDurationSeconds: Double
    var frameDurationOverrides: [String: Double]
    var lastCaptureAt: Date?

    init(
        id: String,
        createdAt: Date,
        status: SessionStatus,
        nextSequence: Int,
        photosAlbumIdentifier: String?,
        frameDurationSeconds: Double = Self.defaultFrameDurationSeconds,
        frameDurationOverrides: [String: Double] = [:],
        lastCaptureAt: Date? = nil
    ) {
        self.id = id
        self.createdAt = createdAt
        self.status = status
        self.nextSequence = nextSequence
        self.photosAlbumIdentifier = photosAlbumIdentifier
        self.frameDurationSeconds = Self.clampedFrameDuration(frameDurationSeconds)
        self.frameDurationOverrides = frameDurationOverrides.mapValues(FrameDurationPolicy.clampedOverride)
        self.lastCaptureAt = lastCaptureAt
    }

    enum CodingKeys: String, CodingKey {
        case id
        case createdAt
        case status
        case nextSequence
        case photosAlbumIdentifier
        case frameDurationSeconds
        case frameDurationOverrides
        case lastCaptureAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        status = try container.decode(SessionStatus.self, forKey: .status)
        nextSequence = try container.decode(Int.self, forKey: .nextSequence)
        photosAlbumIdentifier = try container.decodeIfPresent(String.self, forKey: .photosAlbumIdentifier)
        let duration = try container.decodeIfPresent(Double.self, forKey: .frameDurationSeconds) ?? Self.defaultFrameDurationSeconds
        frameDurationSeconds = Self.clampedFrameDuration(duration)
        let overrides = try container.decodeIfPresent([String: Double].self, forKey: .frameDurationOverrides) ?? [:]
        frameDurationOverrides = overrides.mapValues(FrameDurationPolicy.clampedOverride)
        lastCaptureAt = try container.decodeIfPresent(Date.self, forKey: .lastCaptureAt)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(status, forKey: .status)
        try container.encode(nextSequence, forKey: .nextSequence)
        try container.encodeIfPresent(photosAlbumIdentifier, forKey: .photosAlbumIdentifier)
        try container.encode(frameDurationSeconds, forKey: .frameDurationSeconds)
        try container.encode(frameDurationOverrides, forKey: .frameDurationOverrides)
        try container.encodeIfPresent(lastCaptureAt, forKey: .lastCaptureAt)
    }

    nonisolated var folderName: String { id }
    nonisolated var folderURL: URL { Self.sessionsDirectory.appendingPathComponent(folderName, isDirectory: true) }
    nonisolated var sessionJSONURL: URL { folderURL.appendingPathComponent("session.json") }
    nonisolated var captureLogURL: URL { folderURL.appendingPathComponent("capture_log.txt") }

    var frameCount: Int {
        let contents = (try? FileManager.default.contentsOfDirectory(
            at: folderURL,
            includingPropertiesForKeys: nil
        )) ?? []

        return contents.filter { $0.lastPathComponent.hasPrefix("IMG_") && $0.pathExtension.lowercased() == "jpg" }.count
    }

    nonisolated static var sessionsDirectory: URL {
        SessionStore.sharedSessionsDirectory
    }

    nonisolated static func clampedFrameDuration(_ value: Double) -> Double {
        FrameDurationPolicy.clampedGlobal(value)
    }
}
