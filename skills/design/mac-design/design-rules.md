# Design rules with sources

A checklist for reviewing a macOS SwiftUI app. Each rule is testable on a
snapshot or in the code. Sources are listed at the bottom.

## Structure

1. Write the archetype, sidebar pages, command map, and empty states before building. [petekp]
2. Use standard structures first: `NavigationSplitView`, `.toolbar`, `.searchable`, `.inspector`, `Settings`. They adopt Liquid Glass automatically. [WWDC25-323]
3. Global actions in the toolbar, navigation in the sidebar, content in the center. [Kole Jain, HIG]
4. No sidebar when navigation is one level. Give the width to content. [Kole Jain]
5. Sidebar: at most two levels, an SF Symbol per item, hideable, nothing critical at the bottom. [HIG Sidebars]
6. Selection details in a trailing inspector or detail column. [Kole Jain, WWDC25-323]
7. Design the entry points outside the main window: quick-capture panel, menu bar extra, global shortcut, drag and drop. [Kole Jain]
8. Quick-capture panels have no title bar, one input, and buttons labelled with their shortcuts. Escape closes, Return saves. [Kole Jain]

## Glass and materials

9. Glass only on the navigation and control layer. Never on rows, cards, or document content. Exception: a Spotlight-style panel is all control layer, so its results may sit on its glass. [HIG Materials, WWDC25-219]
10. Never glass on glass. Group neighboring custom glass in `GlassEffectContainer`. [WWDC25-323]
11. Remove custom backgrounds, borders, and custom dimming behind toolbars, sidebars, and sheets. macOS dims the parent window behind a sheet itself; keep that. [WWDC25-356, HIG Sheets]
12. Regular glass by default. Clear glass only over rich media, with a 35% dark dimming layer over bright content and none over dark content. Never mix the two. Background areas in the content layer use standard materials (`.regularMaterial`) with vibrant colors, not glass. [HIG Materials]
13. Tint only to carry meaning, and tint the background, not the glyph. [HIG Color]
14. Nested corners are concentric: inner radius equals outer radius minus padding. A part used both nested and alone gets `ConcentricRectangle` (or `.rect(corners: .concentric(minimum:))`) so it never loses its rounding. Mini, small, and medium controls are rounded rectangles; large controls are capsules. Capsules in dense layouts only for a standout action. [WWDC25-356, WWDC26-289]
15. One scroll-edge effect per pane, only where floating UI overlaps content. Keep the automatic style (it already turns more opaque over dense content). Panes side by side get edge effects of the same height. [WWDC25-356, HIG Scroll views]

## Toolbar and menus

16. At most three toolbar groups, borderless monochrome SF Symbols with `.help`, at most one prominent action (Done, Send) on the trailing side. A text button next to symbol buttons gets a fixed `ToolbarSpacer`. Placement per column: toolbars.md. [HIG Toolbars]
17. Every toolbar item and feature has a menu bar command. Standard menu order. Items stay visible and get disabled when they do not apply. [HIG Menu bar]
18. Every frequent command has a shortcut. Standard shortcuts are never repurposed. [HIG Keyboards]
19. Window titles name the content, stay under 15 characters, and are not the app name. [HIG Toolbars]
20. Menu icons are few and on purpose: only on key actions, all or none within a group, and none when no symbol clearly fits. In a group of related items (Copy, Copy Link, Copy as Markdown) only the first gets a symbol. In SwiftUI menu bar commands an item shows its icon only with `.labelStyle(.titleAndIcon)`. [HIG Menus, WWDC26-269]

## Keyboard and feedback

21. Every shortcut gives visible feedback in the same frame. [Kole Jain]
22. Return is the default action, Escape cancels, Delete removes, Space previews, arrows move. [HIG Keyboards, ehmo]
23. Logical focus order with `@FocusState`. New items get focus. [kageroumado]
24. Shortcuts are taught: menus, `.help` tooltips (they describe the action and end with the shortcut), a shortcut list in Settings or Help, and a short first-run hint for the one shortcut that matters most. [Kole Jain]
25. Optimistic UI with Undo, not spinners and confirmation dialogs. [Kole Jain]

## Content, type, and color

