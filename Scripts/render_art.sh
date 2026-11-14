#!/bin/bash
# Redraw the app icon and README art (assets/) from the app's own SwiftUI views.
set -euo pipefail
cd "$(dirname "$0")/.."
swift build
OUT=$(mktemp -d)
"$(swift build --show-bin-path)/Scrollr" --render-art "$OUT"
iconutil -c icns "$OUT/AppIcon.iconset" -o Resources/AppIcon.icns
cp "$OUT/logo.png" "$OUT/banner.png" "$OUT/social-preview.png" assets/
echo "Updated Resources/AppIcon.icns and assets/"
