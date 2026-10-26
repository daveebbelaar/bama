# Window snapper

Snap the front window to the left or right half, a wide side, or full screen with a keyboard shortcut, and move it to the next display. Replaces: Magnet, Rectangle. Taken from Onyx.

## Brief

```markdown
# Snap

A menu bar app that moves and resizes the front window with keyboard shortcuts, for anyone who wants Magnet without paying for it.

## Replaces
Magnet, Rectangle

## Main jobs
1. Snap the front window to the left half, the right half, or full screen with a shortcut.
2. Snap it to a wide left or right side (two thirds by default), or send it to the next display.
3. Change any shortcut, the wide width, and the gap around windows in Settings.

## Data
- Shortcut: action, key code, modifiers, key name. Stored as JSON in UserDefaults.
- Layout: wide fraction (default 2/3), gap in points (default 0). UserDefaults.
- Restore frame: window ID and its frame before the first snap. Memory only.

## Shape
Menu bar extra plus a Settings window, macOS 26 or later. No Dock icon (LSUIElement).
Local data. Works offline. No accounts.

## System hooks
Global shortcuts (Carbon), menu bar item, Accessibility permission, launch at login.

## Reference
Magnet

## Look
Native, system accent color. Each action shows a small layout glyph in the menu.

## Not in version one
- Drag a window to a screen edge to snap it
- Thirds, quarters, center
- URL scheme and Shortcuts actions
```

## How it works

| Part | API | Permission |
| --- | --- | --- |
| Global shortcuts | Carbon `RegisterEventHotKey` | None |
| Know which app to move | `NSWorkspace.frontmostApplication`, `didActivateApplicationNotification` | None |
| Read and set the front window | `AXUIElement`: `kAXFocusedWindowAttribute`, `kAXPositionAttribute`, `kAXSizeAttribute` | Accessibility |
| Window ID for Restore | private `_AXUIElementGetWindow` (via `@_silgen_name`) | Accessibility |
| Usable screen area | `NSScreen.visibleFrame` (no menu bar, no Dock) | None |
| Menu bar item | `MenuBarExtra` | None |
| Launch at login | `SMAppService.mainApp.register()` | User approves once |

