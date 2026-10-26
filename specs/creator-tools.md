# Creator tools

Menu bar tools for screen-recorded tutorials: show the keys you press, highlight the cursor and clicks, get the Mac ready to film with one switch, drop YouTube chapter markers, and read a script from a teleprompter. Replaces: KeyCastr, Presentify. Taken from Onyx.

## Brief

```markdown
# Studio

Menu bar tools for people who record screen tutorials and YouTube videos.

## Replaces
KeyCastr, Presentify, writing chapter times on paper, a script in a second window

## Main jobs
1. Show my shortcuts and clicks on screen, and turn on Recording Mode with one switch.
2. Drop chapter markers while I record and copy them for YouTube.
3. Read my script from a teleprompter near the camera.

## Data
- ChapterSession: start (date), markers. Saved to Application Support/Studio/chapters.json.
- ChapterMarker: id, offset (seconds since start), label.
- RecordingSnapshot: what Recording Mode changed (desktop icons before, Dock, overlays, Focus shortcut ran). Saved in UserDefaults.
- Settings in UserDefaults: keystroke mode, halo size, teleprompter text, speed, font size, width, opacity, mirror, Focus shortcut names, hotkeys.

## Shape
Menu bar extra plus click-through overlay windows and a Settings window, macOS 26 or later.
LSUIElement, no Dock icon. Local data. Works offline. No accounts.

## System hooks
Global shortcuts, a listen-only event tap for keys, the menu bar, the Shortcuts app (`shortcuts run`).

## Reference
KeyCastr (key caps), Presentify (cursor halo)

## Look
Native with a violet accent (#7B5CFF). Overlays are glass capsules; the teleprompter is a dark plate so white text reads on any wallpaper.

## Not in version one
- Drawing on the screen
- Zoom and spotlight effects
- Its own screen recorder
```

## How it works