26. The UI is a container for content. Remove decoration that does not help the content. [Kole Jain]
27. Progressive disclosure: empty states invite the first action, filters and metadata appear when there is content. [Kole Jain]
28. Semantic colors only. One accent. Status color always paired with an icon or a word. Light and dark follow the Mac by default. Apple advises against an app-only appearance setting; add one only when the app's owner asks for it, with System as the default. [HIG Color]
29. macOS text styles, no iOS sizes. Minimum 10 pt. [HIG Typography]

    | Style | Size / leading | Weight |
    |---|---|---|
    | Large Title | 26 / 32 | Regular |
    | Title 1, 2, 3 | 22 / 26, 17 / 22, 15 / 20 | Regular |
    | Headline | 13 / 16 | Bold (same size as Body) |
    | Body | 13 / 16 | Regular |
    | Callout, Subheadline | 12 / 15, 11 / 14 | Regular |
    | Footnote, Caption 1 | 10 / 13 | Regular |
    | Caption 2 | 10 / 13 | Medium |

    No Ultralight, Thin, or Light weights in UI text. Text of three lines or more never gets tight leading.
30. Dark mode is its own palette with more tonal separation. Check both modes. [Kole Jain]
31. `Label` for icon and text. SF Symbols for icons. [Optical Flow design system]
32. Spacing: 20 pt window margins, 8 pt between related controls, 20 pt between groups. [ehmo]

## Interaction

33. `.contextMenu` on every actionable item. Hover states on custom controls. [kageroumado]
34. No 44 pt touch targets. Control heights come from `.controlSize`. Mac controls default to 28 x 28 pt, with a 20 x 20 pt minimum hit area. Leave about 12 pt around bezeled controls and about 24 pt around borderless ones, or give a borderless icon button a 28 pt hit area. [WWDC25-310, HIG Accessibility]
35. Drag in and out with `Transferable`, plus `ShareLink`. [Kole Jain]
36. Search in the trailing toolbar, live as you type, scope in the placeholder, result count visible. [HIG Search, Kole Jain]
37. Settings opens with Command-comma from the app menu. Few options. [HIG Settings]
38. Windows resize with sensible minimums and remember their frame. [HIG Windows]
39. Reduce Motion, Reduce Transparency, and VoiceOver labels on icon-only buttons. [WWDC25-219]
40. Customize on purpose. Stock UI is the baseline. Restrained custom chrome is fine when it makes the app better at its one job. [Brent Simmons 2026]

## Contrast and safety

41. Accent-colored text uses a light shade in dark mode and a deep shade in light mode, from one token. Text and symbols on an accent fill use the on-accent color, never a fixed white. [field test]
42. Hover and press states never lower contrast. Text over user content (screenshots, video) sits on a dark scrim or capsule. [field test]
43. Every one-click destructive action, in lists and in Settings, offers Undo in place. [field test]

## Toolbar and panels

44. The toolbar follows the columns: the sidebar button over the sidebar, actions and search over the list, the inspector button at the trailing edge over the inspector. No toolbar item crosses a column edge, and every panel can fold away with a button and a shortcut. Recipe: patterns.md, "Toolbar that follows the columns". [field test]
45. Lists support multi-selection, and actions apply to every selected row. After an action removes the selected row, selection moves to the next row. [review]
46. Never ship always-enabled menu items that do nothing; fix the focused-value plumbing instead. Taking over Command-S or Command-O is allowed only in apps without documents, and is noted in the command map. [review]

## Consistency

47. Show each status once per row (one overdue chip, not a date chip and a "due" chip). [review]
48. Date fields share one control style and the list's date format. Values on the trailing edge of a form line up. [review]
49. What a user drags out of the app is meaningful (title text or a link), never an internal id. [review]
50. An on-accent token that is a fixed white fails rule 41 on light accents. Check 4.5:1 contrast in both modes as the floor; aim for 7:1 for small custom text. [review, HIG Dark Mode]

## Windows, focus, and scrolling

51. No control is focused when a window or sheet opens: no focus ring, no cursor, no selected text (`.noInitialFocus()`). Only a window whose one job is typing focuses its field. [field test]
52. Sheets, popovers, and Settings tabs size to their content. A scroll bar appears only when there is more to scroll. [field test]
53. System scroll bars, never restyled. They follow the "Show scroll bars" setting. [HIG Scroll views]
54. Settings: tabs by topic, one grouped Form per tab, 520 pt wide, applied at once, labels as statements. Recipe: settings.md. [HIG Settings, field test]

