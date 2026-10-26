# Specs

Build plans for small Mac apps you can build today with BAMA. Each spec is
one app. Give it to your agent and it builds the app for you.

I took these apart from Onyx, my own menu bar app that replaces Magnet,
AltTab, Alfred, CleanShot, and a few more. Onyx does everything in one app.
Each spec here is one part of it, cut down to an app you can build in an
afternoon of agent time.

## Build one

Install BAMA, copy a spec into an empty folder, open your agent there, and
tell it:

```text
Build the app in window-snapper.md with BAMA.
```

A link works too:
`https://github.com/daveebbelaar/bama/blob/main/specs/window-snapper.md`.

The agent copies the spec's **Brief** into `docs/BRIEF.md` and its
**Stories** into `docs/STORIES.md`, then runs `new-mac-app` and
`improve-loop`. Change the name, the shortcuts, or the scope first if you
want. A spec is a starting point, not a contract.

## The specs

| Spec | What it does | Replaces |
| --- | --- | --- |
| [window-snapper.md](window-snapper.md) | Snap the front window to halves, thirds, or full screen with a shortcut | Magnet, Rectangle |
| [window-switcher.md](window-switcher.md) | Hold Option, press Tab, and pick any window from live previews | AltTab |
| [launcher.md](launcher.md) | Open apps and files from one search box | Alfred, Spotlight |
| [clipboard-history.md](clipboard-history.md) | Search and paste anything you copied | Paste, Maccy |
| [text-snippets.md](text-snippets.md) | Type a short keyword and get the full text | TextExpander |
| [color-picker.md](color-picker.md) | Pick a color anywhere on screen and save it | Sip, ColorSlurp |
| [screenshots.md](screenshots.md) | Capture the screen, an area, or a window, then mark it up | CleanShot |
| [screen-recorder.md](screen-recorder.md) | Record the screen to MP4 with mic, system audio, and a webcam bubble | CleanShot (video), Loom |
| [menu-bar-stats.md](menu-bar-stats.md) | CPU, memory, network, disk, and battery in the menu bar | Stats, iStat Menus |
| [toolbox.md](toolbox.md) | Keep the Mac awake, show hidden files, switch audio devices | Amphetamine, TinkerTool |
| [creator-tools.md](creator-tools.md) | Keystroke overlay, cursor highlight, teleprompter, chapter markers | KeyCastr, Presentify |
| [dev-toolkit.md](dev-toolkit.md) | Open projects, transform text (JSON, Base64, JWT), free a port | DevUtils, Raycast scripts |

Start with the window snapper. It's the smallest, and it teaches the two
things most of these apps need: a global shortcut and the Accessibility
permission.

## What a spec holds

Every spec has the same parts, in this order:

1. **Brief**: the `app-brief` format, filled in. The agent skips the
   interview.
2. **How it works**: the macOS APIs, the permission each one needs, and the
   main types.
3. **Stories**: the `user-stories` format, in milestones. Every acceptance
   line says how to check it.
4. **Gotchas**: what went wrong in Onyx, so your agent gets it right the
   first time.
5. **Done when**: the check that the app is finished.

## Write your own

Copy a spec that's close to your idea and change it. Keep the five parts.
Keep version one small: one shape (menu bar item, panel, or window), two to
five jobs, and 5 to 10 stories in the first milestone.
