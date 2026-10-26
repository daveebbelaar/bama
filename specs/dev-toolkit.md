# Dev toolkit

A small search panel for developers: find a repo and open it in your editor, terminal, Finder, or on GitHub; transform text from the clipboard; see what listens on a port and quit it; run your own script commands by keyword. Replaces: DevUtils, Raycast script commands. Taken from Onyx.

## Brief

```markdown
# DevKit

A keyboard panel for developers who live in repos, terminals, and the clipboard.

## Replaces
DevUtils, Raycast script commands, `lsof -i :3000` followed by `kill`

## Main jobs
1. Find a repo by name and open it in the editor, a terminal, Finder, or its web remote.
2. Transform text (json, b64, url, uuid, ts, jwt, hash, case) and copy the result.
3. See what listens on a port and quit it, or run a script command by keyword.

## Data
- Project: name, path. Cached in Application Support/DevKit/projects.json with the scan date and roots.
- ScriptCommand: file path (id), name, keywords, run, symbol, cwd. One .toml file each in ~/.config/devkit/commands.
- RunningProcess: pid, name, command, cwd, port, address. Never stored.
- Settings in UserDefaults: project roots, editor, commands folder, panel shortcut, open counts per project.

## Shape
Quick panel with a global shortcut, plus a menu bar extra and a Settings window, macOS 26 or later.
LSUIElement, no Dock icon. Local data. Works offline. No accounts.

## System hooks
Global shortcut (default Option-Space), menu bar item.

## Reference
Raycast and Alfred (one search field, results below, key hints on the selected row)

## Look
Native glass panel with the system accent. Rows: symbol, title, a grey subtitle, key hints on the selected row.

## Not in version one
- App and file search
- Script output in a window
- Arguments for script commands
```

## How it works

