---
name: app-brief
description: One-page brief (docs/BRIEF.md) for a new macOS app, written before any code. Use when the user has an app idea, wants to replace an app they pay for, or the research and clone skills are done.
argument-hint: "[idea in a few words]"
---

# App brief

Write `docs/BRIEF.md` in a folder named after the app
(`<parent>/<AppName>/docs/BRIEF.md`; ask for the parent folder, default
`~/Developer`). Every later skill reads it. Keep it to one page.

## 1. Name and read what exists

Pick the name first: one UpperCamelCase word (`Tasks`, `DailyLog`), not the
name of an app already in `~/Applications`, and a bundle id
`com.<yourname>.<appname>` in lowercase. The folder, the research, and the
scaffold all use it.

If `docs/research/` or `docs/screens/INDEX.md` exist, read them first.
Skip every question they already answer.

If the user gives you a spec from BAMA's `specs/` folder (a file or a
link), it already holds the brief and the stories. Copy its **Brief** block
to `docs/BRIEF.md` and its **Stories** block to `docs/STORIES.md`. Keep the
rest of the spec as `docs/SPEC.md`, so later skills read its **How it
works** and **Gotchas**. Ask only what the user wants to change, then call
the Skill tool with `new-mac-app`.

## 2. Interview

Ask a few questions at a time. If the user asked you to decide everything,
answer each question yourself from the research, write the choice in the
brief, and note "decided by the agent" next to it.

1. What do you do today, and which app or habit does it replace?
2. What are the three things you do most often? These become the main pages.
3. What data does it hold? Name the nouns: tasks, notes, recipes, invoices.
4. Is there a reference app you like? Then the `clone` skill comes next.
5. Where does it live: a window with a sidebar, a menu bar item, a
   quick-capture panel with a global shortcut, or a mix?
6. Does it need the internet? Default: no.
7. Which three things are out of scope for version one?
8. Should it look like a built-in Mac app, or have its own look? Note a
   brand or accent color, and any app they name ("like Things"): the
   `design-from-app` skill rebuilds its look. No answer means native with
   the Mac's own accent color.

## 3. Cut scope

A personal app has one user. Remove what exists only for other users:
accounts, sharing, teams, sync servers, billing, onboarding, analytics. If
the user wants data on two Macs, note "later: iCloud sync".

Version one is one afternoon of agent time: one window, two to five main
pages, one data model with two to four types. Smart lists that filter one
model (Today, Upcoming, Someday) count as one page.

## 4. Write docs/BRIEF.md

```markdown
# <AppName>

One sentence: what it is and who it is for.

## Replaces
<app or habit>

## Main jobs
1. ...
2. ...
3. ...

## Data
- <Type>: <fields>

## Shape
<sidebar window / menu bar extra / quick panel>, macOS 26 or later.
Local data. Works offline. No accounts.

## System hooks
<global shortcut, menu bar, Share menu, Shortcuts, CLI, or "none">

## Reference
<app name, or "none">

## Look
<native with an accent color (name it, or "system"), own parts, or "like <app>", and why>

## Not in version one
- ...
```

## 5. Hand off

Call the Skill tool with `user-stories`, or with `new-mac-app` if the user
wants to see a window first.

Done when `docs/BRIEF.md` exists, fits on one page, and has every section.
