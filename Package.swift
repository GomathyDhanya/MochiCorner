// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ScreenShire",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "ScreenShire", targets: ["ScreenShire"])],
    targets: [
        .executableTarget(name: "ScreenShire", resources: [.process("Resources")]),
        .testTarget(name: "ScreenShireTests", dependencies: ["ScreenShire"])
    ]
)
