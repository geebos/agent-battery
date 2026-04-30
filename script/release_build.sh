#!/usr/bin/env bash
set -euo pipefail

# 与 .github/workflows/release.yml 一致的未签名 universal Release 构建。
# 用法：
#   script/release_build.sh build           # 仅编译
#   script/release_build.sh dmg             # 编译 + 打 DMG（需 brew install create-dmg）
#   script/release_build.sh open            # 编译 + 打开 .app（本地验证 Release 行为）
#
# 可通过环境变量覆盖：
#   MARKETING_VERSION (默认 0.0.0-local)
#   BUILD_NUMBER      (默认当前时间戳)
#   CONFIGURATION     (默认 Release)
#   BUILD_DIR         (默认 build/release)

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

PROJECT="agent-battery.xcodeproj"
SCHEME="agent-battery"
APP_NAME="agent-battery"
DISPLAY_NAME="Agent Battery"
CONFIGURATION="${CONFIGURATION:-Release}"
BUILD_DIR="${BUILD_DIR:-build/release}"
MARKETING_VERSION="${MARKETING_VERSION:-0.0.0-local}"
BUILD_NUMBER="${BUILD_NUMBER:-$(date +%s)}"

CMD="${1:-build}"

print_toolchain() {
  echo "==> Toolchain"
  sw_vers || true
  xcodebuild -version
  xcrun --sdk macosx --show-sdk-version
  xcrun swift --version || true
}

run_build() {
  print_toolchain

  rm -rf "$BUILD_DIR"
  mkdir -p "$BUILD_DIR"

  echo "==> xcodebuild ($CONFIGURATION, universal, unsigned)"
  xcodebuild \
    -project "$PROJECT" \
    -scheme "$SCHEME" \
    -configuration "$CONFIGURATION" \
    -destination "generic/platform=macOS" \
    -derivedDataPath "$BUILD_DIR/DerivedData" \
    ARCHS="arm64 x86_64" \
    ONLY_ACTIVE_ARCH=NO \
    CODE_SIGNING_ALLOWED=NO \
    CODE_SIGNING_REQUIRED=NO \
    CODE_SIGN_IDENTITY="" \
    DEVELOPMENT_TEAM="" \
    MARKETING_VERSION="$MARKETING_VERSION" \
    CURRENT_PROJECT_VERSION="$BUILD_NUMBER" \
    build

  APP_PATH="$BUILD_DIR/DerivedData/Build/Products/$CONFIGURATION/$APP_NAME.app"
  EXECUTABLE_PATH="$APP_PATH/Contents/MacOS/$APP_NAME"

  echo "==> Verify universal binary"
  test -d "$APP_PATH"
  lipo -info "$EXECUTABLE_PATH"
  lipo "$EXECUTABLE_PATH" -verify_arch arm64 x86_64
  codesign -dv "$APP_PATH" 2>&1 || true

  echo "APP_PATH=$APP_PATH"
}

run_dmg() {
  run_build

  command -v create-dmg >/dev/null || {
    echo "create-dmg not found. Install with: brew install create-dmg" >&2
    exit 1
  }

  APP_PATH="$BUILD_DIR/DerivedData/Build/Products/$CONFIGURATION/$APP_NAME.app"
  DMG_ROOT="$BUILD_DIR/dmg-root"
  DMG_NAME="$APP_NAME-$MARKETING_VERSION-universal-unsigned.dmg"
  DMG_PATH="$BUILD_DIR/$DMG_NAME"

  rm -rf "$DMG_ROOT"
  mkdir -p "$DMG_ROOT"
  ditto "$APP_PATH" "$DMG_ROOT/$DISPLAY_NAME.app"

  rm -f "$DMG_PATH"
  create-dmg \
    --volname "$DISPLAY_NAME" \
    --window-pos 200 150 \
    --window-size 540 380 \
    --icon-size 100 \
    --icon "$DISPLAY_NAME.app" 140 180 \
    --app-drop-link 400 180 \
    --no-internet-enable \
    "$DMG_PATH" \
    "$DMG_ROOT"

  shasum -a 256 "$DMG_PATH" > "$DMG_PATH.sha256"
  echo "DMG_PATH=$DMG_PATH"
  echo "SHA256_PATH=$DMG_PATH.sha256"
}

run_open() {
  run_build
  APP_PATH="$BUILD_DIR/DerivedData/Build/Products/$CONFIGURATION/$APP_NAME.app"
  pkill -x "$APP_NAME" >/dev/null 2>&1 || true
  /usr/bin/open -n "$APP_PATH"
}

case "$CMD" in
  build) run_build ;;
  dmg)   run_dmg ;;
  open)  run_open ;;
  *)
    echo "usage: $0 [build|dmg|open]" >&2
    exit 2
    ;;
esac
