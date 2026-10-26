---
name: new-mac-app
description: Create a native macOS SwiftUI app from a working template (Swift package, SwiftData, build script, icon script, snapshot mode, git), with no Xcode GUI. Use when the user wants to start a new Mac app or scaffold a macOS project.
argument-hint: "<AppName> <bundle-id> [parent-folder]"
allowed-tools: Bash(*/new-app.sh *) Bash(git *) Bash(swift *) Read Write Edit
---

# New Mac app

The template builds and runs as is. The first build proves the toolchain
works before you write feature code.

## What the template is

A Swift package with one executable target, plus a script that wraps the
binary in a real `.app` bundle. An agent can read and edit every file.

```text
<AppName>/
  Package.swift          macOS 26, Swift 6.2 tools, main-actor default isolation
  Info.plist.in          bundle id, name, icon, minimum macOS
  Icon/AppIcon.icon      the app icon: Icon Composer file, JSON plus SVG layers
  build.sh               swift build -> .app bundle -> codesign -> ~/Applications
  CLAUDE.md              build, check, and design rules for agents
  Sources/<AppName>/
    App.swift            window, menus, Settings, database location
    Models.swift         SwiftData models, sidebar pages, AppModel
    ContentView.swift    NavigationSplitView: sidebar, list, detail
    Snapshot.swift       APP_SNAPSHOT mode: PNG and layout file per page and Settings tab, light and dark
    UI/Theme.swift       accent colors, saved choice, accent tokens
    SettingsView.swift   Settings window: one tab per topic, sized to content
    UI/AppearanceSettings.swift  Settings: accent picker (mode follows the Mac)
    UI/WindowBehavior.swift  no focus ring on open, fit to content
    UI/Grid.swift        the 4 pt spacing scale, layout probes, grid overlay
  tools/
    grid-lint.sh         flags spacing numbers off the 4 pt grid
    check-layout.swift   checks the layout files from snapshot mode
    make_icon.sh         Icon/AppIcon.icon -> Resources/Assets.car + AppIcon.icns (actool)
    icon_review.sh       renders every icon look into one PNG (ictool)
    icon_sheet.swift     joins the renders for icon_review.sh
```

## Steps

1. Check the toolchain:

   ```bash
   swift --version            # Swift 6.2 or later
   sw_vers -productVersion    # 26.0 or later
   ```

   On macOS 15, set `.macOS(.v15)` in `Package.swift` and
   `LSMinimumSystemVersion` to 15 in `Info.plist.in`, and skip Liquid Glass APIs.

2. Pick the name (one UpperCamelCase word) and bundle id (reverse DNS). If
   `docs/BRIEF.md` exists, use its name.

3. Run the script with the parent folder. It copies the template, fills in
   the name and bundle id, runs `git init`, and commits. It keeps a folder
   that holds only a brief.

   ```bash
   "${CLAUDE_SKILL_DIR}/scripts/new-app.sh" Tasks com.yourname.tasks ~/Developer
   ```

   In a Dropbox or iCloud Drive folder the script can take minutes: run it
   in the background.

4. Build the app and its icon, then open it:

   ```bash
   cd ~/Developer/Tasks && ./build.sh --open
   ```

5. Run the checks the template ships with, then look at the snapshots
   (`build-and-verify` skill):

   ```bash
   swift test --scratch-path ~/Library/Developer/Tasks/test-build   # Kit unit tests
   tools/selftest.sh                                                # PASS per check, exit 0
   tools/snap.sh                                                    # sample data, light and dark PNGs
   ```

6. If `docs/BRIEF.md` exists, rename `Item` to the brief's main type and the
   sidebar pages to the brief's pages. Nothing else: features go through
   `improve-loop`, one story at a time. Build, snapshot, commit.

## When to switch to an Xcode project

The Swift package covers most personal apps. Switch to an XcodeGen project
(`project.yml` -> generated `.xcodeproj`, built with `xcodebuild`) when the
app needs App Intents for Shortcuts and Spotlight, an asset catalog, app
extensions, or widgets. Keep `project.yml` in git and the `.xcodeproj` out
of it. Put build output outside Dropbox with `-derivedDataPath`.

## Signing

`build.sh` signs with the first "Apple Development" certificate in the
keychain, or ad hoc without one. Permissions (Accessibility, Screen
Recording, camera) are stored per signature and path. Ad hoc builds ask
again after every rebuild. A free Apple ID makes a certificate in Xcode >
Settings > Accounts > Manage Certificates. Install to the same path every
time.

## A CLI for agents

To let Claude Code, Codex, or scripts read and change the app's data, call
the Skill tool with `agent-cli`. The app binary becomes its own CLI and
sends each command to the running app, so the database keeps one writer
and the window updates live.

## When the build fails

- `cannot find 'X' in scope` after adding a file: SwiftPM cached the file
  list. Run `swift package clean --scratch-path ~/Library/Developer/<AppName>/build`.
- `binary is older than ...`: a file did not compile. Read the first errors.
- Concurrency errors: call the Skill tool with `swift-swiftui`.

Done when the app opens from `~/Applications`, the snapshots show every
page in light and dark, and the first commit exists.
