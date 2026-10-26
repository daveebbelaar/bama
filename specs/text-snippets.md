# Text snippets

Type a short keyword like `;sig` in any app and it turns into the full text.
Replaces: TextExpander. Taken from Onyx.

## Brief

```markdown
# Snippets

A text expander for one person: type a keyword anywhere and get the full text, with today's date or the clipboard filled in.

## Replaces
TextExpander, and typing the same lines over and over.

## Main jobs
1. Type a keyword like ;sig in any app and have it replaced with the text.
2. Add, edit, turn off, and delete snippets in one list.
3. Fill in placeholders: date, time, clipboard, a new UUID, and where the cursor ends up.

## Data
- Snippet: id, keyword, expansion, enabled

## Shape
Menu bar extra plus a Settings window that holds the snippet list. No panel.
macOS 26 or later. Menu-bar-only (LSUIElement). Local data. Works offline. No accounts.

## System hooks
Listen-only keyboard event tap, synthetic key events, menu bar item.

## Reference
TextExpander

## Look
Native Settings form. Each keyword in a monospaced chip with an accent tint, the text
preview next to it, a switch per snippet.

## Not in version one
- Groups and folders
- Fill-in forms and per-app rules
- Rich text and images in snippets
```

## How it works

| Part | API | Permission |
| --- | --- | --- |
| Watch typing | `CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap, options: .listenOnly)` for `keyDown`, `flagsChanged`, mouse downs | Accessibility; if the tap still fails, Input Monitoring (`CGRequestListenEventAccess`) |
| Read typed characters | `CGEvent.keyboardGetUnicodeString` | Same tap |
| Delete the keyword | `CGEvent` key events for `kVK_Delete`, posted to `.cgSessionEventTap` | Accessibility |
| Type short text | `CGEvent.keyboardSetUnicodeString` | Accessibility |
| Paste long text | `NSPasteboard` plus Command-V, then put the old clipboard back | Accessibility |
| Reset on app switch | `NSWorkspace.didActivateApplicationNotification` | None |
| Permission state | `AXIsProcessTrusted()`, polled | None |
| Storage | `snippets.json` in Application Support | None |
| Menu bar item | `MenuBarExtra` | None |

