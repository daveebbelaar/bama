---
name: agent-cli
description: Optional command line and MCP server for a macOS app, so Claude Code, Codex, and scripts can drive it (list, add, change, search, act) through the running app. Use when the user wants agents to work with their app or its data, asks for a CLI, an MCP server, or automation for the app, or says "Claude should be able to use my app".
argument-hint: "<cli-name, like tasks or mail>"
---

# Agent CLI

Give the app a command line, so an agent can do everything a person can
do in the window: `tasks items add --title "Call the dentist"`. The app
binary is the CLI. Each command goes to the running app over a private
socket, runs there like a button press, and the window updates live.

```text
Claude Code --bash--> tasks items add ...  --socket--> Tasks.app (runs the command, saves, redraws)
Claude Desktop --MCP--> tasks mcp           --socket--> same commands, same app
```

## CLI, MCP, or App Intents

| Way in | Who uses it | Ship it |
| --- | --- | --- |
| CLI | Claude Code, Codex, scripts, people in Terminal | Always. Agents learn it from `--help`, and it costs no context until used |
| MCP (`tasks mcp`) | Claude Desktop and other clients with no shell | Optional. The same commands, one tool each. One line to register |
| App Intents | Siri, Spotlight, Shortcuts | Separate work. Agents cannot call them |

The CLI talks to the running app, never to the database file. Then there is
one writer, the app's checks and side effects run, and the window shows the
change at once. If the app is closed, the CLI opens it in the background.
Rules and reasons: [rules.md](rules.md).

## 1. List the commands

Read the user stories (`docs/stories/`). Write each thing a person does as
a command, `<noun> <verb>`, and mark it:

- **read**: `items list`, `items show`, `status`. Safe to run any time.
- **write**: `items add`, `items update`, `open`. Changes data, can be undone.
- **destructive**: `items delete`, `mail send`. Only reports what it would
  do until `--yes` is given.

Add `status` (is it running, what is open, counts) and `open <page>` (show
a page in the window), so an agent can see and steer the app.

Check: every M1 story has its commands, and each command is marked.

## 2. Add the files

```bash
"${CLAUDE_SKILL_DIR}/scripts/add-agent-cli.sh" <app-folder> <cli-name>
```

It copies `Sources/<App>/Agent/` (core, socket, CLI, MCP, example
commands) and `Main.swift`, moves `@main` to `Main.swift`, starts the socket
in the main view's `.task`, and makes `build.sh` link
`~/.local/bin/<cli-name>`. Apps not made from the template: do the same
by hand, following the script.

Check: the script printed "added the agent CLI", and `swift build` passes.

## 3. Write the commands

Replace the examples in `Agent/AgentCommands.swift`. Each command has a
name, a one-line summary, its params, a full example, its mark
(`readOnly` or `destructive`), and a `run` that uses the same model code
as the window's buttons. Never copy logic: call the function the button
calls.

- Every model an agent touches gets `var uuid: UUID = UUID()`. Commands
  show the first 8 characters as `id`, and accept any unique start of it.
- Results are small JSON objects: the fields an agent needs, not the
  whole model. Lists take `--limit` and `--offset`, and return `total`
  and `nextOffset`.
- Errors throw `AgentError` with a message that says how to fix it:
  "no item with id 3f2a. Run `tasks items list`".

All the rules: [rules.md](rules.md).

Check: `<cli-name> help` lists every command from step 1, and
`<cli-name> help <command>` shows its params and example.

## 4. Build and install

```bash
./build.sh
<cli-name> help
```

`build.sh` installs the app and links `~/.local/bin/<cli-name>` to the
binary inside it, so the CLI always matches the app. If the shell cannot
find it, add `~/.local/bin` to `PATH` in `~/.zshrc`.

Check: `<cli-name> --version` prints the app's version.

## 5. Test

```bash
"${CLAUDE_SKILL_DIR}/scripts/check-agent-cli.sh" <cli-name>
```

It starts a test copy of the app on a temporary database, checks help,
JSON output, error codes, every read command, and the MCP tool list, then
quits the test copy. Then run each write command once by hand, with
`APP_STORE=/tmp/<App>-test.store`, and look at the window: the change shows
without a reload.

Check: the script prints `PASS agent CLI`.

## 6. Teach agents

Write `.claude/skills/<cli-name>/SKILL.md` in the app's repo from
[teach-agents.md](teach-agents.md): what the app is, the safety rules,
the main commands, and "run `<cli-name> help` for the rest". To use the
app from any folder, also copy it to `~/.claude/skills/<cli-name>/`. Add
one line to the app's `CLAUDE.md`: "Drive the app with `<cli-name>`. See
`.claude/skills/<cli-name>/SKILL.md`."

Check: a fresh `claude -p "List my starred items with <cli-name>"` finds
the CLI and answers from real data.

## 7. MCP, when the user wants it

For Claude Desktop, or to get one approval prompt per tool:

```bash
claude mcp add --scope user <cli-name> -- ~/Applications/<App>.app/Contents/MacOS/<App> mcp
codex mcp add <cli-name> -- ~/Applications/<App>.app/Contents/MacOS/<App> mcp
```

Claude Desktop: add it to `~/Library/Application Support/Claude/claude_desktop_config.json`
under `mcpServers`, with the full path and `"args": ["mcp"]`. More in
[teach-agents.md](teach-agents.md).

Check: `claude mcp list` shows the server as connected.

Done when every command from step 1 runs through the CLI against the
running app, `check-agent-cli.sh` prints `PASS agent CLI`, the app's repo
has the agent skill from step 6, and a fresh Claude Code session can do a
real task with it.
