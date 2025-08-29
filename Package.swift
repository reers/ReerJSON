// swift-tools-version: 5.10
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

#if os(Linux)
let packageDependencies: [Package.Dependency] = [
    .package(
        url: "https://github.com/ibireme/yyjson.git",
        from: "0.11.1"
    ),
]
#else
let packageDependencies: [Package.Dependency] = [
    .package(
        url: "https://github.com/ibireme/yyjson.git",
        from: "0.12.0"
    ),
    .package(
        url: "https://github.com/michaeleisel/JJLISO8601DateFormatter.git",
        from: "0.1.8"
    ),
]
#endif

#if os(Linux)
let targetDependencies: [Target.Dependency] = [
    .product(
        name: "yyjson",
        package: "yyjson"
    ),
]
#else
let targetDependencies: [Target.Dependency] = [
    .product(
        name: "yyjson",
        package: "yyjson"
    ),
    .product(
        name: "JJLISO8601DateFormatter",
        package: "JJLISO8601DateFormatter"
    ),
]
#endif

let package = Package(
    name: "ReerJSON",
    platforms: [
        .macOS(.v10_13),
        .iOS(.v12),
        .tvOS(.v12),
        .watchOS(.v6),
        .macCatalyst(.v13),
        .visionOS(.v1)
    ],
    products: [
        .library(
            name: "ReerJSON",
            targets: ["ReerJSON"]),
    ],
    dependencies: packageDependencies,
    targets: [
        .target(
            name: "ReerJSON",
            dependencies: targetDependencies
        ),
        .testTarget(
            name: "ReerJSONTests",
            dependencies: ["ReerJSON"],
            resources: [
                .copy("Models/apache_builds.json"),
                .copy("Models/canada.json"),
                .copy("Models/entities.json"),
                .copy("Models/github_events.json"),
                .copy("Models/marine_ik.json"),
                .copy("Models/mesh.json"),
                .copy("Models/numbers.json"),
                .copy("Models/random.json"),
                .copy("Models/twitter.json"),
                .copy("Models/twitter2.json"),
                .copy("Models/twitterescaped.json")
            ]
        )
    ]
)
