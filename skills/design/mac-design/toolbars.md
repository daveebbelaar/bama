# Toolbars

Toolbar layout for a macOS 26 SwiftUI window, checked on macOS 26.5.
Placement changed between 26.0 and 26.2: snapshot the toolbar after each OS update.

## Contents

- Areas
- Columns
- Toggles
- Glass groups
- Labels
- Title and search
- Not iOS
- Review
- Example
- Sources

## Areas

| Area | What goes there | SwiftUI |
|---|---|---|
| Leading | Sidebar toggle, back and forward, title and subtitle | system toggle, `.navigation`, `.navigationTitle` |
| Center | Common controls. They fold into the overflow menu as the window narrows | `.principal`, `.automatic` |
| Trailing | Inspector toggle, search, the one primary action. Visible at every width | `.primaryAction`, `.searchable` |

- At most three groups in the whole toolbar. Only frequent commands get an item.
- Every toolbar item also has a menu bar command and shortcut. People can hide the toolbar.
- The system adds the overflow menu. Never build your own to make items fit.
- No Settings button. Settings opens from the app menu with Command-comma.
- An app people keep open for hours, or with many items, lets people customize
  the toolbar: `.toolbar(id:)` with `ToolbarItem(id:)`. Leading items stay fixed.
- A More menu (`ellipsis`) at the trailing edge may hold extra actions. The
  main actions never hide in it.
- Back and Close use the standard symbols (`chevron.backward`, `xmark`), never
  the words.
- macOS 27 SDK (not checked here): `visibilityPriority(.high)` keeps a key
  group visible as the window narrows, and `ToolbarOverflowMenu` sends rare
  items to the overflow menu on purpose. Check whether this ends the "custom
  item dropped" gotcha below.

## Columns

In a `NavigationSplitView` the toolbar splits at the column dividers. An item
sits over the column whose view declares it.

- Sidebar column: no items of your own. The system puts the sidebar toggle there.
- Content column: title, subtitle, and actions that make or order rows (New,
  Sort). `.primaryAction` puts them at the column's trailing edge.
- Detail column: actions on the selection (Share, Flag, Delete). Plain
  `ToolbarItem`s start at the column's leading edge. Put
  `ToolbarSpacer(.flexible)` first to push them trailing.
- `.inspector` goes on the `NavigationSplitView`, not on a column. It then
  gets a full-height column with its own toolbar area.
- No `.toolbar` on the `NavigationSplitView` itself. A `.primaryAction` there
  lands at the leading edge of the detail column.
- Check: snapshot with the sidebar collapsed and the inspector closed. Every
  item stays over its column, in the same order.

## Toggles

- Sidebar: keep the toggle `NavigationSplitView` adds. Never draw a second one.
  Use `.toolbar(removing: .sidebarToggle)` only when the sidebar never hides.
- `SidebarCommands()` on the scene adds View > Show Sidebar, Control-Command-S.
  Without it the View menu has no sidebar item.
- Inspector: one `sidebar.trailing` button in the inspector's own `.toolbar`,
  after `ToolbarSpacer(.flexible)`. Without the spacer it jumps when the inspector opens.
- `InspectorCommands()` adds View > Show Inspector, Control-Command-I (tested on
  macOS 26; it pairs with Show Sidebar, Control-Command-S). Put that shortcut in
  the button's `.help`. No second inspector command elsewhere. The HIG keyboard
  table still lists Option-Command-I; the framework command wins.
- `ToolbarCommands()` adds View > Show Toolbar (Option-Command-T) and Customize Toolbar.

## Glass groups

On macOS 26 toolbar items float on Liquid Glass, and neighbors share one capsule.

- `ToolbarSpacer(.fixed)` splits groups with different jobs.
  `ToolbarSpacer(.flexible)` pushes items apart. `ToolbarItemGroup` keeps a set together.
- `.sharedBackgroundVisibility(.hidden)` takes one item out of its capsule.
- No backgrounds, borders, or dimming behind the toolbar. The automatic scroll
  edge effect keeps it legible and already turns more opaque over dense content.
  Do not switch it to `.hard`.
- Borderless buttons, monochrome SF Symbols. Tint only to carry meaning.

## Labels

- A symbol first. Text only when no symbol fits ("Edit"). Write
  `Button("Title", systemImage:)` so the title shows in the overflow menu, in
  Icon and Text mode, and to VoiceOver.
- Every item has `.help`: what it does, starting with a verb, then the shortcut ("Create a note (Command-N)"). Not the item's name again.
- A text button next to a symbol button gets a `ToolbarSpacer(.fixed)` between them.
- A primary action (Done, Send) is one item, trailing, alone, prominent. Most
  main windows have none. "New" is not a primary action.

## Title and search

- `.navigationTitle` names the content in under 15 characters, never the app.
  `.navigationSubtitle` holds a count or a date.
- Every page has a subtitle, or none does. A subtitle that comes and goes
  changes the toolbar height, and that crashed AppKit on window reopen in Brisk.
- Window-wide search: `.searchable(text:placement: .toolbar)` on the split view.
  It sits at the trailing edge, over an open inspector, as in Mail and Notes.