## Principles and hierarchy

55. Review every screen against Apple's eight principles: purpose, agency, responsibility, familiarity, flexibility, simplicity, craft, delight. Each feature costs people time, attention, and trust; cut what does not earn it. [HIG Design principles, WWDC26-250]
56. Every screen answers three questions at a glance: Where am I? What can I do? Where can I go? Squint at the snapshot: the most important thing is still the most visible. [WWDC25-359]
57. Simple is not minimal. Hiding the main actions in one More menu looks clean but is harder to use. [WWDC26-250]
58. Delight is the sum of the other seven, aimed at one feeling picked in the brief (calm, confident, quick). Never confetti added at the end. [WWDC26-250]
59. Navigation items are for navigation. No "New..." or other action rows in the sidebar list; actions go in the toolbar and menus. [WWDC25-359]
60. A list for few items or long text, a grid for many images with little text. Group big collections by time (Recent), progress (In Progress, Drafts), or relation (Related). [WWDC25-359]

## Glass, shape, and color (macOS 27)

61. Interactive glass (the bounce on click) only on controls or a group of controls, and sparingly. Apply glass to the control itself, never to the views inside it. [WWDC26-289, WWDC25-356]
62. Custom sidebar and toolbar parts dim when the window is inactive, like the system ones. Read `@Environment(\.appearsActive)`. Not for HUDs and non-activating panels: they never make the app active, so they would stay dim. [WWDC26-269, WWDC25-219]
63. At rest (first launch, top of the scroll) no content sits under glass. Extend rich backgrounds under the sidebar and inspector with `.backgroundExtensionEffect()`, and keep text and controls above it. [WWDC25-219, WWDC25-356, HIG Layout]
64. No controls or critical information at the bottom edge of a window. A bottom status bar holds only small facts about the window (a count, free space). [HIG Layout, HIG Windows]
65. Use the standard symbol for a standard action: Copy `document.on.document`, Paste `document.on.clipboard`, Duplicate `plus.square.on.square`, Rename `pencil`, Move `folder`, Filter `line.3.horizontal.decrease`, Share `square.and.arrow.up`, Delete `trash`, More `ellipsis`, Compose `square.and.pencil`, Archive `archivebox`. The trash icon means delete and nothing else. Where no symbol is unambiguous, use a text label. Match the symbol weight to the text next to it. [HIG Icons, WWDC26-250, WWDC25-356]
66. Never restyle or redefine semantic colors (no `separator` as text, no label color as a background), and never copy their values: they change per release. [HIG Color]

## Menus and keyboard

67. The menu bar follows Apple's order and labels. Window menu even with one window, Show/Hide labels that follow the state, Undo that names the action, "New <Noun>". Full list: [menus.md](menus.md). [HIG The menu bar]
68. Context menus hide items that do not apply (Cut, Copy, and Paste may stay dimmed), show no shortcuts, keep about three groups with the most frequent first, and go at most one submenu deep. Every context menu command also lives in the menu bar. Exception: a menu bar app's status item menu is its menu bar, so it shows the person's global shortcuts. [HIG Context menus]
69. Standard keys: Option-Command-F jumps to the search field, Command-Period cancels an operation or an alert, Escape closes. Never add a modifier to an existing shortcut for an unrelated command (Shift-Command-Z is only Redo). Avoid Option or Shift with punctuation keys; they move on other keyboard layouts. [HIG Keyboards]
70. A push button whose action opens another window or view ends in an ellipsis ("Export..."). At most one or two prominent buttons per view. Switches, checkboxes, and radio buttons never go in a toolbar. [HIG Buttons, HIG Toggles]

## Search, tables, and drag

