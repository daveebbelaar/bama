# SwiftUI patterns for macOS

Code that compiles on macOS 26 with Swift 6.2 and main-actor default isolation
(the `new-mac-app` template). `Item` is the template's SwiftData model. Rename it to yours.

Imports used across these snippets:

```swift
import AppKit
import Carbon.HIToolbox
import SwiftData
import SwiftUI
import UniformTypeIdentifiers
```

## Global shortcut (no Accessibility permission needed)

Carbon's hot key API still works on macOS 26 and needs no permission. Keep the `GlobalHotKey` object alive (store it on the app delegate), or the shortcut stops working.

```swift
/// Calls `action` when the user presses the shortcut anywhere in macOS.
/// Example: GlobalHotKey(key: kVK_Space, modifiers: [.option]) { panel.toggle() }
final class GlobalHotKey {
    private var ref: EventHotKeyRef?
    private var handler: EventHandlerRef?
    private let action: () -> Void

    init(key: Int, modifiers: NSEvent.ModifierFlags, action: @escaping () -> Void) {
        self.action = action
        var carbon: UInt32 = 0
        if modifiers.contains(.command) { carbon |= UInt32(cmdKey) }
        if modifiers.contains(.option) { carbon |= UInt32(optionKey) }
        if modifiers.contains(.control) { carbon |= UInt32(controlKey) }
        if modifiers.contains(.shift) { carbon |= UInt32(shiftKey) }

        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let me = Unmanaged.passUnretained(self).toOpaque()
        InstallEventHandler(GetApplicationEventTarget(), { _, _, data in
            guard let data else { return noErr }
            let hotKey = Unmanaged<GlobalHotKey>.fromOpaque(data).takeUnretainedValue()
            MainActor.assumeIsolated { hotKey.action() }
            return noErr
        }, 1, &spec, me, &handler)
        RegisterEventHotKey(UInt32(key), carbon, EventHotKeyID(signature: 0x4150_5031, id: 1), GetApplicationEventTarget(), 0, &ref)
    }

    isolated deinit {
        if let ref { UnregisterEventHotKey(ref) }
        if let handler { RemoveEventHandler(handler) }
    }
}
```

## Quick-capture panel

A Spotlight-style panel for the app's most frequent action. Pair it with `GlobalHotKey` above. The field uses glass because the panel floats over other apps.

```swift
/// A floating panel without a title bar, like Spotlight. Escape closes it.
final class QuickCapturePanel: NSPanel {
    init<Content: View>(@ViewBuilder content: () -> Content) {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 560, height: 64),
            styleMask: [.nonactivatingPanel, .borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        isMovableByWindowBackground = true
        level = .floating
        hidesOnDeactivate = true
        contentView = NSHostingView(rootView: content())
    }

    override var canBecomeKey: Bool { true }
    override func cancelOperation(_ sender: Any?) { orderOut(nil) }

    func toggle() {
        if isVisible { orderOut(nil); return }
        center()
        makeKeyAndOrderFront(nil)
        NSApp.activate()
    }
}

struct QuickCaptureField: View {
    @State private var text = ""
    @FocusState private var focused: Bool
    let onSubmit: (String) -> Void

    var body: some View {
        TextField("Add a task, like \"Call mom tomorrow at 5pm\"", text: $text)
            .textFieldStyle(.plain)
            .font(.title3)
            .focused($focused)
            .padding(.horizontal, 20)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .glassEffect(.regular, in: .rect(cornerRadius: 16))
            .onAppear { focused = true }
            .onSubmit {
                let title = text.trimmingCharacters(in: .whitespaces)
                guard !title.isEmpty else { return }
                onSubmit(title)  // optimistic: the caller saves, the panel closes right away
                text = ""
            }
    }
}
```

## Commands that reach the focused window

Menu commands act on whatever the focused window has selected. Add `.commands { ItemCommands() }` to the scene and `.focusedSceneValue(\.selectedItem, ...)` in the view.

