# Menus

The menu bar, context menus, and the Dock menu, from the HIG (The menu bar,
Menus, Context menus, Dock menus, June 2026). Every command in the app
lives in the menu bar, even rare ones: Full Keyboard Access and Help >
Search reach it there.

A menu bar app (LSUIElement) has a main menu only while one of its windows
is open. Its status item menu plays the menu bar's role and may show the
person's global shortcuts. Its main menu needs App (with Settings...),
Edit, Window, and Help.

## Contents

- Menu bar order
- Labels
- Icons
- Context menus
- Dock menu
- SwiftUI

## Menu bar order

App, File, Edit, Format, View, your own menus, Window, Help. Your own menus
follow the app's structure, most general first (Mail: Mailbox, Message).

| Menu | What goes there |
|---|---|
| App | About <App> (name of 16 characters or fewer, no version), Settings... (Command-comma), app items, Services, Hide, Hide Others, Show All, Quit |
| File | New <Noun> ("New Event", never just "New"), Open..., Open Recent (names, not paths, plus Clear Menu), Close, Duplicate rather than Save As, Rename..., Move To..., Export As... only for other formats. An app without files renames or drops File |
| Edit | Undo and Redo that name the action ("Undo Typing", "Redo Paste"), Cut, Copy, Paste, Delete (never Erase or Clear), Select All, Find. The system adds Dictation and Emoji |
| View | Show/Hide Sidebar, Show/Hide Toolbar, Show/Hide Inspector, Enter Full Screen. Keep View even when it only holds Enter Full Screen |
| Window | Minimize, Zoom, Bring All to Front, then open windows in alphabetical order. Keep it with one window. No panels in the list. Zoom never enters full screen |
| Help | <App> Help, then a few items after a separator |

## Labels

- A verb or verb phrase in title case, no articles: "Add Bookmark".
- An ellipsis when the command asks for more input before it acts
  ("Rename...", "Export As...").
- A toggled item changes its label with the state ("Show Map", "Hide Map").
  Add a verb when the noun alone is unclear ("Turn Grid On").
- A checkmark marks an attribute that is on (Bold). Offer one item that
  clears several (Plain).
- A submenu when one word repeats in more than two items ("Sort By"). One
  level deep, about five items. A submenu stays enabled even when all its
  items are not.
- Items that do not apply stay visible and get disabled in the menu bar.
- Option-key (dynamic) items: one modifier, menu bar only, never the only
  way to do something.

## Icons

- Few and on purpose: key actions, key features, places, devices, and
  visual ideas (rotate, flip).
- All items in a group get an icon, or none do. In a group of related items
  (Copy, Copy Link, Copy as Markdown) only the first gets the symbol.
- No icon when no symbol clearly fits. Use the standard symbols from
  design-rules.md rule 65.
- In SwiftUI menu bar commands an item shows its icon only with
  `.labelStyle(.titleAndIcon)` (WWDC26-269).

## Context menus

- Hide items that do not apply. Cut, Copy, and Paste may stay dimmed.
- No keyboard shortcuts shown. They belong in the menu bar.
- About three groups, the most frequent first, at most one submenu level.
- A title only when it adds something, such as "3 Items Selected".
- Every command here also lives in the menu bar.
- Offer context menus the same way everywhere an item can be acted on.

## Dock menu

A few high-value items for when the app is not in front (Mail: Get New
Mail, New Message), plus the open windows the system adds. Each item also
exists elsewhere in the app.

```swift
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDockMenu(_ sender: NSApplication) -> NSMenu? {
        let menu = NSMenu()
        menu.addItem(withTitle: "New Task", action: #selector(newTask), keyEquivalent: "")
        return menu
    }

    @objc private func newTask() { /* same action as File > New Task */ }
}
```

## SwiftUI

```swift
.commands {
    SidebarCommands()                 // View > Show Sidebar, Control-Command-S
    ToolbarCommands()                 // View > Show Toolbar, Customize Toolbar
    CommandGroup(replacing: .newItem) {
        Button("New Task") { model.addTask() }
            .keyboardShortcut("n")
    }
    CommandGroup(after: .sidebar) {
        // A label that follows the state.
        Button(model.showsCompleted ? "Hide Completed" : "Show Completed") {
            model.showsCompleted.toggle()
        }
        .keyboardShortcut("h", modifiers: [.command, .shift])
    }
}
```

- A `Window` or `WindowGroup` scene gets the Window and Help menus from the
  system. Keep them.
- Undo names the action: `undoManager?.setActionName("Add Task")` after
  registering the undo. The Edit menu then reads "Undo Add Task".

Done when the menu bar follows the order above, every toolbar and context
menu command has a menu bar item, and no context menu shows a shortcut or a
disabled item other than Cut, Copy, and Paste.
