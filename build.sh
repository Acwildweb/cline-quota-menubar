#!/bin/bash
# Build ClineQuota.app from source. Requires Xcode Command Line Tools (swiftc).
set -e
cd "$(dirname "$0")"

APP=ClineQuota.app
mkdir -p "$APP/Contents/MacOS"
swiftc -O -o "$APP/Contents/MacOS/ClineQuota" Sources/ClineQuota.swift
cp Info.plist "$APP/Contents/Info.plist"

# Remove quarantine flag if the file was downloaded from the internet
xattr -dr com.apple.quarantine "$APP" 2>/dev/null || true

echo "Built $APP"
echo "Run it with:  open $APP"
echo "Optional - start at login:"
echo "  osascript -e 'tell application \"System Events\" to make login item at end with properties {path:\"$(pwd)/$APP\", hidden:false}'"
