#!/bin/sh
# Builds Markdown Viewer, installs it in /Applications, registers the Quick Look
# extension and makes the application the default for Markdown documents.
#
# Signing:
#   TEAM=ABCDE12345 scripts/install.sh   signs with that team's Apple Development certificate
#   scripts/install.sh                   signs ad hoc (runs on this Mac only)
set -eu

cd "$(dirname "$0")/.."

command -v xcodegen >/dev/null || { echo "XcodeGen is required: brew install xcodegen" >&2; exit 1; }
command -v xcodebuild >/dev/null || { echo "Xcode is required." >&2; exit 1; }

if [ -n "${TEAM:-}" ]; then
  SIGNING="DEVELOPMENT_TEAM=$TEAM CODE_SIGN_IDENTITY=Apple\ Development"
else
  SIGNING="DEVELOPMENT_TEAM= CODE_SIGN_IDENTITY=-"
fi

xcodegen generate --quiet
eval xcodebuild -project MarkdownViewer.xcodeproj -scheme MarkdownViewer \
  -configuration Release -derivedDataPath build -quiet $SIGNING build

APP="/Applications/Markdown Viewer.app"
pkill -x "Markdown Viewer" 2>/dev/null || true
rm -rf "$APP"
ditto "build/Build/Products/Release/Markdown Viewer.app" "$APP"

/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$APP"
qlmanage -r >/dev/null 2>&1 || true

# Launching the application registers the Quick Look extension and sets the default handler.
open -a "$APP" --args --set-default

echo "Markdown Viewer is installed in /Applications."
