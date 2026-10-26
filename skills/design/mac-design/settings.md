# Settings window

How to build and structure the Settings window. The template already has
one: `SettingsView.swift`, `UI/AppearanceSettings.swift`, and
`UI/WindowBehavior.swift`. Grow it; do not replace it.

## Contents

- Structure
- Tabs
- Rows
- Size and scrolling
- Focus
- Check

## Structure

- A `Settings` scene, opened with Command-comma from the app menu. Never a
  sheet, a page in the main window, or a custom window.
- `TabView` with one tab per topic. macOS draws the tabs as icons in the
  toolbar, and the window title follows the tab.
- Each tab is one `Form` with `.formStyle(.grouped)`, 520 pt wide.
- Settings apply at once. No Save, Apply, or Cancel button.
- Settings reopens on the tab people last used (`AppModel.settingsTab` is
  saved in the template).
- With a single pane, no tabs: the window title is "<App> Settings".
- `@AppStorage` for simple values, so every view that reads a setting
  updates by itself.

```swift
Settings {
    SettingsView()
        .environment(model)
        .themed()
}
.windowResizability(.contentSize)
```

## Tabs

Add a tab only when a topic has more than about three rows. Two to six tabs
in total. More than six topics (a suite of tools) needs a settings window
with a sidebar instead of tabs. Order:

| Tab | Holds | Symbol |
| --- | --- | --- |
| General | Startup, menu bar and Dock, default behavior | `gearshape` |
| Appearance | Accent color, density. Light and dark follow the Mac; a System/Light/Dark picker only when the owner asks for one (Apple advises against it) | `paintpalette` |
| Shortcuts | Global shortcut, the list of key commands | `keyboard` |
| One per feature | Options for one big feature (Capture, Sync) | the feature's symbol |
| Permissions | Each system permission with its state | `lock.shield` |
| Advanced | Data folder, export, reset, debug options | `gearshape.2` |

The tab names and symbols come from `SettingsTab`. Snapshot mode walks
through every case.

## Rows

- Group rows in `Section("Name")`. Put a short help text in the section
  footer, never in the row label.
- Labels say what the setting does, as a statement: "Show Brisk in the menu
  bar", not "Menu bar icon" or "Enable menu bar".
- On and off: in a grouped `Form` a `Toggle` is a switch; make it a mini
  switch (`.controlSize(.mini)`) so every row keeps the same height. A
  full-size switch only for a master setting that turns a whole group on.
  Outside a grouped form, a checkbox (`.toggleStyle(.checkbox)`) for a
  single option.
- Choices: radio buttons (`.pickerStyle(.radioGroup)`) for two to five, a
  menu `Picker` beyond that. A segmented control belongs in toolbars and
  inspectors, not in Settings rows. `LabeledContent` for a value or a
  custom control on the trailing edge.
- Values on the trailing edge line up. Use the system controls, so they do.
- A permission row shows its state ("Allowed", "Not allowed") and one
  button that opens the right pane of System Settings.
- A setting that cannot be used right now is disabled, with the reason in
  the footer.
- Options that belong to one view (sort, filter, show/hide) live in that
  view or its View menu, not in Settings.
- Do not repeat a system setting (text size, accent, light or dark mode)
  unless the owner asks for it. Offer a button that opens the right System
  Settings pane instead.
- Destructive buttons (Reset, Delete All) go at the bottom of Advanced, with
  `role: .destructive` and a confirmation or Undo.

## Size and scrolling

- `.fitsContent()` on each tab's `Form`, and `.windowResizability(.contentSize)`
  on the scene. The window then grows and shrinks to each tab, and shows no
  scroll bar it does not need.
- A tab taller than 640 pt scrolls. Split it into two tabs before that.

## Focus

`.noInitialFocus()` on the `TabView`. A text field, shortcut recorder, or
button never opens with a focus ring or selected text. The person clicks or
presses Tab to start.

## Check

Snapshot mode writes `settings-<tab>-light.png` and `-dark.png` for every
tab. In each one:

- No control has a focus ring or selected text.
- No scroll bar, unless the tab is taller than 640 pt.
- The window is as tall as its content: no empty band at the bottom.
- Every label is a statement, and trailing values line up.
