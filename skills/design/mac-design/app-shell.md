# App shell

The frame of a window with a left sidebar, a right panel, and a top bar on
macOS 26 and later. Field test: LocalChat on macOS 26.5, one chat app rebuilt
through each layout below while its owner reviewed screenshots, then the same
app on macOS 27.2. Unless a value names macOS 27.2, it comes from macOS 26.5. Use
[toolbars.md](toolbars.md) for which item goes where.

## Contents

- The system sidebar by OS
- Pick the right side
- Inspector on macOS 27
- Floating right panel on macOS 26
- Line up the content
- Pick the top bar
- No top bar
- Sidebar rows
- Motion
- Traps
- Review
- Example

## The system sidebar by OS

The OS decides how the sidebar looks, not the SDK. LocalChat, built with the
macOS 26.5 SDK, shows both columns below, depending on the Mac it runs on.

| | macOS 26.5 | macOS 27.2 |
|---|---|---|
| Shape | Floats: rounded, inset from the window's edges | Runs the window's full height, with no inset |
| Fill | The values under "Floating right panel on macOS 26" | Gray |
| Edge | A soft shadow over the content | A line along its edge |
| Selection pill starts | 10 pt from the sidebar's edge | 10 pt from the window |
| Row text starts | 6 pt inside the pill | 16 pt from the window, which is 6 pt inside the pill |
| Status row's bottom | 18 pt from the window | 10 pt from the window |
| `.inspector` beside it | A flat column with a line, so the two sides differ | The sidebar's gray, full height, and line, so the two sides match |

Inside the sidebar the 10 and the 6 did not change. The sidebar's edge moved to
the window's edge.

## Pick the right side

| OS | Use for the right side |
|---|---|
| macOS 27 | The system `.inspector`, because it matches the sidebar |
| macOS 26 | The inspector, or a floating panel when the two sides must match, as in a chat app or a window that is on camera |

The macOS 27 advice rests on one app, LocalChat, on macOS 27.2. The floating panel
belongs to macOS 26 only: on macOS 27.2 it floats beside a sidebar that does not.
LocalChat uses the inspector on both OSes with no version check, so on macOS 26
its two sides differ.

| | Inspector | Floating panel |
|---|---|---|
| On macOS 27.2 | Looks like the sidebar | Differs from the sidebar |
| On macOS 26.5 | A flat column with a line | Looks like the sidebar |
| Top bar | Splits at the column line | One bar over the chat and the panel |
| Width | People drag it | Fixed by your code |
| Menu command | `InspectorCommands()` | Your own button and shortcut |
| Color | System | Measured by hand |

Decide before you build the toolbar, because the choice sets how the toolbar works.

Inspector rules are in [toolbars.md](toolbars.md), "Columns" and "Toggles". The
main one: put `.inspector` on the `NavigationSplitView`, not on a column.

## Inspector on macOS 27

Measured in LocalChat on macOS 27.2.

- Give the inspector the sidebar's ideal width, with `.inspectorColumnWidth`. With
  empty settings, a sidebar set to 260 draws 260 wide, and an inspector set to 260
  draws 260 wide.
- Check the widths with empty settings. The split view saves the sidebar's width in
  the app's user defaults, under `NSSplitView Subview Frames`, and a saved width wins
  over `ideal`. On one Mac Chat kept a saved 268, while a copy with a new bundle id
  drew 260. To test, copy the app, give the copy a new bundle id, and run the copy.
- Leave the color to the system. Both columns have the same gray in light and in
  dark (`0xECEDEE` in light).
- Use the same insets on both sides: status cards 10 pt from the window, 6 pt of
  padding inside them, and a 10 pt corner radius. Row text then sits 16 pt from the
  window on both sides. These are off the 4 pt grid on purpose, so name them as
  tokens in `Space`.
- Center the first heading on the text in the sidebar's search field. The column
  starts under the toolbar, so in LocalChat that is 15 pt of top padding.
- Keep the toggle's default capsule, because it matches the sidebar toggle.

## Floating right panel on macOS 26

This panel copies the macOS 26.5 sidebar. Its values match nothing on macOS 27.2.

Make the panel a sibling of the content inside the detail column, so the
content narrows when it opens.

