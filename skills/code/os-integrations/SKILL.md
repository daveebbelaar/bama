---
name: os-integrations
description: Deep macOS integrations for a native app, such as global hotkeys, menu bar items, floating panels, window control with Accessibility, screen capture and recording, clipboard, Shortcuts and Spotlight, URL schemes, login items, a CLI, and the permissions each one needs. Use when an app must reach outside its own window or control other apps.
---

# macOS integrations

A Mac app is a set of entry points around the system, not one window. This
skill picks the API for each entry point and the permission it costs.
Code for every row is in [recipes.md](recipes.md).

## Pick the API

| Want | API | Permission |
| --- | --- | --- |
| Global shortcut (key combo) | Carbon `RegisterEventHotKey` | None |
| Hold-to-show (hold Option, press Tab) or key remapping | `CGEvent.tapCreate` event tap | Accessibility |
| Watch keys without changing them (keystroke overlay) | Listen-only event tap | Input Monitoring (`CGRequestListenEventAccess`) |
| List other apps' windows | `CGWindowListCopyWindowInfo` | None (titles need Screen Recording) |
| Menu bar item | `MenuBarExtra` (SwiftUI) or `NSStatusItem` | None |
| Live status in the menu bar (a timer, a sync) | `MenuBarExtra` with a changing label. Live Activities on a Mac only mirror a paired iPhone | None |
| Desktop and Notification Center widgets | WidgetKit extension target (Xcode build, like App Intents) | None |
| Find the app's content in Spotlight | Core Spotlight `CSSearchableIndex` | None |
| Preview the app's own file type in Finder (Space) | Quick Look preview extension | None |
| Menu-bar-only app, no Dock icon | `LSUIElement = YES` in Info.plist | None |
| Spotlight-style panel that keeps the other app in front | `NSPanel` with `.nonactivatingPanel` | None |
| Move and resize other apps' windows | `AXUIElement` (`kAXPositionAttribute`, `kAXSizeAttribute`) | Accessibility |
| Paste into the front app | Write `NSPasteboard`, then post Command-V with `CGEvent` | Accessibility |
| Screenshot | ScreenCaptureKit `SCScreenshotManager` | Screen Recording |
| Window thumbnails | `SCScreenshotManager` with an `SCContentFilter` per window | Screen Recording |
| Screen recording to MP4 | `SCStream` + `SCRecordingOutput` (`AVAssetWriter` when you edit frames) | Screen Recording, Microphone |
| Clipboard history | Poll `NSPasteboard.general.changeCount` | None |
| Text in images | Vision `RecognizeTextRequest` | None |
| Launch at login | `SMAppService.mainApp.register()` | User approves once |
| Links from scripts, Stream Deck, Raycast | `CFBundleURLTypes` + `.onOpenURL` | None |
| Shortcuts app and Spotlight actions | `AppIntent` (App Shortcuts are not supported on macOS). A result or confirmation view is a snippet | None |
| Agent or script reads and changes data | The app binary as a CLI, talking to the running app (`agent-cli` skill) | None |
| A CLI that writes plain files or its own SQLite tells the app to reload | Darwin notification (`notify_post`) | None |
| Keep the Mac awake | `IOPMAssertionCreateWithName` | None |
| System stats | `host_statistics64`, `proc_pid_rusage`, `IOPSCopyPowerSourcesInfo` | None |
| Audio devices | CoreAudio `AudioObjectGetPropertyData` | None |
| Toggle dark mode and other system settings | Apple Events to System Events | Automation |
| Notifications | `UNUserNotificationCenter` | User approves once |
| Dock menu | `applicationDockMenu(_:)` in the app delegate | None |
| Services and Share menu | `NSServices` in Info.plist, `ShareLink` | None |

Prefer the row with no permission when two rows solve the same job.

## Permissions

- Ask at the moment of use. Explain in one line what breaks without it.
  The exception: an app whose core job needs the permission (a window
  manager needs Accessibility) shows its permissions page on first launch.
- Show the state of every permission on one Settings page, with a button
  that opens the right pane:
  `x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility`
  (or `Privacy_ScreenCapture`, `Privacy_AllFiles`).
- The user grants it in System Settings, and nothing calls your app back.
  Check every 1 to 2 seconds while a permission is missing or a view that
  shows it is open. Otherwise check every 20 seconds, with a timer
  tolerance. Check once more right when such a view opens.
- Every `NS...UsageDescription` key (camera, microphone, Apple Events)
  must be in Info.plist before the first request, or the app crashes.

## Menu bar items, widgets, and snippets

- A menu bar item shows a menu, unless the feature is too complex for one.
  Its icon is a template image (an SF Symbol works). People can turn it
  off in Settings, and nothing is reachable only through it: the Dock menu
  and the main window offer the same actions. `MenuBarExtra` already works
  with keyboard navigation; an `NSStatusItem` that opens a custom window
  must too (WWDC26-289).
- A widget shows one idea from the app's purpose, with content that
  changes through the day. Sizes small, medium, large, and extra large. On
  the desktop it renders vibrant and nearly gray, so it must read without
  color. Standard margins 16 pt. A click deep-links to the exact place;
  buttons and toggles in it run App Intents. Never a whole app squeezed
  into a widget.
- A snippet is the view an App Intent shows in Spotlight, Siri, or
  Shortcuts: a result (with Done) or a confirmation (Cancel plus a button
  that names the action, never "OK"). At most 400 pt tall, readable in
  light and dark, and clear without the spoken text.
- Badge the Dock icon only with a count of unread notifications.

## Signing keeps grants

macOS stores Accessibility and Screen Recording grants per code signature
and path. To keep them across rebuilds:

- Sign with one stable "Apple Development" certificate. Ad hoc signing asks
  again after every build.
- Install to the same path every time (`/Applications/<App>.app` or
  `~/Applications/<App>.app`).
- No App Sandbox for apps that use Accessibility, event taps, or other
  apps' windows. The sandbox blocks them.
- After an install, refresh Launch Services so the Dock shows the new icon:
  `lsregister -f -R -trusted /Applications/<App>.app` (the tool lives in
  `/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/`).

If a grant looks on but the API fails, the signature changed. Remove the
app from the list in System Settings, add it again, restart the app.

## Make every feature reachable three ways

Each feature gets: a menu item with a shortcut, a URL
(`<app>://action/<name>`), and an App Intent. The same action enum backs all
three, so a new action shows up everywhere at once. App Intent enum titles
must be literals, so they can drift from menu titles: add a self-test check
that they match. The URL also lets
`test-mac-app` drive the feature from a script.

Done when every entry point in the brief's "System hooks" works from a
clean install, and Settings shows the state of every permission it needs.
