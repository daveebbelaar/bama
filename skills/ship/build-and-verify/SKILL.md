---
name: build-and-verify
description: Build a SwiftUI macOS app from the command line, install it, and check light and dark window snapshots of every page before calling a change done. Use after any UI code change, when a build fails, or when the user asks to run, screenshot, or check the app.
allowed-tools: Bash(./build.sh*) Bash(swift *) Bash(tools/*) Bash(*/Contents/MacOS/*) Bash(open *) Read
---

# Build and verify

A change is done when five things are true:

1. `./build.sh` finishes with no errors.
2. You looked at the light and dark snapshots of every page you touched.
3. The snapshots match what the user story or reference screenshot asks for.
4. The grid checks pass (`layout-grid` skill).
5. Toolbar changes have a passing visible hover result from the installed
   build, including relevant toolbar state changes (step 5).

App not made from the `new-mac-app` template (Xcode, XcodeGen, a menu bar
utility, Swift 5)? Map the commands below with
[existing-app.md](existing-app.md) first.

Do not report a UI change as done from the code alone. SwiftUI code that
compiles can still render an empty sidebar, clipped text, or unreadable dark
mode.

## 1. Build

```bash
./build.sh            # release build, installs ~/Applications/<AppName>.app
./build.sh --debug    # faster build while iterating
./build.sh --open     # also restarts the app so the user sees the new build
```

Read the errors, fix them, and build again. Fix the first error first: later
errors often come from it. If a new file is "not in scope" right after you
created it, run `swift package clean --scratch-path ~/Library/Developer/<AppName>/build`.

## 2. Snapshot

Snapshots run in the background. `screencapture -x -o -l <window>` captures
a window that is not key and is covered by other windows, so the app runs
as an accessory app and hands focus straight back (about 0.1 s at launch).
The user keeps working. Windows show their inactive look: gray selection
and gray prominent buttons. That is fine for layout and grid checks.

For the final review of a finished change, run once with
`APP_SNAPSHOT_ACTIVE=1`. The app comes to the front and each window is key,
so you see real accent colors and focus rings. That takes the user's focus:
tell them before the run, and snapshot only the pages you changed
(`APP_SNAPSHOT_PAGES`). See "Leave the user's mouse and keyboard alone" in
the `test-mac-app` skill.

Run the installed binary directly with a test database and a folder for the
images. The app opens, walks through every sidebar page and every Settings
tab in light and dark mode, saves one PNG per page and mode, and quits.

```bash
tools/snap.sh
# SNAPSHOT /tmp/<AppName>-shots/all-light.png
# ...
# SNAPSHOT done /tmp/<AppName>-shots
```

`tools/snap.sh` deletes the old test store (with its `-wal` and `-shm`
files) and the saved window state first, then runs with sample data
(`APP_SEED=1`). Without that, seed data goes stale, and one crashed run
leaves a "reopen windows?" alert that hangs every later run.

Use `APP_SNAPSHOT_PAGES=today,inbox` to limit the pages. Add `settings` to
include the Settings tabs.

In every image, look for three bugs agents often miss: a focus ring or
selected text that nobody asked for, a scroll bar with nothing to scroll,
and an empty band under short content. The fixes are in `mac-design`,
"Windows open calm".

To see scroll bars as people with a mouse see them, add
`-AppleShowScrollBars Always` after the binary path. It changes only this
run.

Always use `APP_STORE` with a path in `/tmp`. Never take snapshots against the
user's real database in `~/Library/Application Support/<AppName>/`.

### Seed data

Empty pages only show empty states. The template's
`Sources/<AppName>/SeedData.swift` fills an empty test store when
`APP_SEED=1` is set. Grow it with the app: 10 to 20 items with long and
short titles, dates in the past and future, every priority and status, and
only what a person can create in the app.

### Screen Recording permission

Snapshots use `screencapture -l <window>`, which shows glass, sidebars, and
materials exactly as on screen. It needs Screen Recording permission for the
app that runs the command (Terminal, Ghostty, or Claude). If a snapshot line
ends with `(fallback: ...)`, the permission is missing and sidebars and glass
render blank. Ask the user to allow it in System Settings > Privacy &
Security > Screen & System Audio Recording, then restart the terminal.

### Missing snapshots

If every snapshot fails, or `screencapture` says "could not create image
from window", the display is probably asleep: an unattended Mac turns it
off. The template's snapshot mode wakes the display itself. For captures
from outside the app (like `window-shot.sh`), run `caffeinate -u -t 2` first.

If some states print "no window" while others work, another app hid yours
during the run. Computer use does this to apps it does not control, and so
does Hide Others. The template's snapshot mode un-hides the app (without
activating it) before each capture. Run it again, and avoid using computer
use in another session at the same time.

## 3. Check the grid

```bash
tools/grid-lint.sh
swift tools/check-layout.swift /tmp/<AppName>-shots/*-layout.json
```

Both print PASS. On a FAIL, call the Skill tool with `layout-grid`: it has
the rules, the overlay, and a table of fixes.

## 4. Look

Open every PNG with the Read tool and check, in this order:

- Nothing is blank, clipped, or overlapping. Text fits. Sidebars show their items.
- Dark mode is readable. No fixed white or black surfaces.
- The page matches the story or the reference screenshot (layout, labels, order).
- The `mac-design` rules hold: glass only on controls, one accent,
  SF Symbols, system text styles, empty states that invite the first action.

Describe what you see in one or two sentences per page in your report, and
name the PNG paths so the user can open them.

## 5. Interaction checks

Snapshots show state, not behavior. Run `tools/selftest.sh` (exit 0 when
every check passes) and add a check for each new action. The
`test-mac-app` skill covers unit tests, the self-test, key events, the
menu check from outside, and a debug bridge.

### Toolbar tooltips

After adding or changing toolbar controls, run the installed build,
activate its window, and follow
[Add hover help](../../design/ux-design/SKILL.md#6-add-hover-help).
Record the expected text and actual hover result for each icon-only control,
including relevant toolbar updates and disabled controls where help explains
availability. Require passing visible hover results before declaring toolbar
changes complete. Use the real pointer with `tools/tooltip-watch.swift`
and the user, never synthetic events. If hover cannot be tested, report it
as unverified.

Source inspection, accessibility labels, screenshots without a visible
tooltip, and native registration checks support the result but do not
replace visible hover verification. For a reproduced failure, follow
[Toolbar help troubleshooting](../../design/mac-design/toolbars.md#toolbar-help-troubleshooting),
then repeat hover checks and state transitions.

### Inactive windows

Gray traffic lights mean the window was not key when it was captured:
sidebar text, selection, and toggles look dimmer than in use. Background
snapshots always look like this. Use them for layout, spacing, and the
grid, and do not "fix" dim text or gray buttons you only see there. Colors,
contrast, and selection count as reviewed only on an
`APP_SNAPSHOT_ACTIVE=1` run.

### Debug output and private screens

A GUI app started with its output going to a file buffers `print`, and the
lines are lost when the process is killed. Write debug lines to stderr
(`FileHandle.standardError.write`) behind an environment flag.

Do not take full-screen captures to check your app: they show the user's
other windows. Capture your own window, or add a mode to the app that
renders the state you want to see (prefilled text, an open sheet).

## 6. Commit

When the build is clean and the snapshots look right, commit with a message
that says what the user can now do: "Add tasks from the quick-add panel",
not "Update views".

Done when the five conditions at the top hold and the change is committed.
