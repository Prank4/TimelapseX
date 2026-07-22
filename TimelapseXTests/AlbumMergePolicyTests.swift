import Foundation
import Testing
@testable import TimelapseXSessionLogic

struct AlbumMergePolicyTests {
    @Test func framesSortChronologicallyAcrossAlbums() {
        let frames = [
            AlbumMergeFrameSource(albumID: "B", filename: "IMG_000002.jpg", timestamp: Date(timeIntervalSince1970: 30)),
            AlbumMergeFrameSource(albumID: "A", filename: "IMG_000001.jpg", timestamp: Date(timeIntervalSince1970: 10)),
            AlbumMergeFrameSource(albumID: "B", filename: "IMG_000001.jpg", timestamp: Date(timeIntervalSince1970: 20))
        ]

        #expect(AlbumMergePolicy.chronologicallySorted(frames).map(\.timestamp) == [
            Date(timeIntervalSince1970: 10),
            Date(timeIntervalSince1970: 20),
            Date(timeIntervalSince1970: 30)
        ])
    }

    @Test func equalDatesHaveDeterministicOrdering() {
        let date = Date(timeIntervalSince1970: 10)
        let frames = [
            AlbumMergeFrameSource(albumID: "B", filename: "IMG_000001.jpg", timestamp: date),
            AlbumMergeFrameSource(albumID: "A", filename: "IMG_000002.jpg", timestamp: date),
            AlbumMergeFrameSource(albumID: "A", filename: "IMG_000001.jpg", timestamp: date)
        ]

        #expect(AlbumMergePolicy.chronologicallySorted(frames).map(\.filename) == [
            "IMG_000001.jpg",
            "IMG_000002.jpg",
            "IMG_000001.jpg"
        ])
        #expect(AlbumMergePolicy.chronologicallySorted(frames).map(\.albumID) == ["A", "A", "B"])
    }

    @Test func outputFilenamesAreSequential() {
        #expect(AlbumMergePolicy.outputFilename(forZeroBasedIndex: 0) == "IMG_000001.jpg")
        #expect(AlbumMergePolicy.outputFilename(forZeroBasedIndex: 41) == "IMG_000042.jpg")
    }

    @Test func mostRecentFrameReturnsLatestTimestamp() {
        let frames = [
            AlbumMergeFrameSource(albumID: "A", filename: "IMG_000001.jpg", timestamp: Date(timeIntervalSince1970: 10)),
            AlbumMergeFrameSource(albumID: "B", filename: "IMG_000001.jpg", timestamp: Date(timeIntervalSince1970: 30)),
            AlbumMergeFrameSource(albumID: "A", filename: "IMG_000002.jpg", timestamp: Date(timeIntervalSince1970: 20))
        ]

        #expect(AlbumMergePolicy.mostRecentFrame(in: frames)?.albumID == "B")
    }
}
