import ProjectDescription

let appName = "HelmBriefApp"
let organization = "Ravcon"

let project = Project(
    name: "HelmBrief",
    organizationName: organization,
    packages: [
        .package(path: ".")
    ],
    targets: [
        Target(
            name: appName,
            destinations: .iOS, // iPhone + iPad
            product: .app,
            bundleId: "com.ravcon.HelmBrief",
            deploymentTargets: .iOS("17.0"),
            infoPlist: .extendingDefault(with: [
                "CFBundleDisplayName": .string("HelmBrief"),
                "CFBundleShortVersionString": .string("$(MARKETING_VERSION)"),
                "CFBundleVersion": .string("$(CURRENT_PROJECT_VERSION)"),
                "NSLocationWhenInUseUsageDescription": .string("HelmBrief uses location to improve routing context and map orientation.")
            ]),
            sources: [
                "Sources/HelmBriefApp/**"
            ],
            resources: [
                "Resources/**"
            ],
            dependencies: [
                .package(product: "MarineKit"),
                .package(product: "RoutingKit"),
                .package(product: "BriefingKit")
            ]
        )
    ]
)
