---
name: improve-loop
description: Autonomous loop that works through docs/STORIES.md one story at a time for a macOS app, building, snapshotting, comparing against reference screenshots, fixing, and committing, until a milestone is done. Use when the user says "keep going", "work through the backlog", "make it match the reference", or wants an unattended improvement loop.
argument-hint: "[milestone, e.g. M1]"
---

# Improve loop

One pass through the loop takes one story from `todo` to `done`:

```text
pick story -> plan -> code -> ./build.sh -> snapshot -> compare -> fix -> commit -> update STORIES.md
```

Stop after the milestone the user named, or after the current milestone if
they named none. Then report.

## 1. Pick

Open `docs/STORIES.md`. Take the first `todo` story in the current
milestone whose dependencies are `done`. Set it to `doing`.

## 2. Plan

If the story adds a screen, an action, or words and has no `UX:` block
yet, call the Skill tool with `ux-design` first.

Write two to five lines in your head or in the commit body: which files
change, which model fields are new, which menu command and shortcut it adds,
which snapshot page shows it. If the story needs a new SwiftData field, give
it a default value so existing databases keep loading.

## 3. Code

Follow the `swift-swiftui` and `mac-design` skills, the story's `UX:`
block, and `design/DESIGN-SYSTEM.md` if the app has one. System hooks follow
`os-integrations`. Keep each view file under about 300 lines.
Put new pages in the `SidebarItem` enum so snapshot mode visits them.

## 4. Build and snapshot

Follow the `build-and-verify` skill. If the story has logic, add a test
or a self-test step (`test-mac-app` skill). Use seed data (`APP_SEED=1`) so pages
show real content.

## 5. Compare

Open your snapshot and the story's reference screenshot side by side with
the Read tool. Write down the differences that matter, in this order:

1. Missing or wrong behavior from the acceptance criteria.
2. Words and flow: names, surface, and states that differ from the `UX:`
   block or `docs/GLOSSARY.md`.
3. Layout: wrong column, wrong order, missing element, and every FAIL from
   the grid checks.
4. Hierarchy: what is biggest, boldest, first.
5. Spacing and alignment.
6. Color and details.

The goal is the same structure and behavior, built from Apple's own controls.
It is not a pixel copy. When the reference uses a web-style custom control
and macOS has a native one (a toolbar, a sidebar, a context menu, a date
picker), use the native one.

No reference screenshot (no app was cloned)? Compare against the story's
acceptance lines and the `mac-design` rules instead.

Snapshot only the pages a story touches (`APP_SNAPSHOT_PAGES`), and the
full set at the end of each milestone.

Fix, rebuild, and compare again. Three rounds per story at most. If it still
does not match, set the story to `todo` again with a note that says what is
blocking, and move on.

## 6. Commit and record

```bash
git add -A
git commit -m "Complete tasks with Command-Return"
```

Set the story to `done` in `docs/STORIES.md` and commit that with the code.
One story per commit, so any story can be reverted on its own. M1 may
land as one commit when its stories share one skeleton (model, pages,
list, persistence); from M2 on, one story per commit.

## 7. Report

At the end of the loop, report to the user:

- Stories done, with one line each and the snapshot paths that show them.
- Stories blocked, and why.
- Anything the user should try by hand (shortcuts, drag and drop).
- The next story in line.

Then `./build.sh --open` so the user can try the new build.

## Milestone check-in

When the last story of a milestone is `done`, call the Skill tool with
`improve-architecture` before you start the next milestone. Unattended, do
its top recommendation only if it is `Strong`, and leave the rest in the
review file for the user.

When a story fixes a bug, add an entry to `docs/FIXLOG.md`: symptom,
cause, fix, and a last line `Rule: <what to always or never do>`. The fix
log outlives squashed history, and the check-in reads it.

## Running it unattended

The loop works with no one watching, because every step checks itself:
the build, the snapshots, the acceptance criteria. To let it run longer,
start it with a clear limit ("finish M2, then stop"), make sure the tree is
committed before you start, and never let it touch the user's real database.
Each story is a separate commit, so the user can review the history in the
morning and revert anything they do not like.

Done when every story in the milestone is `done` or named in the report as
blocked with a reason, each done story has its own commit, and the user
has the report.
