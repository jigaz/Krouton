// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "krouton",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "Krouton", targets: ["KroutonApp"]),
        .executable(name: "krouton-verify", targets: ["KroutonVerify"]),
        .library(name: "OpticalCore", targets: ["OpticalCore"]),
        .library(name: "DriveKit", targets: ["DriveKit"]),
        .library(name: "BurnKit", targets: ["BurnKit"]),
        .library(name: "AudioKit", targets: ["AudioKit"]),
        .library(name: "ImageKit", targets: ["ImageKit"]),
        .library(name: "RescueKit", targets: ["RescueKit"]),
        .library(name: "LabelKit", targets: ["LabelKit"]),
        .library(name: "VideoKit", targets: ["VideoKit"]),
        .library(name: "NetworkSpool", targets: ["NetworkSpool"]),
        .library(name: "Persistence", targets: ["Persistence"])
    ],
    targets: [
        .target(name: "OpticalCore"),
        .target(name: "DriveKit", dependencies: ["OpticalCore"]),
        .target(name: "BurnKit", dependencies: ["OpticalCore", "DriveKit", "ImageKit"]),
        .target(name: "AudioKit", dependencies: ["OpticalCore"]),
        .target(name: "ImageKit", dependencies: ["OpticalCore"]),
        .target(name: "RescueKit", dependencies: ["OpticalCore"]),
        .target(name: "LabelKit", dependencies: ["OpticalCore", "AudioKit", "RescueKit"]),
        .target(name: "VideoKit", dependencies: ["OpticalCore"]),
        .target(name: "NetworkSpool", dependencies: ["OpticalCore"]),
        .target(name: "Persistence", dependencies: ["OpticalCore"]),
        .executableTarget(
            name: "KroutonApp",
            dependencies: [
                "OpticalCore",
                "DriveKit",
                "BurnKit",
                "AudioKit",
                "ImageKit",
                "RescueKit",
                "LabelKit",
                "VideoKit",
                "NetworkSpool",
                "Persistence"
            ]
        ),
        .executableTarget(
            name: "KroutonVerify",
            dependencies: [
                "OpticalCore",
                "DriveKit",
                "BurnKit",
                "AudioKit",
                "ImageKit",
                "RescueKit",
                "LabelKit",
                "VideoKit",
                "NetworkSpool",
                "Persistence"
            ]
        ),
        .testTarget(name: "OpticalCoreTests", dependencies: ["OpticalCore"]),
        .testTarget(name: "BurnKitTests", dependencies: ["OpticalCore", "DriveKit", "BurnKit"]),
        .testTarget(name: "AudioKitTests", dependencies: ["OpticalCore", "AudioKit"]),
        .testTarget(name: "ImageKitTests", dependencies: ["OpticalCore", "ImageKit"]),
        .testTarget(name: "RescueKitTests", dependencies: ["OpticalCore", "RescueKit"]),
        .testTarget(name: "LabelKitTests", dependencies: ["OpticalCore", "AudioKit", "RescueKit", "LabelKit"]),
        .testTarget(name: "VideoKitTests", dependencies: ["OpticalCore", "VideoKit"]),
        .testTarget(name: "PersistenceTests", dependencies: ["OpticalCore", "Persistence"])
    ]
)
