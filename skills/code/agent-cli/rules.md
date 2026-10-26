# Rules for an agent CLI

The rules behind `Agent/` in the template, and the ones each new command
must follow. From Anthropic's tool-writing guidance, clig.dev, and the CLIs
of Optical Flow and Onyx.

## Contents

- How the parts talk
- Commands
- Output
- Errors and exit codes
- Safety
- Tests
- What not to build

## How the parts talk

- The app binary is the CLI. `Main.swift` runs a command when one follows
  the binary's name, and opens the app otherwise. One build, one version,
  one install.
- The CLI sends one JSON line to `~/Library/Application Support/<App>/agent.sock`
  and reads one JSON line back. The socket is mode 0600: only this Mac
  user can use it.
- Commands run in the app on the main actor, through the same code as the
  buttons. The window updates live, and validation and side effects run
  once, in one place.
- When the app is not running, the CLI opens it with `open -g` (in the
  background) and waits up to 10 seconds. `--no-launch` fails with exit 4
  instead.
- `APP_STORE=/tmp/x.store` moves the database and the socket
  (`/tmp/x.store.sock`), so a test run starts its own copy of the app and
  never touches real data. `APP_AGENT_SOCKET` moves the socket alone.
- A socket path must stay under 104 bytes. Keep test stores in `/tmp`.

## Commands

- Names are `<noun> <verb>`, lowercase: `items add`, `mail draft`,
  `projects list`. Same verbs everywhere: `list`, `show`, `add`, `update`,
  `delete`, `open`.
- One command per thing a person does. Merge steps an agent would always
  chain ("find and open" is one `open`).
- Option names say what they hold: `--title`, `--due`, `--project`, never
  `--t` or `--value`.
- Every option has a flag. No interactive prompts, ever: an agent cannot
  answer them.
- `status` shows what the app shows: running, open page, selection, counts.
- Ids are the first 8 characters of the model's `uuid`. Any unique start
  works. Never print a `PersistentIdentifier`.

## Output

- Without `--json`: short plain lines for people, one per item.
- With `--json`: exactly one JSON object on stdout, and nothing else.
  Notes and progress go to stderr.
- Results hold what an agent needs next: ids, titles, states, dates in ISO
  8601. Not the whole model.
- Lists default to 50 items and return `total`. When more exist, they
  return `nextOffset`; the agent passes it back as `--offset`.
- `help` lists every command. `help <command>` shows params and an example.
  `help --json` returns every command as a JSON schema, for scripts and MCP.

## Errors and exit codes

| Exit | Code | Meaning |
| --- | --- | --- |
| 0 | | OK |
| 1 | `invalid`, `error` | The command ran and failed |
| 2 | `usage` | Unknown command or option, missing or bad value |
| 3 | `not_found` | No such id or page |
| 4 | `app_unavailable` | The app is not running and could not start |

- With `--json`, an error is `{"ok":false,"error":{"code":"...","message":"..."}}`
  on stdout. Without it, `<cli>: message` goes to stderr.
- A message says what to do next: "no item with id 3f2a. Run `tasks items list`",
  "missing --title. Example: tasks items add --title \"Buy milk\"".
- Add a code to `AgentError` when an agent should act differently on it
  (`stale`, `busy`). Keep the list short and in `help`.

## Safety

- Mark each command `readOnly` or `destructive`. MCP clients show the marks
  and can skip the prompt for read-only tools.
- A destructive command (delete, send, empty, overwrite) without `--yes`
  changes nothing. It returns what it would do and the hint "add --yes".
- Sending anything outside the Mac (mail, messages, posts) is two commands:
  `draft` returns an id and a preview, then `send <id> --yes`.
- Writes are idempotent where it is cheap: completing a done task returns
  `"changed": false`, not an error.
- Prefer the Trash and Undo over hard deletes. A command that deletes should
  call the same code as the window, so Edit > Undo can bring it back.
- Never print secrets (tokens, passwords) in results or errors.

## Tests

- `check-agent-cli.sh <cli>` after every new command.
- Keep the parsing and result code in plain functions, and give each
  command one test in the app's tests with a test store.
- Before each release, let a fresh `claude -p` session do one real task
  with only `<cli> help` to go on. If it gets lost, the help text is wrong.

## What not to build

- **Direct database access from the CLI.** Two processes writing one
  SwiftData store skip the app's checks, can migrate it with the wrong
  schema, and the window does not see the change.
- **An XPC service in the app.** Apple's guidance: apps use XPC services,
  they do not provide them to command-line tools. It needs a launchd agent.
- **AppleScript or URL schemes as the main channel.** They return no
  result (URL schemes) or trigger Automation prompts (Apple Events).
- **An MCP server without the CLI.** The CLI is what Claude Code and Codex
  use best, and the MCP server is a thin layer over the same commands.
