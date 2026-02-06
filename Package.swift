// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "HelmBrief",
    platforms: [
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "MarineKit",
            targets: ["MarineKit"]
        ),
        .library(
            name: "RoutingKit",
            targets: ["RoutingKit"]
        ),
        .library(
            name: "BriefingKit",
            targets: ["BriefingKit"]
        ),
        .library(
            name: "HelmBriefApp",
            targets: ["HelmBriefApp"]
        )
    ],
    dependencies: [
        // Add dependencies here as you adopt real data providers or third‑party utilities.
    ],
    targets: [
        .target(
            name: "MarineKit",
            dependencies: []
        ),
        .target(
            name: "RoutingKit",
            dependencies: ["MarineKit"]
        ),
        .target(
            name: "BriefingKit",
            dependencies: ["MarineKit", "RoutingKit"]
        ),
        .target(
            name: "HelmBriefApp",
            dependencies: ["MarineKit", "RoutingKit", "BriefingKit"]
        ),
        .testTarget(
            name: "MarineKitTests",
            dependencies: ["MarineKit"]
        ),
        .testTarget(
            name: "RoutingKitTests",
            dependencies: ["RoutingKit"]
        ),
        .testTarget(
            name: "BriefingKitTests",
            dependencies: ["BriefingKit"]
        )
    ]
)