| Part | API | Permission |
| --- | --- | --- |
| Keystroke overlay | `CGEvent.tapCreate(.cgSessionEventTap, options: .listenOnly)` for `.keyDown` | Input Monitoring (`CGRequestListenEventAccess`) |
| Hide password keys | `IsSecureEventInputEnabled()` (Carbon) | None |
| Cursor halo and click ripple | `NSEvent.addGlobalMonitorForEvents` + local monitor, `CAGradientLayer` | None |
| Overlay windows | Borderless `NSPanel`, `.screenSaver` level, `ignoresMouseEvents` | None |
| Keep notes out of recordings | `NSWindow.sharingType = .none` | None |
| Global shortcuts | Carbon `RegisterEventHotKey` ([recipe](../skills/code/os-integrations/recipes.md#global-hotkey-carbon)) | None |
| Hide desktop icons | `CFPreferences` `com.apple.finder` `CreateDesktop`, then `killall Finder` | None |
| Hide the Dock | `CoreDockSetAutoHideEnabled` via `dlsym`, fallback `com.apple.dock autohide` + `killall Dock` | None |
| Focus (Do Not Disturb) | `Process` running `/usr/bin/shortcuts run "<name>"` | None |

Only the keystroke overlay needs a permission. Everything else works without one.

Types to create:
- `KeyTap`: one listen-only tap on the main run loop; feeds `KeystrokeOverlay`.
- `KeystrokeOverlay`: `@Observable` entries, mode, the overlay panel, fade timing.
- `CursorHighlight`: one window and one layer-hosting view per screen, event monitors while on.
- `RecordingMode`: turn on, turn off, the saved `Snapshot`, resume at launch.
- `ChapterClock`: session, markers, a key prompt panel ([recipe](../skills/code/os-integrations/recipes.md#non-activating-panel)), YouTube text, CSV via `NSSavePanel`, issues.
- `Teleprompter`: text and look settings, clock-based position, the panel.
- `Toast` (glass note, hidden from capture), `HotkeyCenter`, `ShortcutRecorder`, `SettingsView` (pages: Keystrokes, Cursor, Recording Mode, Chapters, Teleprompter, Permissions).

Behaviors that matter:
- **Keystroke modes.** "Shortcuts only" (default) shows combos with ⌘, ⌃, or ⌥, plus Esc, Tab, Return, keypad Enter, and the arrows. "All keys" shows typed text as one cap that grows, last 24 characters.
- **Keystroke timing.** Each key holds 1.5 s, then the capsule fades over 0.35 s and the panel orders out. At most 4 entries; older ones at 50% opacity. The same combo again within 1.5 s shows "×2", "×3". Keys live in memory only while on screen. Nothing is logged or saved.
- **Keystroke panel.** 1200 × 150, centered on the screen with the mouse, 40 pt above the bottom of its visible frame. Caps are 20 pt.
- **Skip what the viewer should not see:** keys while secure input is on, the app's own shortcuts (compare key code and modifiers with every bound combo), and typing in the chapter prompt.
- **Cursor halo.** Diameter 50, 70 (default), or 100. Radial gradient of #7B5CFF at alpha 0.38, 0.2, 0 (stops 0, 0.55, 1). A press scales it to 0.78 over 0.12 s. Each click adds a ring 1.1 times the halo that scales 0.3 to 1.25 and fades 0.95 to 0 over 0.5 s, ease-out. Right clicks use the lighter #A88FFF.
- **Recording Mode** turns on what its options say (defaults: hide desktop icons on, hide Dock on, keystrokes on, cursor on, Focus shortcut names empty). It records what it changed and turns off exactly that. Options can change only while it is off. The menu shows a red "REC MODE" badge; clicking it turns the mode off.
- **Chapters.** Start sets 00:00 with a first marker "Intro". Mark without a session starts one. A new marker is "Chapter N" and opens the prompt; Return saves the label, Esc keeps "Chapter N". A second mark while the prompt is open saves what was typed first. Restart with more than one marker needs a second press within 3 s. Rename saves after 0.6 s; add and delete save at once.
- **Chapter export.** Lines like `05:07 Setup`, and `1:05:07` from one hour on. The first line is always 00:00. Warn under 3 chapters or any chapter under 10 seconds (YouTube rejects those). CSV header `index,timestamp,seconds,label`, file name `chapters-YYYY-MM-DD.csv`.
- **Teleprompter.** Speed 45 pt/s (10 to 200, shortcuts step 5), font 34 pt (20 to 72), width 760 (480 to 1400), plate opacity 0.85 (0.3 to 1), mirror off. Height is max(200, font × 5.5), centered 8 pt below the menu bar on the screen with the mouse. The line you read sits 30% down, between two small violet arrows. It pauses at the end; play from the end starts at the top.
- **Shortcuts.** None set by default, so nothing clashes. Every action is also in the menu bar menu. Each toggle shows a toast ("Keystrokes on", "Speed 50").

Teleprompter position comes from the clock, so nothing runs while paused:

```swift
func position(at date: Date) -> CGFloat {
    guard let playStart else { return min(basePosition, maxPosition) }
    let moved = CGFloat(speed * date.timeIntervalSince(playStart))
    return min(basePosition + moved, maxPosition)
}
// View: TimelineView(.animation(minimumInterval: nil, paused: !isPlaying)) { ctx in
//     text.offset(y: readingLine - prompter.position(at: ctx.date)) }
```

## Stories

```markdown
# Stories

## M1 Core loop

### S-001 Toggle each tool from the menu bar
As the user, I open the menu bar menu and switch keystrokes and the cursor halo on or off.
Screens: menu.png
Acceptance:
- [snap] The menu lists Keystrokes and Cursor highlight with switches, plus Settings and Quit.
- [self] Each switch changes the tool's state and shows a toast that has `sharingType == .none`.
Status: todo

### S-002 Grant Input Monitoring
As the user, I turn on keystrokes and get asked for Input Monitoring once.
Screens: settings-keystrokes.png
Acceptance:
- [manual] The first switch-on calls `CGRequestListenEventAccess` and the system prompt appears.
- [snap] While denied, the Keystrokes page says Studio needs Input Monitoring to see your keys, with an Open System Settings button (`Privacy_ListenEvent`).
- [manual] After granting, keys show within 2 seconds without a restart.
Status: todo

### S-003 Show shortcuts as key caps
As the user, I press ⌘K and see ⌘ K as key caps at the bottom of the screen.
Screens: keystrokes.png, settings-keystrokes.png
Depends: S-002
Acceptance:
- [snap] Up to 4 entries in a glass capsule; the newest at full opacity, older at 50%.
- [unit] The same combo three times within 1.5 s gives one entry with count 3.
- [unit] In "All keys" mode typed text keeps the last 24 characters; arrows never become text.
- [manual] A password field shows nothing, and the overlay never takes a click, also over a full screen app.
Status: todo

### S-004 Highlight the cursor and clicks
As the user, I turn on the halo and every click draws a ripple.
Screens: cursor.png, settings-cursor.png
Acceptance:
- [snap] A violet halo follows the pointer; Small, Medium, Large set 50, 70, 100 pt.
- [manual] It follows the pointer across two displays without lag, and right clicks ripple lighter.
- [self] Turning it off removes every window and event monitor.
Status: todo

### S-005 Set shortcuts in Settings
As the user, I record a shortcut for each action in Settings.
Screens: settings-keystrokes.png
Acceptance:
- [snap] Every action has a recorder field; a combo another app owns shows "Already in use".
- [self] Pressing a recorded shortcut runs its action, and it never shows in the keystroke overlay.
Status: todo

## M2 Recording Mode and chapters

### S-006 Turn on Recording Mode
As the user, I flip one switch and desktop icons, the Dock, and the overlays change for filming.
Screens: menu.png, settings-recording.png
Acceptance:
- [manual] Icons and Dock hide; turning it off puts back exactly what it changed. Already hidden icons cause no Finder restart.
- [manual] With Focus shortcut names filled in, it runs the "on" shortcut, and the "off" one when turned off.
- [snap] The menu shows a red REC MODE badge while on.
Status: todo

### S-007 Restore after a quit or crash
As the user, I quit with Recording Mode on and my desktop comes back.
Depends: S-006
Acceptance:
- [self] A saved snapshot at launch shows Recording Mode as on, and turning it off restores.
- [manual] Quitting with it on restores icons and Dock before the app exits.
Status: todo

### S-008 Mark a chapter while recording
As the user, I press the chapter shortcut, type a label, and press Return.
Screens: chapter-prompt.png
Acceptance:
- [snap] The prompt shows the timestamp, a text field, and hints for Return and Esc.
- [unit] Timestamps read 05:07 under an hour and 1:05:07 after.
Status: todo

### S-009 Copy chapters for YouTube
As the user, I copy the list and paste it into the video description.
Screens: settings-chapters.png
Depends: S-008
Acceptance:
- [unit] The first line is pinned to 00:00; the issues list catches under 3 chapters and chapters under 10 s.
- [snap] Settings lists chapters with editable labels, remove buttons, Copy for YouTube, Export CSV, and Clear with a confirm.
Status: todo

## M3 Teleprompter

### S-010 Read a script from the teleprompter
As the user, I paste my script in Settings and show it under the menu bar.
Screens: teleprompter.png, settings-teleprompter.png
Acceptance:
- [snap] White text on a dark plate, faded at top and bottom, violet arrows at the reading line, "Paused" badge.
- [snap] Font size, width, and opacity sliders show their values; mirror flips the text; a footer says to make a test recording.
Status: todo

### S-011 Play, pause, and change speed
As the user, I start scrolling with a shortcut and match my pace with faster and slower.
Depends: S-010
Acceptance:
- [unit] Changing speed while playing keeps the current position.
- [self] It pauses itself at the end, and play from the end starts at the top.
Status: todo

## Dropped
- Pausing clipboard history in Recording Mode: Studio has no clipboard history.
- Debug bridge commands and status.json fields for every tool.
- Per-feature animation speed settings.
```

## Gotchas

- **A listen-only tap needs Input Monitoring, not Accessibility.** `CGEvent.tapCreate` returns nil until the user grants it. Call `CGRequestListenEventAccess()` once, then try to install the tap again every 2 s until it works.
- **The system turns slow taps off.** On `.tapDisabledByTimeout` or `.tapDisabledByUserInput`, call `CGEvent.tapEnable(tap:enable: true)` and pass the event on. Keep the callback tiny.
- **Never show password keys.** Check `IsSecureEventInputEnabled()` on every key down. Password fields turn secure input on.
- **Overlays vanish or eat clicks without the right flags.** Use `level = .screenSaver`, `ignoresMouseEvents = true`, `hidesOnDeactivate = false`, and `collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]`.
- **The halo lags unless you turn off implicit animation.** Move the layer inside `CATransaction.setDisableActions(true)`. A mouse move must only change a layer position, never redraw the view.
- **The global monitor misses your own windows.** Add a local monitor with the same mask, or clicks in Studio's Settings get no ripple. Rebuild the per-screen windows on `NSApplication.didChangeScreenParametersNotification`. Install monitors only while the halo is on.
- **`sharingType = .none` is a request.** Recorders built on newer ScreenCaptureKit may still capture the teleprompter, the prompt, and toasts. Tell the user to make a short test recording.
- **Desktop icons: unset is not false.** `CreateDesktop` may be missing. Save nil and write nil back on restore. When icons are already hidden, change nothing, so Finder does not restart.
- **Dock auto-hide without a Dock restart.** `CoreDockSetAutoHideEnabled` (found with `dlsym` in ApplicationServices) applies at once. If the symbol is missing, write `autohide` to `com.apple.dock` and `killall Dock`.
- **Quitting with Recording Mode on.** Save the snapshot to UserDefaults on turn-on, so the next launch can restore after a crash. On quit, start `killall` and `shortcuts` directly on the calling thread; work queued on a background queue never runs before exit.
- **The teleprompter must not tick while paused.** Work out the position from `basePosition + speed × elapsed` and pause the `TimelineView` when not playing. When speed changes, set `basePosition` to the current position and reset `playStart`, or the text jumps. Draw one `Text` per paragraph so no single layer gets huge.

Done when keystrokes and the cursor halo show in a test recording, Recording Mode hides and restores the desktop and Dock, chapters copy as valid YouTube text, and the teleprompter scrolls at the set speed while staying out of the user's clicks.
