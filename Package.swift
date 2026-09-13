// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PreventSleep",
    platforms: [.macOS(.v15)],
    products: [
        .library(name: "PreventSleepCore", targets: ["PreventSleepCore"]),
        .library(name: "PreventSleepHelperLib", targets: ["PreventSleepHelperLib"]),
        .library(name: "PreventSleepAppLib", targets: ["PreventSleepAppLib"])
    ],
    targets: [
        .target(name: "PreventSleepCore"),
        .target(name: "PreventSleepHelperLib", dependencies: ["PreventSleepCore"], path: "Sources/PreventSleepHelper", exclude: ["com.sramzz.mac-no-sleep.helper.plist", "main.swift"]),
        .target(name: "PreventSleepAppLib", dependencies: ["PreventSleepCore"], path: "Sources/PreventSleepApp", exclude: ["main.swift", "Resources"]),
        .testTarget(name: "PreventSleepCoreTests", dependencies: ["PreventSleepCore", "PreventSleepHelperLib", "PreventSleepAppLib"])
    ]
)
