// swift-tools-version: 6.4
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

#if os(Linux)
let packageDependencies: [Package.Dependency] = [
    .package(
        url: "https://github.com/ibireme/yyjson.git",
        from: "0.13.0"
    ),
]
#else
let packageDependencies: [Package.Dependency] = [
    .package(
        url: "https://github.com/ibireme/yyjson.git",
        from: "0.13.0"
    ),
    .package(
        url: "https://github.com/michaeleisel/JJLISO8601DateFormatter.git",
        from: "0.2.0"
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
        .macOS(.v12),
        .iOS(.v15),
        .tvOS(.v15),
        .watchOS(.v9),
        .macCatalyst(.v15),
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
            exclude: [
                "Info.plist",
                "Models/instruments.json",
                "Models/json_to_swift.rb",
            ],
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
                .copy("Models/twitterescaped.json"),
                .copy("Resources")
            ]
        )
    ]
)
