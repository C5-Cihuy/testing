// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "MultiPeerMessaging",
    platforms: [.iOS(.v26), .visionOS(.v26), .macOS(.v26)],
    products: [.library(name: "MultiPeerMessaging", targets: ["MultiPeerMessaging"])],
    dependencies: [
        .package(url: "https://github.com/apple/swift-certificates.git", from: "1.0.0")
    ],
    targets: [
        .target(name: "MultiPeerMessaging", dependencies: [
            .product(name: "X509", package: "swift-certificates")
        ]),
        .testTarget(name: "MultiPeerMessagingTests", dependencies: ["MultiPeerMessaging"])
    ]
)
