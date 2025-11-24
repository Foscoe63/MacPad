// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Autocomplete",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "Autocomplete", targets: ["Autocomplete"])
    ],
    targets: [
        .target(
            name: "Autocomplete",
            path: "Sources/Autocomplete"
        )
    ]
)
