// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MiniVPNCore",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "MiniVPNCore", targets: ["MiniVPNCore"]),
    ],
    dependencies: [
        .package(url: "https://github.com/pointfreeco/swift-snapshot-testing", from: "1.17.0"),
    ],
    targets: [
        .target(
            name: "MiniVPNCore",
            resources: [.copy("Resources/Mocks")]
        ),
        .testTarget(
            name: "MiniVPNCoreTests",
            dependencies: [
                "MiniVPNCore",
                .product(name: "SnapshotTesting", package: "swift-snapshot-testing"),
            ]
        ),
    ]
)
