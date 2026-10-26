# Window switcher

Hold Option, press Tab, and pick any window on the current Space from a grid of previews. Let go to jump to it. Replaces: AltTab. Taken from Onyx.

## Brief

```markdown
# Switch

A menu bar app that switches between windows, not apps: hold ⌥, tap Tab, let go.

## Replaces
AltTab

## Main jobs
1. Hold ⌥ and press Tab to step through every window on this Space; let go to focus it.
2. See a preview, the app icon, and the title of each window to find the right one.
3. Pick ⌥Tab or ⌘Tab as the trigger, and turn previews on or off.

## Data
- Settings: enabled (default on), trigger ("option" or "command", default "option"),
  previews (default on). UserDefaults.
- Preview cache: window ID to image. Memory only.

## Shape
A floating, non-activating panel shown while the trigger is held, plus a menu bar
extra and a Settings window. macOS 26 or later. No Dock icon (LSUIElement).
Local data. Works offline. No accounts.

## System hooks
Global shortcuts (Carbon ⌥Tab and ⌥⇧Tab), a listen-only event tap for the modifier
release, Accessibility to focus windows, Screen Recording for previews and titles,
menu bar item.

## Reference
AltTab

## Look
One Liquid Glass panel (radius 32), tiles of 236 by 186 pt, selected tile with a 22%
accent fill and a 2 pt accent border. No open animation: it must feel instant.

## Not in version one
- Windows on other Spaces and minimized windows
- Close, minimize, or quit from the switcher
- Search, app filters, and an exclude list
```

## How it works

| Part | API | Permission |
| --- | --- | --- |
| Trigger ⌥Tab and ⌥⇧Tab | Carbon `RegisterEventHotKey` | None |
| Keys while open (Esc, arrows, Return, all with the modifier held) | Carbon, registered on open, removed on close | None |
| Notice the modifier going up | Listen-only `CGEvent.tapCreate` on `.flagsChanged`, plus a 25 ms poll of `CGEventSource.flagsState(.combinedSessionState)` | Input Monitoring for the tap; the poll needs none |
| List windows | `CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID)` | None (titles need Screen Recording) |
| Previews | `SCShareableContent`, `SCScreenshotManager.captureImage` with `SCContentFilter(desktopIndependentWindow:)` | Screen Recording |
| Focus one window | private SkyLight `_SLPSSetFrontProcessWithOptions` and `SLPSPostEventRecordTo`, then AX `kAXRaiseAction` and `kAXMainAttribute` | Accessibility |
| Window ID to AX element | private `_AXUIElementGetWindow` | Accessibility |
| ⌘Tab mode | private `CGSSetSymbolicHotKeyEnabled` for hotkeys 1 and 2 | None |
| Panel | `NSPanel` with `[.borderless, .nonactivatingPanel]` | None |

