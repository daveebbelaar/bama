# Color picker

Pick a color anywhere on screen with a shortcut, copy it as hex, and keep
colors in named collections. Replaces: Sip, ColorSlurp. Taken from Onyx.

## Brief

```markdown
# Pick

A menu bar color picker for designers and developers who grab colors from the screen all day.

## Replaces
Sip, ColorSlurp, Digital Color Meter

## Main jobs
1. Pick a color from anywhere on screen and copy it in my format.
2. See recent colors in the menu bar and copy one again with a click.
3. Keep colors in named collections and add to them by picking or typing hex.

## Data
- Color: hex string, "#RRGGBB" in uppercase sRGB
- ColorCollection: id, name, colors (hex strings, no duplicates)
- Recent: up to 12 hex strings, newest first
- Settings: picker shortcut, copy format

## Shape
Menu bar extra (a window-style panel) plus a Settings window.
macOS 26 or later. Local data. Works offline. No accounts.

## System hooks
Global shortcut, menu bar item. No permission needed.

## Reference
Sip

## Look
Native, system accent color. Swatches are rounded squares with a hairline edge.

## Not in version one
- Contrast checker and color harmonies
- Export to ASE, CSS, or Tailwind files
- iCloud sync
```

## How it works

| Part | API | Permission |
| --- | --- | --- |
| Shortcut | Carbon `RegisterEventHotKey` | None |
| Menu bar item, no Dock icon | `MenuBarExtra` with `.menuBarExtraStyle(.window)`, `LSUIElement = YES` | None |
| Magnifier and pick | `NSColorSampler().show { color in ... }` | None |
| Copy | `NSPasteboard.general.setString` | None |
| Save | JSON file in `~/Library/Application Support/Pick/colors.json` | None |

`NSColorSampler` is the system loupe from the color panel and needs no Screen Recording permission.
Shortcut code: [os-integrations recipes](../skills/code/os-integrations/recipes.md).

Types: `HexColor` (pure functions: color to hex, parse, normalize, format; unit tested),
`ColorStore` (`@MainActor @Observable`, `collections` and `recent`, saves on every change),
`ColorPicker` (closes the menu bar window, runs the sampler, copies, adds to Recent), `SwatchRow`
(adaptive grid; click copies, right-click shows formats and Remove), `MenuBarView`,
`ColorSettings` (shortcut, format, Recent with Clear, collections with Undo), plus
`HotkeyCenter`, `ShortcutField`, `Toast`.

Behavior that matters:

- Default shortcut: Control-Option-Command-C.
- After a pick: add to Recent, copy in the chosen format, show a toast "Copied #6342E6" with a
  swatch. Escape in the loupe cancels and changes nothing.
- Recent: remove the same hex first, insert at the front, keep 12.
- Copy formats, default `hex`: `hex` gives `#6342E6`, `hexBare` gives `6342E6`, `rgb` gives
  `rgb(99, 66, 230)`, `swiftui` gives `Color(red: 0.388, green: 0.259, blue: 0.902)`.
- Right-click on any swatch lists every format as "Copy <value>", plus Remove inside a collection.
- Typed hex: accept `5b47e0`, `#5B47E0`, `#abc`, and spaces around it. Store as `#5B47E0`.
  Reject anything else with a beep.
- A collection never holds the same hex twice. New collections are named "New Collection".
- First launch seeds one collection, "Brand", with a few sample colors, so the menu is not empty.
- Picking into a collection (eyedropper button on its row) adds the color there and to Recent.
- The file is written with `.atomic` on every change, pretty-printed JSON.

Read sRGB components before making hex:

```swift
static func string(from color: NSColor) -> String? {
    guard let c = color.usingColorSpace(.sRGB) else { return nil }
    func byte(_ v: CGFloat) -> Int { Int((min(max(v, 0), 1) * 255).rounded()) }
    return String(format: "#%02X%02X%02X", byte(c.redComponent), byte(c.greenComponent), byte(c.blueComponent))
}
```

## Stories

```markdown
# Stories

## M1 Core loop

### S-001 Pick a color with the shortcut
As the user, I press Control-Option-Command-C, click anywhere, and the color is copied.
Screens: toast
Acceptance:
- [manual] The system loupe appears; clicking copies `#RRGGBB` and a toast shows the value and a swatch.
- [manual] No permission prompt appears, on first launch or later.
- [manual] Escape in the loupe copies nothing and adds nothing to Recent.
Status: todo

### S-002 Turn picked colors into hex
As the user, I get the same hex for a color no matter which display it came from.
Acceptance:
- [unit] `HexColor.string(from:)` converts to sRGB first and rounds each channel to 0 to 255.
- [unit] A Display P3 color outside sRGB clamps each channel to 0 to 255 and never crashes.
Status: todo

