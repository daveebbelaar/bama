# Accessibility audit

How to check step 7 of [SKILL.md](SKILL.md) on a running build, and the
SwiftUI modifiers that fix what it finds. Standard controls do most of this
on their own. Custom controls need the work.

## Contents

- Run the audit
- Keyboard
- VoiceOver
- Custom controls
- Color and contrast
- Motion and transparency
- Text size

## Run the audit

1. Build and open the app: `./build.sh --open`.
2. Open Accessibility Inspector: `open -a "Accessibility Inspector"` (it
   ships with Xcode). Pick the app as the target, open the Audit tab, and
   run the audit on each new view.
3. Turn on keyboard navigation: System Settings > Keyboard > Keyboard
   navigation. Run the whole flow with Tab, arrows, Return, Escape, and
   Space.
4. Turn on VoiceOver with Command-F5. Move with Control-Option and the
   arrow keys. Run the flow again, listening.
5. In System Settings > Accessibility > Display, turn on Increase
   Contrast, Reduce Motion, and Reduce Transparency one at a time. Look at
   each new view in light and dark mode.

Done when the audit shows no issues for the new views and both runs
finish the flow without the mouse.

## Keyboard

- Every step of the flow is reachable with the keyboard, in reading order.
- The default button responds to Return, Cancel to Escape.
- A new item gets focus so people can type at once.

```swift
@FocusState private var focused: Item.ID?

List(items) { item in
    ItemRow(item: item).focused($focused, equals: item.id)
}
.onChange(of: items.count) { focused = items.last?.id }
```

## VoiceOver

- The label matches the words on screen. An icon-only button keeps its
  title as the VoiceOver label; the tooltip describes what it does.
- A row reads as one element, with its actions available from the
  VoiceOver actions menu.
- Decorative images stay silent.

```swift
Button("New Task", systemImage: "plus", action: addTask)
    .labelStyle(.iconOnly)          // VoiceOver still reads "New Task"
    .help("Add a task to this list (⌘N)")

HStack { /* checkbox, title, due date */ }
    .accessibilityElement(children: .combine)
    .accessibilityAction(named: "Complete") { complete(item) }

Image("hero").accessibilityHidden(true)
```

- Section titles are headings, so VoiceOver can jump between them:
  `.accessibilityAddTraits(.isHeader)`.
- When content changes without a click (a sync finishes, a filter empties
  the list), post an announcement:
  `AccessibilityNotification.Announcement("No tasks left").post()`.
- A chart gets a one-line summary as its label ("Spending rose 12% in
  October").
- Voice Control says what people see: the visible label and the
  accessibility label are the same words.
- No view that hides itself on a timer is the only way to act. An Undo
  toast also has Edit > Undo, Command-Z.

## Custom controls

Every custom control answers four questions for VoiceOver (WWDC26-220):
what it is (label), what it is set to (value), what people can do
(actions), and what changed (feedback). A control that only works with a
drag also offers actions, so Switch Control and Voice Control reach it.

```swift
struct VolumeDial: View {
    @Binding var level: Double            // 0...1
    @State private var lastAnnounced = Date.distantPast

    var body: some View {
        Circle()
            .trim(from: 0, to: level)
            .stroke(.tint, lineWidth: 6)
            .frame(width: 44, height: 44)
            .gesture(DragGesture().onChanged { drag in
                level = min(1, max(0, level - drag.translation.height / 400))
                announce()
            })
            .accessibilityElement()
            .accessibilityLabel("Volume")
            .accessibilityValue(level.formatted(.percent.precision(.fractionLength(0))))
            .accessibilityAdjustableAction { direction in
                switch direction {
                case .increment: level = min(1, level + 0.1)
                case .decrement: level = max(0, level - 0.1)
                @unknown default: break
                }
            }
            .accessibilityAction(named: "Mute") { level = 0 }
    }

    /// During a drag, speak the value at most every 0.3 s.
    private func announce() {
        guard Date.now.timeIntervalSince(lastAnnounced) >= 0.3 else { return }
        lastAnnounced = .now
        AccessibilityNotification.Announcement(level.formatted(.percent.precision(.fractionLength(0)))).post()
    }
}
```

A two-axis control (a color square, a position pad) gets four named
actions, "Move Up", "Move Down", "Move Left", "Move Right", with a fixed
step that stops at the edges.

## Color and contrast

- Status color always comes with an icon or a word.
- Body text contrast is at least 4.5 to 1 against its background, in light
  and dark mode. Aim for 7 to 1 for small text in custom colors.
- Honor Differentiate Without Color and Increase Contrast in custom views.

```swift
@Environment(\.accessibilityDifferentiateWithoutColor) private var noColorOnly
@Environment(\.colorSchemeContrast) private var contrast

Image(systemName: noColorOnly ? "exclamationmark.circle.fill" : "circle.fill")
    .foregroundStyle(.red)
```

## Motion and transparency

Replace slides, springs, and parallax with a fade when Reduce Motion is on.
Never animate a blur or a change in depth (scale toward the viewer) under
Reduce Motion, and make springs tighter. Never make people wait for an
animation: it can be interrupted. Give custom glass a solid fallback when
Reduce Transparency is on.

```swift
@Environment(\.accessibilityReduceMotion) private var reduceMotion
@Environment(\.accessibilityReduceTransparency) private var reduceTransparency

.transition(reduceMotion ? .opacity : .move(edge: .trailing))
.background(reduceTransparency ? AnyShapeStyle(.background) : AnyShapeStyle(.regularMaterial))
```

## Text size

- macOS body text is 13 pt and nothing is under 10 pt. Use text styles
  (`.body`, `.callout`, `.caption`), not fixed sizes.
- Truncated text shows its full value in a tooltip.

```swift
Text(item.title)
    .lineLimit(1)
    .truncationMode(.tail)
    .help(item.title)
```

macOS has no Dynamic Type, but people must be able to enlarge text to
200%. An app people read in (notes, articles, mail) adds View > Bigger,
Smaller, and Actual Size, and scales its reading text from one setting:

```swift
struct TextSizeCommands: Commands {
    @AppStorage("textScale") private var scale = 1.0
    var body: some Commands {
        CommandGroup(after: .toolbar) {
            Button("Bigger") { scale = min(2, scale + 0.1) }.keyboardShortcut("+")
            Button("Smaller") { scale = max(0.8, scale - 0.1) }.keyboardShortcut("-")
            Button("Actual Size") { scale = 1 }.keyboardShortcut("0")
        }
    }
}

// In the reading view:
@AppStorage("textScale") private var scale = 1.0
Text(note.body).font(.system(size: 13 * scale))
```
