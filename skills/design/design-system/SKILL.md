---
name: design-system
description: Accent color and design system for a macOS app, from the app's accent and the accent picker in Settings to Swift tokens in code plus a design/DESIGN-SYSTEM.md that says which token to use when. Use when the user wants a brand or accent color, wants people to pick a color, when an app has more than a few screens, when screens drift apart or animations feel inconsistent, or when the user asks for themes, a style guide, or design tokens.
---

# Design system

A design system is a short list of **tokens** in code and one page that
says which token to use when. Every screen uses tokens, never raw values.
Then a change in one place changes the whole app, and an agent can review a
screen against one page.

Start from `mac-design`. Tokens cover only what the system does not:
the accent, custom surfaces, radii, motion, overlays, and custom controls.

The app keeps Apple's look. Only the accent color changes. For parts of
your own (a custom sidebar, buttons, icons), call the Skill tool with
`design-kit`. To copy the look of an app the user names, call it with
`design-from-app`.

The template already has the base in `Sources/<App>/UI/`:

- `Theme.swift`: the accent colors (`Theme.all`), the saved choice
  (`ThemeStore`), the tokens `Palette.accent`, `Palette.accentText`,
  `Palette.onAccent`, and `.themed()`, which tints every scene.
- `AppearanceSettings.swift`: Settings > Appearance, where people pick the
  accent. Light and dark mode follow the Mac. Apple advises against an
  app-specific mode setting; add a System/Light/Dark picker only when the
  owner asks for one, with System as the default. [HIG Dark Mode]
- `Grid.swift`: spacing (see the `layout-grid` skill).

## 1. Pick the accent

Read `## Look` in `docs/BRIEF.md`. With no color named, keep `system`: it
follows the accent color the person set for their Mac.

For a brand color, set `ThemeStore.brand` to a `Theme` with three shades:
`light` (accent text in dark mode), `base` (fills and tint), and `deep`
(accent text in light mode). Set `darkText: true` when white text on
`base` is hard to read (yellow, mint, cyan). Keep
`ThemeStore.defaultID = "system"`. The brand then shows only while the
Mac's accent is Multicolor, as in Apple's apps. Any other accent the person
chose for their Mac wins, and so do sidebar icons, which people expect in
their own accent. [HIG Color, Sidebars]

Use brand color sparingly: the app icon, an empty state, one hero element
in the content. Keep it off most controls. [HIG Branding]

To compare colors, take snapshots with `APP_ACCENT=<id>` for two or three
of them and show the user the PNGs. Keep the picker in Settings, so people
can still choose their own color.

Check: `ThemeStore.defaultID` is "system", and the snapshots show the
accent on buttons, toggles, and selection in light and dark mode.

## 2. Collect

New app with no views yet? Skip this step: write the token files with the
defaults below before the first view.

Existing app: read every view. List each raw value you find: hex colors, opacities,
corner radii, paddings, frame widths, animation durations and curves,
custom button styles. Group them. Most apps have 3 to 5 of each where 1 or
2 are meant.

## 3. Write the tokens

Accent values live in `Theme.swift`. The rest get one file per group in
`Sources/<App>/UI/`. Add each token when the app first needs it:

| File | Holds |
| --- | --- |
| `Theme.swift` | the accents, `ThemeStore`, `.themed()`, and `Palette`: `accent`, `onAccent` (text and symbols on accent fills), `accentText` (accent-colored text: deep shade in light mode, light shade in dark mode) |
| `Grid.swift` | the spacing scale (`Space`) and the layout probes |
| `Surfaces.swift` | `surface`, `surfaceHover`, `hairline`, one warning color |
| `Radius.swift` | `xs 6` chips and key caps, `sm 8` controls, `row 10` row hover fills, `md 12` cards, `lg 18` widgets, `xl 26` floating glass |
| `Layout.swift` | `contentWidth`, fixed column and sheet widths |
| `Motion.swift` | `hover`, `quick` (presses, small flips), `ui`, `select` (selection moving through a live list), `appear`, `dismiss`, `glide`, `numberRoll`, `listChange`, loops (`pulse`) that stop under Reduce Motion |
| `Components.swift` | more control styles: `HoverButtonStyle`, `.hoverFill`, toggles, chips |
| `Overlay.swift` | one panel builder, one entrance, one exit |

Surfaces adapt to light and dark. Views read the accent through `.tint` or
`Palette`, so a new choice in Settings redraws the whole app.

## 4. Write design/DESIGN-SYSTEM.md

One section per file above. Each section says which token to use when, and
the rules that go with it. Keep it under 100 lines. Rules that transfer to
most apps:

- Never hard-code a hex accent. Use `.tint` or `Palette.accent`.
- Every custom color has four values: light, dark, and a stronger one of
  each for Increase Contrast (`Color(light:dark:highContrastLight:highContrastDark:)`
  in `Theme.swift`). [HIG Color]
- Never redefine or copy a semantic color (`.separator` as text, a label
  color as a fill). Their values change per release.
- A custom surface in its neutral state is a little translucent, so it
  picks up the desktop tint like system surfaces. A colored state is
  opaque.
- A custom font only for headings. Body and captions stay in the system
  font, and every custom font has a bold weight for the Bold Text setting.
- Accent-colored text uses `Palette.accentText`. Text on an accent fill
  uses `Palette.onAccent`, never a fixed white.
- Style controls with `ButtonStyle` and `ToggleStyle`. Never rebuild a
  control from shapes: it loses the keyboard, focus, and VoiceOver.
- Inner corners are concentric: inner radius = outer radius - inset.
- Every animation goes through `Motion`, so a per-feature "Full, Fast,
  Off" setting and Reduce Motion apply everywhere.
- Search results and switchers do not animate. Speed wins.
- Hover never moves a selection. Only a click or a key does.
- Units ("KB/s", "%") never animate. Only the number does
  (`.contentTransition(.numericText())`).
- Never animate a view's first layout. Overlays wait one frame, then
  animate opacity, scale, and a few points of travel.
- Leave room around glass for its shadow (about 3 times the shadow radius).
- One primary button per page or card.

## 5. Migrate

Replace raw values screen by screen, one commit per screen. After each,
build and snapshot (`build-and-verify` skill). The screen looks the same or
better, never worse.

## 6. Point agents at it

Add one line to the app's `CLAUDE.md` (create the file if it is missing):
"Design rules: `design/DESIGN-SYSTEM.md`. Use its tokens; never raw colors,
radii, or durations."

Done when this finds no hits outside the token files:

```bash
grep -rnE 'cornerRadius: [0-9]{1,2}\b|duration: [0-9]|\.spring\(response|\.snappy\b|\.easeInOut|\.easeOut\(|Color\(hex:|Color\(red:' Sources/ \
  | grep -v 'Path(roundedRect'
```

(hex strings in data and comments are fine), and DESIGN-SYSTEM.md has a section
for every token file.