Recipe: [Event tap](../skills/code/os-integrations/recipes.md#event-tap) (use
`.listenOnly`, the tap never changes input). Signing that keeps the grant:
[os-integrations](../skills/code/os-integrations/SKILL.md#signing-keeps-grants).

Types to create:

- `Snippet` (Codable; `isReady` means a keyword of 2 or more characters and some text) and `SnippetStore` (`@Observable`, saved on every change, three starters on first run).
- `SnippetMatcher`: pure buffer logic; feed it characters, it returns a match. Unit tested.
- `SnippetEngine`: owns the matcher, the pending expansion, and `expand`.
- `KeyEventTap`: installs the tap, retries, re-enables, skips the app's own events.
- `SyntheticEvents` (`press`, `type`, `paste`, all marked) and `Pasteboard` (`snapshot`, `restore`, `pasteTransient`).
- `Placeholders`: pure `resolve(text, now:, clipboard:)`. Unit tested.
- `Permissions`, `SettingsView`, `SnippetRow`, `SnippetSheet`.

Exact behavior:

- Starters: `;date` gives `{date}`, `;time` gives `{time}`, `;shrug` gives `¯\_(ツ)_/¯`.
- Buffer: append each typed character. Trim it to the length of the longest ready keyword.
- Delete removes the last buffer character. Command or Control held resets the buffer.
- Reset on: Return, keypad Enter, Tab, Esc, arrows, Home, End, Page Up, Page Down, Forward Delete, any mouse click, and an app switch.
- Match: of the enabled, ready snippets, the longest keyword that the buffer ends with wins, so `;dates` beats `;date`.
- On a match: clear the buffer, store it as pending, and expand 0.02 s later, so the last typed character lands first.
- While pending: collect typed characters as "extra". Delete removes the last extra (or cancels when none). Command, Control, or a reset key cancels.
- Expand: skip when `AXIsProcessTrusted()` is false. Resolve placeholders, cut out `{cursor}` and count the characters after it. Press Delete `keyword.count + extra.count` times.
- Text with a newline or over 60 characters: paste it. Shorter text: type it in chunks of 20 UTF-16 units.
- After that: type the extra characters again. With no extra and a `{cursor}`, press Left arrow that many times, 0.05 s later.
- Paste path: snapshot every item and every type on the clipboard, write the text plus the app's own type and `org.nspasteboard.TransientType`, post Command-V, restore the snapshot 0.35 s later.
- Placeholders: `{date}` is `yyyy-MM-dd`, `{time}` is `HH:mm`, `{date:PATTERN}` uses any `DateFormatter` pattern, `{uuid}` is a new UUID, `{clipboard}` is the current clipboard string, `{cursor}` marks where the cursor ends up.
- Editor: Save is off until the snippet is ready and no other snippet has the same keyword (trimmed). Command-S saves. Delete asks first.
- The tap retries every 2 s until it installs, so a grant works without a restart.

The tap callback. Skip your own events and turn the tap back on when macOS
turns it off:

```swift
if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
    MainActor.assumeIsolated { KeyEventTap.shared.reenable() }
    return Unmanaged.passUnretained(event)
}
if event.getIntegerValueField(.eventSourceUserData) == SyntheticEvents.marker {
    return Unmanaged.passUnretained(event)   // text this app typed
}
// .keyDown -> engine.handleKeyDown(event); mouse down -> engine.resetBuffer()
return Unmanaged.passUnretained(event)
```

## Stories

```markdown
# Stories

## M1 Core loop

### S-001 Grant Accessibility on first launch
As the user, I open Snippets for the first time and it shows what it needs and why.
Screens: settings-permissions
Acceptance:
- [snap] With Accessibility off, Settings opens on launch with "Snippets needs Accessibility to read keywords and type text" and an Open System Settings button.
- [manual] The button opens the Accessibility pane; the state turns On within 2 s of granting, no restart.
- [snap] While off, the menu bar menu shows "Needs Accessibility" at the top.
- [manual] The tap starts on its own once granted (retry every 2 s).
Status: todo

### S-002 Expand a snippet while typing
As the user, I type ;shrug in TextEdit and it becomes ¯\_(ツ)_/¯.
Depends: S-001
Acceptance:
- [unit] SnippetMatcher fed ";shrug" returns the shrug snippet; fed ";shru" returns nil.
- [unit] Delete removes the last buffer character; Return, Tab, arrows, and Command keys reset it.
- [manual] The keyword is gone and the text is in its place, in TextEdit, Notes, and Safari.
- [unit] With ;date and ;dates set, ";dates" picks ;dates; snippets that are off or not ready never match.
- [manual] The app's own typed text never triggers another expansion.
Status: todo

### S-003 Keep what I type during the expansion
As the user, I type ;shrug and keep typing fast; nothing I typed is lost.
Depends: S-002
Acceptance:
- [manual] Typing ";shrug ok" quickly gives "¯\_(ツ)_/¯ ok".
- [manual] Pressing an arrow key right after the keyword cancels the expansion.
Status: todo

### S-004 Paste long text and keep my clipboard
As the user, a three-line signature expands at once and my clipboard is unchanged after.
Depends: S-002
Acceptance:
- [manual] Text with a newline or over 60 characters arrives in one paste.
- [manual] An image on the clipboard before the expansion is still there 1 s after.
- [manual] A clipboard manager does not save the expansion (TransientType is set).
Status: todo

### S-005 Date and time placeholders
As the user, ;date gives today's date as 2026-10-24.
Depends: S-002
Acceptance:
- [unit] resolve("{date}") is yyyy-MM-dd, "{time}" is HH:mm, "{date:EEEE}" is the weekday name.
Status: todo

### S-006 Add a snippet
As the user, I click Add Snippet, type a keyword and text, and save.
Screens: settings-snippets, snippet-sheet
Acceptance:
- [snap] The sheet has Keyword (monospaced, placeholder ;sig), Text, an On switch, Cancel, and Add Snippet.
- [manual] Add Snippet stays off until the keyword has 2 or more characters and the text is not empty.
- [snap] A keyword another snippet uses shows "Another snippet already uses this keyword."
- [self] Snippets survive a restart (snippets.json); a first run has the three starters.
Status: todo

### S-007 Edit, turn off, or delete a snippet
As the user, I click a row to edit it, flip its switch, or delete it.
Screens: settings-snippets
Depends: S-006
Acceptance:
- [snap] A turned-off row is dimmed; a row that is not ready shows an orange "Not ready" badge.
- [manual] Delete asks "Delete ;sig?" first.
Status: todo

### S-008 Use the menu bar item
As the user, I click the menu bar icon to turn expansion on or off, open Settings, or quit.
Screens: menu
Acceptance:
- [snap] The menu shows "Expand Snippets" with a checkmark, Settings, and Quit.
- [manual] With expansion off, keywords stay as typed.
- [manual] Settings shows in the Dock and Command-Tab while open; closing it keeps the app running.
Status: todo

## M2 More placeholders

### S-009 Clipboard and UUID placeholders
As the user, {clipboard} inserts what I copied and {uuid} a new UUID.
Depends: S-005
Acceptance:
- [unit] resolve with a clipboard string fills {clipboard}; two {uuid} resolves differ.
Status: todo

### S-010 Put the cursor inside the text
As the user, a snippet "Hi {cursor}," leaves the cursor before the comma.
Depends: S-005
Acceptance:
- [unit] Cutting {cursor} returns the text without it and the count of characters after it.
- [manual] In TextEdit the cursor lands where {cursor} was.
Status: todo

### S-011 Insert a placeholder from the editor
As the user, I click a placeholder button under the text field and it is added to the text.
Screens: snippet-sheet
Depends: S-006
Acceptance:
- [snap] Buttons for {date}, {time}, {date:EEEE d MMMM}, {clipboard}, {uuid}, {cursor}.
Status: todo

## Dropped
- One shared event tap that also feeds a window switcher and a keystroke overlay.
- Activity stats (expansion counter).
```

## Gotchas

- The app's own key events came back through its own tap and could match again. Set `source.userData` and `.eventSourceUserData` to one marker on every posted event, and return early in the callback when it matches.
- macOS turns a tap off when the callback is slow (`.tapDisabledByTimeout`) or on some user input (`.tapDisabledByUserInput`). Re-enable it with `CGEvent.tapEnable` right there, and keep the callback tiny.
- `CGEvent.tapCreate` returns nil until the permission is granted. Retry every 2 s, and call `CGRequestListenEventAccess()` once if it still fails with Accessibility on.
- Fast typing got deleted in place of the keyword. Wait 0.02 s so the last keyword character lands, count characters typed in that window into the Delete presses, and type them again after the text.
- A one-letter keyword or empty text eats characters while you type. Only snippets with a keyword of 2 or more characters and some text fire. Tell users to start keywords with `;`.
- Without resets the buffer matched across contexts: half a keyword in one app plus the rest in another. Reset on clicks, app switches, arrows, Return, Tab, Esc, and Command or Control combos.
- `keyboardSetUnicodeString` carries at most 20 UTF-16 units per event, and splitting a surrogate pair breaks emoji. Send chunks of 20 UTF-16 units and move the cut back one unit when it lands after a lead surrogate.
- Typing with Unicode key events only works well for short, single-line text. Text with `\n` or over 60 characters goes through the clipboard and Command-V.
- Snapshot every pasteboard item with every type's data, not only the string, or an image the user had copied is gone after an expansion. Restore it 0.35 s after the paste.
- The Settings window is the only real UI, but an `.accessory` app never shows in Command-Tab. Switch to `.regular` while Settings is open and back after, and return false from `applicationShouldTerminateAfterLastWindowClosed`.
- An ad hoc signed build loses the Accessibility grant on every rebuild, and expansion silently stops. Sign with one stable certificate and install to the same path.

Done when typing `;shrug` in TextEdit gives `¯\_(ツ)_/¯`, `;date` gives today's date, a three-line snippet pastes and the old clipboard comes back, and snippets survive a restart.
