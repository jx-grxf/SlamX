// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "SlamDih",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "SlamDih", targets: ["SlamDih"]),
        .library(name: "SlamDihCore", targets: ["SlamDihCore"])
    ],
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.7.3")
    ],
    targets: [
        .target(name: "SlamDihCore"),
        .executableTarget(
            name: "SlamDih",
            dependencies: [
                "SlamDihCore",
                .product(name: "Sparkle", package: "Sparkle")
            ],
            resources: [
                .copy("Resources/SlapSoundEffect.mp3"),
                .copy("Resources/FartSoundEffect.mp3"),
                .copy("Resources/SexySoundEffect.mp3"),
                .copy("Resources/YowchSoundEffect.mp3")
            ],
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("AVFoundation"),
                .linkedFramework("IOKit")
            ]
        ),
        .testTarget(
            name: "SlamDihCoreTests",
            dependencies: ["SlamDihCore"]
        )
    ]
)
