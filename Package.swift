// swift-tools-version: 6.1

import PackageDescription

var package = Package(
    name: "NimbusMetaKit",
    platforms: [.iOS(.v13)],
    products: [
        .library(
           name: "NimbusMetaKit",
           targets: ["NimbusMetaKit"])
    ],
    dependencies: [
        .package(url: "https://github.com/facebook/FBAudienceNetwork", from: "6.21.0"),
    ],
    targets: [
        .target(
            name: "NimbusMetaKit",
            dependencies: [
                .product(name: "NimbusKit", package: "nimbus-ios-sdk"),
                .product(name: "FBAudienceNetwork", package: "FBAudienceNetwork")
            ]
        ),
        .testTarget(
            name: "NimbusMetaKitTests",
            dependencies: ["NimbusMetaKit"],
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ]
        ),
    ]
)

package.dependencies.append(.package(url: "https://github.com/adsbynimbus/nimbus-ios-sdk", from: "3.0.0"))
