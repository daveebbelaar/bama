# Writing patterns

Patterns for the words in a Mac app. Each one has a rule and a before and
after. Most rules come from Apple's HIG pages on writing, alerts, and
modality.

## Contents

- Voice
- Names
- Buttons and menu items
- Titles
- Empty states
- Errors
- Alerts
- Confirmations
- Undo
- Settings
- Fields and placeholders
- Permissions
- Progress
- Tooltips
- Counts and plurals
- Words to cut

## Voice

Pick three words for the app's voice and keep them in `docs/GLOSSARY.md`
under `## Voice`, for example "calm, direct, brief". Tone changes with the
moment: plain and serious for errors, a little warmer for a finished goal.

- Talk to people as "you". Never "the user".
- Say "click" on a Mac, never "tap".
- No idioms or jokes that do not translate. Explain a technical term the
  first time, or drop it.

## Names

A good name fits the app's other words, sets the right expectation, and
works in every language and market (WWDC26-290).

- Name a feature by what it does for the person, not by the technology:
  "Enhance Dialogue", not "Isolate Vocals" or "Voice Separation".
- A toggle gets a verb phrase that answers "what" and "for whom".
- Avoid clever names that raise questions. A label must not sound like a
  judgment when its value is low or zero ("Spending Power: $0").
- Where trust matters (money, health, privacy), use the industry word
  ("Balance", not "Current Funds").
- Reuse words already in the app. A new name for an old idea is a bug.
- Test each name in sentences: "Turn on Enhance Dialogue", "Search for
  it in Recent". If the sentence sounds odd, the name is wrong.

To find a name: write who it is for, then three lists of words, what the
feature makes people think, feel, and do. Group them into themes, cut what
fails the rules above, and try the rest in sentences.

## Buttons and menu items

Start with a verb. Name the object when the verb alone is unclear.

| Before | After |
| --- | --- |
| OK | Save |
| Let's go! | Create Project |
| New | New Task |
| Export | Export… (it opens a save panel first) |
| Click here to learn more | Learn About Smart Lists |

- Title case on buttons and menu items.
- An ellipsis means "asks for more before it acts". Leave it off commands
  that act at once.
- Multi-step flows start with "Get Started", move with "Continue", and end
  with "Done". Keep the same words in every flow.

## Titles

Window titles name the content, not the app. Modal titles name the task.

| Before | After |
| --- | --- |
| Taskly | Today |
| Edit | Rename Project |
| Settings Window | Settings |

## Empty states

Say what the page is for and give the first action as a button.

| Before | After |
| --- | --- |
| Nothing here. | No Tasks. Tasks you add appear here. [Add Task] |
| Your inbox is empty! 🎉 | All Done. New tasks land here first. |

Keep critical information out of empty states. They disappear.

## Errors

Say what happened and how to fix it, next to the problem, without blame.

| Before | After |
| --- | --- |
| Oops! Something went wrong. | Unable to save the task. The disk is full. |
| Invalid name. | Use letters and numbers only. |
| Password too short. | Choose a password with at least 8 characters. |
| Error 401 | Your session ended. Sign in again. |
| We're having trouble loading this. | Unable to load tasks. |

Say what to do, not what is forbidden: "Use only letters for your name",
not "Numbers are not allowed".

When the same error keeps happening to many people, change the design, not
the message.

## Alerts

- A title that is a full sentence uses sentence case and ends with a
  period. A fragment uses title case and no period: "Unable to Export".
  A question uses title case: "Delete 3 Tasks?"
- At most two lines. Never "Error", "Warning", or an error code as the title.
- The message never explains the buttons. The buttons name the action.

## Confirmations

Ask only for rare actions that cannot be undone. The title is a question
with the verb. The button repeats the verb.

| Before | After |
| --- | --- |
| Are you sure? [Yes] [No] | Delete 3 Tasks? [Delete] [Cancel] |
| Warning! This cannot be undone. [OK] | Empty Trash? You can't undo this action. [Empty Trash] [Cancel] |

## Undo

Name every undoable action so the Edit menu reads "Undo Complete Task",
not "Undo".

```swift
undoManager?.setActionName("Complete Task")
```

## Settings

Label the setting by what it does. Describe the on state only; people
infer the off state. Link to a setting instead of describing where it is.

| Before | After |
| --- | --- |
| Enable notifications for tasks that are due if the app is not open | Notify me when a task is due |
| Sync | Keep tasks on all my Macs |

## Fields and placeholders

Every field has a visible label. The placeholder shows an example or the
format, never the only label.

| Before | After |
| --- | --- |
| (placeholder only) Email | Label "Email", placeholder "name@example.com" |
| Enter date | Label "Due Date", placeholder "Tomorrow, Friday, Oct 30" |

## Permissions

Ask at the moment of first use, never at launch, unless the app cannot
work at all without it. The purpose string in `Info.plist` is one short,
complete sentence in the active voice, in sentence case, ending with a
period. It says how and why.

| Before | After |
| --- | --- |
| This app needs access to improve your experience | Snap reads the screen to find the window under the pointer. |
| Microphone access required | Recordings use the microphone to capture your voice. |

A window shown before the system prompt explains the reason and has one
button, "Continue". No Cancel, no Allow: the system prompt is where people
decide.

Accessibility, Screen Recording, and Input Monitoring have no in-app
prompt that grants them: people switch them on in System Settings. Show
the reason in the app's own Permissions row first, then one button
("Open System Settings") that opens the right pane. Never fire the system
request and open System Settings at the same moment.

## Progress

Say what is happening, with a count when there is one.

| Before | After |
| --- | --- |
| Loading... | Importing 12 photos... |
| Processing | Summarizing your notes... |
| Please wait | Exporting "Q3 Report"... |

## Tooltips

These rules cover tooltips on controls. An information tooltip (the full
text of a truncated value, a chart value, why a control is disabled) just
shows that information.

Say what the control does, starting with a verb, then add its shortcut in
parentheses, written with symbols: "(⌘N)", "(⌃⌥←)".
Do not repeat the control's name: the tooltip adds what the name does not
say. Sentence case, no period, at most 60 to 75 characters. Skip tooltips
on buttons whose text label already says it all.

| Before | After |
| --- | --- |
| (none) | Add a task to this list (⌘N) |
| New Task (⌘N) | Add a task to this list (⌘N) |
| Click this button to create a new task in the current list | Add a task to this list (⌘N) |

## Counts and plurals

Use automatic grammar agreement so counts read right in every language.

```swift
Text("^[\(count) task](inflect: true) left")
```

## Words to cut

- "we", "our": unclear who that is. "Unable to sync", not "We couldn't sync".
- "Oops", "Uh-oh", "Whoops": sound insincere in an error.
- "Simply", "just", "easily": they blame people who find it hard.
- "Please": once in a while is fine, every message is noise.
- "Your", "my": "Favorites" already means yours.
- Code words: entity, record, payload, null, sync token, 404.
