# Integration recipes

Short, working shapes, each taken from a shipped menu bar utility.

## Contents

- Global hotkey (Carbon)
- Event tap
- Non-activating panel
- Accessibility: move a window
- Screen capture
- Launch at login
- URL scheme
- App Intents
- CLI and Darwin pings
- Debug bridge

## Global hotkey (Carbon)

No permission, and the key never reaches the front app.

```swift
import Carbon.HIToolbox

var ref: EventHotKeyRef?
let id = EventHotKeyID(signature: OSType(0x41505031), id: 1)   // 'APP1', 1
RegisterEventHotKey(UInt32(kVK_Space), UInt32(optionKey), id,
                    GetApplicationEventTarget(), 0, &ref)

var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                         eventKind: UInt32(kEventHotKeyPressed))
InstallEventHandler(GetApplicationEventTarget(), { _, event, _ in
    var hk = EventHotKeyID()
    GetEventParameter(event, EventParamName(kEventParamDirectObject),
                      EventParamType(typeEventHotKeyID), nil,
                      MemoryLayout<EventHotKeyID>.size, nil, &hk)
    Task { @MainActor in HotkeyCenter.shared.fire(hk.id) }
    return noErr
}, 1, &spec, nil, nil)
```

`RegisterEventHotKey` returns an `OSStatus`. Keep it: non-zero means
registration failed, usually because another app owns the combo. Show those failures in
Settings next to the shortcut.

## Event tap

For hold-to-show and modifier tricks. Needs Accessibility.

```swift
let mask = (1 << CGEventType.keyDown.rawValue) | (1 << CGEventType.flagsChanged.rawValue)
guard let tap = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap,
                                  options: .defaultTap, eventsOfInterest: CGEventMask(mask),
                                  callback: { _, type, event, _ in
    if type == .tapDisabledByTimeout { /* re-enable with CGEvent.tapEnable */ }
    return Unmanaged.passUnretained(event)          // or nil to swallow
}, userInfo: nil) else { return }                   // nil: no Accessibility
let source = CFMachPortCreateRunLoopSource(nil, tap, 0)
CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
CGEvent.tapEnable(tap: tap, enable: true)
```

Keep the callback tiny. A slow callback gets the tap disabled by the system.

## Non-activating panel

A launcher that takes typing but leaves the other app frontmost, so a paste
lands there.

```swift
final class FloatingPanel: NSPanel {
    init(size: NSSize, content: some View) {
        super.init(contentRect: NSRect(origin: .zero, size: size),
                   styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView],
                   backing: .buffered, defer: false)
        isFloatingPanel = true
        level = .statusBar
        hidesOnDeactivate = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false                 // the glass draws its own shadow
        let host = NSHostingView(rootView: content)
        host.sizingOptions = []           // fixed frame, no resize jumps
        contentView = host
    }
    override var canBecomeKey: Bool { true }
    override func resignKey() { super.resignKey(); orderOut(nil) }
    override func cancelOperation(_ sender: Any?) { orderOut(nil) }
}
```

Show with `orderFrontRegardless()` then `makeKey()`.

## Accessibility: move a window

```swift
AXUIElementSetMessagingTimeout(AXUIElementCreateSystemWide(), 1.0)   // once, at launch

let app = AXUIElementCreateApplication(pid)
var value: CFTypeRef?
AXUIElementCopyAttributeValue(app, kAXFocusedWindowAttribute as CFString, &value)
let window = value as! AXUIElement
var origin = CGPoint(x: 0, y: 25)
var size = CGSize(width: 960, height: 1050)
AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, AXValueCreate(.cgPoint, &origin)!)
AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, AXValueCreate(.cgSize, &size)!)
```

AX uses top-left origin coordinates of the main screen. `NSScreen` uses
bottom-left. Convert with the main screen's height.

## Screen capture

```swift
let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
let display = content.displays.first!
let filter = SCContentFilter(display: display, excludingWindows: [])
let config = SCStreamConfiguration()
config.width = Int(display.frame.width * scale)
config.height = Int(display.frame.height * scale)
config.showsCursor = false
let image = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
```

Check `CGPreflightScreenCaptureAccess()` first. Capture all displays in
parallel with a task group. For a "freeze the screen" picker, show the
picker first, then capture (see the `performance` skill).

## Launch at login

```swift
import ServiceManagement
try SMAppService.mainApp.register()     // .unregister() to turn off
SMAppService.mainApp.status == .enabled
```

## URL scheme

In Info.plist (or XcodeGen `info.properties`):

```yaml
CFBundleURLTypes:
  - CFBundleURLName: com.you.app
    CFBundleURLSchemes: [yourapp]
```

Handle `yourapp://action/<name>` with `.onOpenURL` on a scene, or in the
app delegate's `application(_:open:)` for a menu bar app.

## App Intents

```swift
struct SnapLeft: AppIntent {
    static let title: LocalizedStringResource = "Snap Window Left"
    @MainActor func perform() async throws -> some IntentResult {
        WindowManager.shared.run(.left); return .result()
    }
}
```

On a Mac, people find each `AppIntent` in the Shortcuts app and build
their own shortcuts from it. App Shortcuts (`AppShortcutsProvider`, ready-made
phrases) are not supported on macOS, so skip them in a Mac-only app.
[HIG App Shortcuts]

App Intents need an Xcode build (XcodeGen project), which extracts the
intent metadata. A plain `swift build` does not.

## CLI and Darwin pings

For a CLI that owns plain files or its own SQLite (not a SwiftData store).
For a SwiftData app, use the `agent-cli` skill: the CLI sends commands to
the running app instead. Here the CLI writes, then pings the app:

```swift
notify_post("com.you.app.changed")                         // CLI side
var token: Int32 = 0                                       // app side
notify_register_dispatch("com.you.app.changed", &token, .main) { _ in
    MainActor.assumeIsolated { AppModel.shared.reload() }
}
```

Give every CLI command a `--json` flag. Agents read JSON, people read text.

## Debug bridge

A development-only command channel lets an agent drive the running app:

```swift
DistributedNotificationCenter.default().addObserver(
    forName: .init("com.you.app.command"), object: nil, queue: .main) { note in
    let command = note.object as? String ?? "status"
    MainActor.assumeIsolated { DebugBridge.run(command) }   // writes status.json
}
```

A script posts the command and reads `status.json` back. The
`test-mac-app` skill builds on this.
