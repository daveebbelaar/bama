---
name: layout-grid
description: Grid and alignment rules for a macOS SwiftUI app, with three checks that catch misalignment (a lint for off-grid numbers, a layout probe that measures real frames in snapshot mode, and a grid overlay). Use when building or reviewing a custom page, card, row, form, or sheet, after every build that touched layout, or when the user says something looks misaligned, crooked, cramped, or unevenly spaced.
---

# Layout grid

Agents guess numbers. A guessed `.padding(13)` looks almost right and
makes the whole app feel slightly off. This skill replaces guessing with
one scale and three checks that fail when something is off.

The template has everything in place: `Sources/<App>/UI/Grid.swift` and
`tools/`. For an app made before this skill, copy `UI/Grid.swift`,
`tools/grid-lint.sh`, and `tools/check-layout.swift` from the `new-mac-app`
skill's template, and the layout file line from its `Snapshot.swift`.

## The rules

1. Every padding, spacing, and size comes from `Space`: `xs 4`, `sm 8`,
   `md 12`, `lg 16`, `xl 20`, `xxl 24`, `section 32`. Raw numbers are
   0, 1, 2, or a multiple of 4.
2. Pages and windows have a 20 pt margin (`Space.margin`). Cards pad 16
   (`Space.lg`). Related controls sit 8 apart, groups 20 to 24, sections 32.
3. Each column has one leading edge. Titles, text, cards, and buttons in a
   column start on the same x. Indent on purpose, by a step of the scale.
4. Let containers do the aligning:
   - Labels with controls: `Form` with `.formStyle(.grouped)`, or
     `.columns` for the Mac layout of right-aligned labels.
   - Rows and columns of values: `Grid` and `GridRow`.
   - A label with a value: `LabeledContent`.
   - Text of different sizes in one row: `HStack(alignment: .firstTextBaseline)`.
   - Numbers in a column: `.monospacedDigit()`, trailing aligned.
   - An icon with text: `Label`.
5. Sheets are 360, 480, or 640 wide. Controls take their height from
   `.controlSize`, never from a fixed height.
6. Nested corners are concentric: inner radius = outer radius - padding.
7. `.offset` and `.position` move a view after layout, so nothing lines up
   with it. Use them only for motion and drag previews, with
   `// grid: ok <why>` on the line.
8. Long text truncates with its full value in a tooltip. Nothing clips.

## Check 1: lint the code

Run it after every build that touched views:

```bash
tools/grid-lint.sh
# Sources/Tasks/TaskRow.swift:14: off grid (10): .padding(.horizontal, 10)
# FAIL grid-lint: 1 lines off the grid
```

Fix each line with a `Space` token.

## Check 2: probe the real layout

Mark what you lay out yourself: the page, its sections, cards, rows in a
card, sheet content. System lists, forms, sidebars, and toolbars align
themselves and need no probes.

```swift
VStack(alignment: .leading, spacing: Space.xxl) {
    Text("Today").gridProbe("title", area: "page")
    StatsRow().gridProbe("stats", area: "page")
    TaskCard()
        .gridArea("card", inset: Space.lg)
        .gridProbe("card", area: "page")
}
.padding(Space.margin)
.gridArea("page")
```

`.gridArea` marks a container and its inset. `.gridProbe` marks a view in
it. Probes with the same `edge` (default `"lead"`) must share one leading
edge. Pass `edge: nil` for views that sit side by side.

Snapshot mode writes a `<page>-<mode>-layout.json` next to every PNG.
Check them:

```bash
swift tools/check-layout.swift /tmp/<App>-shots/*-layout.json
# PASS today-light-layout.json: 12 probes in 2 areas
# FAIL inbox-light-layout.json
#   - edge page/lead has 2 leading edges: title 320, list 324
```

It checks that every probe:

1. Starts on a whole or half point, so its edges stay sharp.
2. Starts a multiple of 4 pt from its area's edge.
3. Stays inside its area's inset on both sides.
4. Shares one leading edge with the others on its edge.
5. Sits a multiple of 4 pt below the probe above it.
6. Never overlaps another probe in its area.

## Check 3: look at the grid

When a check fails and the cause is not clear, draw the grid over the
window:

```bash
APP_GRID=1 APP_STORE=/tmp/<App>-test.store APP_SNAPSHOT=/tmp/<App>-grid \
  ~/Applications/<App>.app/Contents/MacOS/<App>
```

The PNGs show an 8 pt grid, each area in blue with its inset dashed, and
each probe in pink with its name. Open them with the Read tool.

## Fix a failure

| Message | Usual cause | Fix |
| --- | --- | --- |
| starts 23 pt into page | a raw padding on one child | remove it, use the stack's `Space` padding |
| 2 leading edges | a centered stack, or one child with extra padding | `alignment: .leading` on the stack |
| gap 10 pt | `spacing: 10`, or a `Spacer(minLength:)` | a `Space` token |
| inside its 20 pt inset | a missing margin, or a fixed width wider than the parent | `.padding(Space.margin)`, `maxWidth` instead of `width` |
| overlap | `.offset`, `.position`, or a fixed height | remove it, let the stack size the view |
| x between pixels | a fractional number | a whole number from `Space` |

Done when `tools/grid-lint.sh` passes, `tools/check-layout.swift` passes
on the layout files of every page you touched, and every custom page and
card has a `.gridArea` with probes on its main parts.
