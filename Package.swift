// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "ClaudeWatch",
    platforms: [
        .macOS(.v13)
    ],
    targets: [
        .executableTarget(
            name: "ClaudeWatch",
            path: "Sources/ClaudeWatch"
        ),
        .testTarget(
            name: "ClaudeWatchTests",
            dependencies: ["ClaudeWatch"],
            path: "Tests/ClaudeWatchTests"
        )
    ]
)
