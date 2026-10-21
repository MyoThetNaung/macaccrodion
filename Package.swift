// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Accordion",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "Accordion", targets: ["Accordion"])
    ],
    targets: [
        .executableTarget(
            name: "Accordion",
            resources: [
                .process("Resources")
            ],
            linkerSettings: [
                .linkedFramework("IOKit"),
                .linkedFramework("AVFoundation"),
                .linkedFramework("AppKit"),
                .linkedFramework("SwiftUI"),
            ]
        )
    ]
)
