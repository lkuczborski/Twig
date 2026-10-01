// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Twig",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "Twig", targets: ["Twig"]),
        .executable(name: "TwigInspect", targets: ["TwigInspect"]),
        .library(name: "TwigCore", targets: ["TwigCore"])
    ],
    targets: [
        .target(name: "TwigCore"),
        .target(name: "TwigSync"),
        .executableTarget(name: "Twig", dependencies: ["TwigCore", "TwigSync"]),
        .executableTarget(name: "TwigInspect", dependencies: ["TwigCore"]),
        .testTarget(name: "TwigCoreTests", dependencies: ["TwigCore"]),
        .testTarget(name: "TwigSyncTests", dependencies: ["TwigSync"])
    ]
)
