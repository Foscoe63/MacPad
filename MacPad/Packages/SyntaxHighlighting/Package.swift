// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "SyntaxHighlighting",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "SyntaxHighlighting", targets: ["SyntaxHighlighting"])
    ],
    targets: [
        .target(
            name: "SyntaxHighlighting",
            path: "Sources/SyntaxHighlighting"
        )
    ]
)
