// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "MacPad",
    platforms: [.macOS(.v13)],
    targets: [
        .target(
            name: "MacPad",
            dependencies: [
                .target(name: "FindReplace"),
                .target(name: "SyntaxHighlighting"), 
                .target(name: "Autocomplete"),
                .target(name: "CodeLinter")
            ],
            path: "MacPad",
            sources: [
                // Sources are in the MacPad directory
            ]
        ),
        .testTarget(
            name: "MacPadTests",
            dependencies: ["MacPad"]),
        .target(
            name: "FindReplace",
            path: "Packages/FindReplace/Sources/FindReplace"
        ),
        .target(
            name: "SyntaxHighlighting", 
            path: "Packages/SyntaxHighlighting/Sources/SyntaxHighlighting"
        ),
        .target(
            name: "Autocomplete",
            path: "Packages/Autocomplete/Sources/Autocomplete"
        ),
        .target(
            name: "CodeLinter",
            path: "Packages/CodeLinter/Sources/CodeLinter"
        )
    ]
)