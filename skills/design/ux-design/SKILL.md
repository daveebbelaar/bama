---
name: ux-design
description: UX pass for one feature of a macOS app, covering names, flow, where it opens (inline, popover, sheet, window, alert), states, words, hover help, accessibility, and AI features. Use before coding a story that adds a screen, an action, or text, when user-stories or improve-loop call it, or when the user asks for a UX review, clearer wording, better names, or whether something should be a modal.
argument-hint: "[story ID or screen]"
---

# UX design

A feature that works can still confuse people. This pass decides what
things are called, how a person moves through the feature, where it opens,
and what it says, before any code exists.

Run it once per story that adds a screen, an action, or words. The output
is a `UX:` block in the story in `docs/STORIES.md`, plus new terms in
`docs/GLOSSARY.md`. To review a built screen, run the same steps against
its snapshot and list what fails, most serious first.

## 0. Read

Read `docs/BRIEF.md`, `docs/GLOSSARY.md` (create it if missing), the story,
and its reference screenshots.

## 1. Name it

Every thing in the app has exactly one name, and every name lives in the
glossary.

```markdown
| Term | Means | Not |
| --- | --- | --- |
| Task | One thing to do, with an optional due date | to-do, item, entry |
| Complete | Mark a task done; it leaves the list | check, finish, close |
```

- Name the things first (the nouns in the brief), then the actions on them.
- Use the user's words, not the code's: "Task", not "TaskEntity" or "record".
- Use Apple's words for system actions: Settings, Quit, Close, Undo, Move
  to Trash (when it can come back), Delete (when it cannot).
- One word per idea across buttons, menus, titles, tooltips, and errors.
- Name a feature for what it does for the person, not the technology. A
  toggle gets a verb phrase that says what and for whom ("Enhance
  Dialogue", not "Isolate Vocals"). Say the name in a sentence out loud.
  Method: [writing.md](writing.md#names).

Check: every noun and verb the story puts on screen is in the glossary,
and no glossary term has a second name anywhere.

## 2. Map the flow

Write the flow as one line, from every way in to a clear end.

```text
Command-N, toolbar +, File > New Task -> title field has focus -> Return saves, row appears -> focus stays for the next task
```

- List every entry point: menu command, shortcut, toolbar, context menu,
  drag and drop.
- Cut steps: fill in good defaults, ask only for what you cannot guess.
- Every step has a way back: Escape cancels, Command-Z undoes.
- The end is visible: the new row, a checkmark, the window closing.

Check: the flow fits on one line, and each step names its way back.

## 3. Pick the surface

Go down this list and use the first one that fits. Lighter is better.

| The feature | Use |
| --- | --- |
| Changes one value on something already on screen | Inline (field, toggle, menu in the row) |
| Shows details of the selection while people keep working | Inspector |
| A few related choices tied to one control | Popover |
| Input people repeat while they watch the result, or a tool kept open beside the work | Panel |
| One short task that must finish or cancel before going on | Sheet |
| A long or self-contained task, or one people keep open beside the main window | New window |
| A place people come back to, like a list or a collection | Sidebar page |
| A rare action that destroys data and cannot be undone | Confirmation dialog |
| A problem people must act on right now | Alert |

- Show one modal at a time. Never open a popover from a popover, or a
  sheet from a sheet.
- A modal's title names its task: "Rename Project", not "Edit".
- Return confirms, Escape cancels, and the confirm button names the action.
- Ask before closing only when people would lose what they typed.
- Information that needs no action goes inline, never in an alert.

Details and SwiftUI code for each surface: [presentation.md](presentation.md).

Check: the `UX:` block names the surface and the table row that picked it.

## 4. Cover the states

Every view the story touches has words and a look for each state:

- **Empty**: what it is for, plus the first action as a button.
- **Loading**: only when it can take longer than half a second. Show
  cached content first. A bar when the length is known, with words for
  what is happening ("Importing 12 photos"), and Cancel when it is safe.
- **Error**: inline, next to the problem, with the fix.
- **Too much**: long names truncate with the full text in a tooltip; a
  thousand rows still scroll smoothly.
- **Done**: visible feedback in the same frame, and Undo where it applies.

Check: each state has a snapshot page or seed data that shows it.

## 5. Write the words

- Buttons and menu items start with a verb: "Add Task", "Export…".
- Add an ellipsis when the command asks for more input before it acts.
- Title case for buttons, menu items, and window titles. Sentence case for
  labels, descriptions, and messages.
- Errors say what happened and how to fix it, without blame. Write
  "Unable to load tasks", never "We're having trouble".
- Confirmations repeat the action: "Delete 3 Tasks?" with buttons "Delete"
  and "Cancel", never "Yes" and "No".

Patterns and before and after examples: [writing.md](writing.md).

A feature that uses AI (a summary, generated text, a model's suggestion)
also follows [ai-features.md](ai-features.md).

Check: read every string aloud. Each one is short, uses glossary terms
only, and a new user could say what each button does.

## 6. Add hover help

- Every icon-only button gets `.help("Add a task to this list (⌘N)")`:
  what it does, starting with a verb, then its shortcut. Not its name
  again. Rules: [writing.md](writing.md#tooltips).
- Hover can reveal secondary actions on a row. The same actions are also in
  the context menu and on the keyboard.
- Hover feedback shows at once and never shifts the layout.
- Information people need is always visible. Hover only adds detail.

Check: hover every icon-only control on the snapshot build. Each one shows
a tooltip.

## 7. Check accessibility

- The whole flow works with the keyboard alone, in a logical focus order.
- VoiceOver reads every control with the same words as the screen.
- Meaning never rests on color alone: add an icon or a word.
- Text is 10 pt or larger and readable in Increase Contrast.
- Reduce Motion replaces slides and bounces with fades.
- Every custom control has a label, a value, actions, and feedback.

The audit steps and SwiftUI modifiers: [accessibility.md](accessibility.md).

Check: you ran the flow keyboard-only and with VoiceOver, and the
Accessibility Inspector audit shows no issues for the new views.

## 8. Write the UX block

Add the result under the story's acceptance lines:

```markdown
UX:
- Flow: Command-N, toolbar +, File > New Task -> title field -> Return saves -> focus stays
- Surface: inline row at the top of the list (changes one value on screen)
- States: empty "No Tasks" with "Add Task"; error "Give the task a title." under the field
- Words: "Add Task", tooltip "Add a task to this list (⌘N)", "Undo Add Task"
- Access: Return saves, Escape cancels; VoiceOver "New task title"
```

Done when the story has a `UX:` block, every term it uses is in
`docs/GLOSSARY.md`, and steps 1 to 7 pass on its snapshots.
