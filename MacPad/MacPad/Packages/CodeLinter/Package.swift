// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "CodeLinter",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "CodeLinter", targets: ["CodeLinter"])
    ],
    targets: [
        .target(
            name: "CodeLinter",
            path: "Sources/CodeLinter"
        )
    ]
)
