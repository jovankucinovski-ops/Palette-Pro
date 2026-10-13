// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "PalettePro",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "PalettePro",
            path: "Sources/PalettePro"
        )
    ]
)
