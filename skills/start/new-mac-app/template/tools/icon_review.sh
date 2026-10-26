#!/bin/zsh
# Renders Icon/AppIcon.icon the way macOS shows it, with Icon Composer's
# ictool, into one contact sheet:
#   Default, Dark, TintedDark, ClearLight at 256 pt, then Default at 32 and 16 pt.
# Usage: tools/icon_review.sh [out.png]     (default /tmp/__APP_NAME__-icon.png)
set -euo pipefail
here=${0:A:h}
repo=${here:h}
out=${1:-/tmp/__APP_NAME__-icon.png}
ictool="$(xcode-select -p)/../Applications/Icon Composer.app/Contents/Executables/ictool"
[[ -x "$ictool" ]] || { echo "ictool not found. Install Xcode 26 or later."; exit 1; }
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

render() { # rendition size file
  "$ictool" "$repo/Icon/AppIcon.icon" --export-image --output-file "$work/$3" \
    --platform macOS --rendition "$1" --width "$2" --height "$2" --scale 2 >/dev/null
}
render Default 256 1.png
render Dark 256 2.png
render TintedDark 256 3.png
render ClearLight 256 4.png
render Default 32 5.png
render Default 16 6.png
swift "$here/icon_sheet.swift" "$out" "$work"/{1,2,3,4,5,6}.png
echo "wrote $out"
