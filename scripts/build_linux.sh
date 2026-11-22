#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

FLUTTER_BIN="${FLUTTER_BIN:-flutter}"

"$FLUTTER_BIN" pub get
"$FLUTTER_BIN" build linux --release

mkdir -p dist
tar -C build/linux/x64/release/bundle -czf dist/StageCommander-linux-x64.tar.gz .

PKG_ROOT="$(mktemp -d build/stagecommander-deb.XXXXXXXX)"
trap 'rm -rf -- "$PKG_ROOT"' EXIT
mkdir -p "$PKG_ROOT/DEBIAN" "$PKG_ROOT/opt/stagecommander" "$PKG_ROOT/usr/bin" "$PKG_ROOT/usr/share/applications"
cp -R build/linux/x64/release/bundle/* "$PKG_ROOT/opt/stagecommander/"
ln -s /opt/stagecommander/StageCommander "$PKG_ROOT/usr/bin/stagecommander"

cat << 'EOF' > "$PKG_ROOT/DEBIAN/control"
Package: stagecommander
Version: 2.0.0
Section: sound
Priority: optional
Architecture: amd64
Depends: libgtk-3-0, libasound2 | libasound2t64, libpulse0
Maintainer: StageCommander
Description: Material Design 3 cross-platform live stage audio & cue controller
EOF

cat << 'EOF' > "$PKG_ROOT/usr/share/applications/stagecommander.desktop"
[Desktop Entry]
Name=StageCommander
Comment=Live Stage Audio Cue & Show Controller
Exec=/opt/stagecommander/StageCommander
Type=Application
Categories=AudioVideo;Audio;
Terminal=false
EOF

dpkg-deb --root-owner-group --build "$PKG_ROOT" dist/StageCommander-linux-x64.deb
ls -lh dist/