- Inset it 8 pt on its three outer sides, with a 20 pt continuous corner radius:
  `.padding([.top, .bottom, .trailing], 8)`. Leave no gap on the content's side,
  or the content sits 4 pt off center between the panels. The radius matches
  the sidebar by eye on macOS 26.5.
- Run it up to the top of the window: `.ignoresSafeArea(.container, edges: .top)`.
- Match the system sidebar's insets, measured on macOS 26.5: the selection pill
  starts 10 pt from the panel's edge, and row text 6 pt inside the pill. These
  are off the 4 pt grid on purpose, so name them as tokens in `Space`.
- Center the panel's first heading on the text in the sidebar's search field. In
  LocalChat that is 59 pt of top padding.
- Build any status row at the bottom as one view, used by both panels. Pin it with
  `.safeAreaInset(edge: .bottom)`, 10 pt from the panel's edges, with a 10 pt
  corner radius: the panel's 20 minus the inset.
- Use a solid fill measured from the sidebar. Sample a pixel from snapshots with
  colored traffic lights, in light and in dark. The sidebar changes when the
  window is behind others, so read `@Environment(\.appearsActive)`. LocalChat
  uses `0xFAFAFA` and `0x1F2124` in front, and `0xF7F7F7` and `0x2A2C30` behind.
  The last one comes from a single sample. Measure yours.
- Add a shadow toward the content, and `.zIndex(1)` so the content does not
  cover it: black at 10% in light and 35% in dark, radius 16.
- Set the window's minimum width to the sidebar, plus the content's minimum,
  plus the panel. Otherwise the columns slide past the window's edge.

A behind-window material looks wrong here: `NSVisualEffectView` with `.sidebar`
shows the desktop through it, and the glass sidebar does not. `.glassEffect` on
the panel came out grayer than the sidebar.

## Line up the content

Views inside and outside a scroll view must share one edge: the text, the chips,
and the chat box under them.

- Measure the scroll bar's width and add it back. With a mouse attached, a scroll
  bar takes about 16 pt of width, and 17 pt on macOS 27.2. Centered content inside
  the scroll view then moves about 8 pt left, while the chat box outside it stays.
  It also jumps when a short chat grows long enough to scroll. Do these steps, and
  the example has the code:
  1. Read the scroll view's outer width and its content's width, each with
     `.onGeometryChange`.
  2. Size the column from the outer width, the same way as the chat box.
  3. Add the difference as leading padding on the column:
     `.padding(.leading, max(outerWidth - innerWidth, 0))`.

  When the scroll bar takes no width, the difference is 0 and nothing moves.
- Leave `scrollerStyle` alone. Setting `.overlay` on the enclosing `NSScrollView`
  worked on macOS 26.5. On macOS 27.2 the style reads `.overlay` and the scroll bar
  still takes its 17 pt.
- Give the content's lowest control and both status rows one bottom. In LocalChat
  on macOS 27.2 with the inspector, that is 10 pt from the window. On macOS 26.5
  with the floating panel, it is 18 pt: the panel's 8 plus the row's 10.
- Probe these edges across areas, so the check fails when one moves: `layout-grid`
  skill, "Line up across areas".
- Run the snapshots once with `-AppleShowScrollBars Always`. Without a mouse the
  default hides this bug.

## Pick the top bar

| Top bar | Use when | How |
|---|---|---|
| Full | The window has real commands to reach | [toolbars.md](toolbars.md) |
| Only the toggles | The window is about its content, and the sidebars can hold the rest | "No top bar", below |

With a floating panel and a full top bar, the bar has one section, so nothing
keeps items off the panel. Add a hidden item before the panel toggle, wide enough
to push the controls clear of the panel. Check it at the minimum width.

## No top bar

The toolbar stays, because it holds the sidebar toggles and lets people drag the
window. What goes away is everything people read as a bar.

1. Keep `.navigationTitle`, because the Window menu reads it. Hide it with
   `.toolbar(removing: .title)`.
2. Hide the bar's background: `.toolbarBackgroundVisibility(.hidden, for: .windowToolbar)`.
3. Move the commands. New and search go to the sidebar. Text size and appearance
   go to Settings and the View menu. Each one keeps its menu command and shortcut.
4. Run the content to the top of the window, and fade it out under the window
   buttons with a mask. The system's scroll edge effect goes off:
   `.scrollEdgeEffectHidden(true, for: .top)`.
5. Give the content a top margin, so a short page starts below the fade.

