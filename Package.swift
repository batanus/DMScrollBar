// swift-tools-version:5.7
import PackageDescription

let package = Package(
    name: "DMScrollBar",
    platforms: [.iOS(.v14)],
    products: [
        .library(
            name: "DMScrollBar",
            targets: ["DMScrollBar"]
        )
    ],
    targets: [
        .target(
            name: "DMScrollBar",
            path: "DMScrollBar"
        )
    ]
)
