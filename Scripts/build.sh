#!/bin/bash
# Build Scrollr.app (Apple silicon + Intel).
#
#   Scripts/build.sh            build, sign with your Apple Development certificate, install to /Applications, launch
#   Scripts/build.sh release    build, sign ad-hoc and zip it to build/Scrollr-macOS.zip for a GitHub release
#
# A stable signature keeps macOS from asking for permission again after every rebuild.
# The release zip is signed ad-hoc so it carries no personal certificate details.
set -euo pipefail
cd "$(dirname "$0")/.."
MODE=${1:-install}
ARGS=(-c release --arch arm64 --arch x86_64)
swift build "${ARGS[@]}"

APP=build/Scrollr.app
rm -rf "$APP" && mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$(swift build "${ARGS[@]}" --show-bin-path)/Scrollr" "$APP/Contents/MacOS/"
cp Info.plist "$APP/Contents/"
cp Resources/AppIcon.icns "$APP/Contents/Resources/"

if [[ $MODE == release ]]; then
  codesign --force --options runtime --sign - "$APP"
  (cd build && rm -f Scrollr-macOS.zip && ditto -c -k --keepParent Scrollr.app Scrollr-macOS.zip)
  shasum -a 256 build/Scrollr-macOS.zip
  exit 0
fi

# Pick a signing identity by hash: Xcode can leave a revoked certificate with the same name next to the new one.
IDENTITY=${SIGN_IDENTITY:-$(security find-identity -p codesigning | grep -E "Apple Development|Developer ID" \
  | grep -vE "REVOKED|EXPIRED" | awk '{print $2; exit}')}
codesign --force --options runtime --sign "${IDENTITY:--}" "$APP"
if [[ "$(spctl -a -t exec "$APP" 2>&1 || true)" == *CERT_REVOKED* ]]; then
  echo "Certificate $IDENTITY is revoked. Make a new one in Xcode > Settings > Accounts > Manage Certificates."
  exit 1
fi

pkill -x Scrollr 2>/dev/null || true
rm -rf /Applications/Scrollr.app && ditto "$APP" /Applications/Scrollr.app
open /Applications/Scrollr.app
echo "Installed /Applications/Scrollr.app (signed with ${IDENTITY:-ad-hoc})"
