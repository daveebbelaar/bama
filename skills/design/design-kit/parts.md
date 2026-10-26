# Kit parts in SwiftUI

Code for each step of [SKILL.md](SKILL.md). It compiles on macOS 26 with
Swift 6.2 and main-actor default isolation (the `new-mac-app` template).
Rename `Kit` types freely; keep the layers.

## Contents

- Tokens
- Type
- Part states
- Buttons
- Checkbox as a Toggle
- Fields
- Sidebar rows with keyboard navigation
- List rows
- Icons
- Window chrome
- Gallery

## Tokens

```swift
import SwiftUI

// Layer 1: raw colors. Only this file reads Palette.
enum Palette {
    static let gray50 = Color(hex: 0xF9FBFC)
    static let gray900 = Color(hex: 0x202020)
    static let blue100 = Color(hex: 0xDFEDFA)
    static let blue600 = Color(hex: 0x287ABC)
    static let night = Color(hex: 0x1E1F22)
    static let snow = Color(hex: 0xF2F2F2)
}

// Layer 2: meaning, with a light and a dark value. Parts read only this.
enum Ink {
    static let text = Color(light: Palette.gray900, dark: Palette.snow)
    static let sidebar = Color(light: Palette.gray50, dark: Palette.night)
    static let accent = Palette.blue600
    static let selection = Color(light: Palette.blue100, dark: Palette.blue600.opacity(0.25))
}

// Layer 3: scales.
enum Metric {
    static let rowHeight: CGFloat = 28
    static let rowInset: CGFloat = 8
    static let radius: CGFloat = 6
}

enum Motion {
    static let hover = Animation.easeOut(duration: 0.12)
    static let press = Animation.spring(response: 0.25, dampingFraction: 0.7)
}

extension Color {
    init(hex: UInt32) {
        self.init(.sRGB, red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255, blue: Double(hex & 0xFF) / 255)
    }

    /// A color that follows light and dark mode.
    init(light: Color, dark: Color) {
        self.init(nsColor: NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? NSColor(dark) : NSColor(light)
        })
    }
}
```

## Type

```swift
enum KitType {
    case title, body, label, labelStrong, meta

    var font: Font {
        switch self {
        case .title: .system(size: 22, weight: .bold)
        case .body, .label: .system(size: 13)
        case .labelStrong: .system(size: 13, weight: .semibold)
        case .meta: .system(size: 11)
        }
    }
}

extension View {
    func kitType(_ type: KitType) -> some View { font(type.font) }
}
```

A bundled font: `.custom("Inter-Medium", size: 13, relativeTo: .body)`.

## Part states

Every part computes one state. The gallery forces it, so hover and pressed
show up in a snapshot.

```swift
enum PartState: String, CaseIterable {
    case rest, hover, pressed, selected, focused, disabled
}

extension EnvironmentValues {
    @Entry var forcedPartState: PartState?
}
```

## Buttons

A real `Button` with a `ButtonStyle`: keyboard, focus, and VoiceOver work.

```swift
struct KitButtonStyle: ButtonStyle {
    enum Kind { case primary, secondary, ghost }
    var kind: Kind = .primary

    func makeBody(configuration: Configuration) -> some View {
        KitButtonBody(configuration: configuration, kind: kind)
    }
}

extension ButtonStyle where Self == KitButtonStyle {
    static func kit(_ kind: KitButtonStyle.Kind = .primary) -> KitButtonStyle { KitButtonStyle(kind: kind) }
}

private struct KitButtonBody: View {
    let configuration: ButtonStyleConfiguration
    let kind: KitButtonStyle.Kind
    @Environment(\.forcedPartState) private var forced
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.isFocused) private var isFocused
    @State private var hovering = false

    private var state: PartState {
        forced ?? (!isEnabled ? .disabled : configuration.isPressed ? .pressed
            : hovering ? .hover : isFocused ? .focused : .rest)
    }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: Metric.radius, style: .continuous)
        configuration.label
            .kitType(.labelStrong)
            .padding(.horizontal, 12)
            .frame(height: Metric.rowHeight)
            .foregroundStyle(kind == .primary ? AnyShapeStyle(.white) : AnyShapeStyle(Ink.text))
            .background(shape.fill(fill))
            .overlay(shape.strokeBorder(Ink.accent, lineWidth: state == .focused ? 2 : 0))
            .opacity(state == .disabled ? 0.4 : 1)
            .scaleEffect(state == .pressed ? 0.98 : 1)
            .animation(Motion.press, value: state)
            .onHover { hovering = $0 }
            .contentShape(shape)
    }

    private var fill: Color {
        switch kind {
        case .primary: Ink.accent.opacity(state == .hover ? 0.9 : state == .pressed ? 0.8 : 1)
        case .secondary: Ink.selection.opacity(state == .hover || state == .pressed ? 1 : 0.6)
        case .ghost: state == .hover || state == .pressed ? Ink.selection : .clear
        }
    }
}
```