### S-003 See recent colors in the menu bar
As the user, I open the menu bar item and see my last 12 picks, newest first.
Screens: menu, menu-empty
Depends: S-001
Acceptance:
- [snap] The menu shows a Pick button, a Recent row of swatches, and the collections below.
- [unit] Picking a color already in Recent moves it to the front; the list never passes 12.
- [snap] With nothing saved, the menu says "Pick a color to start a collection."
Status: todo

### S-004 Copy a swatch again
As the user, I click a swatch to copy it, or right-click it to copy another format.
Depends: S-003
Acceptance:
- [manual] Click copies in the chosen format and shows the toast.
- [snap] Right-click lists "Copy #6342E6", "Copy 6342E6", "Copy rgb(99, 66, 230)", and the SwiftUI line.
- [snap] Hovering a swatch shows its hex as a tooltip.
Status: todo

### S-005 Pick from the menu bar
As the user, I click Pick in the menu bar panel and pick a color.
Depends: S-001
Acceptance:
- [manual] The panel closes first and the loupe opens about 0.12 s later, not on top of the panel.
Status: todo

### S-006 Choose the copy format and shortcut
As the user, I pick a copy format and change the picker shortcut in Settings.
Screens: settings-picker
Acceptance:
- [unit] Each format gives the exact text above for `#6342E6`, with or without `#`, in any case.
- [manual] Click the shortcut field and press a combo; Escape cancels, Delete clears; the old shortcut pauses while recording.
- [snap] A combo another app owns shows "In use by another app" under the field.
Status: todo

### S-007 Keep colors after a restart
As the user, I quit and reopen Pick and my Recent and collections are still there.
Acceptance:
- [unit] `ColorStore` round-trips through `colors.json` with names, order, and colors intact.
- [unit] A missing file loads the seeded "Brand" collection; a broken file does not crash.
Status: todo

## M2 Collections

### S-008 Create and rename a collection
As the user, I click New Collection and type its name in the header.
Screens: settings-collections
Acceptance:
- [snap] A new, empty collection says "No colors yet. Pick one from the screen or type a hex code."
- [manual] The name saves as I type.
Status: todo

### S-009 Add a color by picking
As the user, I click the eyedropper on a collection and pick a color into it.
Depends: S-008
Acceptance:
- [unit] Adding a hex the collection already has changes nothing.
- [manual] The color lands in that collection and in Recent.
Status: todo

### S-010 Add a color by typing hex
As the user, I type a hex code in a collection's field and press Return or Add.
Depends: S-008
Acceptance:
- [unit] `5b47e0`, `#5B47E0`, and ` #abc ` become `#5B47E0` and `#AABBCC`; `#12345`, `zzzzzz`, `#ab` are rejected.
- [manual] A rejected code beeps and stays in the field.
Status: todo

### S-011 Remove a color or delete a collection
As the user, I remove a swatch with right-click, or delete a whole collection with its trash button.
Depends: S-008
Acceptance:
- [snap] After delete, the footer says "Deleted "<name>"." with an Undo button.
- [manual] Undo (or Command-Z) puts the collection back at the same position.
- [manual] Clear on Recent also offers Undo.
Status: todo

## Dropped
- Usage stats and the activity log
- Debug bridge color commands
```

## Gotchas

- Use `NSColorSampler`, not your own screen capture loupe. It needs no Screen Recording grant,
  handles every display and scale, and supports Escape.
- Close the menu bar panel before the sampler opens, then wait about 0.12 s. Otherwise the loupe
  opens over the panel. Find it with `NSApp.windows` where `className` contains `"MenuBarExtra"`
  and `isVisible`, then `orderOut(nil)`.
- Keep a strong reference to the `NSColorSampler` until its handler runs, and set it to nil there.
- Convert with `usingColorSpace(.sRGB)` before reading `redComponent`. Reading components of a
  color in another color space raises an exception, and Display P3 values give a different hex.
- `HexColor.formatted(_, as: "hexBare")` dropped the first digit when the stored value had no `#`
  (`"6342E6"` became `"342E6"`). Build every format from the parsed components, never by
  slicing the string. A unit test found it.
- Deleting a collection was one click with no confirm and no Undo. Keep the removed collection
  and its index, show Undo in the footer, and bind Command-Z to it.
- The sampler handler runs on the main thread, but Swift 6 does not know that. Wrap the body in
  `MainActor.assumeIsolated { ... }`.
- Keep `HexColor` free of AppKit state and stores, so a test target can compile it without
  hosting the app. A hosted test bundle launches a second copy that fights over the shortcut.
- Pause all registered shortcuts while a shortcut field records, or pressing the current combo
  fires the picker instead of being recorded.

Done when the shortcut copies any on-screen color as hex with no permission prompt, Recent shows
the last 12 picks in the menu bar, and collections survive a restart.
