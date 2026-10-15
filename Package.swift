// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "DegenerationGuardKit",
    platforms: [
        .macOS(.v13),
        .iOS(.v16),
        .tvOS(.v16),
        .watchOS(.v9)
    ],
    products: [
        .library(name: "DegenerationGuardKit", targets: ["DegenerationGuardKit"]),
        .executable(name: "DegenerationGuardDemo", targets: ["DegenerationGuardDemo"])
    ],
    targets: [
        .target(name: "DegenerationGuardKit"),
        .executableTarget(
            name: "DegenerationGuardDemo",
            dependencies: ["DegenerationGuardKit"]
        ),
        .testTarget(
            name: "DegenerationGuardKitTests",
            dependencies: ["DegenerationGuardKit"]
        )
    ],
    swiftLanguageModes: [.v6]
)
