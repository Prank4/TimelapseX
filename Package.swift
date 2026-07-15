// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "TimelapseXSessionLogic",
    platforms: [.macOS(.v14), .iOS(.v18)],
    products: [
        .library(
            name: "TimelapseXLogic",
            targets: ["TimelapseXSessionLogic", "TimelapseXGalleryLogic"]
        )
    ],
    targets: [
        .target(
            name: "TimelapseXSessionLogic",
            path: "TimelapseX/Data/Session",
            exclude: [
                "CaptureLogEntry.swift",
                "SessionRecord.swift",
                "SessionStatus.swift",
                "SessionStore.swift"
            ],
            sources: ["SessionRotationPolicy.swift"]
        ),
        .target(
            name: "TimelapseXGalleryLogic",
            path: "TimelapseX/Features/Gallery",
            exclude: [
                "GalleryView.swift",
                "PhotosSaveAction.swift",
                "SessionDetailView.swift",
                "TimelapseExporter.swift"
            ],
            sources: ["GalleryGridLayoutPolicy.swift", "GalleryImageLoader.swift"]
        ),
        .testTarget(
            name: "TimelapseXSessionLogicTests",
            dependencies: ["TimelapseXSessionLogic", "TimelapseXGalleryLogic"],
            path: "TimelapseXTests"
        )
    ]
)
