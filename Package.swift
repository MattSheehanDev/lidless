// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "Lidless",
    platforms: [.macOS(.v14)],
    targets: [
        .target(
            name: "LidlessCore",
            path: "Sources/LidlessCore"
        ),
        .executableTarget(
            name: "Lidless",
            dependencies: ["LidlessCore"],
            path: "Sources/Lidless"
        ),
        .testTarget(
            name: "LidlessCoreTests",
            dependencies: ["LidlessCore"],
            path: "Tests/LidlessCoreTests"
        ),
    ]
)
