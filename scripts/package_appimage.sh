#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="Remail"
APP_ID="ink.hifuu.remail"
BUNDLE_DIR="$ROOT_DIR/build/linux/x64/release/bundle"
SOURCE_BINARY="$BUNDLE_DIR/rusend_next"
ICON_SOURCE="$ROOT_DIR/assets/remail_icon.png"
APPIMAGE_BUILD_DIR="$ROOT_DIR/build/appimage"
APPDIR="$APPIMAGE_BUILD_DIR/${APP_NAME}.AppDir"
OUTPUT_APPIMAGE="$APPIMAGE_BUILD_DIR/${APP_NAME}-x86_64.AppImage"

if ! command -v appimagetool >/dev/null 2>&1; then
  echo "appimagetool was not found in PATH" >&2
  exit 1
fi

if [[ ! -x "$SOURCE_BINARY" ]]; then
  echo "Linux bundle executable not found: $SOURCE_BINARY" >&2
  exit 1
fi

if [[ ! -f "$ICON_SOURCE" ]]; then
  echo "Icon not found: $ICON_SOURCE" >&2
  exit 1
fi

rm -rf "$APPDIR"
mkdir -p "$APPDIR"

cp -a "$BUNDLE_DIR/." "$APPDIR/"
mv "$APPDIR/rusend_next" "$APPDIR/$APP_NAME"
cp "$ICON_SOURCE" "$APPDIR/${APP_NAME}.png"
ln -s "${APP_NAME}.png" "$APPDIR/.DirIcon"

cat > "$APPDIR/AppRun" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
HERE="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
export LD_LIBRARY_PATH="$HERE/lib:${LD_LIBRARY_PATH:-}"
exec "$HERE/Remail" "$@"
EOF

cat > "$APPDIR/${APP_NAME}.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=${APP_NAME}
Exec=${APP_NAME}
Icon=${APP_NAME}
Comment=Remail desktop client
Categories=Network;Email;
StartupNotify=true
Terminal=false
X-AppImage-Name=${APP_NAME}
X-AppImage-Version=1.0.0
X-AppImage-Identifier=${APP_ID}
EOF

chmod +x "$APPDIR/AppRun"
rm -f "$OUTPUT_APPIMAGE"

APPIMAGE_EXTRACT_AND_RUN=1 ARCH=x86_64 appimagetool "$APPDIR" "$OUTPUT_APPIMAGE"

echo "Created: $OUTPUT_APPIMAGE"
