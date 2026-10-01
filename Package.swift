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
        .executableTarget(name: "Twig", dependencies: ["TwigCore"]),
        .executableTarget(name: "TwigInspect", dependencies: ["TwigCore"]),
        .testTarget(name: "TwigCoreTests", dependencies: ["TwigCore"])
    ]
)