| Part | API | Permission |
| --- | --- | --- |
| Search panel | `NSPanel` with `.nonactivatingPanel`, SwiftUI field ([recipe](../skills/code/os-integrations/recipes.md#non-activating-panel)) | None |
| Panel shortcut | Carbon `RegisterEventHotKey` ([recipe](../skills/code/os-integrations/recipes.md#global-hotkey-carbon)) | None |
| Project scan | `FileManager.contentsOfDirectory` three levels deep, off the main thread | None (a root in Documents or Desktop gets a one-time folder prompt) |
| Open in editor, terminal, Finder | `NSWorkspace.open(_:withApplicationAt:configuration:)`, `activateFileViewerSelecting` | None |
| Web remote | Read `.git/config` as text, `NSWorkspace.open(url)` | None |
| Transforms | Foundation, `JSONSerialization` (validate only), CryptoKit | None |
| Listening ports | libproc: `proc_listallpids`, `proc_pidinfo(PROC_PIDLISTFDS)`, `proc_pidfdinfo(PROC_PIDFDSOCKETINFO)`; command line from `sysctl(KERN_PROCARGS2)`, folder from `PROC_PIDVNODEPATHINFO` | None, own processes only |
| Quit a process | `kill(pid, SIGTERM)`, `SIGKILL` for force | None, own processes only |
| Script commands | `Process` with `/bin/zsh -c`, `DispatchSource.makeFileSystemObjectSource` on the folder | None |

DevKit needs no system permission. Processes of other users (root daemons) are not readable, so they never show.

Types to create:
- `FloatingPanel`, `SearchModel` (query, results, selection, Return with modifiers, Tab), and `Result` (kind: project, transform, process, command, note; title, subtitle, symbol, path, value).
- `FuzzyMatch`, `ProjectIndex`, `ProjectActions`, `GitRemote`, `CodeEditor`.
- `DevTransforms`, `JSONFormatter`, `Processes`: pure functions, plain values in, rows out.
- `CommandStore`, `ScriptCommand` (TOML subset parser), `CommandRunner`, and `SettingsView`.

Behaviors that matter:
- **Query.** The first word, lowercased, is a command name; the rest is the argument. Commands: `json`, `b64`/`base64`, `url`, `uuid`/`ulid`, `ts`/`time`, `jwt`, `hash`, `case`, `port`/`ports`, `kill`. An empty argument means the clipboard (not for `uuid` and `ts`).
- **Anything else** searches projects (2 or more characters, score 400 or more, top 5, plus 20 per past open up to 200) and script commands (exact keyword 2000, keyword prefix 1200, fuzzy name 450 or more).
- **Fuzzy score**, case and accents folded: exact 1000, prefix 900, initials ("vsc") 800, word prefix 700, substring 500, each minus the name length up to 60; letters in order 300 minus 8 per gap.
- **Project keys.** Return opens the editor; ⌘↩ Finder, ⌥↩ a new terminal window in the folder, ⇧↩ the web remote. The selected row shows these as key hints.
- **Editor** choices: Cursor (`com.todesktop.230313mzl4w4u92`), VS Code (`com.microsoft.VSCode`), Xcode, Finder. Default is the first one installed. Terminal is Ghostty (`com.mitchellh.ghostty`) when installed, else Terminal.
- **Project index.** Default root is the first of ~/Repositories, ~/Developer, ~/Projects, ~/Code, ~/src that exists. Cached on disk so the panel has projects at launch. Rescan when the panel opens and the list is older than 10 minutes or the roots changed.
- **Transforms copy, never paste.** Return copies the value, closes the panel, and shows "Copied". A note row (bad input, empty clipboard) has an empty value: Return beeps.
- **Big input.** Over 64 KB runs off the main thread with a "Working…" row. Over 2 MB shows "The clipboard is too large".
- **Transform outputs.** `json`: pretty (2 spaces) and minified. `b64` and `url`: decoded (only if readable) and encoded. `uuid`: lowercase, uppercase, ULID. `ts`: now as seconds, milliseconds, ISO 8601 UTC, local; a number to dates; a date to Unix time. `jwt`: payload, header, and exp, iat, nbf as relative times; a "Bearer " prefix is dropped. `hash`: SHA-256, SHA-1, MD5. `case`: camel, snake, kebab, Title, Pascal, CONSTANT.
- **Ports.** `port 30` filters by port prefix, name, or command. Old rows stay up while a new lookup runs, so the list does not flicker. **Quit takes two Returns.** The first arms the row ("Press again to quit"); a second within 5 s sends SIGTERM, ⌥↩ sends SIGKILL. ⌘↩ shows the process folder. The list refreshes 0.6 s later.
- **Script commands.** Return runs the command in the background: a toast "Name…", then the last output line (120 characters max). Tab fills in the keyword. New Command writes a starter file and opens it.

A command file. Parse only `key = "text"`, `key = ["a", "b"]`, and `#` comments:

```toml
name = "Morning light"
keywords = ["sun", "morning"]
run = "uv run --script ~/scripts/lights.py on"
symbol = "sun.max.fill"   # optional SF Symbol, default terminal.fill
cwd = "~/Projects/lights" # optional
```

## Stories

```markdown
# Stories

## M1 Core loop

### S-001 Open the panel with a shortcut
As the user, I press Option-Space and type at once; Esc closes the panel.
Screens: panel-empty.png
Acceptance:
- [snap] A glass panel with one search field in the upper part of the screen.
- [self] The panel is on screen within 100 ms of the shortcut, also on the first press after launch.
Status: todo

### S-002 Add project folders
As the user, I add the folder that holds my repos and see how many projects it found.
Screens: settings-projects.png
Acceptance:
- [snap] Settings lists roots with remove buttons, Add Folder…, a project count, and Rescan.
- [unit] The scan finds repos inside repos, skips the skip list, hidden folders, symlinks, and packages, and stops at depth 3.
Status: todo

### S-003 Open a project in my editor
As the user, I type part of a repo name and press Return.
Screens: panel-projects.png
Depends: S-001, S-002
Acceptance:
- [snap] Rows show the repo name, a short parent path like "… › Code › clients", and key hints on the selected row.
- [unit] "on" finds "onyx" by prefix; an initials match beats a substring.
- [manual] Xcode opens the .xcworkspace, .xcodeproj, or Package.swift, not the bare folder.
Status: todo

### S-004 Open a project in Terminal, Finder, or on GitHub
As the user, I hold ⌥, ⌘, or ⇧ with Return.
Depends: S-003
Acceptance:
- [unit] `webURL` turns git@github.com:o/r.git, ssh://git@host:2222/g/r.git, and https://user:token@host/o/r.git into https URLs without credentials; a local path gives nil.
- [unit] A worktree's `.git` file leads to the main repo's config through `gitdir` and `commondir`.
Status: todo

### S-005 Format JSON from the clipboard
As the user, I copy JSON, type `json`, and copy the pretty or minified version.
Screens: panel-transform.png
Depends: S-001
Acceptance:
- [unit] `{"b":[1,2.50],"a":{}}` keeps key order, keeps `2.50`, and keeps `{}` on one line.
- [snap] Invalid input shows "The clipboard has no valid JSON" and Return beeps.
Status: todo

### S-006 Decode Base64, URL, and JWT text
As the user, I type `b64 aGVsbG8=`, `url a%20b`, or `jwt` with a token on the clipboard.
Depends: S-005
Acceptance:
- [unit] URL-safe Base64 without padding decodes; a length with remainder 1 is rejected.
- [unit] URL encoding keeps only letters, digits, and `-._~`.
- [unit] A "Bearer " prefix is dropped; a past exp reads "Expired" with a relative time.
- [snap] The JWT subtitle says "decoded locally, signature not checked".
Status: todo

### S-007 Convert a timestamp, make an ID, hash, or change case
As the user, I type `ts 1700000000`, `uuid`, `hash abc`, or `case parseHTTPResponse`.
Depends: S-005
Acceptance:
- [unit] 1700000000 reads as seconds, 1700000000000 as milliseconds, over 1e14 as microseconds; past year 10000 gives no rows.
- [snap] `ts` alone shows now in seconds, milliseconds, ISO 8601, and local time.
- [unit] A ULID is 26 Crockford Base32 characters; `parseHTTPResponse_v2` splits into parse, HTTP, Response, v2.
Status: todo

### S-008 Set the shortcut and editor
As the user, I record a new panel shortcut and pick my editor in Settings.
Screens: settings-general.png
Acceptance:
- [snap] A shortcut recorder, an editor picker with only installed editors, and a cheat sheet of every command.
Status: todo

### S-009 Use the menu bar item
As the user, I click the menu bar icon to open the panel, Settings, or quit.
Screens: menu.png
Acceptance:
- [snap] The menu shows Open DevKit with its shortcut, Settings…, and Quit.
Status: todo

## M2 Ports, processes, and commands

### S-010 See what listens on a port
As the user, I type `port`, `port 3000`, or `kill node`.
Screens: panel-ports.png
Acceptance:
- [snap] Rows read "3000 · uvicorn app:app" with pid, folder, and "localhost only" where it applies.
- [unit] `commandLine` drops the interpreter path: python plus /…/uvicorn becomes "uvicorn app:app".
- [unit] `kill` matches only my own processes, by name, pid, or program, at most 30.
- [snap] No match shows "Nothing is listening on 3000"; `kill` alone shows "Type a process name or pid, like kill node".
Status: todo

### S-011 Quit a process with two Returns
As the user, I press Return twice on a row to quit it, or ⌥↩ to force quit.
Depends: S-010
Acceptance:
- [snap] After one Return the hint reads "Press again to quit"; after 5 s it arms again instead.
- [unit] launchd, loginwindow, WindowServer, kernel_task, and DevKit itself are refused.
- [self] A pid whose name changed since the list was made is left alone ("no longer running"); not allowed shows "Not allowed to quit".
Status: todo

### S-012 Run a script command
As the user, I type a keyword, press Tab to complete it, and Return to run it.
Screens: panel-commands.png, settings-commands.png
Acceptance:
- [self] The toast shows the last output line; a line starting with ✗ counts as a failure even with exit code 0.
- [unit] A file without `run` reports "Needs a run line"; a missing name falls back to the file name.
- [manual] A new .toml file in the folder shows up without a restart, and parse problems list in Settings.
Status: todo

## Dropped
- App, file, and quick web search: DevKit is not a launcher.
- Learned query-to-project ranking (only open counts stay).
```

## Gotchas

- **`JSONSerialization` changes your JSON.** It reorders keys and rewrites `2.50` as `2.5`. Use it only to validate, then re-indent with a small character walker that tracks strings and escapes.
- **Remotes hold tokens.** `https://user:token@github.com/o/r.git` is common. Drop everything before `@` when building the web URL. Keep a custom https port, drop an ssh port.
- **`.git` is not always a folder.** In worktrees and submodules it is a file with `gitdir:`, and a worktree's config lives in the main repo's folder named in `commondir`. Read the config as text; no need to run git.
- **The scan can explode.** Stay three levels deep, skip `node_modules`, `.venv`, `venv`, `build`, `dist`, `DerivedData`, `Pods`, `target`, `vendor`, `__pycache__`, `Library`, `site-packages`, `out`, plus hidden folders, symlinks, and packages. Run it off the main thread.
- **Use libproc, not `lsof`.** A full scan of every pid and socket takes a few milliseconds. Shelling out to `lsof` is slower and leaves you parsing text.
- **Pids get reused.** Check that `proc_name(pid)` still matches the name in the row before sending a signal. `kill` returning `ESRCH` means it is gone; any other error means not allowed.
- **GUI apps get a bare PATH.** Scripts that call `uv`, `node`, or `brew` fail from a menu bar app. Prepend `~/.local/bin`, `/opt/homebrew/bin`, `/opt/homebrew/sbin`, `~/.cargo/bin`, and every `~/.nvm/versions/node/*/bin`, newest first.
- **A chatty script fills the pipe and hangs.** Read output with `readabilityHandler` while it runs, set stdin to `FileHandle.nullDevice`, and stop it after 90 s.
- **The folder watcher misses in-place saves.** A `DispatchSource` on the folder fires for add, rename, and delete, not when an editor rewrites a file in place. Reload the commands every time the panel opens too.
- **Panel speed.** Each first-responder change in a SwiftUI panel costs about 14 ms. Do not call `makeFirstResponder` in `show()`; resign when hiding. Build the panel about 2 s after launch so the first press is fast. LaunchServices lookups (editor installed, terminal name) are slow per row: look them up once.

Done when the shortcut opens the panel, a repo opens in the editor, terminal, Finder, and on its web remote, every transform copies the right value, a dev server found with `port` quits after two Returns, and a script command runs by keyword.
