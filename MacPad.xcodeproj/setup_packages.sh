#!/bin/bash

# Script to create the proper package directory structure for MacPad

echo "Creating Packages directory structure..."

# Create the Packages directory if it doesn't exist
mkdir -p Packages/Autocomplete/Sources
mkdir -p Packages/CodeLinter/Sources
mkdir -p Packages/FindReplace/Sources

# Create Autocomplete Package.swift
cat > Packages/Autocomplete/Package.swift << 'EOF'
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
            path: "Sources"
        )
    ]
)
EOF

# Create CodeLinter Package.swift
cat > Packages/CodeLinter/Package.swift << 'EOF'
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
            path: "Sources"
        )
    ]
)
EOF

# Create FindReplace Package.swift
cat > Packages/FindReplace/Package.swift << 'EOF'
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
EOF

echo ""
echo "✅ Package structure created!"
echo ""
echo "Now you need to:"
echo "1. Move Autocomplete.swift and AutocompleteEngine.swift to Packages/Autocomplete/Sources/"
echo "2. Move CodeLinter.swift to Packages/CodeLinter/Sources/"
echo "3. Move FindReplaceSheet.swift and CocoaTextView.swift to Packages/FindReplace/Sources/"
echo ""
echo "Directory structure should be:"
echo "Packages/"
echo "├── Autocomplete/"
echo "│   ├── Package.swift"
echo "│   └── Sources/"
echo "│       ├── Autocomplete.swift"
echo "│       └── AutocompleteEngine.swift"
echo "├── CodeLinter/"
echo "│   ├── Package.swift"
echo "│   └── Sources/"
echo "│       └── CodeLinter.swift"
echo "└── FindReplace/"
echo "    ├── Package.swift"
echo "    └── Sources/"
echo "        ├── FindReplaceSheet.swift"
echo "        ├── CocoaTextView.swift"
echo "        └── FindReplace.swift"
echo ""
echo "After moving files:"
echo "1. In Xcode: File → Packages → Reset Package Caches"
echo "2. Clean Build Folder (Cmd+Shift+K)"
echo "3. Build (Cmd+B)"
