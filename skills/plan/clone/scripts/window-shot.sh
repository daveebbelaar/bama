#!/bin/zsh
# Saves a PNG of the largest on-screen window of an app.
# Usage: window-shot.sh <app name as in the menu bar> <out.png>
#   window-shot.sh "<App Name>" docs/screens/01-inbox.png
# Needs Screen Recording permission for the terminal (or Claude) that runs it.
set -euo pipefail
app=${1:?usage: window-shot.sh <AppName> <out.png>}
out=${2:?usage: window-shot.sh <AppName> <out.png>}
id=$(swift - "$app" <<'SWIFT' 2>/dev/null
import CoreGraphics
let name = CommandLine.arguments[1]
let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []
let windows = list.filter { ($0[kCGWindowOwnerName as String] as? String) == name && ($0[kCGWindowLayer as String] as? Int) == 0 }
let largest = windows.max { a, b in
    let ra = a[kCGWindowBounds as String] as? [String: Double] ?? [:]
    let rb = b[kCGWindowBounds as String] as? [String: Double] ?? [:]
    return (ra["Width"] ?? 0) * (ra["Height"] ?? 0) < (rb["Width"] ?? 0) * (rb["Height"] ?? 0)
}
if let id = largest?[kCGWindowNumber as String] as? Int { print(id) }
SWIFT
)
[[ -n "$id" ]] || { echo "no on-screen window for \"$app\" (is it open and not minimized?)"; exit 1; }
mkdir -p "${out:h}"
screencapture -x -o -l "$id" "$out"
[[ -s "$out" ]] || { echo "capture failed: allow Screen Recording for this terminal in System Settings"; exit 1; }
echo "$out"
