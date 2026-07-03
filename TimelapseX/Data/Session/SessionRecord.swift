//
//  SessionRecord.swift
//  TimelapseX
//
//  Created by Prank on 02/07/26.
//

import Foundation

struct SessionRecord: Codable, Identifiable, Equatable {
    let id: String
    let createdAt: Date
    var status: SessionStatus
    var nextSequence: Int
    var photosAlbumIdentifier: String?

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
}
