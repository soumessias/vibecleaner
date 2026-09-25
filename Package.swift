// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "VibeCleaner",
    defaultLocalization: "en",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "VibeCleaner", targets: ["VibeCleaner"])
    ],
    targets: [
        .executableTarget(
            name: "VibeCleaner",
            resources: [.process("Resources")]
        )
    ]
)
