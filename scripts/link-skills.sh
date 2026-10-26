#!/bin/zsh
# Links every skill in this repo into ~/.claude/skills and ~/.agents/skills,
# so edits in the repo show up in Claude Code and Codex at once.
# Usage: scripts/link-skills.sh
set -euo pipefail
repo=${0:A:h:h}
for target in ~/.claude/skills ~/.agents/skills; do
  mkdir -p "$target"
  for skill in "$repo"/skills/*/*/; do
    skill=${skill%/}
    name=${skill:t}
    ln -sfn "$skill" "$target/$name"
    echo "$target/$name"
  done
done
