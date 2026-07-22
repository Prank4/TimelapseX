//
//  AlbumMergePolicy.swift
//  TimelapseX
//
//  Created by Prank on 17/07/26.
//

import Foundation

struct AlbumMergeFrameSource: Equatable, Sendable {
    let albumID: String
    let filename: String
    let timestamp: Date
}

enum AlbumMergePolicy {
    nonisolated static func chronologicallySorted(
        _ frames: [AlbumMergeFrameSource]
    ) -> [AlbumMergeFrameSource] {
        frames.sorted { lhs, rhs in
            if lhs.timestamp != rhs.timestamp {
                return lhs.timestamp < rhs.timestamp
            }
            if lhs.albumID != rhs.albumID {
                return lhs.albumID < rhs.albumID
            }
            return lhs.filename < rhs.filename
        }
    }

    nonisolated static func outputFilename(forZeroBasedIndex index: Int) -> String {
        String(format: "IMG_%06d.jpg", index + 1)
    }

    nonisolated static func mostRecentFrame(
        in frames: [AlbumMergeFrameSource]
    ) -> AlbumMergeFrameSource? {
        chronologicallySorted(frames).last
    }
}
