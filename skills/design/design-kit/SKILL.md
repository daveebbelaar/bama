---
name: design-kit
description: Custom design system for a macOS SwiftUI app with its own parts, not Apple's, covering three token layers, type, an icon set, every part in every state, custom window chrome, a parts gallery, and checks. Use when the user wants the app to have its own look and feel, a brand, or custom buttons, rows, and sidebars, when design-from-app has measured a reference app, or when the user asks for a design system or component library.
---

# Design kit

A native look comes from Apple's parts. A custom look comes from your own
parts: your sidebar row, your button, your checkbox, your icons. SwiftUI
draws all of them. A kit is those parts, the numbers behind them, and one
page that shows every part in every state.

Most apps keep Apple's parts and only pick an accent color (`design-system`
skill). Build a kit when the parts themselves must change. To copy the look of an existing app,
call the Skill tool with `design-from-app` first: it measures the app and
then comes back here.

Everything lives in `Sources/<App>/DesignKit/`. Code for every step:
[parts.md](parts.md).

## 1. Write the spec

Write `design/KIT.md` from [kit-spec.md](kit-spec.md): three words for the
feel, the tokens, the type scale, the icon rules, and one section per part
with its sizes and states. Agents build from this page and review against it.

Check: every part the app's screens need has a section with its sizes and
its states.

## 2. Tokens in three layers

`DesignKit/Tokens.swift`:

1. **Palette**: raw colors, named by hue and step (`gray50`, `blue600`).
   Only this file reads it.
2. **Meaning**: `Ink.text`, `Ink.accent`, `Ink.selection`, `Ink.divider`,
   with a light and a dark value each. Parts read only this layer.
3. **Scales**: `KitType` (type roles), `Metric` (sizes), `Motion`
   (named intents like `hover` and `check`).

A rebrand changes the palette. A dark mode fix changes the meaning layer.
Neither touches a part.

Check: `grep -rn 'Palette\.' Sources/ | grep -v Tokens.swift` finds nothing.

## 3. Type

Name styles by role (`title`, `body`, `label`, `section`, `meta`), never
by size. Use the system font unless the brand needs its own; a bundled
font goes in `Resources/Fonts/` with `ATSApplicationFontsPath` in
`Info.plist.in`. Half-point sizes are fine when a reference needs them.

Check: views set fonts only through `.kitType(...)`.

## 4. Icons

Icons decide the feel more than color does. Views name a `KitIcon`, never
an SF Symbol or a file, so the whole set can change in one place.

- Start from SF Symbols at a fixed size and weight. Light weights read
  less like Apple.
- For a set of your own, draw each icon as a SwiftUI `Shape` from its SVG
  path, or make custom symbols in the SF Symbols app.
- One size, one stroke weight, one corner style for the whole set.
- A selected row may switch to the filled form.

Check: `grep -rn 'systemName:' Sources/ | grep -v DesignKit/` finds nothing.

## 5. Parts

One file per family in `DesignKit/Components/`: sidebar, rows, buttons,
fields, menus. Each part:

- Is a real control. Style a `Button` with a `ButtonStyle`, a `Toggle`
  with a `ToggleStyle`, a field with a `TextFieldStyle`. Never a shape with
  a tap gesture: it loses the keyboard, focus, and VoiceOver.
- Has every state: rest, hover, pressed, selected, focused, disabled, in
  light and dark. Hover uses `onHover`, pressed uses
  `configuration.isPressed`, disabled reads `isEnabled`.
- Takes a forced state for the gallery, so hover and pressed show up in a
  snapshot.
- Reads only meaning tokens, `KitType`, `Metric`, `Motion`, and `KitIcon`.

Check: the part matches its section in `design/KIT.md` in every state.

## 6. Window chrome

For a fully custom look, hide the title bar and draw your own top bar,
and build the sidebar from kit rows instead of `List`. Keep the traffic
lights, menus, context menus, sheets, and alerts native: users depend on
them. SwiftUI cannot move the traffic lights; a small `NSViewRepresentable`
reaches the `NSWindow` (parts.md, Window chrome).

A custom sidebar matches the macOS 27 system one where people would
notice: the selected row's text turns semibold, the selection fill dims
when the window is inactive (`@Environment(\.appearsActive)`), and row
corners stay concentric with the sidebar (mac-design patterns.md, "Custom
chrome that follows the window"). Custom glass bounces on click only on
controls.

Check: the window opens at its default size, the traffic lights sit where
the spec says, the custom sidebar moves with the arrow keys, and its
selection dims when another window is in front.

## 7. Gallery

`DesignKit/KitGallery.swift` shows every part in every state, in light and
dark, the way a storybook does. The app shows it instead of its pages when
`APP_KIT_GALLERY=1` is set, so the normal snapshot command captures it.
Review a new part here before it goes into a screen.

Check: the gallery snapshot shows every part from `design/KIT.md`, and the
user has seen it.

## 8. Checks

```bash
tools/grid-lint.sh
grep -rnE 'Color\(hex|Color\(red|\.font\(\.system|systemName:' Sources/ | grep -v DesignKit/
```

Both come back clean. Then build, snapshot, and run the `layout-grid`
checks on the screens (`build-and-verify` skill).

Done when `design/KIT.md` covers every part, every part is a real control
with every state, the gallery shows them all in light and dark, and the
checks above come back clean.
