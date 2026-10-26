#!/bin/zsh
# Prints one page of Apple's Human Interface Guidelines as plain text, for
# agents. Pages are cached for 7 days in ~/Library/Caches/bama/hig/ and never
# go into a repo (the text is Apple's).
#
# Usage: hig.sh <topic>          the whole page, e.g. hig.sh toolbars
#        hig.sh <topic> --mac    drop the iOS, watchOS, tvOS, and visionOS sections
#        hig.sh --list           every topic name
set -euo pipefail
cache="$HOME/Library/Caches/bama/hig"
mkdir -p "$cache"
base="https://developer.apple.com/tutorials/data/design/human-interface-guidelines"

fetch() { # topic (or "index") -> cached json path
  local file="$cache/$1.json" url="$base/$1.json"
  [[ "$1" == "index" ]] && url="$base.json"
  if [[ ! -s "$file" || -n "$(find "$file" -mtime +7 2>/dev/null)" ]]; then
    curl -fsSL "$url" -o "$file.tmp" 2>/dev/null || { rm -f "$file.tmp"; echo "no HIG page named '$1'. Try: hig.sh --list" >&2; return 1; }
    mv "$file.tmp" "$file"
  fi
  print -r -- "$file"
}

refs_of() { # json path -> topic names it links to
  python3 -I -c '
import json, re, sys
refs = json.load(open(sys.argv[1])).get("references", {})
for k in refs:
    m = re.search(r"Human-Interface-Guidelines/([a-z0-9-]+)$", k, re.I)
    if m: print(m.group(1).lower())' "$1"
}

if [[ "${1:-}" == "--list" ]]; then
  # The index links to sections, sections to groups, groups to pages. Walk
  # three levels; the first run fetches about 40 pages, then the cache answers.
  index=$(fetch index) || exit 1
  typeset -U seen level next
  level=($(refs_of "$index"))
  seen=($level)
  for depth in 1 2; do
    next=()
    for topic in $level; do
      json=$(fetch "$topic" 2>/dev/null) || continue
      [[ "$(python3 -I -c 'import json,sys; print(json.load(open(sys.argv[1])).get("metadata",{}).get("role",""))' "$json")" == "collectionGroup" ]] || continue
      next+=($(refs_of "$json"))
    done
    level=(${next:|seen})
    seen+=($level)
  done
  print -l $seen | sort
  exit 0
fi

topic=${1:?usage: hig.sh <topic> [--mac] | --list}
mac=0; [[ "${2:-}" == "--mac" ]] && mac=1
json=$(fetch "$topic") || exit 1
python3 -I -c '
import json, sys
page = json.load(open(sys.argv[1])); mac = sys.argv[2] == "1"
refs = page.get("references", {})

def inline(items):
    out = []
    for i in items or []:
        t = i.get("type")
        if t == "text": out.append(i.get("text", ""))
        elif t == "codeVoice": out.append("`" + i.get("code", "") + "`")
        elif t == "reference": out.append(refs.get(i.get("identifier"), {}).get("title", ""))
        elif t == "link": out.append(i.get("title", ""))
        elif t == "image": pass
        else: out.append(inline(i.get("inlineContent")))
    return "".join(out)

def blocks(items, ind=""):
    lines = []
    for b in items or []:
        t = b.get("type")
        if t == "heading": lines.append(("\n" + "#" * b.get("level", 2) + " " + b.get("text", ""), b.get("level", 2)))
        elif t == "paragraph":
            s = inline(b.get("inlineContent"))
            if s.strip(): lines.append((ind + s, None))
        elif t in ("unorderedList", "orderedList"):
            for it in b.get("items", []):
                sub = blocks(it.get("content"), ind + "  ")
                if sub: lines.append((ind + "- " + sub[0][0].strip(), None)); lines += sub[1:]
        elif t == "aside":
            text = " ".join(x[0].strip() for x in blocks(b.get("content")))
            lines.append((ind + "> " + (b.get("name") or b.get("style", "")) + ": " + text, None))
        elif t == "table":
            for row in b.get("rows", []):
                lines.append((ind + " | ".join(" ".join(x[0].strip() for x in blocks(c)) for c in row), None))
        elif t == "termList":
            for it in b.get("items", []):
                lines.append((ind + "- " + inline(it["term"]["inlineContent"]) + ": "
                              + " ".join(x[0].strip() for x in blocks(it["definition"]["content"])), None))
        elif t == "tabNavigator":
            for tab in b.get("tabs", []):
                lines.append((ind + "[" + tab.get("title", "") + "]", None)); lines += blocks(tab.get("content"), ind)
        elif t == "row":
            for c in b.get("columns", []): lines += blocks(c.get("content"), ind)
        elif "content" in b: lines += blocks(b["content"], ind)
    return lines

meta = page.get("metadata", {})
print("# " + meta.get("title", ""))
note = meta.get("customMetadata", {})
if note.get("alert-date"): print("Updated " + note["alert-date"] + ": " + note.get("alert-text", ""))
print(inline(page.get("abstract")))
skip = False
for section in page.get("primaryContentSections", []):
    for text, level in blocks(section.get("content")):
        if level is not None and level <= 3:
            skip = mac and level == 3 and "macOS" not in text and "Platform" not in text and any(
                p in text for p in ("iOS", "iPadOS", "watchOS", "tvOS", "visionOS"))
        if not skip: print(text)
' "$json" "$mac"
