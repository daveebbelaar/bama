---
name: design-from-app
description: Rebuild the look of an app the user likes as a native SwiftUI design kit, by measuring its screenshots (sizes, spacing, type, colors, icons), building its parts, and comparing pixel by pixel until they match. Use when the user names an app whose look they want, shares screenshots of one, or says "make it look like X".
argument-hint: "<app name or screenshot paths>"
---

# Design from app

Look at an app, measure it, and rebuild its design system in SwiftUI. The
result is a design kit (`design-kit` skill) with the reference app's
numbers, and one reference screen that matches the screenshot.

Guessing gets close. Measuring gets it right. Two scripts do the
measuring, next to this skill:

- `scripts/measure.swift`: sizes, positions, text heights, and colors from
  a screenshot.
- `scripts/compare.swift`: a side-by-side, a diff, and the share of pixels
  that differ.

Run them with `swift "${CLAUDE_SKILL_DIR}/scripts/measure.swift" ...`.
All coordinates are points (pixels / 2 for a Retina capture).

## 1. Get the screenshots

Ask for screenshots, or take them with the `clone` skill. You need:

- The window only, at 2x, no desktop. Save them in `design/reference/`.
- One screen with the most parts on it (a sidebar, a list, a toolbar),
  plus close-ups of menus, dialogs, and dark mode if they matter.
- The window size: `measure.swift info shot.png`.

Check: `info` prints the window size in points, and every screenshot uses
the same scale.

## 2. List the parts

Look at each screenshot and name every distinct part: window chrome,
sidebar row, section header, primary action, list row, checkbox, date
chip, icon button, divider. Start `design/KIT.md` from the `design-kit`
skill's kit-spec.md with one section per part.

Check: every visible element on the main screenshot belongs to a part.

## 3. Measure

Fill `design/KIT.md` with numbers, not estimates. The recipes and the
traps are in [measuring.md](measuring.md). In short:

| To find | Command |
| --- | --- |
| Sidebar width, panes | `hline shot.png <y in an empty area>` |
| Row positions and pitch | `rows shot.png <x0> <x1> [y0 y1]` |
| Left edges, gaps | `cols shot.png <y0> <y1> [x0 x1]` |
| Selection pill, dividers | `vline` and `hline` through it, `--tolerance 4` |
| Text and icon colors | `ink shot.png x y w h` |
| Surface colors | `palette shot.png x y w h` |
| A close look | `crop shot.png x y w h out.png 4` |

Check: every token and every part size in `design/KIT.md` has a number
from a command.

## 4. Find the font and the icons

- Most apps on the Mac use the system font, even web apps. Start there.
  When the letters differ (a, g, t, digits), name the font and pick it or
  an open alternative with a license that allows bundling.
- Text sizes come from step 6: build, measure the same word in both
  images, scale.
- Icons: note the size, stroke weight, corners, and whether selected rows
  switch to a filled form. Match with SF Symbols at a light weight first;
  draw the ones that do not match as shapes (`design-kit` parts.md, Icons).

Check: `design/KIT.md` names the font, the icon source, and the icon size
and weight.

## 5. Build the kit and one screen

Call the Skill tool with `design-kit` and build the tokens, the parts, the
window chrome, and the gallery from `design/KIT.md`. Then build the main
screenshot's screen from kit parts only, with the same data and the same
window size.

Check: a snapshot of that screen has the same size in pixels as the
reference.

## 6. Compare until it matches

```bash
swift "${CLAUDE_SKILL_DIR}/scripts/compare.swift" design/reference/main.png /tmp/<App>-shots/<page>-light.png /tmp/<App>-compare
swift "${CLAUDE_SKILL_DIR}/scripts/compare.swift" ... /tmp/<App>-compare-sidebar 0 0 220 300
```

Open `side-by-side.png` and `diff.png` with the Read tool. Then measure
the same rows, edges, and words in both images, and fix the tokens, not
the views. Order: window size, text sizes, columns and left edges, row
heights, colors, icons.

Check: under 2% of pixels differ on the whole window, and every row and
left edge is within 1.5 pt of the reference.

## 7. Make it yours

Before the app ships to anyone else, replace what belongs to the other
company: its name, logo, illustrations, and any font or icon it owns.
Keep the structure, the spacing, and the feel. Write the replacements in
`design/KIT.md`.

Done when `design/KIT.md` has a measured number for every token and part,
the kit's gallery shows every part, the reference screen passes step 6,
and step 7 lists what was replaced.