Without the sidebar, the fade alone keeps text clear of the traffic lights. Check
a window with no sidebar, scrolled so that text sits under them. In LocalChat the
fade is clear for the top 28 pt and solid at 60 pt.

The panel toggle needs `ToolbarSpacer(.flexible)` in front of it. As a lone item
it sits at the column's leading edge, over the content. On the inspector on macOS
27.2 it keeps its default capsule, which matches the sidebar toggle. On the floating
panel on macOS 26.5 it is an icon with no capsule, like the sidebar toggle. With
that panel closed it gets its capsule back:
`.sharedBackgroundVisibility(isOpen ? .hidden : .automatic)`.

## Sidebar rows

- Search: `.searchable(text:placement: .sidebar)`. The system places and styles
  the field. `.searchFocused` connects it to Command-F, and Command-F also opens
  a collapsed sidebar.
- New: a plain row in `.safeAreaInset(edge: .top)` on the list. It sits under the
  search field and does not scroll with the list.
- Status: `.safeAreaInset(edge: .bottom)` on the list.
- A row's own actions (Delete): show them on hover and on the selected row, with
  the same actions in the context menu.

## Motion

Both sides should open at the same speed. The sidebar's animation is the system's,
and one screen recording timed it at about 0.45 s. A `.snappy(duration: 0.2)` panel
felt visibly faster, and people notice. Use `.smooth(duration: 0.45)` with
`.move(edge: .trailing)` and no fade, and respect Reduce Motion. The 0.45 s comes
from one noisy recording, so compare the two sides by eye.

## Traps

| You see | Cause | Fix |
|---|---|---|
| Toolbar items cross the panel's line | `.inspector` sits on a column, not on the split view | Move it to the `NavigationSplitView` |
| A line runs beside the right panel | `.inspector` draws it, and covering it with a view does not hold | On macOS 26.5, use a floating panel if the sides must match. On macOS 27.2 the line is correct, because the sidebar has one too |
| The right panel floats and the sidebar does not | A floating panel on macOS 27 | Use the inspector |
| The two column lines sit at different distances from the window's edges | A saved sidebar width wins over `ideal` | Give both columns one ideal width, and check with empty settings |
| A probe in the sidebar's `safeAreaInset` keeps its old frame after a snapshot resizes the window | The view does not report its new frame | Add a counter to `GridProbes`, put it in the view's `.id`, and raise it after the resize. Confirm with pixels |
| A line runs under the top bar | `.scrollEdgeEffectStyle(.hard, for: .top)` | Use the default style, or hide the effect |
| The content slides past the window's edge | Column minimums add up to more than the window | Raise the window's minimum width |
| A custom toolbar item is not there | A toolbar hides a `Button` with a custom label | Use a plain view with `.onTapGesture` and `.accessibilityAction` |
| The panel toggle shows twice | A second toggle in the main toolbar, while the first stays with the closed inspector | One toggle only |
| Text sits about 8 pt left of the chat box | The scroll bar takes width, even with `scrollerStyle = .overlay` on macOS 27.2 | Measure it and add it back: "Line up the content" |
| Content sits 4 pt off center between the panels | The floating panel has a gap on the content's side | Inset only its three outer sides |
| Section headers start 2 pt left of the rows | The system places them there | Add 2 pt of leading padding to the header's text |
| The status row sticks out past the selection pill | An 8 pt inset, where the pill uses 10 | Use the sidebar's measured inset |
| Two "Chat" menus in the menu bar | A `CommandMenu` has the app's name | Name it something else |

## Review

Take a snapshot of each state, in light and in dark, as the key window, on every
macOS version the app supports:

- Left and right panels match, in front and behind other windows. On macOS 27.2
  check width, color, line, and insets. On macOS 26.5 with a floating panel check
  shape, inset, shadow, and color.
- The content's left and right edges match the chat box's, with scroll bars
  forced on. Its column is centered between the panels.
- Both panels open, each one closed, and both closed. Each toggle appears once
  and stays over its own panel.
- The window at its minimum width, with both panels open.
- The biggest text size, if the app has one.
- A window with no sidebar, scrolled, with text under the traffic lights.
- No line under the top bar. On macOS 27.2 both columns draw a line along their
  edge. On macOS 26.5 no line runs beside a panel, unless you chose the inspector.

