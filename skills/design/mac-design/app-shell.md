# App shell

The frame of a window with a left sidebar, a right panel, and a top bar on
macOS 26. Field test: LocalChat on macOS 26.5, one chat app rebuilt through
each layout below while its owner reviewed screenshots. Use
[toolbars.md](toolbars.md) for which item goes where.

## Contents

- Pick the right side
- Floating right panel
- Line up the content
- Pick the top bar
- No top bar
- Sidebar rows
- Motion
- Traps
- Review
- Example

## Pick the right side

The system sidebar floats: rounded, inset from the window's edges, with a soft
shadow over the content. A SwiftUI `.inspector` does not. On macOS 26.5 it is a
flat full-height column with a line along its edge, so the two sides look
different.

| | Inspector | Floating panel |
|---|---|---|
| Looks like | A flat column with a line | The sidebar on the left |
| Top bar | Splits at the column line | One bar over the chat and the panel |
| Width | People drag it | Fixed by your code |
| Menu command | `InspectorCommands()` | Your own button and shortcut |
| Color | System | Measured by hand |

Start with the inspector: it is less code, and people can resize it. Use the
floating panel when the two sides must match, as in a chat app or a window that
is on camera. Decide before you build the toolbar, because the choice sets how
the toolbar works.

Inspector rules are in [toolbars.md](toolbars.md), "Columns" and "Toggles". The
main one: put `.inspector` on the `NavigationSplitView`, not on a column.

## Floating right panel

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

- Make the scroll bar float. With a mouse attached, a scroll bar takes about 16 pt
  of width. Centered content inside the scroll view then moves 8 pt left, while
  the chat box outside it stays. It also jumps when a short chat grows long enough
  to scroll. Set `scrollerStyle = .overlay` on the enclosing `NSScrollView`, and
  set it again when the system's preferred style changes. The example has the code.
- Give the content's lowest control and both status rows one bottom. In LocalChat
  that is 18 pt from the window: the panel's 8 plus the row's 10.
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
it sits at the column's leading edge, over the content. On the panel it is an
icon with no capsule, like the sidebar toggle. With the panel closed it gets its
capsule back: `.sharedBackgroundVisibility(isOpen ? .hidden : .automatic)`.

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
| A line runs beside the right panel | `.inspector` draws it, and covering it with a view does not hold | Use the floating panel |
| A line runs under the top bar | `.scrollEdgeEffectStyle(.hard, for: .top)` | Use the default style, or hide the effect |
| The content slides past the window's edge | Column minimums add up to more than the window | Raise the window's minimum width |
| A custom toolbar item is not there | A toolbar hides a `Button` with a custom label | Use a plain view with `.onTapGesture` and `.accessibilityAction` |
| The panel toggle shows twice | A second toggle in the main toolbar, while the first stays with the closed inspector | One toggle only |
| Text sits 8 pt left of the chat box | The scroll bar takes width | Make the scroll bar float |
| Content sits 4 pt off center between the panels | The floating panel has a gap on the content's side | Inset only its three outer sides |
| Section headers start 2 pt left of the rows | The system places them there | Add 2 pt of leading padding to the header's text |
| The status row sticks out past the selection pill | An 8 pt inset, where the pill uses 10 | Use the sidebar's measured inset |
| Two "Chat" menus in the menu bar | A `CommandMenu` has the app's name | Name it something else |

## Review

Take a snapshot of each state, in light and in dark, as the key window:

- Left and right panels share shape, inset, shadow, and color, in front and
  behind other windows.
- The content's left and right edges match the chat box's, with scroll bars
  forced on. Its column is centered between the panels.
- Both panels open, each one closed, and both closed. Each toggle appears once
  and stays over its own panel.
- The window at its minimum width, with both panels open.
- The biggest text size, if the app has one.
- A window with no sidebar, scrolled, with text under the traffic lights.
- No line under the top bar, and none beside a panel, unless you chose the
  inspector.

## Example

Typechecked against the macOS 26.5 SDK. `Color(light:dark:)` and `Space` come
from the template's `UI/Theme.swift` and `UI/Grid.swift`.

```swift
struct ContentView: View {
    @State private var showPanel = true
    @State private var search = ""
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

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
        } detail: {
            HStack(spacing: 0) {
                page
                    .frame(minWidth: 420)
                if showPanel {
                    Text("Panel")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .modifier(FloatingPanel(width: 260))
                        .transition(.move(edge: .trailing))
                        .zIndex(1)
                }
            }
            .animation(reduceMotion ? nil : .smooth(duration: 0.45), value: showPanel)
            .navigationTitle("First chat")  // for the Window menu
            .toolbar(removing: .title)
            .toolbarBackgroundVisibility(.hidden, for: .windowToolbar)
            .toolbar {
                ToolbarSpacer(.flexible)  // a lone item would sit at the leading edge
                ToolbarItem {
                    Button(showPanel ? "Hide Panel" : "Show Panel", systemImage: "sidebar.trailing") {
                        showPanel.toggle()
                    }
                    .help("Show or hide the panel (Control-Command-I)")
                }
                .sharedBackgroundVisibility(showPanel ? .hidden : .automatic)
            }
        }
        .frame(minWidth: 1000, minHeight: 520)  // sidebar + content + panel
    }

    private var page: some View {
        ScrollView {
            Text("The conversation")
                .frame(maxWidth: .infinity)
                .floatingScrollBar()
        }
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

/// Matches the system sidebar: inset, rounded, with a soft shadow over the content.
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

extension View {
    /// A scroll bar that takes no width. Put it on the content inside a ScrollView.
    func floatingScrollBar() -> some View { background(FloatingScrollBarHook()) }
}

private struct FloatingScrollBarHook: NSViewRepresentable {
    func makeNSView(context: Context) -> Probe { Probe() }
    func updateNSView(_ probe: Probe, context: Context) { probe.apply() }

    final class Probe: NSView {
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            NotificationCenter.default.removeObserver(self)
            guard window != nil else { return }
            // The system resets the style when the person plugs in a mouse or changes the setting.
            NotificationCenter.default.addObserver(self, selector: #selector(styleChanged),
                                                   name: NSScroller.preferredScrollerStyleDidChangeNotification, object: nil)
            DispatchQueue.main.async { [weak self] in self?.apply() }
        }

        @objc private func styleChanged(_ note: Notification) {
            DispatchQueue.main.async { [weak self] in self?.apply() }
        }

        func apply() {
            guard let scrollView = enclosingScrollView, scrollView.scrollerStyle != .overlay else { return }
            scrollView.scrollerStyle = .overlay
        }
    }
}
```
