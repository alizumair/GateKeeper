// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "GateKeeper",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "GateKeeper",
            targets: ["GateKeeper"]
        )
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "GateKeeper",
            dependencies: [],
            path: "Sources/GateKeeper"
        )
    ]
)
