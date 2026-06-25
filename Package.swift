// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "LowWhisper",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "LowWhisper", targets: ["LowWhisper"])
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "LowWhisper",
            dependencies: [
                "whisper"
            ],
            path: "Sources/LowWhisper",
            swiftSettings: [
                .enableUpcomingFeature("BareSlashRegexLiterals")
            ]
        ),
        .binaryTarget(
            name: "whisper",
            path: "Frameworks/whisper.xcframework"
        )
    ]
)