Recipes: [global hotkey](../skills/code/os-integrations/recipes.md#global-hotkey-carbon), [move a window](../skills/code/os-integrations/recipes.md#accessibility-move-a-window), [launch at login](../skills/code/os-integrations/recipes.md#launch-at-login).

Main types:

- `SnapCommand`: enum of `left`, `right`, `maximize`, `leftWide`, `rightWide`, `nextDisplay`, `previousDisplay`, `restore`.
- `Layout`: pure functions that turn a command, a window frame, and a screen area into a target frame. Unit tested.
- `WindowManager`: picks the target app, reads the focused window, applies the frame, remembers Restore frames.
- `AX`: small helpers: `focusedWindow(pid:)`, `frame(of:)`, `setFrame(_:window:pid:)`, `windowID(of:)`.
- `HotkeyCenter`: registers Carbon hotkeys from the saved bindings, keeps a set of failed ones, can suspend and resume.
- `KeyCombo`: key code, modifiers, and a printable key name. `Codable`.
- `ShortcutField`: SwiftUI shortcut recorder for one action.
- `Permissions`: `@Observable` Accessibility state with polling.

Default shortcuts: Left Half ⌥⌘←, Right Half ⌥⌘→, Maximize ⌥⌘↩, Left Wide ⌥⌘↓, Right Wide ⌥⌘↑, Next Display ⌃⌥⌘→, Previous Display ⌃⌥⌘←, Restore ⌥⌘⌫.

Behaviors that matter:

- **Which screen.** The screen that shows the largest part of the window (biggest intersection of `screen.frame` and the window). Use its `visibleFrame` as the area, so the menu bar and Dock stay clear.
- **Halves.** Left: `x = area.minX`, `width = area.width / 2`, full height. Right: `x = area.midX`. Maximize: the whole area.
- **Wide.** One setting, not a cycle: two thirds (default), three quarters, or five sixths. Clamp to 0.5...0.9. Left Wide starts at `area.minX`; Right Wide ends at `area.maxX`. Settings titles show the fraction: "Left Wide (3/4)".
- **Gap.** 0 to 40 pt in steps of 2, default 0. Round the frame to whole points first (`.integral`), then inset: a full gap on a side that touches the area edge (within 1 pt), half a gap on a side that meets a neighbour. Two halves then have one full gap between them.
- **Next and previous display.** Sort `NSScreen.screens` by `(frame.minX, frame.minY)` and wrap around. Keep the relative position and size: scale x, y, width, and height by the ratio of the two visible frames, then intersect with the new area. If that is empty, use the whole new area. With one display, do nothing.
- **Restore.** Before the first snap of a window, store its frame under its `CGWindowID`. Later snaps keep the first one. Restore puts it back and forgets it. No stored frame: beep.
- **Target app.** The front app, unless the front app is Snap itself (a click in its menu) or Shortcuts. Then use the last other app, tracked with `didActivateApplicationNotification`.
- **Failure.** No permission, no app, or no focused window: `NSSound.beep()` and nothing else.
- **Check and retry.** After setting the frame, read it back. If it is more than 2 pt off, set it again after 0.08 s. If the window is still larger than the target (an app with a minimum size), keep it inside the screen against the edge it was sent to: right-side commands align its right edge, all commands align its top.
- **Shortcut rules.** One combo belongs to one action: setting it removes it from any other action. A combo needs at least one modifier, except F1 to F12.

AX frames use a top-left origin on the primary screen. AppKit uses bottom-left. The same flip converts both ways:

```swift
extension CGRect {
    var flipped: CGRect {
        let height = NSScreen.screens.first?.frame.maxY ?? 0   // primary screen, not .main
        return CGRect(x: minX, y: height - maxY, width: width, height: self.height)
    }
}
```

## Stories

```markdown
## M1 Core loop

### S-001 Snap the front window to the left half
As the user, I press ⌥⌘← and the front window fills the left half of its screen.
Acceptance:
- [unit] `Layout` returns x = area.minX, width = area.width / 2, full height for a 1440x875 area.
- [unit] A frame flipped twice equals the original.
- [manual] In Safari, ⌥⌘← fills the left half below the menu bar and above the Dock.
Status: todo

### S-002 Snap the front window to the right half
As the user, I press ⌥⌘→ and the front window fills the right half.
Depends: S-001
Acceptance:
- [unit] `Layout` returns x = area.midX and the same width as the left half.
- [manual] TextEdit snaps right on a second display when its window is on that display.
Status: todo

### S-003 Maximize the front window
As the user, I press ⌥⌘↩ and the front window fills the screen without going full screen.
Acceptance:
- [unit] `Layout` returns the whole visible frame.
Status: todo

### S-004 Snap to a wide side
As the user, I press ⌥⌘↓ or ⌥⌘↑ and the window takes two thirds of the screen on the left or right.
Depends: S-001
Acceptance:
- [unit] Right Wide at 2/3 ends exactly at area.maxX.
- [unit] A wide fraction of 0.95 is clamped to 0.9.
Status: todo

### S-005 Grant Accessibility on first launch
As the user, I open Snap for the first time and it shows Settings with a Permissions row and a Grant button.
Screens: settings-permissions.png
Acceptance:
- [snap] The row shows "Accessibility: Off" with a Grant button and one line: "Snap needs this to move windows."
- [manual] Grant opens the system prompt or the Accessibility pane in System Settings.
- [manual] Within 2 seconds of turning it on in System Settings, the row shows "On" without a restart.
Status: todo

### S-006 Press a shortcut without Accessibility
As the user, I press a snap shortcut while Accessibility is off and Snap tells me why nothing moved.
Depends: S-005
Acceptance:
- [manual] The Mac beeps, the window does not move, and Settings opens on the Permissions row.
- [snap] The menu shows a warning row "Accessibility is off" that opens Settings.
Status: todo

### S-007 Snap from the menu bar
As the user, I click the Snap icon and pick an action; it moves the window I was using before.
Screens: menu.png
Acceptance:
- [snap] The menu lists every action with its layout glyph and current shortcut, then Settings and Quit.
- [manual] Clicking Left Half snaps the last app's window, not Snap's own.
Status: todo

## M2 Settings and displays

### S-008 Record a new shortcut
As the user, I click a shortcut field in Settings and press a new combo.
Screens: settings-shortcuts.png
Acceptance:
- [snap] The field shows "Type shortcut…" with an accent border while recording.
- [self] While recording, all global shortcuts are paused and come back after.
- [unit] Assigning a combo used by another action removes it from that action.
- [manual] Esc cancels, Delete clears, a key without a modifier beeps.
- [snap] A combo another app owns shows an orange triangle with help text "Another app already uses this shortcut."
Status: todo

### S-009 Pick the wide width and the gap
As the user, I choose Two thirds, Three quarters, or Five sixths, and a gap from 0 to 40 pt.
Screens: settings-layout.png
Acceptance:
- [unit] With a 10 pt gap, two halves leave 10 pt at each screen edge and 10 pt between them.
- [snap] The Left Wide row title changes to "Left Wide (3/4)".
Status: todo

### S-010 Move the window to the next display
As the user, I press ⌃⌥⌘→ and the window moves to the next display at the same relative spot.
Acceptance:
- [unit] A left-half window on a 1440 wide display becomes a left-half window on a 2560 wide display.
- [unit] With one display, the command returns no frame.
- [manual] Moving from a large display to a small one ends with the right size, not a clamped one.
Status: todo

### S-011 Restore a snapped window
As the user, I press ⌥⌘⌫ and the window goes back to where it was before I first snapped it.
Acceptance:
- [unit] Two snaps in a row keep the frame from before the first snap.
- [manual] Restore with nothing stored beeps.
Status: todo

### S-012 Launch at login
As the user, I turn on "Open at login" in Settings.
Acceptance:
- [self] The toggle reflects `SMAppService.mainApp.status`.
Status: todo

## Dropped
- Center command (Onyx retired it)
- URL scheme, App Intents, activity log, app icon picker
```

## Gotchas

- AX and CG use a top-left origin on the primary screen. Take the height from `NSScreen.screens.first`, not `NSScreen.main` (that is the screen with the key window). Wrong choice: windows land off-screen on a second display.
- macOS clamps a window's size to the display it is on. Set size, position, size. Moves across displays still settle late, so read the frame back and set it once more after 0.08 s.
- Some apps turn on `AXEnhancedUserInterface`, which makes them animate and ignore size changes. Read it on the app element, set it to false while you move the window, and put it back after.
- The default AX messaging timeout is 6 s. A hung app froze Onyx until it called `AXUIElementSetMessagingTimeout(AXUIElementCreateSystemWide(), 1.0)` at launch.
- A click in the menu bar makes Snap the front app, so menu actions moved nothing. Track the last app that is not Snap (and not `com.apple.shortcuts`) with `didActivateApplicationNotification`.
- Apps with a minimum size end up hanging off the screen after a half snap. After the retry, check the size and pin the window to the edge it was sent to.
- `AXUIElement` values are not stable keys. Key Restore frames by the `CGWindowID` from `_AXUIElementGetWindow`. It is private, but AltTab and Rectangle have used it for years.
- `RegisterEventHotKey` fails when another app owns the combo, and nothing else tells you. Keep the `OSStatus` and show the failure next to the shortcut.
- The recorder never sees a combo that is still registered: Carbon swallows it. Suspend every hotkey while recording, resume when done.
- The Accessibility grant is tied to the code signature and path. Sign with one Apple Development certificate, install to the same path, no App Sandbox. If the switch shows on but `AXIsProcessTrusted()` is false, remove the app from the list and add it again.
- Onyx polled permissions every 1.5 s forever. Poll every 1.5 s only while Accessibility is off or Settings is open, otherwise every 20 s with a 10% timer tolerance.

Done when every default shortcut snaps the front window of any app to the right frame on each connected display, and Settings shows the Accessibility state and changes every shortcut.
