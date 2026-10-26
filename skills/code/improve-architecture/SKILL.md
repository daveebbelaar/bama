---
name: improve-architecture
description: Architecture check-in for a growing macOS Swift codebase. Finds hot spots, proposes deeper modules, and refactors one step per commit with behavior proven unchanged. Use at the end of a milestone, before a big feature, when a file passes 600 lines, when one feature touches many files, when bugs repeat in one area, or when the user asks to refactor or clean up the code.
---

# Improve architecture

Features pile up, and an app that was easy to change gets hard to change.
A **check-in** catches that early: survey, propose, let the user pick, then
refactor in small steps that keep behavior the same. The target shape for
apps that grow is in [architecture.md](architecture.md).

## When to run

Any one signal is enough:

- The end of a milestone (the `improve-loop` skill calls this skill there).
- Before a big feature. Ask: "What change to the code would make this
  feature easy?"
- A Swift file over 600 lines (act at 1,000), a type over 400 lines, or
  "unable to type-check this expression".
- One feature touched more than 6 files or more than 2 targets.
- The same area shows up in 3 fix-log entries, or the same kind of bug
  happens twice.
- State that changes more than 10 times a second sits on a model that many
  views observe.
- A dependency cannot be replaced in a test.

## Vocabulary

Use these words exactly, so proposals stay comparable:

- **Module**: anything with an interface and an implementation (a type, a
  file group, a target).
- **Interface**: everything a caller must know: signatures, ordering,
  error modes, threading, performance.
- **Depth**: how much a module does per unit of interface. Deep modules hide
  a lot behind a small interface. Shallow modules are pass-throughs.
- **Seam**: a place where you can swap behavior without editing callers.
- **Adapter**: one implementation behind a seam. One adapter is a
  hypothetical seam. Two (production and test) make it real.
- **Locality**: a change touches one place. **Leverage**: callers get a lot
  for little.

## 1. Survey

Change no code in this step.

1. Read `CLAUDE.md`, `ARCHITECTURE.md`, `docs/adr/`, and `docs/FIXLOG.md`
   where they exist.
2. Find hot spots:

   ```bash
   git log --since=30.days --name-only --format= | sort | uniq -c | sort -rn | head -20
   find Sources -name '*.swift' | xargs wc -l | sort -n | tail -20
   ```

3. Map the structure: targets and their dependencies, protocols and their
   conformers, `@MainActor` types that do I/O, and what runs on which
   queue.
4. Look for Swift friction:
   - A view model that owns everything (a god model).
   - Wrappers that only forward calls.
   - App code that reaches into a library's internals.
   - Test hooks in the app target.
   - Fast-changing state published to every view.
   - Slow work on the main thread or a real-time queue.
   - Protocols with one conformer and no test adapter.
   - Drifted copies: the same `private struct <Name>` defined in two files
     (`grep -rn 'private struct' Sources/ | awk '{print $3}' | sort | uniq -d`).
   - A settings or detail page that lives far from its feature. Pages live
     in the feature's folder.
   - Pure logic inside a `@MainActor` store, which tests cannot compile
     alone. Move it into a plain type that takes plain values.
5. **Deletion test** for each candidate: if you deleted this module, would
   its complexity concentrate in one place (keep it) or spread to every
   caller (it earns its place)? Pass-throughs fail the test.

## 2. Propose

Write `docs/architecture-review-<YYYY-MM-DD>.md`, one card per candidate:

```markdown
## <Title in domain nouns>  [Strong | Worth exploring | Speculative]

Files: Sources/App/EditorModel.swift (1,750 lines), ...
Signal: <which trigger above>
Problem: <what is hard to change today, with one example>
Proposal: <the new module and its interface, 15 lines of Swift at most>
Benefits: <locality and leverage; which tests get simpler>
Proof of same behavior: <tests, golden files, snapshots, perf baseline>
Plan: <one commit per step>
```

End with a **top recommendation** and a short "considered, not
recommended" list. Saying "the code is fine" is a valid result: then
every card is `Speculative` or there are none.

Stop and ask the user which candidate to do. In an unattended loop, do the
top recommendation only if it is `Strong`. Leave the rest in the file.

## 3. Refactor

- **Before:** record the proof: tests at the interface, golden outputs
  (file bytes or hashes, snapshot PNGs, old files that must still load),
  and a performance baseline where speed matters.
- One refactor per commit. Behavior stays the same. No features mixed in.
- New types go in new files that compile first. Then move callers over.
  The project builds after every step.
- Replacing an engine: keep the old path behind a flag for one milestone,
  then delete it.
- Replace tests, do not layer them: delete the old shallow tests that the
  new interface tests cover.
- If a diff passes about 10 files, split it.
- If the interface is open, design it twice: sketch two or three
  interfaces under different constraints (fewest entry points, simplest
  common caller, ports and adapters) and pick one with a reason.

## 4. Record

- Update `ARCHITECTURE.md`: targets, layers, dependency direction, seams.
- Add an ADR in `docs/adr/` only when the decision is hard to reverse,
  surprising without context, and a real trade-off.
- Add a `docs/FIXLOG.md` entry for any bug the refactor found. Every entry
  ends with a `Rule:` line.

Done when the review file exists, the chosen refactor is committed in
steps, the proof gives the same results before and after, and
`ARCHITECTURE.md` matches the code.
