# Existing apps

The ship and code skills assume an app made from the `new-mac-app`
template: SwiftPM, `build.sh`, `APP_SNAPSHOT`, `APP_STORE`, Swift 6 with
main-actor default isolation. An older app, or one built with Xcode or
XcodeGen, has none of these. Map each piece first, then follow the skills.

## Contents

- Map the template pieces
- Snapshots through a debug bridge
- Unit tests without a host app
- Self-test in a running app
- Moving to Swift 6

## Map the template pieces

| Template piece | Existing Xcode or XcodeGen app |
| --- | --- |
| `./build.sh` | `make build`, or `xcodebuild -scheme <App> -configuration Release -derivedDataPath ~/Library/Developer/<App>-cli build` |
| `./build.sh --open` | Kill, copy to the same install path, `lsregister -f -R -trusted`, `open` |
| `APP_SNAPSHOT` mode | A `snapshot:` command in a debug bridge (below) |
| `APP_STORE=/tmp/...` | A data folder override, or a bridge command that only reads |
| `swift test` | A test target with no host app (below) |
| `--selftest` launch flag | A `selftest` bridge command (below) |
| Swift 6, default isolation | Swift 5 mode: migrate (below) or keep it and annotate `@MainActor` |

Write the mapping into the app's `CLAUDE.md`, and create the file if it is
missing.

## Snapshots through a debug bridge

A single-instance app (menu bar utility, background agent) cannot be
launched a second time in snapshot mode. Add commands to its debug bridge
(see the `os-integrations` skill, recipes.md):

- `snapshot:<file>:<match>`: capture one of the app's own windows with
  ScreenCaptureKit, from inside the app:

  ```swift
  let content = try await SCShareableContent.current
  guard let scWindow = content.windows.first(where: { $0.windowID == CGWindowID(window.windowNumber) })
  else { return }
  let filter = SCContentFilter(desktopIndependentWindow: scWindow)
  let config = SCStreamConfiguration()
  config.width = Int(window.frame.width * 2); config.height = Int(window.frame.height * 2)
  let image = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
  ```

  It shows glass, forms, and sidebars exactly as on screen, needs only the
  app's own Screen Recording grant, and never shows other apps.
- Find windows in `NSApp.windows`. `NSApp.orderedWindows` skips panels.
  Match by title, or by root view type:
  `String(describing: type(of: window.contentView!))` reads like
  `NSHostingView<LauncherView>`.
- `appearance:light|dark|system`: set `NSApp.appearance` (not the saved
  preference), so one script snapshots every surface in both modes.
- `cacheDisplay(in:to:)` is a fallback only. It draws forms, sidebars, and
  glass blank.

After a refactor, diff new snapshots against a baseline:

```bash
magick compare -metric AE -fuzz 8% before/settings.png after/settings.png /tmp/diff.png
```

Zero changed pixels proves the screen did not change. Small diffs on live
data (clocks, stats) are fine.

## Unit tests without a host app

An Xcode or XcodeGen app has no library target. Add a unit test target
that compiles the pure logic files directly, with no host app:

```yaml
# project.yml
<App>Tests:
  type: bundle.unit-test
  platform: macOS
  sources:
    - path: Tests
    - path: <App>/Features/Colors/ColorFormat.swift
    - path: <App>/Core/FuzzyMatch.swift
```

Give it its own scheme and run:

```bash
xcodebuild test -scheme <App>Tests -destination 'platform=macOS,arch=arm64'
```

`-quiet` prints nothing on success. Read the exit code.

A hosted test bundle launches a second copy of the app, which fights the
running one for global hotkeys, the menu bar slot, event taps, and bridge
notifications. Avoid it.

Logic buried in `@MainActor` stores cannot be compiled alone. Move it into
its own file and type that takes plain values (text, not a URL; numbers,
not a view).

## Self-test in a running app

Make the self-test a bridge command that prints PASS or FAIL per check.
Checks worth adding to any app:

- Every action's Shortcuts title equals its menu title.
- Every SF Symbol name exists: `NSImage(systemSymbolName:accessibilityDescription:) != nil`.
- Every URL action name round-trips through the URL handler.
- **Smoke step**: start every background timer, sampler, and observer for a
  few seconds, then print PASS. Only this catches crashes on background
  queues (see Moving to Swift 6).

## Moving to Swift 6

- Expect several build rounds. The compiler stops early, so the first error
  count is low. One app showed 9 errors first and about 22 errors and 28
  warnings in the end.
- The compiler-clean build can still crash at run time. A closure created
  inside a `@MainActor` type and handed to an API that does not take a
  `@Sendable` closure inherits the main actor. When the API runs it on a
  background queue, Swift 6 traps (`dispatch_assert_queue`). Find them:

  ```bash
  grep -rn 'setEventHandler\|setCancelHandler\|DispatchWorkItem\|addPeriodicTimeObserver\|AudioObjectAddPropertyListenerBlock' Sources/
  ```

  Mark each such closure `{ @Sendable in ... }` and hop to the main actor
  inside it where needed. Then run the smoke step.
- Common errors and fixes: see the `swift-swiftui` skill, "Swift 6 errors".
