---
name: test-mac-app
description: Test a macOS app at three levels, from Swift Testing unit tests and an in-app self-test to a debug bridge that lets an agent drive the running app and read its state, plus computer use for real clicks. Use when adding logic, fixing a bug, before a release, or when the user asks for tests, end-to-end checks, or "make sure it works".
---

# Test a Mac app

Three levels, cheapest first. Each new story gets the cheapest level that
can prove its acceptance criteria. A bug fix starts with a test that fails.

| Level | Proves | Speed |
| --- | --- | --- |
| Unit tests (Swift Testing) | Rules, parsing, data | Seconds |
| Self-test (`--selftest`) | The app's real functions on a test store | Seconds |
| Key events and menu audit (inside the self-test) | Keyboard flows and every shortcut, without the screen | Seconds |
| Debug bridge + computer use | Global shortcuts, panels, permissions, other apps | Minutes |

Snapshots (`build-and-verify` skill) prove how it looks. This skill proves
how it behaves.

## 1. Unit tests

Logic lives in a library target (`<App>Kit`) with no SwiftUI, so tests run
without the app.

```swift
import Testing
@testable import AppKitCore

@Test("Natural dates", arguments: [("tomorrow 9am", 1, 9), ("next fri", 5, nil)])
func parses(_ phrase: String, dayOffset: Int, hour: Int?) throws {
    let result = try #require(DateParser.parse(phrase, now: .fixed))
    #expect(result.dayOffset == dayOffset)
    #expect(result.hour == hour)
}
```

```bash
swift test --scratch-path ~/Library/Developer/<App>/test-build
```

