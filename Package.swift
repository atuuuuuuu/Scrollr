// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Scrollr",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(name: "Scrollr", path: "Sources/Scrollr"),
        .testTarget(name: "ScrollrTests", dependencies: ["Scrollr"], path: "Tests/ScrollrTests"),
    ]
)