## Example

Typechecked against the macOS 26.5 SDK, and run on macOS 27.2 with empty settings
and scroll bars forced on: the text and the chat box share both edges, and both
columns draw 260 wide. `Space` comes from the template's `UI/Grid.swift`.

```swift
struct ContentView: View {
    @State private var showPanel = true
    @State private var search = ""
    @State private var outerWidth: CGFloat = 0
    @State private var innerWidth: CGFloat = 0
    private let readingWidth: CGFloat = 640
    private let sidebarWidth: CGFloat = 260

    /// The same width as the chat box under it.
    private var columnWidth: CGFloat {
        max(min(readingWidth, outerWidth - Space.margin * 2), 0)
    }

    var body: some View {
        NavigationSplitView {
            List { Text("First chat") }
                .searchable(text: $search, placement: .sidebar, prompt: "Search")
                .safeAreaInset(edge: .top, spacing: 0) {
                    Button("New Chat", systemImage: "square.and.pencil") {}
                        .buttonStyle(.plain)
                        .padding(.horizontal, Space.md)
                        .padding(.bottom, Space.xs)
                }
                .navigationSplitViewColumnWidth(min: 200, ideal: sidebarWidth, max: 460)
        } detail: {
            page
                .frame(minWidth: 420)
                .safeAreaBar(edge: .bottom) {
                    Text("The chat box")
                        .frame(width: columnWidth)
                        .padding(.bottom, 10)  // grid: ok one bottom with the status cards
                }
                .navigationTitle("First chat")  // for the Window menu
                .toolbar(removing: .title)
                .toolbarBackgroundVisibility(.hidden, for: .windowToolbar)
        }
        .inspector(isPresented: $showPanel) {  // on the split view
            Text("Panel")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .inspectorColumnWidth(min: 200, ideal: sidebarWidth, max: 460)
                .toolbar {
                    ToolbarSpacer(.flexible)  // a lone item would sit at the leading edge
                    ToolbarItem {
                        Button(showPanel ? "Hide Panel" : "Show Panel", systemImage: "sidebar.trailing") {
                            showPanel.toggle()
                        }
                        .help("Show or hide the panel (Control-Command-I)")
                    }
                }
        }
        .frame(minWidth: 1000, minHeight: 520)  // sidebar + content + panel
    }

    private var page: some View {
        ScrollView {
            Text("The conversation")
                .frame(width: columnWidth, alignment: .leading)
                // A scroll bar can take width. This keeps the column on the chat box's edges.
                .padding(.leading, max(outerWidth - innerWidth, 0))
                .frame(maxWidth: .infinity)
                .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { innerWidth = $0 }
        }
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { outerWidth = $0 }
        .contentMargins(.top, 36, for: .scrollContent)
        .mask {  // text fades out under the window buttons
            VStack(spacing: 0) {
                LinearGradient(stops: [.init(color: .clear, location: 0.47), .init(color: .black, location: 1)],
                               startPoint: .top, endPoint: .bottom)
                    .frame(height: 60)
                Color.black
            }
        }
        .ignoresSafeArea(.container, edges: .top)
        .scrollEdgeEffectHidden(true, for: .top)
    }
}
```

The floating panel, for macOS 26 only. Put it in an `HStack` beside the page, inside
the detail column, in place of the inspector. `Color(light:dark:)` comes from the
template's `UI/Theme.swift`.

```swift
/// Matches the system sidebar on macOS 26.5: inset, rounded, with a soft shadow over the content.
struct FloatingPanel: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.appearsActive) private var appearsActive
    let width: CGFloat

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: 20, style: .continuous)
        content
            .frame(width: width)
            .frame(maxHeight: .infinity)
            .background(appearsActive ? Color(light: 0xFAFAFA, dark: 0x1F2124) : Color(light: 0xF7F7F7, dark: 0x2A2C30),
                        in: shape)  // measure your own
            .overlay(shape.strokeBorder(.primary.opacity(colorScheme == .dark ? 0.12 : 0.04), lineWidth: 1))
            .shadow(color: .black.opacity(colorScheme == .dark ? 0.35 : 0.1), radius: 16, x: -2, y: 0)
            .padding([.top, .bottom, .trailing], Space.sm)  // no gap on the content's side
            .ignoresSafeArea(.container, edges: .top)
    }
}
```
