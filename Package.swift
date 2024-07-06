// swift-tools-version:5.7

import PackageDescription

let name = "MMDB"

let package = Package(
    name: name,
    platforms: [
        .macOS(.v10_15), .iOS(.v13)
    ],
    products: [
        .library(name: name, targets: [name])
    ],
    dependencies: [],
    targets: [
        .target(
            name: name,
            dependencies: ["libmaxminddb"]
        ),
        
        .target(name: "libmaxminddb"),
        
        .testTarget(
            name: "\(name)Tests",
            dependencies: [.target(name: name)],
            resources: [
                .copy("Resources/GeoLite2-Country.mmdb")
            ]
        )
    ]
)
