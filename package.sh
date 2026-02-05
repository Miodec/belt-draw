#!/bin/bash

# Get the mod name and version from info.json
MOD_NAME=$(jq -r '.name' info.json)
MOD_VERSION=$(jq -r '.version' info.json)
PACKAGE_NAME="${MOD_NAME}_${MOD_VERSION}"

# Create temporary directory
TEMP_DIR=$(mktemp -d)
PACKAGE_DIR="$TEMP_DIR/$PACKAGE_NAME"

# Copy folder to temp directory
cp -r . "$PACKAGE_DIR"

# Remove unnecessary files/folders
rm -rf "$PACKAGE_DIR/.git"
rm -rf "$PACKAGE_DIR/.luarc.json"
rm -rf "$PACKAGE_DIR/.gitignore"
rm -rf "$PACKAGE_DIR/screenshots"
rm -rf "$PACKAGE_DIR/design"
rm -rf "$PACKAGE_DIR/.vscode"
rm -f "$PACKAGE_DIR/package.sh"

# Create zip in user's home directory
cd "$TEMP_DIR"
zip -r "$HOME/${PACKAGE_NAME}.zip" "$PACKAGE_NAME"

# Cleanup
rm -rf "$TEMP_DIR"

echo "Package created: $HOME/${PACKAGE_NAME}.zip"
