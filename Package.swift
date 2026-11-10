// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Krouton",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v15)
    ],
    products: [
        .executable(name: "Krouton", targets: ["KroutonApp"]),
        .library(name: "OpticalDough", targets: ["OpticalDough"]),
        .library(name: "Marmalade", targets: ["Marmalade"]),
        .library(name: "VideoOven", targets: ["VideoOven"]),
        .library(name: "Tartine", targets: ["Tartine"]),
        .library(name: "Galette", targets: ["Galette"]),
        .library(name: "Crustini", targets: ["Crustini"])
    ],
    targets: [
        .target(name: "OpticalDough"),
        .target(name: "Marmalade", dependencies: ["OpticalDough"]),
        .target(name: "VideoOven", dependencies: ["OpticalDough"]),
        .target(name: "Tartine", dependencies: ["OpticalDough"]),
        .target(name: "Galette", dependencies: ["OpticalDough"]),
        .target(name: "Crustini", dependencies: ["OpticalDough"]),
        .executableTarget(
            name: "KroutonApp",
            dependencies: [
                "OpticalDough",
                "Marmalade",
                "VideoOven",
                "Tartine",
                "Galette",
                "Crustini"
            ],
            resources: [
                .process("Resources")
            ]
        )
    ]
)
