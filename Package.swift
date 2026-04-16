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
    targets: [
        .target(name: "SlamDihCore"),
        .executableTarget(
            name: "SlamDih",
            dependencies: ["SlamDihCore"],
            resources: [
                .copy("Resources/SlapSoundEffect.mp3"),
                .copy("Resources/FartSoundEffect.mp3")
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
