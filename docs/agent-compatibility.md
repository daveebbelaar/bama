# Claude Code and Codex

The same skill directories, references, scripts, and templates serve both agents.

## Load another skill

Claude Code uses its Skill tool. Codex reads the selected skill's `SKILL.md`
and follows it, loading linked references when needed. Use the installed skill
name shown by the client: plugin names can be namespaced, such as `bama:clone`.
In Codex, invoke `$bama:bama` for the router, `$bama:clone` for a walkthrough,
or `$bama:agent-cli` for an app CLI and MCP. You can also select BAMA in the
skills picker. Standalone installs use `$bama`, `$clone`, `$agent-cli`, and
the other unprefixed skill names.

## Find scripts

Resolve relative paths from the loaded `SKILL.md`, not the app's working folder.
Before running a command that uses `BAMA_SKILL_DIR`, set that shell variable to
the absolute directory containing the selected `SKILL.md`. In Claude Code,
`CLAUDE_SKILL_DIR` supplies that directory. In Codex, use the loaded file's path.
Keep the app's working directory as requested by the command.

## Tools and permissions

Use the tools actually provided by the client. For Codex desktop computer use,
use `cua_repl` when available; for browser tasks, use its browser API or another
available browser tool. Follow that tool's interaction and screenshot rules.
Do not assume Claude's `mcp__computer-use__*` tools exist in Codex. A skills
installation does not grant computer control, permissions, or a subscription.
If the needed capability is absent, report it and use supplied screenshots or
other supported evidence. Do not claim a live walkthrough was performed.

Research can use the client's subagent tools when available and authorized.
Respect its concurrency limit and batch tracks; otherwise run tracks serially.

## MCP

BAMA is a skills plugin. It does not ship a BAMA MCP server. The `agent-cli`
skill adds a CLI and optional stdio MCP server to an app built from the template.
Register that app's actual binary after building it. Existing MCP registrations
for other tools are independent of BAMA.

Done when the selected workflow uses the client's available tools and reports
any unverified capability explicitly.
