// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SuaveScroll",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "SuaveScroll",
            path: "Sources/SuaveScroll"
        )
    ]
)
