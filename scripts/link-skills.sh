#!/bin/zsh
# Link shared skill sources into Claude Code, Codex, or an explicit directory.
# Usage: link-skills.sh [--agent codex|claude|all] [--dry-run]
#        link-skills.sh --target DIRECTORY [--dry-run]
set -euo pipefail
repo=${0:A:h:h}
agent=all
destination=''
dry_run=0
while (( $# )); do
  case "$1" in
    --agent) agent=${2:?--agent requires codex, claude, or all}; shift 2 ;;
    --target) destination=${2:?--target requires a directory}; shift 2 ;;
    --dry-run) dry_run=1; shift ;;
    --help|-h) sed -n '2,4p' "$0"; exit 0 ;;
    *) print -u2 -- "Unknown option: $1"; exit 2 ;;
  esac
done
case "$agent" in
  codex) targets=("$HOME/.agents/skills") ;;
  claude) targets=("$HOME/.claude/skills") ;;
  all) targets=("$HOME/.claude/skills" "$HOME/.agents/skills") ;;
  *) print -u2 -- "Unknown agent: $agent"; exit 2 ;;
esac
[[ -z "$destination" ]] || targets=("${destination:A}")

# Check every destination before writing any links. Existing user skills stay intact.
for target in "${targets[@]}"; do
  for skill in "$repo"/skills/*/*/; do
    skill=${skill%/}
    link="$target/${skill:t}"
    if [[ -e "$link" || -L "$link" ]]; then
      if [[ ! -L "$link" || "${link:A}" != "${skill:A}" ]]; then
        print -u2 -- "Refusing to replace existing skill: $link"
        exit 1
      fi
    fi
  done
done
for target in "${targets[@]}"; do
  (( dry_run )) || mkdir -p "$target"
  for skill in "$repo"/skills/*/*/; do
    skill=${skill%/}
    link="$target/${skill:t}"
    if (( dry_run )); then
      print -r -- "Would link $link -> $skill"
    elif [[ ! -L "$link" ]]; then
      ln -s "$skill" "$link"
      print -r -- "$link"
    fi
  done
done