```swift
struct SelectedItemKey: FocusedValueKey { typealias Value = Item }

extension FocusedValues {
    var selectedItem: Item? {
        get { self[SelectedItemKey.self] }
        set { self[SelectedItemKey.self] = newValue }
    }
}

struct ItemCommands: Commands {
    @FocusedValue(\.selectedItem) private var item

    var body: some Commands {
        CommandMenu("Item") {
            Button(item?.isStarred == true ? "Unstar" : "Star", systemImage: "star") {
                item?.isStarred.toggle()
            }
            .keyboardShortcut("s", modifiers: [.command, .shift])
            .disabled(item == nil)
        }
    }
}
```

## Toolbar that follows the columns

A window with a sidebar, a list, and an inspector has three toolbar areas,
one over each column. Each button sits over the column it acts on:

```text
[traffic lights] [sidebar]  | Title           [+] [Search...] | [inspector]
     over the sidebar       |       over the list             | over the inspector
```

- The sidebar button comes with `NavigationSplitView` at the sidebar's
  trailing edge.
- Put `.inspector` on the `NavigationSplitView`, not inside the detail
  view. The inspector is then a full-height column with its own toolbar
  area. Inside the detail view it shares the detail's toolbar, and items
  slide over the inspector.
- The inspector button goes in the inspector's own `.toolbar`, after a
  flexible spacer. SwiftUI keeps it at the window's trailing edge while the
  inspector is hidden. Do not add a second button to the detail toolbar:
  it then shows twice.
- `.searchable(placement: .toolbar)` always moves to the window's trailing
  edge, over the inspector. To keep search over the list, put a native
  `NSSearchField` in a detail `ToolbarItem` (fixed width about 220 pt).
- Add `InspectorCommands()` to the scene's `.commands`: View > Show
  Inspector, Control-Command-I. No second inspector command elsewhere.

```swift
NavigationSplitView {
    Sidebar()
} detail: {
    ListPage()
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("New Item", systemImage: "plus") { model.add() }
            }
            ToolbarItem(placement: .primaryAction) {
                ToolbarSearchField(text: $model.searchText, prompt: "Search")   // NSViewRepresentable around NSSearchField
            }
        }
}
.inspector(isPresented: $model.showInspector) {
    InspectorView()
        .inspectorColumnWidth(min: 240, ideal: 280, max: 360)
        .toolbar {
            ToolbarSpacer(.flexible)
            ToolbarItem(placement: .primaryAction) {
                Button { model.showInspector.toggle() } label: {
                    Label(model.showInspector ? "Hide Inspector" : "Show Inspector",
                          systemImage: "sidebar.trailing")
                }
                .help("Show or hide the inspector (Control-Command-I)")
            }
        }
}
```

Check both states in a real window capture (inspector open and closed),
and once at the window's minimum width: nothing overlaps the column edge,
each button appears once, and search is still reachable (toolbars.md,
"Title and search").

## Search, inspector, keyboard, context menu, feedback

One list that shows search with a result count, an inspector, the Delete key, a context menu, and a symbol animation as feedback.