Use it: `Button("Add Task", action: add).buttonStyle(.kit())`. Add
`.focusEffectDisabled()` at the root so the system ring does not draw
over the kit's own focus ring.

## Checkbox as a Toggle

A custom check is a `ToggleStyle`, so it stays a real toggle.

```swift
struct RoundCheckboxStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button { configuration.isOn.toggle() } label: {
            HStack(spacing: 8) {
                ZStack {
                    Circle().strokeBorder(Ink.text.opacity(0.4), lineWidth: 1)
                    if configuration.isOn {
                        Circle().fill(Ink.accent)
                        Image(systemName: "checkmark").font(.system(size: 8, weight: .bold)).foregroundStyle(.white)
                    }
                }
                .frame(width: 16, height: 16)
                configuration.label
            }
        }
        .buttonStyle(.plain)
        .accessibilityValue(configuration.isOn ? "Checked" : "Unchecked")
    }
}
```

## Fields

`TextFieldStyle` cannot be written outside Apple's code, so style a plain
field with a modifier.

```swift
struct KitField: ViewModifier {
    @FocusState private var focused: Bool

    func body(content: Content) -> some View {
        content
            .textFieldStyle(.plain)
            .kitType(.body)
            .focused($focused)
            .padding(.horizontal, 8)
            .frame(height: Metric.rowHeight)
            .background(RoundedRectangle(cornerRadius: Metric.radius).fill(Ink.selection.opacity(0.4)))
            .overlay(RoundedRectangle(cornerRadius: Metric.radius)
                .strokeBorder(focused ? Ink.accent : .clear, lineWidth: 1.5))
    }
}
```

Use it: `TextField("Task name", text: $name).modifier(KitField())`.

## Sidebar rows with keyboard navigation

A custom sidebar replaces `List`, so it must add back what `List` gave:
arrow keys and selection for VoiceOver.

```swift
struct KitSidebar: View {
    let items: [String]
    @Binding var selection: String

    var body: some View {
        VStack(spacing: 0) {
            ForEach(items, id: \.self) { item in
                Button(item) { selection = item }
                    .buttonStyle(KitRowStyle(isSelected: item == selection))
                    .accessibilityAddTraits(item == selection ? .isSelected : [])
            }
        }
        .focusable()
        .focusEffectDisabled()
        .onMoveCommand { direction in
            guard let index = items.firstIndex(of: selection) else { return }
            switch direction {
            case .up: selection = items[max(index - 1, 0)]
            case .down: selection = items[min(index + 1, items.count - 1)]
            default: break
            }
        }
    }
}

struct KitRowStyle: ButtonStyle {
    var isSelected: Bool

    func makeBody(configuration: Configuration) -> some View {
        RowBody(configuration: configuration, isSelected: isSelected)
    }

    private struct RowBody: View {
        let configuration: Configuration
        let isSelected: Bool
        @Environment(\.forcedPartState) private var forced
        @Environment(\.isEnabled) private var isEnabled
        @State private var hovering = false

        var body: some View {
            let state = forced ?? (!isEnabled ? .disabled : isSelected ? .selected
                : configuration.isPressed ? .pressed : hovering ? .hover : .rest)
            let shape = RoundedRectangle(cornerRadius: Metric.radius)
            configuration.label
                .kitType(.label)
                .foregroundStyle(state == .selected ? Ink.accent : Ink.text)
                .padding(.horizontal, Metric.rowInset)
                .frame(maxWidth: .infinity, minHeight: Metric.rowHeight, alignment: .leading)
                .background(shape.fill(state == .selected ? Ink.selection
                    : state == .hover || state == .pressed ? Ink.selection.opacity(0.5) : .clear))
                .overlay(shape.strokeBorder(Ink.accent, lineWidth: state == .focused ? 2 : 0))
                .opacity(state == .disabled ? 0.4 : 1)
                .contentShape(.rect)
                .onHover { hovering = $0 }
                .animation(Motion.hover, value: hovering)
                .padding(.horizontal, Metric.rowInset)
        }
    }
}
```

## List rows

Rows draw their own divider, inset to where the text starts.

```swift
struct KitListRow: View {
    let title: String
    @Binding var done: Bool

    var body: some View {
        Toggle(isOn: $done) { Text(title).kitType(.body).foregroundStyle(Ink.text) }
            .toggleStyle(RoundCheckboxStyle())
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .overlay(alignment: .bottom) {
                Rectangle().fill(Ink.text.opacity(0.08)).frame(height: 0.5).padding(.leading, 24)
            }
    }
}
```

## Icons

Views name a `KitIcon`. The set maps each name to an SF Symbol or to a
drawn shape, in one place.