Recipes: [global hotkey](../skills/code/os-integrations/recipes.md#global-hotkey-carbon), [event tap](../skills/code/os-integrations/recipes.md#event-tap), [non-activating panel](../skills/code/os-integrations/recipes.md#non-activating-panel), [screen capture](../skills/code/os-integrations/recipes.md#screen-capture).

Main types:

- `OnScreenWindow`: id, pid, app name, title, icon, bounds.
- `WindowList`: reads on-screen windows front to back, filters them, caches app icons per pid.
- `WindowSwitcher`: `@Observable` session: items, selection, isActive; `step`, `commit`, `cancel`.
- `SwitcherView`: the tile grid inside a `FirstClickHostingView` (an `NSHostingView` whose `acceptsFirstMouse` returns true).
- `WindowThumbnails`: captures and caches previews with ScreenCaptureKit.
- `KeyEventTap`: one listen-only tap that forwards `flagsChanged` to the switcher.
- `SkyLight`: looks up the private calls with `dlopen` and `dlsym`, falls back to public APIs when missing.
- `HotkeyCenter`, `KeyCombo`, `Permissions`: as in the window snapper spec.

Behaviors that matter:

- **Which windows.** Layer 0, alpha above 0.01, at least 60 by 60 pt, owned by an app with `activationPolicy == .regular`. Keep the list order: it is front to back. An empty title falls back to the app name. Switch's own Settings window counts; its panel is not on layer 0.
- **First press.** Open and select index 1 (the window behind the current one). ⌥⇧Tab opens on the last item. Later presses add or subtract one and wrap around.
- **Quick tap.** If the modifier is already up when the list is built, select index 1 and switch at once. No panel.
- **Show delay.** Show the panel 90 ms after opening, and only if the session is still active. A fast ⌥Tab never flashes the panel.
- **Let go.** The tap sees `flagsChanged` without the trigger flag and commits. A 25 ms timer on the main queue checks the real key state too, in case that event is missed.
- **Keys while open.** Esc cancels. ← and → step by one. ↑ and ↓ step by one row (the column count). Return commits. A click on a tile selects and commits.
- **Grid size.** Use the visible frame of the screen under the pointer. Columns = how many 236 pt tiles with 10 pt spacing fit in 90% of the width, minus padding 14 and shadow margin 30 on each side, at least 1, at most the window count. Height stops at 90% of the screen; the grid scrolls.
- **Previews.** Only with Screen Recording. Show cached pictures right away, then capture up to 24 windows at once and update each tile as its picture lands. Max 440 by 280 px, scale at most 2, `showsCursor = false`, `ignoreShadowsSingleWindow = true`. A generation counter drops pictures from an older session. Keep the cache to the current windows. Fetch `SCShareableContent` again only when a window ID is not cached.
- **Focus.** Close the panel first, then on a `.userInteractive` background queue: find the AX window by ID, call SkyLight, then un-minimize, raise, and set main. Without SkyLight, `NSRunningApplication.activate()`. One of Switch's own windows: `NSApp.activate()` and `makeKeyAndOrderFront`.
- **⌘Tab mode.** Turn off system hotkeys 1 and 2 (⌘Tab and ⌘⇧Tab) and register ⌘Tab instead. Turn them back on in `applicationWillTerminate` and whenever the trigger goes back to ⌥ or the switcher is turned off.
- **Prewarm.** 2 s after launch, build the panel and fill the icon cache, so the first ⌥Tab is as quick as the rest.

The focus call, without the error handling:

```swift
var psn = ProcessSerialNumber()
if getProcessForPID(pid, &psn) == noErr {
    _ = setFrontProcess(&psn, windowID, 0x200)   // 0x200: user generated
    makeKeyWindow(&psn, windowID)                // two SLPSPostEventRecordTo calls
} else {
    NSRunningApplication(processIdentifier: pid)?.activate()
}
AXUIElementPerformAction(axWindow, kAXRaiseAction as CFString)
```

## Stories

```markdown
## M1 Core loop

### S-001 Open the switcher with ⌥Tab
As the user, I hold ⌥ and press Tab, and a panel shows every window on this Space.
Screens: switcher.png
Acceptance:
- [snap] Tiles show the app icon and the window title, with the second tile selected.
- [unit] The window filter drops layer 1 windows, windows under 60 pt, and windows with alpha 0.
- [manual] The panel shows about 90 ms after the press, centered on the screen under the pointer.
Status: todo

### S-002 Step through windows
As the user, I press Tab again to move forward and ⇧Tab to move back while holding ⌥.
Depends: S-001
Acceptance:
- [unit] Stepping past the last item wraps to the first, and back from the first wraps to the last.
- [snap] The accent border sits on the selected tile.
Status: todo

### S-003 Let go to switch
As the user, I let go of ⌥ and the selected window comes to the front with keyboard focus.
Depends: S-001
Acceptance:
- [manual] Picking the second window of the same app (two Finder windows) focuses that window, not just the app.
- [manual] Typing right after the switch goes into the new window.
- [manual] A quick tap of ⌥Tab lands in the window I used before and never shows the panel.
Status: todo

### S-004 Cancel with Esc
As the user, I press Esc while holding ⌥ and the panel closes without switching.
Depends: S-001
Acceptance:
- [self] After cancel, the session keys (Esc, arrows, Return) are unregistered.
Status: todo

### S-005 Grant Accessibility and Input Monitoring
As the user, I open Switch for the first time and Settings shows both permissions with Grant buttons.
Screens: settings-permissions.png
Acceptance:
- [snap] Each row shows On or Off, one line on what breaks without it, and a Grant button.
- [manual] Within 2 seconds of a grant in System Settings, the row shows On and ⌥Tab works without a restart.
- [manual] Settings opens by itself at launch while Accessibility is off.
Status: todo

### S-006 Menu bar item
As the user, I click the Switch icon to see the trigger, open Settings, or quit.
Screens: menu.png
Acceptance:
- [snap] The menu shows "Switch windows: ⌥⇥", a warning row when a permission is off, Settings, and Quit.
Status: todo

## M2 Previews and settings

### S-007 Show window previews
As the user, I see a picture of each window in its tile.
Depends: S-001
Screens: switcher-previews.png
Acceptance:
- [manual] Tiles show cached pictures at once and fresh ones within a moment.
- [self] A session with 12 windows captures at most 24 and never above 440 by 280 px.
Status: todo

### S-008 Work without Screen Recording
As the user, I use Switch without Screen Recording and still find my windows.
Depends: S-007
Acceptance:
- [snap] Tiles show a large app icon in place of the picture, and the app name as the title.
- [snap] Settings shows "Screen Recording: Off. Previews and window titles need it." with a Grant button.
Status: todo

### S-009 Move with arrows and click
As the user, I use the arrow keys while holding ⌥, or click a tile.
Depends: S-002
Acceptance:
- [unit] ↓ moves the selection by the column count and wraps.
- [manual] One click on a tile switches, even though the panel is not key.
Status: todo

### S-010 Use ⌘Tab as the trigger
As the user, I pick "⌘ Tab (replaces the macOS app switcher)" in Settings.
Screens: settings-switcher.png
Acceptance:
- [manual] ⌘Tab opens Switch and the macOS app switcher does not appear.
- [manual] After quitting Switch, ⌘Tab shows the macOS app switcher again.
Status: todo

### S-011 Turn the switcher or previews off
As the user, I turn off the switcher or the previews in Settings.
Acceptance:
- [self] With the switcher off, no trigger hotkey is registered.
- [self] With previews off, opening the switcher starts no capture.
Status: todo

## Dropped
- Activity log of switches
- Per-feature animation speed setting
- URL scheme and debug bridge preview command
```

## Gotchas

- Public APIs cannot reliably focus one specific window of another app on macOS 14 and later: `activate()` brings the app, not the window. Onyx uses the same SkyLight calls as AltTab and yabai, looked up with `dlsym` at run time, and falls back to public APIs when a symbol is missing.
- The key-up can arrive before the Tab hotkey is handled, or get lost. The panel then stays open with nothing held. The 25 ms check of `CGEventSource.flagsState` fixes it. Keep that timer on the main queue: a closure from a `@MainActor` type that runs on a background queue traps at run time in Swift 6.
- The system turns a tap off after a slow callback (`tapDisabledByTimeout`, `tapDisabledByUserInput`). Re-enable it in the callback and keep the callback tiny.
- `CGEvent.tapCreate` returns nil until the permission is granted. Retry every 2 s, and call `CGRequestListenEventAccess()` once.
- Turning off the system ⌘Tab outlives the app. Turn it back on at quit, and set it from the saved trigger at every launch, so a crash does not leave the user without ⌘Tab.
- `NSRunningApplication.icon` asks NSWorkspace on every call, about 14 ms for a dozen windows. Cache icons per pid and clear the cache past 150 entries.
- The first ⌥Tab after launch took 162 ms because the panel and hosting view were built on that press. Prewarm both 2 s after launch.
- `SCWindow` and `SCContentFilter` are not Sendable, and a task group over them fails with a region isolation error. Use an array of `Task { @MainActor in ... }` and await each one.
- A hosting view in a panel that is not key eats the first click. Return true from `acceptsFirstMouse`.
- Without Screen Recording, `kCGWindowName` is empty. Fall back to the app name and never show a blank title.
- AX calls can block up to the messaging timeout on a hung app. Run the focus call on a background queue and set `AXUIElementSetMessagingTimeout` to 1.0 at launch.

Done when holding ⌥ and pressing Tab shows every window on the current Space with icon and title, and letting go focuses the chosen window, including a second window of the same app.
