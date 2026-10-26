---
name: clone
description: Walk through any existing app (native Mac app with computer use, web app with a browser), screenshot every screen, menu, and dialog, write a screen index, and turn it into user stories. Use when the user wants to clone, rebuild, replace, or copy the design of an app, or says "screenshot every screen".
argument-hint: "<app name as shown in the menu bar, or a URL>"
---

# Clone

Output: a folder of screenshots, one index that describes everything the
app shows, and a backlog built from it.

```text
docs/screens/
  INDEX.md
  01-inbox.png
  02-today.png
  ...
docs/STORIES.md      (from the user-stories skill)
```

## 1. Pick the tool

| The app is | Use |
| --- | --- |
| A native Mac app, or Electron | Computer use (`mcp__computer-use__*`) |
| A web app | A browser tool: the built-in browser, Claude in Chrome, or Playwright |

Computer use needs a Pro or Max plan, and Accessibility and Screen
Recording permissions. Claude desktop: Settings > This computer > Enable
computer use. Claude Code CLI: `/mcp` > `computer-use` > Enable. Ask for
access to the reference app only. Browsers are view-only and terminals are
click-only for computer use.

## 2. Agree on privacy

Tell the user you will see everything in the app. Suggest a demo account or
sample data. Look, do not touch: open screens and menus, press Escape to
close dialogs. Type, create, change, or delete only when the user says so.

## 3. Save real files

Computer use screenshots come to you downscaled, not to disk. Save each
screen at full resolution with the script in this skill:

```bash
"${CLAUDE_SKILL_DIR}/scripts/window-shot.sh" "<App Name>" docs/screens/01-inbox.png
```

It captures the app's largest window. For menus and popovers outside the
window, use `screencapture -x docs/screens/<name>.png` and note it in the
index. In a browser, use the tool's screenshot with a file path.

## 4. Walk the app in this order

1. Main window, default page.
2. Every sidebar item, top to bottom. Expand collapsed groups.
3. Every view mode (list, board, calendar), sort menu, filter menu.
4. One item opened in detail: panel, fields, sub-items.
5. Creation flows: add button, quick-add panel (global shortcut), inline
   editor. Empty and half filled in, then Escape.
6. Context menus on an item, a section, a sidebar entry.
7. The menu bar: every menu once. Record every item and shortcut.
8. Settings: every pane.
9. Empty states.
10. Dark mode: the two or three main pages again.

Name files `NN-page-or-state.png` in capture order. The walk is
exhaustive when every sidebar item, menu, and settings pane has a file.

## Lessons from real walkthroughs

- Many "Mac apps" are Electron. Their menu bars are nearly empty, and the
  actions hide in hover toolbars, right-click menus, and command palettes.
  Hover rows and search the palettes (typing in a palette search is safe;
  do not press Return).
- Background clicks (`app_*` tools) fail on some Electron screens. Then ask
  for full-screen control, and tell the user to keep off the mouse.
- Preview fields test behavior without saving. A "Type a date" box in a
  to-do app shows how it parses a phrase before anything is stored. 30 phrases there
  corrected 3 answers from the docs.
- Note any change in the user's data during the walk, even if you are not
  sure you caused it, and tell them.

## 5. Write docs/screens/INDEX.md

One section per screenshot:

```markdown
## 03-upcoming.png

Page: Upcoming. Reached from: sidebar > Upcoming.
Layout: header with month picker and "Today" button; week strip; tasks
grouped by day, each day a section with a heading and an add button.
Elements: task row (checkbox, title, description line, date, project tag,
priority flag color).
Actions: complete, open, drag to another day, add to a day.
Shortcuts seen: none.
```

End with three lists:

- **Navigation map**: sidebar items and where each leads.
- **Command map**: every menu item and keyboard shortcut.
- **Data model guess**: the nouns and fields you saw.

Describe structure and behavior. Take no text, logo, or icon from the app:
rebuilding for personal use is fine, copying a brand is not. Keep the PNGs
out of public repos (add `docs/screens/*.png` to `.gitignore`).

## 6. Turn it into stories

Call the Skill tool with `user-stories`. Every screen in the index ends up
linked from at least one story, or listed under `## Dropped`.

Done when INDEX.md has a section per PNG, the three maps exist, and
`docs/STORIES.md` covers every screen.
