// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PreventSleep",
    platforms: [.macOS(.v15)],
    products: [
        .library(name: "PreventSleepCore", targets: ["PreventSleepCore"])
    ],
    targets: [
        .target(name: "PreventSleepCore"),
        .testTarget(name: "PreventSleepCoreTests", dependencies: ["PreventSleepCore"])
    ]
)
