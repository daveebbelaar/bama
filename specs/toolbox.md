# Toolbox

One menu bar panel for the small Mac settings you flip every day: keep the Mac awake, show hidden files, hide desktop icons, dark mode, Dock auto-hide, sound devices, and mouse scroll direction. Replaces: Amphetamine, Caffeine, TinkerTool, Mos. Taken from Onyx.

## Brief

```markdown
# Toolbox

A menu bar panel of one-click toggles for the Mac settings you change every day.

## Replaces
Amphetamine, Caffeine, TinkerTool, Mos

## Main jobs
1. Keep the Mac awake until I turn it off, for a set time, or while one app runs.
2. Flip hidden files, desktop icons, dark mode, and Dock auto-hide with one click.
3. Switch the sound output and input device.

## Data
- Settings: Keep Awake duration (default "Until turned off"), reverse mouse scroll
  (default off), shortcuts. UserDefaults.
- Keep Awake session: on, end date, app pid and name. Memory only.

## Shape
Menu bar extra in window style, plus a Settings window. macOS 26 or later.
No Dock icon (LSUIElement). Local data. Works offline. No accounts.

## System hooks
Menu bar item, global shortcuts for four toggles (no defaults), Automation of System
Events for dark mode, Accessibility for the scroll reverser, launch at login.

## Reference
Amphetamine for Keep Awake, Control Center for the look.

## Look
Native, system accent color. A row of round toggle buttons, each a symbol with a
one-word label under it, like Control Center. A short glass toast confirms each change.

## Not in version one
- Keep Awake schedules and battery rules
- More hidden settings (screenshot format, key repeat)
- Per-app sound output
```

## How it works

| Part | API | Permission |
| --- | --- | --- |
| Keep Awake | `IOPMAssertionCreateWithName` with `kIOPMAssertionTypePreventUserIdleDisplaySleep` | None |
| Stop when an app quits | `NSWorkspace.didTerminateApplicationNotification` | None |
| Hidden files, desktop icons, Dock auto-hide | `CFPreferencesSetAppValue` on `com.apple.finder` / `com.apple.dock`, then `/usr/bin/killall Finder` or `Dock` | None |
| Read dark mode | `CFPreferencesCopyAppValue("AppleInterfaceStyle", kCFPreferencesAnyApplication)` | None |
| Set dark mode | `NSAppleScript` to System Events | Automation (System Events) |
| Follow dark mode changes | `DistributedNotificationCenter`, `AppleInterfaceThemeChangedNotification` | None |
| Sound devices | CoreAudio `AudioObjectGetPropertyData` / `AudioObjectSetPropertyData` | None |
| Follow device changes | `AudioObjectAddPropertyListenerBlock` | None |
| Reverse mouse scroll | Modifying `CGEvent.tapCreate` (`.defaultTap`) on `.scrollWheel` | Accessibility |
| Shortcuts | Carbon `RegisterEventHotKey` | None |
| Menu bar | `MenuBarExtra` with `.menuBarExtraStyle(.window)` | None |

