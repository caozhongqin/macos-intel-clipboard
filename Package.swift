// swift-tools-version:5.7
import PackageDescription

let package = Package(
    name: "ClipboardHistory",
    platforms: [
        .macOS(.v12)
    ],
    targets: [
        .executableTarget(
            name: "ClipboardHistory",
            path: "Sources/ClipboardHistory"
        )
    ]
)
