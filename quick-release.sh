WORKSPACE_ROOT="$HOME/dev/solidgroundux-installer"
BUILD_DIR="$WORKSPACE_ROOT/build"
TARGET_ROOT="$WORKSPACE_ROOT/target-root"
RELEASE_NAME="SolidgroundUX Installer"



mkdir -p "$BUILD_DIR"

tar -czf \
    "$BUILD_DIR/$RELEASE_NAME.tar.gz" \
    -C "$TARGET_ROOT" \
    .

tar -tzf "$BUILD_DIR/$RELEASE_NAME.tar.gz" | head -200