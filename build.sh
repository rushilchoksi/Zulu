#!/usr/bin/env bash
# Builds Zulu.app into ./build and (by default) installs it to ~/Applications.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_NAME="Zulu"
BUNDLE_ID="com.rushilchoksi.zulu"
VERSION="1.1.0"
BUILD_DIR="$ROOT/build"
APP="$BUILD_DIR/$APP_NAME.app"
INSTALL_DIR="${INSTALL_DIR:-$HOME/Applications}"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

echo "==> Compiling"
swiftc -O \
    -target "$(uname -m)-apple-macos14.0" \
    -swift-version 5 \
    -o "$APP/Contents/MacOS/$APP_NAME" \
    "$ROOT"/Sources/*.swift

echo "==> Assembling bundle"
cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>                <string>$APP_NAME</string>
    <key>CFBundleDisplayName</key>         <string>$APP_NAME</string>
    <key>CFBundleExecutable</key>          <string>$APP_NAME</string>
    <key>CFBundleIdentifier</key>          <string>$BUNDLE_ID</string>
    <key>CFBundlePackageType</key>         <string>APPL</string>
    <key>CFBundleShortVersionString</key>  <string>$VERSION</string>
    <key>CFBundleVersion</key>             <string>$VERSION</string>
    <key>LSMinimumSystemVersion</key>      <string>14.0</string>
    <key>LSUIElement</key>                 <true/>
    <key>NSHumanReadableCopyright</key>    <string>MIT Licensed</string>
</dict>
</plist>
PLIST

printf 'APPL????' > "$APP/Contents/PkgInfo"

echo "==> Signing (ad-hoc)"
codesign --force --sign - --timestamp=none "$APP" >/dev/null 2>&1 || \
    echo "    warning: ad-hoc signing failed; 'Start at Login' may not stick"

if [[ "${NO_INSTALL:-0}" != "1" ]]; then
    echo "==> Installing to $INSTALL_DIR"
    mkdir -p "$INSTALL_DIR"
    if pkill -x "$APP_NAME" 2>/dev/null; then
        # Let the old instance release the bundle before it is replaced,
        # otherwise LaunchServices can fail the relaunch with -600.
        for _ in 1 2 3 4 5 6 7 8 9 10; do
            pgrep -x "$APP_NAME" >/dev/null || break
            sleep 0.2
        done
    fi
    rm -rf "${INSTALL_DIR:?}/$APP_NAME.app"
    cp -R "$APP" "$INSTALL_DIR/"
    sleep 0.3
    open -n "$INSTALL_DIR/$APP_NAME.app"
    echo "==> $APP_NAME is running: look at the right side of your menu bar"
else
    echo "==> Built at $APP"
fi
