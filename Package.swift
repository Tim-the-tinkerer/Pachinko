// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Pachinko",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "Pachinko", targets: ["Pachinko"]),
    ],
    targets: [
        .executableTarget(
            name: "Pachinko",
            path: "Sources/Pachinko"
        ),
    ]
)
