// swift-tools-version: 6.0
import PackageDescription

let strictSwiftSettings: [SwiftSetting] = [
    .swiftLanguageMode(.v6),
    .unsafeFlags(["-warnings-as-errors"])
]

let package = Package(
    name: "krouton",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14),
        // Only the portable libraries (krouton-verify Suite 31) are built for iPadOS, by CI.
        .iOS(.v17)
    ],
    products: [
        .executable(name: "Krouton", targets: ["KroutonMain"]),
        // The app as a library, for the Xcode project's app target (XcodeHost/project.yml).
        .library(name: "KroutonApp", targets: ["KroutonApp"]),
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
        .target(name: "OpticalCore", swiftSettings: strictSwiftSettings),
        .target(name: "DriveKit", dependencies: ["OpticalCore"], swiftSettings: strictSwiftSettings),
        .target(name: "BurnKit", dependencies: ["OpticalCore", "DriveKit", "ImageKit"], swiftSettings: strictSwiftSettings),
        .target(name: "AudioKit", dependencies: ["OpticalCore"], swiftSettings: strictSwiftSettings),
        .target(name: "ImageKit", dependencies: ["OpticalCore"], swiftSettings: strictSwiftSettings),
        .target(name: "RescueKit", dependencies: ["OpticalCore"], swiftSettings: strictSwiftSettings),
        .target(name: "LabelKit", dependencies: ["OpticalCore", "AudioKit", "RescueKit"], swiftSettings: strictSwiftSettings),
        .target(name: "VideoKit", dependencies: ["OpticalCore"], swiftSettings: strictSwiftSettings),
        .target(name: "NetworkSpool", dependencies: ["OpticalCore"], swiftSettings: strictSwiftSettings),
        .target(name: "Persistence", dependencies: ["OpticalCore"], swiftSettings: strictSwiftSettings),
        .executableTarget(name: "KroutonMain", dependencies: ["KroutonApp"], swiftSettings: strictSwiftSettings),
        .target(
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
            ],
            resources: [
                .process("Resources")
            ],
            swiftSettings: strictSwiftSettings
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
            ],
            swiftSettings: strictSwiftSettings
        ),
        .testTarget(name: "OpticalCoreTests", dependencies: ["OpticalCore"], swiftSettings: strictSwiftSettings),
        .testTarget(name: "BurnKitTests", dependencies: ["OpticalCore", "DriveKit", "BurnKit"], swiftSettings: strictSwiftSettings),
        .testTarget(name: "AudioKitTests", dependencies: ["OpticalCore", "AudioKit"], swiftSettings: strictSwiftSettings),
        .testTarget(name: "ImageKitTests", dependencies: ["OpticalCore", "ImageKit"], swiftSettings: strictSwiftSettings),
        .testTarget(name: "RescueKitTests", dependencies: ["OpticalCore", "RescueKit"], swiftSettings: strictSwiftSettings),
        .testTarget(name: "LabelKitTests", dependencies: ["OpticalCore", "AudioKit", "RescueKit", "LabelKit"], swiftSettings: strictSwiftSettings),
        .testTarget(name: "VideoKitTests", dependencies: ["OpticalCore", "VideoKit"], swiftSettings: strictSwiftSettings),
        .testTarget(name: "PersistenceTests", dependencies: ["OpticalCore", "Persistence"], swiftSettings: strictSwiftSettings),
        .testTarget(name: "KroutonVerifyTests", dependencies: ["KroutonVerify"], swiftSettings: strictSwiftSettings)
    ]
)
