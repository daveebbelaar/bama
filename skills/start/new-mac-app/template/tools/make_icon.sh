#!/bin/zsh
# Compiles Icon/AppIcon.icon (an Icon Composer file) with actool and writes:
#   Resources/Assets.car     the Liquid Glass icon (light, dark, tinted, clear)
#   Resources/AppIcon.icns   flat fallback for Finder views that read .icns
# build.sh runs this when the .icon changed. Run it by hand to check errors.
set -euo pipefail
here=${0:A:h}
repo=${here:h}
icon="$repo/Icon/AppIcon.icon"
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
mkdir -p "$repo/Resources"

# actool fails on a missing layer image, so it doubles as the validator.
# The .icon must be named AppIcon.icon to match --app-icon, or actool
# writes nothing and still exits 0. Check the output to catch that.
xcrun actool "$icon" --compile "$work" --platform macosx \
  --minimum-deployment-target 26.0 --app-icon AppIcon \
  --output-partial-info-plist "$work/partial.plist" \
  --output-format human-readable-text --errors --warnings >"$work/log" 2>&1 || { cat "$work/log"; exit 1; }
[[ -f "$work/Assets.car" && -f "$work/AppIcon.icns" ]] || { cat "$work/log"; echo "actool wrote no icon"; exit 1; }
cp "$work/Assets.car" "$work/AppIcon.icns" "$repo/Resources/"
echo "wrote Resources/Assets.car and Resources/AppIcon.icns"