```swift
struct SearchableList: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Item.createdAt, order: .reverse) private var items: [Item]
    @State private var query = ""
    @State private var selection: Item.ID?
    @State private var showInspector = true

    private var results: [Item] {
        query.isEmpty ? items : items.filter {
            $0.title.localizedStandardContains(query) || $0.notes.localizedStandardContains(query)
        }
    }

    var body: some View {
        List(results, selection: $selection) { item in
            Label(item.title, systemImage: item.isStarred ? "star.fill" : "circle")
                .contentTransition(.symbolEffect(.replace))  // visible feedback when starring
                .tag(item.id)
                .contextMenu {
                    Button(item.isStarred ? "Unstar" : "Star", systemImage: "star") {
                        withAnimation { item.isStarred.toggle() }
                    }
                    Divider()
                    Button("Delete", systemImage: "trash", role: .destructive) { context.delete(item) }
                }
        }
        .searchable(text: $query, placement: .toolbar, prompt: "Search items")
        .navigationSubtitle(query.isEmpty ? "" : "\(results.count) results")
        .onDeleteCommand {  // the Delete key and Edit > Delete
            if let item = results.first(where: { $0.id == selection }) { context.delete(item) }
        }
        .focusedSceneValue(\.selectedItem, results.first { $0.id == selection })
        .inspector(isPresented: $showInspector) {
            Text("Details of the selection")
                .inspectorColumnWidth(min: 220, ideal: 280)
        }
        .toolbar {
            ToolbarItem {
                Button("Inspector", systemImage: "sidebar.trailing") { showInspector.toggle() }
                    .help("Show or hide details (Control-Command-I)")
                    // Same key as InspectorCommands(). Use one or the other, not both.
                    .keyboardShortcut("i", modifiers: [.command, .control])
            }
        }
    }
}
```

## Search with scopes, suggestions, and recent searches

Search starts broad, a scope bar narrows it, recent searches show before
typing with a way to clear them, and no results shows the query
(design-rules.md rules 71 and 72).

```swift
enum SearchScope: String, CaseIterable, Identifiable {
    case all = "All Items", starred = "Starred"
    var id: Self { self }
}

struct SearchPage: View {
    @Query(sort: \Item.createdAt, order: .reverse) private var items: [Item]
    @State private var query = ""
    @State private var scope = SearchScope.all
    @AppStorage("recentSearches") private var recentStore = ""

    private var recent: [String] { recentStore.split(separator: "\n").map(String.init) }

    private var results: [Item] {
        items.filter { item in
            (scope == .all || item.isStarred)
                && (query.isEmpty || item.title.localizedStandardContains(query))
        }
    }

    var body: some View {
        List(results) { item in Text(item.title) }
            .overlay {
                if !query.isEmpty && results.isEmpty {
                    ContentUnavailableView.search(text: query)  // shows the query, so typos show
                }
            }
            .searchable(text: $query, placement: .toolbar, prompt: "Search items")
            .searchScopes($scope) {
                ForEach(SearchScope.allCases) { Text($0.rawValue).tag($0) }
            }
            .searchSuggestions {
                if query.isEmpty {
                    ForEach(recent.prefix(5), id: \.self) { term in
                        Text(term).searchCompletion(term)
                    }
                    if !recent.isEmpty {
                        Button("Clear Recent Searches") { recentStore = "" }
                    }
                }
            }
            .onSubmit(of: .search) { remember(query) }
    }

    private func remember(_ term: String) {
        let term = term.trimmingCharacters(in: .whitespaces)
        guard !term.isEmpty else { return }
        recentStore = ([term] + recent.filter { $0 != term }).prefix(10).joined(separator: "\n")
    }
}
```

## Sortable table

Header click sorts and reverses, columns resize and remember their widths,
rows alternate, and long names truncate in the middle (rule 73).

```swift
struct ItemTable: View {
    @Query private var items: [Item]
    @State private var sortOrder = [KeyPathComparator(\Item.createdAt, order: .reverse)]
    @State private var selection = Set<Item.ID>()
    @SceneStorage("ItemTable.columns") private var columns = TableColumnCustomization<Item>()

    var body: some View {
        Table(items.sorted(using: sortOrder), selection: $selection,
              sortOrder: $sortOrder, columnCustomization: $columns) {
            TableColumn("Title", value: \.title) { item in
                Text(item.title).truncationMode(.middle)
            }
            .customizationID("title")
            TableColumn("Created", value: \.createdAt) { item in
                Text(item.createdAt, format: .dateTime.day().month().year())
            }
            .width(min: 90, ideal: 120)
            .customizationID("created")
        }
        .alternatingRowBackgrounds()
    }
}
```

## Drag to Finder makes a real file

