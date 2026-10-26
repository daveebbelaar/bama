---
name: mac-design
description: Design rules that make a SwiftUI app look and feel like a native Mac app on macOS 26 and later, from Apple's eight design principles to Liquid Glass, layout, toolbars, menus, search, keyboard, type, color, and dark mode. Use when building or reviewing any window, sidebar, toolbar, menu, panel, or settings screen, or when the user asks for a more native, Apple-like, or better designed app.
---

# Mac design

Apple already designed your app. Pick the right system parts, arrange them,
and stay out of their way. Use the system first. Add custom design only
where the system has nothing.

- The full checklist with sources: [design-rules.md](design-rules.md).
  Use it for reviews.
- Copyable SwiftUI code: [patterns.md](patterns.md).
- The Settings window: [settings.md](settings.md).
- Toolbars: which item goes where, per column: [toolbars.md](toolbars.md).
- The menu bar, context menus, and the Dock menu: [menus.md](menus.md).
- Apple's current text on one topic, when a rule here is not enough:
  `"${CLAUDE_SKILL_DIR}/scripts/hig.sh" <topic>` (for example `toolbars`,
  `sheets`). It prints the HIG page as plain text.
- App-wide tokens (colors, radii, motion): call the Skill tool with
  `design-system`.
- How a feature works and what it says (names, flow, modals, errors,
  accessibility): call the Skill tool with `ux-design`.
- Spacing, alignment, and the checks that catch misalignment: call the
  Skill tool with `layout-grid`.
- Parts of your own instead of Apple's: call the Skill tool with
  `design-kit`, or `design-from-app` to match an app the user names.

## Apple's eight principles

Use them as the review lens for every screen (HIG Design principles, 2026):

1. **Purpose**: each feature costs people time, attention, and trust. Cut what does not earn it.
2. **Agency**: people choose their path. Undo forgives mistakes. No forced tours.
3. **Responsibility**: ask for permissions at first use, keep data private, guard AI output.
4. **Familiarity**: things that look the same work the same. Standard parts, standard symbols.
5. **Flexibility**: keyboard, pointer, and resizing all work. People can customize what they use daily.
6. **Simplicity**: simple is not minimal. Hierarchy comes from order, space, and contrast.
7. **Craft**: instant response, smooth scrolling, aligned edges, layouts that survive resizing.
8. **Delight**: the sum of the other seven, aimed at one feeling. Never decoration added at the end.

Every screen answers: Where am I? What can I do? Where can I go?

## Before you write views

Write these four under `## Design plan` in `docs/BRIEF.md`, or in
`docs/DESIGN.md` when the brief would pass one page:

1. **Archetype**: sidebar window, single-window document, menu bar extra, or
   quick-capture panel. Most personal apps are a sidebar window plus one
   quick-capture entry point. A menu bar utility is "menu bar extra +
   panels + Settings window": the toolbar and sidebar rules then apply to
   the Settings window only.
2. **Information architecture**: sidebar pages, at most two levels.
3. **Command map**: every action, its menu, its shortcut.
4. **Empty states**: what each page shows before there is data.
5. **Feeling**: the one feeling the app aims for (calm, quick, confident).
   Motion, words, and color all reinforce it.

## Entry points first

A Mac app is used through its small entry points: a global shortcut, the
menu bar, a quick panel, drag and drop, the Share menu. Design those first.
A to-do app lives in its quick-add panel.

- Quick capture: one floating panel, one input, opened by a global shortcut,
  closed by Escape or Return.
- **Optimistic UI**: on Return, close and show the result at once. Save in the
  background. Offer Undo, not a spinner.

## Layout

- `NavigationSplitView`: sidebar, content, detail. Global actions in the
  toolbar. No sidebar when navigation is one level.
- Selection details in `.inspector` or the detail column.
- The UI frames the user's content. Ask what the least UI is that lets it
  stand out.
- Progressive disclosure: an empty page shows one `ContentUnavailableView`
  with the first action. Filters appear once there is content.
- Keep the top 50 pt free for dragging the window.
- Spacing from `Space`, on a 4 pt grid: 20 pt window margins, 8 pt
  between related controls, 20 pt between groups. `.controlSize` for dense
  areas, never hard-coded heights.

## Liquid Glass

- Glass is for the navigation and control layer: toolbars, sidebars,
  floating buttons, popovers. Content (rows, cards, documents) gets none.
- Never glass on glass. Group neighboring custom glass in
  `GlassEffectContainer`.
- Standard components get glass on their own. Delete custom backgrounds
  behind bars and sheets.
- `.glassEffect()` only for a custom floating control. Tint only to carry
  meaning. Interactive glass (the bounce on click) only on controls, and
  sparingly.
