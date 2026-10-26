#!/bin/zsh
# Checks an app's agent CLI against the agent-cli rules, on a test database.
# Usage: check-agent-cli.sh <cli>        the CLI name or a path to the app binary
#   check-agent-cli.sh tasks
#   check-agent-cli.sh ~/Applications/Tasks.app/Contents/MacOS/Tasks
# Starts a test copy of the app (APP_STORE in /tmp), never the real one, and
# quits it at the end. Prints PASS or FAIL lines, and exits 1 on any FAIL.
set -uo pipefail
cli=${1:?usage: check-agent-cli.sh <cli>}
export APP_STORE="/tmp/agent-cli-check-$$.store"
export APP_AGENT_SOCKET="$APP_STORE.sock"
fails=0
pass() { echo "PASS $1"; }
fail() { echo "FAIL $1"; fails=$((fails + 1)); }

out=$("$cli" help 2>&1); [[ $? == 0 && -n "$out" ]] && pass "help" || fail "help exits 0 and prints the commands"

schema=$("$cli" help --json 2>/dev/null)
python3 -I -c '
import json, sys
s = json.loads(sys.argv[1])
cmds = s["commands"]
assert cmds, "no commands"
for c in cmds:
    assert c["description"] and "Example:" in c["description"], c["name"] + ": summary and example"
    assert c["inputSchema"]["type"] == "object", c["name"]
' "$schema" 2>/dev/null && pass "help --json: every command has a summary, an example, and a schema" || fail "help --json lists every command with a summary, example, and schema"

"$cli" no-such-command >/dev/null 2>&1; [[ $? == 2 ]] && pass "unknown command exits 2" || fail "unknown command exits 2"
err=$("$cli" no-such-command --json 2>/dev/null)
python3 -I -c 'import json,sys; e=json.loads(sys.argv[1])["error"]; assert e["code"] and e["message"]' "$err" 2>/dev/null \
  && pass "errors with --json are {\"error\":{code,message}} on stdout" || fail "errors with --json are {\"error\":{code,message}} on stdout"

# Every read-only command without required params runs and prints JSON.
for name in ${(f)"$(python3 -I -c '
import json, sys
for c in json.loads(sys.argv[1])["commands"]:
    if c["inputSchema"].get("required") == [] and c.get("readOnly"):
        print(c["name"])
' "$schema" 2>/dev/null)"}; do
  res=$("$cli" ${=name} --json 2>/dev/null); code=$?
  python3 -I -c 'import json,sys; json.loads(sys.argv[1])' "$res" 2>/dev/null && [[ $code == 0 ]] \
    && pass "$name --json" || fail "$name --json exits 0 with one JSON object (got exit $code)"
done

mcp=$(printf '%s\n' \
  '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-06-18","capabilities":{},"clientInfo":{"name":"check","version":"1"}}}' \
  '{"jsonrpc":"2.0","method":"notifications/initialized"}' \
  '{"jsonrpc":"2.0","id":2,"method":"tools/list"}' | "$cli" mcp 2>/dev/null)
python3 -I -c '
import json, re, sys
lines = [json.loads(l) for l in sys.argv[1].splitlines() if l.strip()]
assert lines[0]["result"]["capabilities"]["tools"] is not None
tools = lines[1]["result"]["tools"]
assert len(tools) == len(json.loads(sys.argv[2])["commands"])
for t in tools:
    assert re.fullmatch(r"[A-Za-z0-9_-]{1,64}", t["name"]), t["name"]
    assert "readOnlyHint" in t["annotations"]
' "$mcp" "$schema" 2>/dev/null && pass "mcp: initialize and tools/list, one tool per command" || fail "mcp answers initialize and tools/list with one tool per command"

# Quit the test copy only: the process that owns the test socket.
pid=$(lsof -t "$APP_AGENT_SOCKET" 2>/dev/null | head -1)
[[ -n "$pid" ]] && kill "$pid" 2>/dev/null
rm -f "$APP_STORE"* 2>/dev/null

[[ $fails == 0 ]] && { echo "PASS agent CLI"; exit 0; }
echo "FAIL agent CLI: $fails checks"; exit 1
