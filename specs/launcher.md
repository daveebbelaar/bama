# Launcher

Press Option-Space, type a few letters, press Return: the app, file, or web
search opens. Replaces: Alfred, Spotlight. Taken from Onyx.

## Brief

```markdown
# Launch

A keyboard launcher for one person: press a shortcut, type, and open an app, a file, or a web search.

## Replaces
Alfred and Spotlight, for opening apps and files.

## Main jobs
1. Open an app by typing part of its name or its initials ("vsc" for Visual Studio Code).
2. Find a file or folder by name, then open it or show it in Finder.
3. Run a keyword search: "g cats" searches Google, "code" lists workspace files.

## Data
- AppEntry: name, path, folded name, initials (rebuilt on every open, not saved)
- QuickSearch: keyword, name, kind (files or website), extensions, url with {query}, app path, enabled
- Usage: open count per path, and the last path picked for each query

## Shape
Floating panel opened with a global shortcut, a menu bar extra, and a Settings window.
macOS 26 or later. Menu-bar-only (LSUIElement). Local data. Works offline. No accounts.

## System hooks
Global shortcut (default Option-Space), menu bar item, Spotlight file search.

## Reference
Alfred, Spotlight

## Look
Native. A Liquid Glass capsule for the search field, a glass card for results below it,
the system accent color on the selected row. Results never animate.

## Not in version one
- Calculator and System Settings panes
- Clipboard history, snippets, workflows, plugins
- GIF search and developer project search
```

## How it works

| Part | API | Permission |
| --- | --- | --- |
| Global shortcut | Carbon `RegisterEventHotKey` | None |
| Panel that keeps the other app in front | `NSPanel` with `.nonactivatingPanel`, `NSHostingView` | None |
| App list | `FileManager.contentsOfDirectory` on the app folders | None |
| File search | Spotlight `MDQueryCreate`, `MDQuerySetSearchScope`, `MDQuerySetMaxCount` | None |
| Icons | `NSWorkspace.shared.icon(forFile:)` in an `NSCache` | None |
| Open, reveal | `NSWorkspace` `openApplication(at:)`, `open(_:)`, `open(_:withApplicationAt:)`, `activateFileViewerSelecting` | None |
| Menu bar item | `MenuBarExtra` | None |