A drag into Finder writes a file the app (or any app) can open again. Apps
that take no files get the title as text (rule 74).

```swift
struct ItemFile: Transferable {
    let title: String
    let notes: String

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(exportedContentType: .plainText) { file in
            let url = URL.temporaryDirectory.appending(path: "\(file.title).txt")
            try "\(file.title)\n\n\(file.notes)".write(to: url, atomically: true, encoding: .utf8)
            return SentTransferredFile(url)
        }
        ProxyRepresentation(exporting: \.title)
    }
}

// In a row:
Text(item.title)
    .draggable(ItemFile(title: item.title, notes: item.notes))
```

## Restore the selection on relaunch

Windows restore their frame on their own. `@SceneStorage` brings back UI
state per window: the selection, the open tab, column widths. Store a
stable id, never the data itself (rule 75).

```swift
struct RestoringList: View {
    @Query private var items: [Item]
    @SceneStorage("selectedItem") private var selectedID = ""  // the item's uuid

    var body: some View {
        List(items, id: \.uuid.uuidString, selection: Binding(
            get: { selectedID.isEmpty ? nil : selectedID },
            set: { selectedID = $0 ?? "" })) { item in
            Text(item.title)
        }
    }
}
```

## Custom chrome that follows the window

A custom selection fill turns gray when the window is not in front, keeps
concentric corners with a minimum radius, and lets a rich background run
under the sidebar (rules 14, 62, 63).

```swift
struct CustomSidebarRow: View {
    @Environment(\.appearsActive) private var appearsActive
    let title: String
    let selected: Bool

    private var fill: AnyShapeStyle {
        guard selected else { return AnyShapeStyle(.clear) }
        return appearsActive ? AnyShapeStyle(.tint) : AnyShapeStyle(.quaternary)
    }

    var body: some View {
        Text(title)
            .padding(.horizontal, 8)
            .frame(maxWidth: .infinity, minHeight: 24, alignment: .leading)
            .background(fill, in: ConcentricRectangle(corners: .concentric(minimum: 8)))
    }
}

// On a hero image or tinted header that an inset sidebar covers:
HeroImage().backgroundExtensionEffect()
```

## Undo with SwiftData

Register the reverse of each action yourself, on the window's undo manager.
Do not set `mainContext.undoManager = UndoManager()`: a separate manager
never reaches Edit > Undo. SwiftData's automatic undo also failed to save
the reverted values in testing (the next fetch returned the old state).

```swift
@Environment(\.undoManager) private var undoManager

func complete(_ todo: Todo) {
    let uid = todo.uid                       // your own UUID, stable across saves
    todo.isDone = true
    try? context.save()
    undoManager?.registerUndo(withTarget: store) { store in
        store.find(uid)?.isDone = false     // look up again; the object may be new
        try? store.context.save()
    }
    undoManager?.setActionName("Complete")
}
```

When `groupsByEvent` is off, wrap registrations in `beginUndoGrouping()` and
`endUndoGrouping()`, or the undo manager throws an exception that crashes
later inside SwiftUI. Test undo in the self-test: do, undo, fetch again.

## Menu bar extra

Add `MenuBarExtra` next to the main `Window` scene in `App.swift` for an always-available entry point. Let people turn it off in Settings (`isInserted:`), and never make it the only way to reach a feature: the app also has a Dock menu (menus.md). The icon is a template SF Symbol, so it follows the menu bar's light and dark look. Show a menu, as below. Use `.menuBarExtraStyle(.window)` only when the feature is too complex for a menu (a timer with controls, a small player). [HIG The menu bar]

```swift
struct MenuBarScenePreview: Scene {
    var body: some Scene {
        MenuBarExtra("Starter", systemImage: "checkmark.circle") {
            Button("Quick Add") {}
                .keyboardShortcut("a")
            Divider()
            Button("Quit") { NSApp.terminate(nil) }
                .keyboardShortcut("q")
        }
    }
}
```

