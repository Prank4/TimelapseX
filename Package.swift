// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "TimelapseXSessionLogic",
    platforms: [.iOS(.v18)],
    products: [
        .library(name: "TimelapseXSessionLogic", targets: ["TimelapseXSessionLogic"])
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
        .testTarget(
            name: "TimelapseXSessionLogicTests",
            dependencies: ["TimelapseXSessionLogic"],
            path: "TimelapseXTests"
        )
    ]
)
