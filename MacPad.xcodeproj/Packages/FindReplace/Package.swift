// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "FindReplace",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "FindReplace", targets: ["FindReplace"])
    ],
    targets: [
        .target(
            name: "FindReplace",
            path: "Sources"
        )
    ]
)
