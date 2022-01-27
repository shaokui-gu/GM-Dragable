// swift-tools-version:5.5
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "GM+Dragable",
    platforms: [.iOS(.v11)],
    products: [
        // Products define the executables and libraries a package produces, and make them visible to other packages.
        .library(
            name: "GM+Dragable",
            targets: ["GM+Dragable"]),
    ],
    dependencies: [
        .package(url: "https://github.com/shaokui-gu/GM.git", branch: "main"),
        .package(url: "https://github.com/SnapKit/SnapKit.git", from: "5.0.1"),
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages this package depends on.
        .target(
            name: "GM+Dragable",
            dependencies: [
                "GM",
                "SnapKit"
            ],
            path: "Sources"
        ),
        .testTarget(
            name: "GM_DragableTests",
            dependencies: ["GM+Dragable"]),
    ]
)
