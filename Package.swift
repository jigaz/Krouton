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
        .library(name: "OpticalDough", targets: ["OpticalDough"]),
        .library(name: "Marmalade", targets: ["Marmalade"]),
        .library(name: "Tartine", targets: ["Tartine"]),
        .library(name: "VideoOven", targets: ["VideoOven"]),
        .library(name: "Galette", targets: ["Galette"]),
        .library(name: "Crustini", targets: ["Crustini"])
    ],
    targets: [
        .target(name: "OpticalDough"),
        .target(name: "Marmalade", dependencies: ["OpticalDough"]),
        .target(name: "Tartine", dependencies: ["OpticalDough"]),
        .target(name: "VideoOven", dependencies: ["OpticalDough"]),
        .target(name: "Galette", dependencies: ["OpticalDough"]),
        .target(name: "Crustini", dependencies: ["OpticalDough"]),
        .executableTarget(
            name: "KroutonApp",
            dependencies: [
                "OpticalDough",
                "Marmalade",
                "Tartine",
                "VideoOven",
                "Galette",
                "Crustini"
            ]
        ),
        .executableTarget(
            name: "KroutonVerify",
            dependencies: [
                "OpticalDough",
                "Marmalade",
                "Tartine",
                "VideoOven",
                "Galette",
                "Crustini"
            ]
        ),
        .testTarget(
            name: "KroutonTests",
            dependencies: [
                "OpticalDough",
                "Marmalade",
                "Tartine",
                "VideoOven",
                "Galette",
                "Crustini"
            ]
        )
    ]
)