- Fix the clock (`now:` parameter) and the store path in every test.
- A parser that removes text from what the user typed needs at least 20
  negative rows: real titles that contain date or time words ("Watch
  Friday Night Lights"). Add consistency rows for related phrases ("next
  week" and "next friday"), and a tested way to undo a parsed part.
- **Table tests** for anything with many cases. Keep the table in
  `docs/research/<topic>.md` too, and add a row there before changing
  behavior. A date parser easily needs 100 rows.

## 2. Self-test

A launch flag that runs the same functions the UI calls, prints PASS or FAIL
per step, and exits 0 or 1:

```bash
APP_STORE=/tmp/<App>-self.store ~/Applications/<App>.app/Contents/MacOS/<App> --selftest
# PASS add task
# PASS complete task
# PASS undo
```

Always point it at a store in `/tmp`. Never at the user's data.

Checks worth adding to any self-test:

- Every action's Shortcuts title equals its menu title.
- Every SF Symbol name exists (`NSImage(systemSymbolName:accessibilityDescription:)`).
- Every URL action round-trips.
- For every page: New Item creates a row that is visible and focused on
  that page. After an action removes the selected row, selection moves to
  the next row.
- **Smoke step**: start every background timer, sampler, and observer for a
  few seconds, then print PASS. It is the only check that catches crashes on
  background queues.

A single-instance app (menu bar utility) cannot launch a second copy with
`--selftest`. Make it a bridge command instead. Xcode and XcodeGen apps
without a library target: see
[../build-and-verify/existing-app.md](../build-and-verify/existing-app.md)
for a test target with no host app.

### Key events and menu audit

The self-test can send synthetic key events through the app.
`NSApp.sendEvent` delivers a key event to `NSApp.keyWindow`, not to the
window in `windowNumber`. If no window is key, the event is lost and the
check fails for the wrong reason. While another app is in front, the
window becomes key only after the app activates, a short time later. So
make the window key, focus the view under test, and wait in the
self-test's `Task` until both are true. A loop on `RunLoop.main` does not
work here, because activation needs the main queue.

```swift
window.makeKeyAndOrderFront(nil)
window.makeFirstResponder(list)  // a toolbar search field can take focus first
for _ in 0..<40 where NSApp.keyWindow !== window {
    try? await Task.sleep(for: .milliseconds(50))
}
check("list has keyboard focus", NSApp.keyWindow === window && window.firstResponder === list)
let event = NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [],
    timestamp: 0, windowNumber: window.windowNumber, context: nil,
    characters: "\r", charactersIgnoringModifiers: "\r", isARepeat: false, keyCode: 36)!
NSApp.sendEvent(event)                                // Return through app event routing
NSApp.mainMenu?.performKeyEquivalent(with: commandK)  // a menu shortcut
```

Send events with the flags a real keyboard sends. Arrow keys carry
`.numericPad` and `.function`; using `modifierFlags: []` can make a test
pass while real input fails. For example, send an unmodified Right Arrow:

```swift
let rightArrow = NSEvent.keyEvent(with: .keyDown, location: .zero,
    modifierFlags: [.numericPad, .function], timestamp: 0,
    windowNumber: window.windowNumber, context: nil,
    characters: "\u{F703}", charactersIgnoringModifiers: "\u{F703}",
    isARepeat: false, keyCode: 124)!
NSApp.sendEvent(rightArrow)
```

When app code checks for an arrow with no shortcut modifiers held, remove
key classification flags and ignore Caps Lock:

```swift
let held = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
    .subtracting([.numericPad, .function, .capsLock])
if event.keyCode == 124, held.isEmpty { browseInto() }
```

Check plain arrows and arrows with Shift, Control, Option, or Command so
navigation does not consume a modified shortcut by mistake.

Test typing by sending key events through `NSApp.sendEvent` and checking
what the field received. Setting the model's text is useful for setup,
but does not test focus or input routing. Start from the focus state the
user encounters, including any selected placeholder text, type a name or
filter, and assert the resulting field text and model value. Keep a real
keyboard check for input methods and system shortcuts that synthetic
events do not exercise.

Walk `NSApp.mainMenu` and check every command's title, key equivalent,
modifiers, and symbol against the command map. One loop turns "every
action has a menu item and a shortcut" into a check per item.

### Menu check (from outside)

Do not test SwiftUI menu state from inside the app. Its items carry no
action selector, `isEnabled` updates on SwiftUI's schedule, and the checks
fail whenever another app is in front, which is always true while an agent
works. In the self-test, check what the commands receive (the selection
passed into them) and run the actions the items call.

Check the real menu from outside, through Accessibility, on a seeded test
copy. Computer use `app_menu` works in the background:

1. Nothing selected: To-Do > Complete is reported disabled.
2. Click a row (`app_click`), then To-Do > Complete: the row is done and the
   next row is selected (`app_screenshot`).

Write these steps into the app's `CLAUDE.md`, so every agent runs them
after touching commands.

### Runs that never hang

- Quit through `NSApp.terminate`, with the exit code set in
  `applicationWillTerminate`. Close open sheets first, or terminate is
  refused and the run waits forever.
- Before each run, delete `~/Library/Saved Application State/<bundle id>.savedState`.
  After a crash, the next launch shows a "reopen windows?" alert that
  blocks every later run with no output. Do not use
  `-ApplePersistenceIgnoreState`: SwiftUI then opens no window at all.
- Delete the old test store and its `-wal` and `-shm` files before a
  seeded run. Seed data only fills an empty store.
- Print line-buffered (`setvbuf(stdout, nil, _IOLBF, 0)`), so a crash
  keeps the PASS lines before it.

## 3. Debug bridge

For behavior a self-test cannot reach: global shortcuts, floating panels,
window control, permissions, timing. The running app listens for commands
and writes its state to a file. Code shape:
[../../code/os-integrations/recipes.md](../../code/os-integrations/recipes.md) (Debug bridge).

```bash
swift scripts/<app>ctl.swift status            # writes and prints status.json
swift scripts/<app>ctl.swift windowLeft        # runs an action by name
swift scripts/<app>ctl.swift snapshot:launcher # draws a window to a PNG
swift scripts/<app>ctl.swift captureProbe:/tmp/a.png   # runs, logs timing, cancels
```

Commands worth adding:

- `status`: permissions, feature flags, open panels, counts, last error.
- One command per action, by the same name as the menu item and URL.
- `snapshot:<window>`: captures one of the app's windows with ScreenCaptureKit
  (code in [../build-and-verify/existing-app.md](../build-and-verify/existing-app.md)).
- `appearance:light|dark|system`: switches the app's appearance for snapshots.
- `selftest`: the self-test as a command, for an app that is already running.
- `<feature>File:<path>`: opens an editor or card on a test file, with no
  clipboard or data change.
- `<feature>Probe`: runs a slow path and logs the time of each step (see
  the `performance` skill).

Compile the bridge in debug builds, or behind a launch flag in release.

## 4. Computer use

Last resort, for what only a person can do: a real key press in another
app, drag and drop from Finder, a permission prompt. See the `clone` skill
for setup. Tell the user to keep off the mouse while it runs. Capture your
own window, never the full screen.

## Debug output

A GUI app's `print` is buffered and lost when the process is killed. Write
debug lines to stderr (`FileHandle.standardError.write`) behind an
environment flag (`APP_DEBUG=1`).

Done when every acceptance line of the story maps to a passing test,
self-test step, bridge command, or a named manual check, and the bug fix
has a test that failed before the fix.
