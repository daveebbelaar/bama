#!/usr/bin/env python3
"""Exercise standalone skill installation and generated Codex app instructions."""
import os
import subprocess
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
LINK = ROOT / 'scripts/link-skills.sh'
SCAFFOLD = ROOT / 'skills/start/new-mac-app/scripts/new-app.sh'


class CompatibilityTests(unittest.TestCase):
    def run_link(self, destination, *args):
        return subprocess.run(['zsh', str(LINK), '--target', str(destination), *args],
                              text=True, capture_output=True)

    def test_link_install_dry_run_and_repeat(self):
        with tempfile.TemporaryDirectory() as folder:
            destination = Path(folder) / 'skills'
            preview = self.run_link(destination, '--dry-run')
            self.assertEqual(preview.returncode, 0, preview.stderr)
            self.assertFalse(destination.exists())
            installed = self.run_link(destination)
            self.assertEqual(installed.returncode, 0, installed.stderr)
            expected = {p.parent.name: p.parent for p in ROOT.glob('skills/*/*/SKILL.md')}
            self.assertEqual({p.name for p in destination.iterdir()}, set(expected))
            for name, source in expected.items():
                self.assertTrue((destination / name).is_symlink())
                self.assertEqual((destination / name).resolve(), source.resolve())
            repeated = self.run_link(destination)
            self.assertEqual(repeated.returncode, 0, repeated.stderr)
            self.assertEqual(repeated.stdout, '')

    def test_conflict_preserves_files_and_writes_no_links(self):
        with tempfile.TemporaryDirectory() as folder:
            destination = Path(folder) / 'skills'
            existing = destination / 'swift-swiftui'
            existing.mkdir(parents=True)
            (existing / 'SKILL.md').write_text('User skill\n')
            result = self.run_link(destination)
            self.assertNotEqual(result.returncode, 0)
            self.assertEqual(list(destination.iterdir()), [existing])
            self.assertEqual((existing / 'SKILL.md').read_text(), 'User skill\n')

    def test_new_app_gets_matching_codex_instructions(self):
        with tempfile.TemporaryDirectory() as folder:
            env = {**os.environ, 'GIT_AUTHOR_NAME': 'BAMA Test',
                   'GIT_AUTHOR_EMAIL': 'bama-test@example.invalid',
                   'GIT_COMMITTER_NAME': 'BAMA Test',
                   'GIT_COMMITTER_EMAIL': 'bama-test@example.invalid'}
            result = subprocess.run(['zsh', str(SCAFFOLD), 'CodexSmoke',
                                     'dev.bama.codexsmoke', folder],
                                    env=env, text=True, capture_output=True)
            self.assertEqual(result.returncode, 0, result.stderr)
            app = Path(folder) / 'CodexSmoke'
            self.assertEqual((app / 'AGENTS.md').read_bytes(), (app / 'CLAUDE.md').read_bytes())
            self.assertIn('CodexSmoke', (app / 'AGENTS.md').read_text())
            self.assertNotIn('__APP_NAME__', (app / 'AGENTS.md').read_text())


if __name__ == '__main__':
    unittest.main()