Launch needs no permission. The one failure state is a shortcut that another
app already owns. Recipes: [Global hotkey](../skills/code/os-integrations/recipes.md#global-hotkey-carbon),
[Non-activating panel](../skills/code/os-integrations/recipes.md#non-activating-panel).

Types to create:

- `HotkeyCenter` and `KeyCombo`: register the shortcut, record failures, suspend while recording.
- `FloatingPanel`: the panel, its local key monitor, `present()` and `hide()`.
- `LauncherModel` (`@Observable`): query, results, selection, generation; `search()` and `activate()`.
- `FuzzyMatch`: pure enum with `fold`, `initials`, `score`. Unit tested.
- `AppIndex`, `FileSearch`, `QuickSearchStore` (JSON), `IconCache` with `FileIconView`.
- `LauncherView`, `SettingsView`, `ShortcutRecorder`.

Fuzzy score: fold query and name with `.caseInsensitive, .diacriticInsensitive`,
`penalty = min(name.count, 60)`, higher is better, nil is no match. Exact name 1000.
Name prefix 900, initials prefix 800, word prefix 700, substring 500, each minus
penalty. Letters in order: `max(1, 300 - gaps * 8 - penalty)`, gaps = skipped characters.

Initials: the first letter of each word, plus each capital after a lowercase letter:

```swift
var result = "", previous: Character = " "
for c in s {
    let word = c.isLetter || c.isNumber
    let prevWord = previous.isLetter || previous.isNumber
    if word && (!prevWord || (c.isUppercase && previous.isLowercase)) { result.append(c) }
    previous = c
}
return fold(result)   // "Visual Studio Code" -> "vsc", "WebStorm" -> "ws"
```

Ranking and limits:

- App score = fuzzy score + `min(200, opens * 20)` + 300 when this app was the last pick for this exact query.
- Keep the top 6 apps. When the best app scores 500 or more, hide apps under 450.
- Order: apps, then quick search hint rows, then files, then one "Search Google" row last. An app wins a tie.
- App folders: `/Applications`, `/System/Applications`, `/System/Applications/Utilities`, `~/Applications`, `/System/Library/CoreServices/Applications`, plus Finder. Look one level into vendor subfolders. Drop duplicate names. Rescan on every open, on a background queue (a few ms).
- Files: only when the query has 2 or more characters. Wait 80 ms after the last key, then run a synchronous MDQuery on a background queue.
- File query: one clause per word, `kMDItemDisplayName == "word*"cdw`, joined with `&&`, plus `kMDItemContentType != "com.apple.application-bundle"`. Escape `\` and `"`, strip `*`. Scope: the folders in Settings, default the home folder. Max 80 results.
- Drop paths containing `/node_modules/`, `/.git/`, `/Library/`, `/.build/`, `/DerivedData/`, `/site-packages/`, `/.venv/`. Score by file name plus usage, keep 12.
- File subtitle: the last three folders, home as `~`: "… › Projects › app › Sources".
- Quick search: "keyword rest" where the keyword matches an enabled, ready search. Ready means a keyword without spaces, and at least one extension (files) or a url with `{query}` (website). Defaults: `code` (files, `code-workspace`), `g` Google, `yt` YouTube, `gh` GitHub.
- Website kind: one row that opens the url with the percent-encoded text. Files kind: `kMDItemFSName == "*.ext"c` for each extension (joined with `||`), plus `kMDItemFSName == "*word*"cd` per word. Max 400, newest `kMDItemContentModificationDate` first, show 60. Opens in the chosen app, or the default app.
- Hints: with no space typed, each keyword that starts with the query shows a hint row. An exact keyword goes on top. Return or Tab on a hint fills in "keyword ".
- Keys: Up, Down, Return opens, Command-Return shows in Finder, Command-1 to 9 opens that row, Tab completes, Esc closes. A click outside closes.
- Usage: on open, `usage[path] += 1` and `learned[foldedQuery] = path`, in `UserDefaults`.
- Panel: glass 700 pt wide, search bar 58 pt, rows 50 pt, up to 8 rows then scroll. The top sits 18% below the top of the screen with the mouse. The window is fixed and transparent, with 60 pt around the glass for the shadow.

## Stories

```markdown
# Stories

## M1 Core loop

### S-001 Open the launcher with the shortcut
As the user, I press Option-Space in any app and the search panel appears.
Screens: launcher-empty
Acceptance:
- [snap] A glass capsule with "Search apps and files" sits 18% below the top of the screen.
- [manual] The other app stays frontmost; the field has focus and I can type at once.
- [manual] Esc, a click outside, or Option-Space again closes it.
Status: todo

### S-002 Find an app by name or initials
As the user, I type "saf" or "vsc" and the matching app is the first row.
Screens: launcher-results
Depends: S-001
Acceptance:
- [unit] FuzzyMatch scores exact > prefix > initials > word prefix > substring > letters in order.
- [unit] initials("Visual Studio Code") is "vsc"; "cafe" matches "Café".
- [snap] Rows show icon, name, path, and Command-1 to 9 key caps; the last row is "Search Google".
Status: todo

### S-003 Open, reveal, or search the web
As the user, I pick a row with the arrow keys or Command-N and press Return or Command-Return.
Screens: launcher-results
Depends: S-002
Acceptance:
- [manual] Return opens the app or file and the panel closes; Command-Return shows it in Finder.
- [manual] The "Search Google" row opens the browser; spaces and & in the query survive.
- [manual] Hovering a row selects it only after the mouse really moves.
Status: todo

### S-004 Learn from what I open
As the user, the app I picked for "s" last time is first the next time I type "s".
Depends: S-003
Acceptance:
- [unit] Opening adds min(200, opens * 20); the last pick for the exact query adds 300.
- [self] Usage survives a restart.
Status: todo

### S-005 Find files by name
As the user, I type part of a file name and files show up under the apps.
Screens: launcher-files
Depends: S-002
Acceptance:
- [manual] Files appear within about 150 ms, between apps and the web row; rows above them do not move.
- [unit] Paths in node_modules, .git, Library, DerivedData, .build, site-packages, .venv are dropped.
- [snap] The subtitle shows the last three folders, home as ~.
Status: todo

### S-006 Use the menu bar item
As the user, I click the menu bar icon and see Open Launch (with its shortcut), Settings, and Quit.
Screens: menu
Acceptance:
- [snap] The menu shows the current shortcut next to Open Launch.
- [manual] No Dock icon; closing Settings keeps the app running.
Status: todo

### S-007 Change the shortcut, and see when it is taken
As the user, I click the recorder in Settings and press a new combo.
Screens: settings-general
Acceptance:
- [manual] All shortcuts pause while recording. Esc cancels, Delete clears, a combo without a modifier or F-key beeps.
- [manual] When RegisterEventHotKey fails, an orange warning shows next to the shortcut.
Status: todo

## M2 Keyword searches

### S-008 Search a website with a keyword
As the user, I type "yt cats" and Return opens YouTube results for cats.
Screens: launcher-quick-web
Acceptance:
- [snap] The search bar shows a "YouTube" chip and a single row.
- [unit] match("yt cats") returns YouTube and "cats"; disabled or not-ready searches never match.
- [manual] Typing "y" shows a YouTube hint row; Tab or Return fills in "yt ".
Status: todo

### S-009 List files with a keyword
As the user, I type "code " and see my .code-workspace files, newest first.
Screens: launcher-quick-files
Depends: S-008
Acceptance:
- [manual] More words narrow the list; Return opens the file in the chosen app.
- [snap] An empty result shows "No code workspaces found".
Status: todo

### S-010 Edit quick searches in Settings
As the user, I add, edit, turn off, and delete keyword searches.
Screens: settings-quick-searches
Depends: S-008
Acceptance:
- [snap] A search that is not ready shows an orange "Not ready" badge.
- [self] Quick searches survive a restart (quicksearches.json).
Status: todo

### S-011 Choose what and where to search
As the user, I turn apps, files, and the web row on or off, and pick the folders for file search.
Screens: settings-search
Acceptance:
- [manual] The last folder cannot be removed; a new folder is used on the next search.
Status: todo

## Dropped
- GIF search (needs an outside API key), developer projects, and text transforms (json, b64, jwt).
- Custom shell commands, port and process commands.
- Calculator row and System Settings panes (good M3 candidates).
- "find" and "open" file-only keywords, URL scheme, App Intents, activity stats.
```

## Gotchas

- Calling `makeFirstResponder` in `present()` cost about 14 ms of SwiftUI focus-graph work before the first frame, and the old field resigning at the next show cost 13 ms more. Fix: set `@FocusState` one run loop turn after show (`DispatchQueue.main.async`), and call `makeFirstResponder(nil)` 0.3 s after `hide()`.
- The first press built the panel and its hosting view (cold frame about 88 ms). Fix: build it 2 s after launch and call `contentView?.layoutSubtreeIfNeeded()`. Cold frame went to about 37 ms.
- The `TextField` eats arrow keys and Return. Use a local `.keyDown` monitor that only handles events where `event.window === panel` and returns nil for keys it used. Remove the monitor in `hide()`.
- Files arrive later than apps. Insert them between the instant rows and the web row, and keep the selection by row id if the user already moved. Bump a generation counter on every search and drop any async result from an older one.
- A list that changes under a still mouse stole the selection through hover. Select on hover only when `NSEvent.mouseLocation` changed since the last search.
- A typed `"` or `*` broke the MDQuery string. Escape `\` and `"`, strip `*`. Folders excluded in Spotlight never show up, so say that in the folder setting's footer.
- `NSWorkspace.icon(forFile:)` returns a large multi-size image that is slow to draw in a list. Draw each once at 64 px with `cgImage(forProposedRect:)` off the main thread, show it at 32 pt, and keep it in an `NSCache` (thread-safe; mark the static `nonisolated(unsafe)` in Swift 6).
- Carbon swallows a registered combo, so a recorder never sees it. Call `suspend()` on all shortcuts while recording and `resume()` after.
- Resizing the window for each result count made it jump. Keep one fixed transparent window sized for 8 rows, set `sizingOptions = []` on the hosting view, and let the glass grow inside.

Done when Option-Space opens the panel over any app, "vsc" or "saf" puts the right app first and Return opens it, a file in the home folder shows up and opens, "yt cats" opens YouTube, and usage survives a restart.