- Custom chrome dims with the window: read `@Environment(\.appearsActive)`
  (patterns.md, "Custom chrome that follows the window").

## Toolbars and menus

- Each toolbar item sits over the column it acts on: nothing of your own
  over the sidebar, New and Sort over the list, actions on the selection
  over the detail, the inspector toggle over the inspector. Full rules and
  a checked example: [toolbars.md](toolbars.md).
- At most three toolbar groups, split with `ToolbarSpacer`. Monochrome SF
  Symbols, each with a title and `.help`. At most one prominent action,
  only for a completing action like Done or Send. Most main windows have
  none.
- `SidebarCommands()`, `ToolbarCommands()`, and (with an inspector)
  `InspectorCommands()` in `.commands`, so the View menu can show and hide
  each part.
- Every toolbar button and feature also lives in the menu bar with a
  shortcut (`.commands`, `CommandGroup`, `CommandMenu`). Apple's menu order
  and labels: [menus.md](menus.md).
- Menu icons only on key actions, all or none in a group.
- Standard shortcuts keep their meaning: Command-C, V, X, Z, W, Q, N, comma.
- Disable menu items that do not apply; keep them visible. SwiftUI menus
  only update when the selection is passed into the commands from the App
  (`swift-swiftui`, "Menu commands").
- Window titles name the content ("Today"), not the app.

## Windows open calm

- Nothing is focused when a window or sheet opens: no focus ring, no
  blinking cursor, no selected text. Put `.noInitialFocus()` on every
  window and sheet. The one exception is a window whose only job is
  typing, like a search or quick-add panel: it focuses its field.
- A sidebar list may hold focus at launch. It shows as a selected row, not
  a ring, and the arrow keys work at once.
- A sheet, popover, or Settings tab grows to fit its content
  (`.fitsContent()`). It scrolls only when the content is taller than
  the screen allows, about 640 pt.
- System scroll bars. The "Show scroll bars" setting decides when they
  show. Do not restyle them.

## Keyboard first

- Every frequent action has a shortcut, and every shortcut shows feedback
  in the same frame.
- Return is the default action, Escape cancels, Delete removes, Space
  previews, arrows move.
- New items get focus (`@FocusState`) so the user can type at once.
- Teach shortcuts in menus, `.help` tooltips, and a list in Settings.

## Color, type, dark mode

- Text is `.primary`, `.secondary`, `.tertiary`. System backgrounds. No
  fixed white, black, or gray in chrome.
- One accent color. Status color always comes with an icon or a word.
- macOS text styles: body 13 pt, nothing under 10 pt. Never iOS sizes.
  Headline is bold 13 pt, the same size as Body. Full table:
  design-rules.md rule 29.
- Dark mode is its own palette with more distance between tones. Check
  both in every snapshot.
- Accent-colored text uses a deep shade in light mode and a light shade in
  dark mode. Text and symbols on an accent fill use the theme's on-accent
  color, never a fixed white (white fails on yellow and green accents).
- Hover and press never lower contrast. Text over user content
  (screenshots, video) sits on a dark scrim or capsule.
- `Label` for icon and text, SF Symbols for every icon.

## Interaction

- `.contextMenu` on everything a user can act on. It hides items that do
  not apply and shows no shortcuts. Hover states on custom controls. Mac
  controls are 22 to 28 pt tall, not 44.
- Drag and drop in and out with `Transferable`. A drag to Finder makes a
  real file. `ShareLink` where it fits.
- Relaunch brings back the windows, the selection, and the scroll position
  (`@SceneStorage`). Quit never asks unless typed work would be lost.
- Undo for every destructive or bulk action, in Settings too. A one-click
  trash button needs Undo in place.
- `Settings` scene, opened with Command-comma: tabs, one grouped Form per
  tab, sized to its content. Structure and rows: [settings.md](settings.md).
- Respect Reduce Motion and Reduce Transparency. Label icon-only buttons.

## When to customize

Custom chrome is fine when it makes the app clearly better at its one job,
like a quick-add field or a calendar grid. Write why in a code comment, and
match the system: concentric radii, system fonts, system spacing.

## Review set

Snapshot every surface in light and dark: each page, the menu bar menu,
each panel and overlay (launcher, toasts, cards), editors, and each
Settings tab (snapshot mode does pages and Settings tabs). Look for focus
rings, selected text, scroll bars with nothing to scroll, and empty bands
under short content. Capture each window as the key window: a snapshot of
an inactive window (gray traffic lights, dim toggles) or with flattened
glass does not count as reviewed. Views that pause while covered show a
placeholder; that one is expected.

Done when every rule in [design-rules.md](design-rules.md) holds on the
light and dark snapshots of every surface, or has a comment saying why not.