Recipes: [global hotkey](../skills/code/os-integrations/recipes.md#global-hotkey-carbon), [event tap](../skills/code/os-integrations/recipes.md#event-tap), [launch at login](../skills/code/os-integrations/recipes.md#launch-at-login).

Main types:

- `KeepAwake`: `@Observable`. Holds the power assertion, the end timer, and the app watch. `Duration`: `minutes15`, `hour1`, `hours2`, `indefinitely`.
- `SystemToggle`: enum `hiddenFiles`, `desktopIcons`, `darkMode`, `dockAutoHide`, with title, one-word label, detail line, symbol, toast text.
- `SystemToggles`: reads and writes the setting behind each toggle. No state.
- `QuickToggles`: `@Observable` live state for the views, a `busy` set, optimistic changes.
- `AudioDevices`: `@Observable` list of outputs and inputs and the current defaults.
- `ScrollReverser`: installs or removes the scroll tap to match the setting.
- `Toast`: a glass capsule at the top of the screen under the pointer, gone after 1.5 s, ignores the mouse.
- `MenuBarPanel`: the round toggles, the Keep Awake timer menu, the sound menu.

Behaviors that matter:

- **Keep Awake.** It only stops idle display sleep. Closing the lid still sleeps the Mac; say so in Settings. Every start first releases the old assertion and clears the timer and app watch. Timed: a one-shot `Timer` that turns it off. While an app runs: watch `didTerminateApplicationNotification` and stop when the pid matches, with a toast "Xcode quit. Keep Awake is off". Changing the duration while a timed session runs restarts it with the new length.
- **Keep Awake text.** Settings: "On, 14:59 left", "On while Xcode runs", "On until you turn it off", or "Off. Your Mac sleeps as usual." The menu bar button label shows the time left, else "Awake". Clock format `h:mm:ss` over an hour, else `m:ss`, rounded up. Tick with `TimelineView(.periodic(from: .now, by: 1))`, so it only runs while visible.
- **Keep Awake button.** Click toggles with the saved duration. Right-click shows 15 minutes, 1 hour, 2 hours, Until turned off, and Turn Off.
- **Toggles.** Click sets the new state right away, marks the toggle busy (a small spinner, further clicks ignored), and runs the change in a `Task`. On success: toast. On failure: put the old state back and toast the error.
- **Refresh.** Read every toggle again when the menu bar panel or Settings appears (the panel window stays alive, so listen for `NSWindow.didBecomeKeyNotification`), and on the dark mode notification.
- **Sound.** Setting the output also sets `kAudioHardwarePropertyDefaultSystemOutputDevice` so alerts follow; ignore that one's failure. Refresh on changes to devices, default output, and default input.
- **Scroll reverser.** Leave trackpad and Magic Mouse scrolls alone: they carry a scroll phase or momentum phase. For a wheel, negate the line, point, and fixed-point deltas on axis 1 and 2.

| Toggle | Key and domain | Missing means | Applies by |
| --- | --- | --- | --- |
| Show hidden files | `AppleShowAllFiles`, `com.apple.finder` | off | `killall Finder` |
| Show desktop icons | `CreateDesktop`, `com.apple.finder` | on | `killall Finder` |
| Hide the Dock automatically | `autohide`, `com.apple.dock` | off | `killall Dock` |
| Dark mode | `AppleInterfaceStyle == "Dark"`, any app | off (light) | System Events |

Reading a preference. The value can be a number or a string:

```swift
CFPreferencesAppSynchronize(app)               // drop the cached copy first
switch CFPreferencesCopyAppValue(key as CFString, app) {
case let number as NSNumber: return number.boolValue
case let text as String: return ["1", "yes", "true"].contains(text.lowercased())
default: return nil                            // use the "missing means" column
}
```

Dark mode script: `tell application "System Events" to tell appearance preferences to set dark mode to true`.

## Stories

```markdown
## M1 Core loop

### S-001 Turn Keep Awake on and off
As the user, I click the cup button in the menu bar panel and the Mac stops going to sleep.
Screens: menu.png
Acceptance:
- [snap] The cup button shows its on state and the label "Awake".
- [self] `pmset -g assertions` lists a PreventUserIdleDisplaySleep assertion named "Toolbox Keep Awake"; it is gone after the second click.
- [manual] A toast "Keep Awake on" shows for 1.5 s at the top of the screen.
Status: todo

### S-002 Keep the Mac awake for a set time
As the user, I right-click the cup button and pick 15 minutes, 1 hour, or 2 hours.
Depends: S-001
Acceptance:
- [unit] `clock(3599)` is "59:59" and `clock(7199.2)` is "2:00:00".
- [snap] The button label counts down, for example "14:59".
- [self] Starting a new session releases the old assertion first: only one assertion exists.
Status: todo

### S-003 Show or hide hidden files
As the user, I click the eye button and Finder shows dot files.
Screens: menu.png
Acceptance:
- [unit] A stored string "YES" reads as on; a missing value reads as off.
- [manual] Finder restarts and shows hidden files; the button shows a spinner until it is done.
Status: todo

### S-004 Hide desktop icons and the Dock
As the user, I click the desktop button for a clean desktop before I share my screen, and the Dock button to hide the Dock.
Acceptance:
- [unit] A missing `CreateDesktop` value reads as on.
- [manual] Desktop icons disappear after Finder restarts, and come back with a second click.
- [manual] The Dock button turns on auto-hide the same way, through a Dock restart.
Status: todo

### S-005 Switch dark mode and grant Automation
As the user, I click the moon button; the first time, macOS asks if Toolbox may control System Events.
Acceptance:
- [manual] After Allow, the Mac switches to dark mode and the button stays in sync when I change it in System Settings.
- [manual] After Don't Allow, the button flips back and a toast says "Allow Toolbox to control System Events in Privacy & Security > Automation".
- [self] Info.plist has `NSAppleEventsUsageDescription`.
Status: todo

### S-006 Switch the sound output and input
As the user, I open the sound menu in the panel header and pick a device.
Screens: menu-sound.png
Acceptance:
- [snap] The header shows the current output name; the menu lists outputs and inputs with a check on the current ones.
- [manual] Plugging in headphones adds them to the list without reopening the panel.
Status: todo

## M2 Settings and extras

### S-007 Keep the Mac awake while an app runs
As the user, I pick an app in Settings and Keep Awake stays on until that app quits.
Screens: settings.png
Acceptance:
- [manual] Quitting the app turns Keep Awake off with a toast naming the app.
- [snap] The status line reads "On while Xcode runs".
Status: todo

### S-008 Settings page
As the user, I open Settings and see Keep Awake, the four toggles with a detail line each, Sound, and Shortcuts.
Screens: settings.png
Acceptance:
- [snap] Each toggle row has a symbol, a title, one line of detail, and a switch.
- [snap] The Keep Awake footer says "Closing the lid still sleeps the Mac."
Status: todo

### S-009 Give a toggle a shortcut
As the user, I record a shortcut for Keep Awake, hidden files, desktop icons, or dark mode.
Depends: S-008
Acceptance:
- [manual] The shortcut flips the setting and shows the toast.
- [snap] A shortcut another app owns shows an orange warning next to the field.
Status: todo

### S-010 Reverse the mouse wheel and grant Accessibility
As the user, I turn on "Reverse mouse scroll direction" and the wheel flips while the trackpad stays the same.
Acceptance:
- [manual] Without Accessibility, the row shows "Needs Accessibility" with a button to the right System Settings pane, and the tap installs within 2 s of the grant.
- [manual] The wheel scrolls the other way; trackpad and Magic Mouse do not change.
- [snap] The footer says "Quit Mos or other scroll apps first, or the direction flips twice."
Status: todo

### S-011 Launch at login
As the user, I turn on "Open at login" in Settings.
Acceptance:
- [self] The toggle reflects `SMAppService.mainApp.status`.
Status: todo

## Dropped
- Debug bridge commands, URL scheme, and App Intents for each toggle
- App icon picker and Dock icon option
```

## Gotchas

- `CFPreferencesCopyAppValue` returns a cached value, so a change made in Terminal or System Settings never showed. Call `CFPreferencesAppSynchronize` before every read.
- Finder and the Dock read these keys only at launch. Write, synchronize, then `killall Finder` or `killall Dock`; macOS starts them again. Run `killall` and `waitUntilExit()` in a detached task, not on the main thread.
- The first dark mode switch blocks until the user answers the Automation prompt. On the main thread that froze the whole menu. Run `NSAppleScript` on a serial background queue and resume a continuation.
- Error `-1743` from the script means Automation was denied. Show where to fix it, not a generic error. Without `NSAppleEventsUsageDescription` in Info.plist the request fails. With the hardened runtime, also add the `com.apple.security.automation.apple-events` entitlement.
- Release the old power assertion before creating a new one. A leaked `IOPMAssertionID` keeps the Mac awake after the button says off.
- `kIOPMAssertionTypePreventUserIdleDisplaySleep` does not stop lid-close sleep. Users expect it to, so the Settings footer says it.
- Setting the default system output device fails on some devices. Treat only the main output call as the result.
- Swift 6 traps at run time when a closure made in a `@MainActor` type runs on a background queue. Pass `.main` as the queue to `AudioObjectAddPropertyListenerBlock`, or mark the closure `@Sendable`.
- Setting one scroll delta field changes the others. Read line, point, and fixed-point values first, then write all three negated.
- A modifying tap needs Accessibility, and `CGEvent.tapCreate` returns nil until it is granted. Retry every 2 s while the setting is on, remove the tap when it is off, and re-enable it on `tapDisabledByTimeout`.
- System switches draw grey when their window is not key, which looks like "off" in a snapshot taken while another app is in front. Check toggle state with `[self]` lines, not only snapshots.

Done when every button in the menu bar panel changes its macOS setting and shows the true state after a change made elsewhere, and Keep Awake holds exactly one assertion while on and none while off.
