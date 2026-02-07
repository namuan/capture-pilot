// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "CapturePilot",
    platforms: [
        .macOS(.v12)
    ],
    products: [
        .executable(name: "CapturePilot", targets: ["CapturePilot"])
    ],
    targets: [
        .executableTarget(
            name: "CapturePilot",
            resources: [
                .process("Resources")
            ]
        )
    ]
)
