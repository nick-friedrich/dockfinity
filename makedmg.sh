#!/bin/bash

# Get version from arguments or fail
if [ -z "$1" ]; then
    echo "Usage: $0 <version>"
    exit 1
fi

VERSION="$1"
APP_NAME="Dockfinity"
DMG_NAME="${APP_NAME}_${VERSION}.dmg"
SOURCE_FOLDER="releases/$VERSION"
OUTPUT_PATH="releases/${DMG_NAME}"

echo "Creating DMG installer for ${APP_NAME} version ${VERSION}..."

# Check if create-dmg is installed
if ! command -v create-dmg &> /dev/null; then
    echo "Error: create-dmg is not installed!"
    echo "Please install it with: brew install create-dmg"
    exit 1
fi

# Check if the release folder exists
if [ ! -d "$SOURCE_FOLDER" ]; then
    echo "Error: $SOURCE_FOLDER directory not found!"
    exit 1
fi

# Check if the app exists
if [ ! -d "$SOURCE_FOLDER/${APP_NAME}.app" ]; then
    echo "Error: ${APP_NAME}.app not found in $SOURCE_FOLDER/"
    exit 1
fi

# Clean up any existing DMG file
if [ -f "$OUTPUT_PATH" ]; then
    echo "Removing existing DMG..."
    rm "$OUTPUT_PATH"
fi

# Create the DMG using create-dmg
echo "Creating professional DMG installer..."
create-dmg \
  --volname "$APP_NAME" \
  --window-pos 200 120 \
  --window-size 600 400 \
  --icon-size 100 \
  --icon "${APP_NAME}.app" 150 190 \
  --hide-extension "${APP_NAME}.app" \
  --app-drop-link 450 190 \
  --format UDZO \
  "$OUTPUT_PATH" \
  "$SOURCE_FOLDER"

# Check if DMG was created successfully
if [ -f "$OUTPUT_PATH" ]; then
    echo "✅ DMG created successfully: $OUTPUT_PATH"
    echo "Users can now drag ${APP_NAME}.app to the Applications folder!"
    
    # Show file size
    SIZE=$(du -h "$OUTPUT_PATH" | cut -f1)
    echo "📦 DMG size: $SIZE"

    # Echo Sha 256
    echo "📦 DMG SHA256: $(shasum -a 256 "$OUTPUT_PATH")"
else
    echo "❌ Failed to create DMG"
    exit 1
fi