- `.searchable` on one column does not move the field over that column on
  macOS. To filter only the sidebar, use `placement: .sidebar`. To keep a
  list-only search over the list while an inspector is open, use a native
  `NSSearchField` toolbar item (patterns.md, "Toolbar that follows the columns").
- Command-F focuses the field (`.searchFocused`), and so does
  Option-Command-F, Apple's standard "jump to the search field". Escape
  clears it. The subtitle shows the result count.
- A big app with many sections (Music) gets a Search item in the sidebar.
  Selecting it shows a full results page and focuses its field.
- Scopes, suggestions, recent searches, and the no-results view:
  patterns.md, "Search with scopes, suggestions, and recent searches".
- On macOS 27 the top scroll edge turns hard on its own when free text such as
  the window title floats over content. Do not fight it.
- A custom toolbar item that does not fit is dropped, with no overflow
  entry and no warning. Measure the list column (`.onGeometryChange`) and
  below about 480 pt show a Find button (`magnifyingglass`) that opens the
  search field in a popover; Command-F opens it too. Check the toolbar at
  the window's minimum width with the inspector open and closed.

## Not iOS

Mac toolbars sit at the top of the window. These do not compile for macOS:
`.bottomBar`, `.topBarLeading`, `.topBarTrailing`, `.largeTitle`,
`.searchToolbarBehavior(.minimize)`, `ToolbarRole.navigationStack`. Also drop
large titles, 44 pt buttons, floating add buttons, and ellipsis menus that hold
the main actions.

## Review

The toolbar fails when it has two sidebar or inspector toggles, items over the
wrong column, items that move when a column collapses, more than three groups,
an item without `.help`, an action missing from the menu bar, a Settings
button, tint as decoration, or an `HStack` drawn in place of `.toolbar`.

## Example

Typechecked against the macOS 26.5 SDK. `Library` is your `@Observable` model.
The scene adds `.commands { SidebarCommands(); InspectorCommands(); ToolbarCommands() }`
plus New Note (Command-N) and Flag (Shift-Command-L) menu commands.

```swift
struct ContentView: View {
    @Environment(Library.self) private var library

    var body: some View {
        @Bindable var library = library
        NavigationSplitView {
            FolderList()  // no items of your own: the system adds the sidebar toggle
        } content: {
            NoteList()
                .navigationTitle(library.folderName)
                .navigationSubtitle("\(library.notes.count) notes")
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        Button("New Note", systemImage: "square.and.pencil") { library.addNote() }
                            .help("Create a note (Command-N)")
                    }
                }
        } detail: {
            NoteEditor()
                .toolbar {
                    ToolbarSpacer(.flexible)  // push the items to the column's trailing edge
                    ToolbarItem { ShareLink(item: library.noteText) }
                    ToolbarSpacer(.fixed)
                    ToolbarItem {
                        Button("Flag", systemImage: "flag") { library.toggleFlag() }
                            .help("Flag the selected note (Shift-Command-L)")
                    }
                }
        }
        .inspector(isPresented: $library.showInspector) {  // on the split view
            NoteInfo()
                .inspectorColumnWidth(min: 220, ideal: 260, max: 340)
                .toolbar {
                    ToolbarSpacer(.flexible)  // keeps the toggle in place, open or closed
                    ToolbarItem {
                        Button("Inspector", systemImage: "sidebar.trailing") { library.showInspector.toggle() }
                            .help("Show or hide the inspector (Control-Command-I)")
                    }
                }
        }
        .searchable(text: $library.query, placement: .toolbar, prompt: "Search all notes")
    }
}
```

## Sources

- HIG: [Toolbars](https://developer.apple.com/design/human-interface-guidelines/toolbars), [Sidebars](https://developer.apple.com/design/human-interface-guidelines/sidebars), [Split views](https://developer.apple.com/design/human-interface-guidelines/split-views), [Search fields](https://developer.apple.com/design/human-interface-guidelines/search-fields), [The menu bar](https://developer.apple.com/design/human-interface-guidelines/the-menu-bar)
- WWDC25-323 Build a SwiftUI app with the new design: https://developer.apple.com/videos/play/wwdc2025/323/
- WWDC25-356 Get to know the new design system: https://developer.apple.com/videos/play/wwdc2025/356/
- SwiftUI: [ToolbarSpacer](https://developer.apple.com/documentation/swiftui/toolbarspacer), [sharedBackgroundVisibility](https://developer.apple.com/documentation/swiftui/toolbarcontent/sharedbackgroundvisibility(_:)), [ToolbarDefaultItemKind](https://developer.apple.com/documentation/swiftui/toolbardefaultitemkind), [InspectorCommands](https://developer.apple.com/documentation/swiftui/inspectorcommands), [Adding a search interface](https://developer.apple.com/documentation/swiftui/adding-a-search-interface-to-your-app)
- Landmarks toolbar sample: https://developer.apple.com/documentation/swiftui/landmarks-refining-the-system-provided-glass-effect-in-toolbars
- Inspector toggle placement across macOS 26 releases: https://developer.apple.com/forums/thread/795561
- Field test: Brisk commit f9f264b, and placement snapshots on macOS 26.5