## More patterns from real apps

Each one was built and checked in a shipped app.

### Highlight parts of a text field while typing

SwiftUI's `TextField` cannot color part of its text. For inline
highlights (dates, tags), wrap a one-line `NSTextView` in an
`NSViewRepresentable` and color ranges with temporary attributes, which
change the look without changing the text:

```swift
let range = NSRange(span.range, in: textView.string)
textView.layoutManager?.addTemporaryAttribute(.backgroundColor, value: NSColor.systemPurple.withAlphaComponent(0.16), forCharacterRange: range)
textView.layoutManager?.addTemporaryAttribute(.foregroundColor, value: NSColor.systemPurple, forCharacterRange: range)
```

Override `keyDown` for Return (keyCode 36) and Escape (53), and
`mouseDown` with `characterIndexForInsertion(at:)` to react to clicks on a
highlight. Draw a placeholder in `draw(_:)` when the string is empty.

### Let a CLI wake the app instantly

When the app and a command-line tool share a SQLite file, the CLI can ping
the app after each write. `notify_post` is not visible to Swift; the
CoreFoundation Darwin center is the same mechanism:

```swift
CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(),
                                     CFNotificationName("com.you.app.changed" as CFString), nil, nil, true)
```

The app adds an observer with `CFNotificationCenterAddObserver` and
reloads. Keep a cheap fallback: `PRAGMA data_version` changes whenever
another connection commits, so checking it once a second catches a missed ping.

### Services menu: "Add to MyApp" in every app

In Info.plist, an `NSServices` entry with `NSMessage` (say `addTask`),
`NSPortName`, and `NSSendTypes` (`NSStringPboardType`). In
`applicationDidFinishLaunching`: `NSApp.servicesProvider = provider` and
`NSUpdateDynamicServices()`. The provider method signature is
`@objc func addTask(_ pasteboard: NSPasteboard, userData: String?, error: AutoreleasingUnsafeMutablePointer<NSString>)`.
Test it without clicking: `NSPerformService("Add to MyApp", pasteboard)` from a small Swift script.

### Menu bar extra that keeps the app alive

`MenuBarExtra("App", systemImage: "checklist", isInserted: $showMenuBar) { ... }`
(a menu; add `.menuBarExtraStyle(.window)` only for a feature too complex for one),
and return `false` from `applicationShouldTerminateAfterLastWindowClosed`
so closing the main window keeps the menu bar and global shortcuts working.

Hide the main window instead of closing it. On macOS 26, closing a SwiftUI
`Window` scene, opening it again, and then changing state crashed AppKit in
a constraint loop every time. Set a forwarding `NSWindowDelegate` whose
`windowShouldClose` calls `orderOut(nil)` and returns false. Prove it with
a self-test that closes and reopens the window 20 times.

### Notifications and the Dock badge

`NSApp.dockTile.badgeLabel = "3"` works right away. The badge counts only
unread notifications, never other numbers, and goes back to `nil` at zero.
A notification never says "open the app to do X", never repeats one
already shown, and offers at most four actions with title-case labels, none
of them "Open". Errors go in an alert inside the app, not a notification. Notifications need the
user's yes: if the permission prompt appears while nobody is there, macOS
records "denied" and `requestAuthorization` keeps failing with "not
allowed". Show the status in Settings and open
`x-apple.systempreferences:com.apple.Notifications-Settings.extension?id=<bundle id>`.
Implement the delegate's `didReceive` as `nonisolated`, call the
completion handler right away, and hop to the main actor for the work.
Skip notifications, login items, and anything else with a system prompt
when the store points to `/tmp`, so tests never trigger a prompt.

### A floating capture panel without a title bar

Use `styleMask: [.nonactivatingPanel, .borderless, .fullSizeContentView]`,
`isOpaque = false`, `hasShadow = true`, and override `canBecomeKey` to
return true. A `.titled` panel with a hidden title bar still leaves an
empty strip on top.
