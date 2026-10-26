#!/bin/zsh
# Adds the agent CLI and MCP server to an app made from the bama template.
# Usage: add-agent-cli.sh <app-folder> <cli-name>
#   add-agent-cli.sh ~/Developer/Tasks tasks
# Copies Sources/<App>/Agent/*.swift and Sources/<App>/Main.swift, moves @main
# from App.swift to Main.swift, and makes build.sh link ~/.local/bin/<cli-name>.
# The example commands in Agent/AgentCommands.swift fit the template's Item
# model. Replace them with the app's own (agent-cli skill, step 3).
set -euo pipefail
app_dir=${1:?usage: add-agent-cli.sh <app-folder> <cli-name>}
cli=${2:?usage: add-agent-cli.sh <app-folder> <cli-name>}
[[ "$cli" =~ ^[a-z][a-z0-9-]*$ ]] || { echo "cli-name must be lowercase letters, digits, and dashes, like tasks or mail"; exit 1; }
here=${0:A:h}
template=${here:h}/template
name=$(basename "$(find "$app_dir/Sources" -mindepth 1 -maxdepth 1 -type d | head -1)")
src="$app_dir/Sources/$name"
[[ -f "$src/App.swift" ]] || { echo "no $src/App.swift: is this an app from the bama template?"; exit 1; }
[[ ! -e "$src/Agent" ]] || { echo "$src/Agent already exists"; exit 1; }

mkdir -p "$src/Agent"
for f in "$template"/Agent/*.swift; do
  sed -e "s/__APP_NAME__/$name/g" -e "s/__CLI_NAME__/$cli/g" "$f" > "$src/Agent/${f:t}"
done
sed -e "s/__APP_NAME__/$name/g" "$template/Main.swift" > "$src/Main.swift"

# Main.swift has @main now: it starts the CLI or the app.
perl -0pi -e "s/\@main\s*\n(struct ${name}App\s*:\s*App)/\$1/" "$src/App.swift"
grep -q "^@main" "$src/App.swift" && { echo "could not remove @main from App.swift: remove it by hand"; exit 1; }

# Start the socket first in the main view's .task block, where the template
# starts seed data, the self-test, and snapshot mode.
if ! grep -q "AgentSocket.listen" "$src/ContentView.swift" && grep -qE '^\s*\.task \{$' "$src/ContentView.swift"; then
  perl -0pi -e 's/^(\s*)\.task \{\n/$1.task {\n$1    AgentRouter.model = model\n$1    AgentSocket.listen { AgentRouter.handle(\$0) }\n/m' "$src/ContentView.swift"
  grep -q "AgentSocket.listen" "$src/ContentView.swift" && started=1
fi

# build.sh puts the CLI on PATH.
if ! grep -q "local/bin/$cli" "$app_dir/build.sh"; then
  perl -0pi -e "s|(echo \"installed \\\$app[^\n]*\n)|\$1# The CLI: the app binary under a short name on PATH (bama agent-cli skill).\nmkdir -p \"\\\$HOME/.local/bin\"\nln -sf \"\\\$app/Contents/MacOS/\\\$name\" \"\\\$HOME/.local/bin/$cli\"\n|" "$app_dir/build.sh"
  grep -q "local/bin/$cli" "$app_dir/build.sh" || echo "note: add the ~/.local/bin/$cli link to build.sh by hand"
fi

echo "added the agent CLI to $name as \`$cli\`. Next (agent-cli skill):"
echo "  3. replace the example commands in $src/Agent/AgentCommands.swift"
[[ -n "${started:-}" ]] || echo "  4. start the socket in the main view's .task: AgentRouter.model = model; AgentSocket.listen { AgentRouter.handle(\$0) }"
echo "  5. ./build.sh, then $cli help"
