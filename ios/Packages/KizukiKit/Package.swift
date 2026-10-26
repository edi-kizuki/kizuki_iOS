// swift-tools-version: 6.0
import PackageDescription

let features = ["Onboarding", "Home", "Search", "Suki", "MyProjects", "Profile", "Chat", "Settings"]

let package = Package(
    name: "KizukiKit",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "KizukiCore", targets: ["KizukiCore"]),
        .library(name: "KizukiInfrastructure", targets: ["KizukiInfrastructure"]),
        .library(name: "KizukiDesignSystem", targets: ["KizukiDesignSystem"]),
        .library(name: "KizukiFoundationFeature", targets: ["KizukiFoundationFeature"]),
        .library(name: "KizukiTestSupport", targets: ["KizukiTestSupport"])
    ] + features.map { .library(name: "Kizuki\($0)Feature", targets: ["Kizuki\($0)Feature"]) },
    dependencies: [
        .package(url: "https://github.com/supabase/supabase-swift.git", exact: "2.55.4")
    ],
    targets: [
        .target(name: "KizukiCore"),
        .target(name: "KizukiInfrastructure", dependencies: [
            "KizukiCore", .product(name: "Supabase", package: "supabase-swift")
        ]),
        .target(name: "KizukiDesignSystem", resources: [.process("Resources")]),
        .target(name: "KizukiFoundationFeature", dependencies: ["KizukiCore", "KizukiDesignSystem"]),
        // Fixtures and the in-memory backend. Every source file is wrapped in #if DEBUG.
        // The prototype feature targets below follow the same rule (scripts/check-release-artifact.py enforces it).
        .target(name: "KizukiTestSupport", dependencies: ["KizukiCore"])
    ] + features.map { .target(name: "Kizuki\($0)Feature", dependencies: ["KizukiCore", "KizukiDesignSystem"]) }
)
