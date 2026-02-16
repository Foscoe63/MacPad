#!/bin/bash

# Script to remove CodeLinter package reference from Xcode project

echo "Searching for CodeLinter references in Xcode project files..."
echo ""

# Search in .xcodeproj
if [ -d "MacPad.xcodeproj" ]; then
    echo "=== Found in MacPad.xcodeproj/project.pbxproj ==="
    grep -n "CodeLinter" MacPad.xcodeproj/project.pbxproj || echo "No references found in project.pbxproj"
    echo ""
fi

# Search in workspace
if [ -d "MacPad.xcworkspace" ]; then
    echo "=== Found in MacPad.xcworkspace ==="
    find MacPad.xcworkspace -type f -exec grep -l "CodeLinter" {} \;
    echo ""
fi

# Search in workspace data
if [ -d ".swiftpm" ]; then
    echo "=== Found in .swiftpm ==="
    find .swiftpm -type f -exec grep -l "CodeLinter" {} \;
    echo ""
fi

echo ""
echo "=== To remove CodeLinter reference manually ==="
echo "1. Close Xcode completely"
echo "2. Open MacPad.xcodeproj/project.pbxproj in a text editor"
echo "3. Search for 'CodeLinter' and remove those lines"
echo "4. Save the file"
echo "5. Reopen Xcode"
echo ""
echo "OR try this in Xcode:"
echo "1. File → Workspace Settings (or Project Settings)"
echo "2. Click 'Resolve Package Versions' or 'Reset Package Cache'"
echo "3. Clean Build Folder (Cmd+Shift+K)"
echo ""
