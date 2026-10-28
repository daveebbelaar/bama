#!/usr/bin/env python3
"""Check the shared Claude/Codex plugin contract and bundled resources."""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent


def check():
    claude = json.loads((ROOT / '.claude-plugin/plugin.json').read_text())
    codex = json.loads((ROOT / '.codex-plugin/plugin.json').read_text())
    assert claude['name'] == codex['name'] == 'bama'
    assert claude['version'] == codex['version']
    assert claude['skills'] == codex['skills'], 'Client skill catalogs differ'
    assert len(set(codex['skills'])) == len(codex['skills']), 'Duplicate skills'
    shipped = {str(p.parent.relative_to(ROOT)) for p in ROOT.glob('skills/*/*/SKILL.md')}
    declared = {p.removeprefix('./') for p in codex['skills']}
    assert declared == shipped, 'Manifest omits a skill or includes an absent skill'
    for relative in declared:
        skill = ROOT / relative
        assert (skill / 'agents/openai.yaml').is_file(), f'No Codex metadata: {relative}'
        text = (skill / 'SKILL.md').read_text()
        assert text.startswith('---\n') and '\nname: ' in text and '\ndescription: ' in text
        assert '${CLAUDE_SKILL_DIR}' not in text, f'Claude-only script path: {relative}'
        assert (skill / '../../../docs/agent-compatibility.md').resolve().is_file()
    marketplace = json.loads((ROOT / '.agents/plugins/marketplace.json').read_text())
    entry, = marketplace['plugins']
    assert entry['name'] == codex['name']
    assert (ROOT / entry['source']['path']).resolve() == ROOT
    assert (ROOT / 'AGENTS.md').read_bytes() == (ROOT / '.claude/CLAUDE.md').read_bytes()
    print(f'PASS: {len(declared)} shared skills, both plugin catalogs, metadata and instructions')


if __name__ == '__main__':
    check()