```swift
enum KitIcon {
    case inbox, today, search, custom(KitGlyph)

    var symbol: String? {
        switch self {
        case .inbox: "tray"
        case .today: "calendar"
        case .search: "magnifyingglass"
        case .custom: nil
        }
    }
}

struct KitIconView: View {
    let icon: KitIcon
    var size: CGFloat = 14
    var filled = false

    var body: some View {
        Group {
            if case .custom(let glyph) = icon {
                glyph.stroke(style: StrokeStyle(lineWidth: 1.25, lineCap: .round, lineJoin: .round))
            } else if let name = icon.symbol {
                Image(systemName: filled ? name + ".fill" : name).font(.system(size: size, weight: .light))
            }
        }
        .frame(width: size, height: size)
    }
}

/// An icon of your own: an SVG path from a 24 x 24 box, scaled to any size.
/// This one is a tray: copy the numbers from the SVG's `d` attribute.
struct KitGlyph: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 3, y: 13))
        path.addLine(to: CGPoint(x: 8, y: 13))
        path.addLine(to: CGPoint(x: 10, y: 16))
        path.addLine(to: CGPoint(x: 14, y: 16))
        path.addLine(to: CGPoint(x: 16, y: 13))
        path.addLine(to: CGPoint(x: 21, y: 13))
        path.addRoundedRect(in: CGRect(x: 3, y: 5, width: 18, height: 14), cornerSize: CGSize(width: 3, height: 3))
        return path.applying(CGAffineTransform(scaleX: rect.width / 24, y: rect.height / 24))
    }
}
```

Use `.custom(KitGlyph())` for a drawn icon. A set of drawn icons is one
`Shape` per icon, all on the same 24 x 24 box and stroke weight.

## Window chrome

Hide the title bar, keep the traffic lights, and move them where the kit
wants them. SwiftUI has no API for the position, so this reaches the
`NSWindow`.

```swift
struct WindowChrome: NSViewRepresentable {
    var firstButtonCenter = CGPoint(x: 20, y: 20)
    var buttonSpacing: CGFloat = 20

    func makeNSView(context: Context) -> NSView {
        let view = ChromeView()
        view.configure = configure
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}

    private func configure(_ window: NSWindow) {
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.styleMask.insert(.fullSizeContentView)
        for (index, type) in [NSWindow.ButtonType.closeButton, .miniaturizeButton, .zoomButton].enumerated() {
            guard let button = window.standardWindowButton(type), let container = button.superview else { continue }
            let x = firstButtonCenter.x + CGFloat(index) * buttonSpacing
            button.setFrameOrigin(NSPoint(x: x - button.frame.width / 2,
                                          y: container.frame.height - firstButtonCenter.y - button.frame.height / 2))
        }
    }

    private final class ChromeView: NSView {
        var configure: ((NSWindow) -> Void)?
        private var observer: NSObjectProtocol?

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            guard let window else { return }
            DispatchQueue.main.async { [weak self] in self?.configure?(window) }
            // AppKit moves the buttons back on resize.
            observer = NotificationCenter.default.addObserver(forName: NSWindow.didResizeNotification,
                                                              object: window, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.configure?(window) }
            }
        }
    }
}
```

In the App:

```swift
Window("Tasks", id: "main") {
    ContentView()
        .ignoresSafeArea()
        .background(WindowChrome())
        .focusEffectDisabled()
}
.windowStyle(.hiddenTitleBar)
.defaultSize(width: 1000, height: 742)
.restorationBehavior(.disabled)
```

Set the size with `.defaultSize`, not a fixed `.frame`: with a hidden title
bar a fixed frame makes the window taller by the title bar's height, and a
window that cannot resize grays out the green button.

## Gallery

Every part in every state, light and dark. Show it instead of the app
when `APP_KIT_GALLERY=1`, then use the normal snapshot command.

```swift
struct KitGallery: View {
    static let enabled = ProcessInfo.processInfo.environment["APP_KIT_GALLERY"] == "1"
    @State private var done = false
    @State private var name = ""

    var body: some View {
        ScrollView {
            Grid(alignment: .leading, horizontalSpacing: 24, verticalSpacing: 16) {
                GridRow {
                    Text("")
                    ForEach(PartState.allCases, id: \.self) { Text($0.rawValue).kitType(.meta) }
                }
                row("Primary") { Button("Add Task") {}.buttonStyle(.kit()) }
                row("Secondary") { Button("Plan Week") {}.buttonStyle(.kit(.secondary)) }
                row("Ghost") { Button("Cancel") {}.buttonStyle(.kit(.ghost)) }
                row("Sidebar row") { Button("Inbox") {}.buttonStyle(KitRowStyle(isSelected: false)).frame(width: 160) }
            }
            .padding(24)
            GroupBox("Controls") {
                KitListRow(title: "Write the launch post", done: $done)
                TextField("Task name", text: $name).modifier(KitField())
            }
            .padding(24)
        }
    }

    private func row(_ name: String, @ViewBuilder part: @escaping () -> some View) -> some View {
        GridRow {
            Text(name).kitType(.label)
            ForEach(PartState.allCases, id: \.self) { state in
                part()
                    .environment(\.forcedPartState, state)
                    .disabled(state == .disabled)
            }
        }
    }
}
```

In the App: `if KitGallery.enabled { KitGallery() } else { ContentView() }`.