71. Where search sits tells people what it searches: the trailing toolbar searches the whole window, the top of the sidebar filters the sidebar, and a Search sidebar item gives a big multi-section app room for results. One search location per app. [HIG Searching, WWDC26-292]
72. Search starts broad and narrows: a scope bar (`.searchScopes`, "All" vs the current place), suggestions while typing (`.searchSuggestions`, a few), recent searches people can remove one by one or clear, and tokens only next to visible filters. No results: `ContentUnavailableView.search(text:)`, so the query and its typos show. [WWDC26-292, HIG Search fields]
73. Multicolumn tables: click a header to sort, click again to reverse; columns resize; rows alternate in color; headers are nouns in title case; names that differ at the end truncate in the middle. Outlines save which rows are open across launches, and Option-click opens a row and everything under it. Recipe: patterns.md, "Sortable table". [HIG Lists and tables, HIG Outline views]
74. Drag and drop works everywhere and has a menu alternative. A drag to Finder makes a real file the app can open again. A drag of several items shows a count badge. Option at drop time copies. Dropped content stays selected, and a drop can be undone. [HIG Drag and drop]

## Windows, panels, and launch

75. Relaunch restores windows (frame, minimized, full screen), the selection, and the scroll position (`@SceneStorage`). Save UI state only, never data. Quit never asks unless typed work would be lost. [HIG Launching, WWDC26-289]
76. No splash screen and no onboarding tour. Teach with a contextual tip (TipKit) for a feature of three steps or fewer, at most about one tip a day. A skipped tutorial never shows again and stays reachable from Help. [HIG Onboarding, WWDC26-250]
77. Sidebar: never hidden by default, folds away on its own when the window gets narrow, and its rows follow the system sidebar icon size (no fixed row height). Big lists get disclosure groups; let people reorder or hide items when the list is long. [HIG Sidebars]
78. "Open in New Window" in the context menu or File menu. Do not open new windows by default. Say "window" in the UI, never "scene". [HIG Windows]
79. A time-limited view (a toast that hides itself) is never the only way to act. An Undo toast also has Edit > Undo, Command-Z. An error never lives only in a toast, and every toast is announced to VoiceOver. A menu bar app (LSUIElement) has Edit > Undo only while it switches to `.regular` with a window open. [HIG Accessibility]
80. Progress: determinate when the length is known, and switch from a spinner to a bar never mid-task. The text says what is happening ("Importing 12 photos"), not "Loading". Offer Cancel when it is safe. [HIG Progress indicators]

## Sources

- Kole Jain, "Everything you need to Design macOS Apps EXACTLY like Apple (beginner friendly)", YouTube, December 2025: https://www.youtube.com/watch?v=Vy0KKvZJRH8
- Apple Human Interface Guidelines, Designing for macOS: https://developer.apple.com/design/human-interface-guidelines/designing-for-macos
- HIG Materials, Color, Typography, Sidebars, Toolbars, Menus, Context menus, Scroll views, Sheets, Search fields, Searching, Settings, The menu bar, Keyboards, Icons, Buttons, Toggles, Layout, Windows, Lists and tables, Outline views, Drag and drop, Launching, Onboarding, Accessibility, Progress indicators: https://developer.apple.com/design/human-interface-guidelines
- HIG Design principles (June 2026): https://developer.apple.com/design/human-interface-guidelines/design-principles
- WWDC25-219 Meet Liquid Glass: https://developer.apple.com/videos/play/wwdc2025/219/
- WWDC25-356 Get to know the new design system: https://developer.apple.com/videos/play/wwdc2025/356/
- WWDC25-323 Build a SwiftUI app with the new design: https://developer.apple.com/videos/play/wwdc2025/323/
- WWDC25-310 Build an AppKit app with the new design: https://developer.apple.com/videos/play/wwdc2025/310/
- WWDC26-269 What's new in SwiftUI: https://developer.apple.com/videos/play/wwdc2026/269/
- WWDC26-250 Principles of great design: https://developer.apple.com/videos/play/wwdc2026/250/
- WWDC26-292 Design intuitive search experiences: https://developer.apple.com/videos/play/wwdc2026/292/
- WWDC26-289 Modernize your AppKit app: https://developer.apple.com/videos/play/wwdc2026/289/
- WWDC25-359 Design foundations from idea to interface: https://developer.apple.com/videos/play/wwdc2025/359/
- Brent Simmons, inessential.com, September 2026: https://inessential.com/2026/09/22/that-about-wraps-it-up-for.html
- petekp/agent-skills `macos-app-design`, kageroumado/swiftui-macos-skill, ehmo/platform-design-skills (GitHub)
- Optical Flow and Pulse design systems (Dave Ebbelaar's own apps)
