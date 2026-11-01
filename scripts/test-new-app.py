#!/usr/bin/env python3
"""Regression checks for scaffolding, including failed placeholder substitution."""
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

SCRIPT = Path(os.environ.get(
    "BAMA_NEW_APP_SCRIPT",
    str(Path(__file__).resolve().parents[1] / "skills/start/new-mac-app/scripts/new-app.sh"),
)).resolve()


class ScaffoldTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="bama scaffold ")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.dest = self.root / "Demo"
        self.env = dict(os.environ,
            GIT_AUTHOR_NAME="Scaffold Test", GIT_AUTHOR_EMAIL="test@example.invalid",
            GIT_COMMITTER_NAME="Scaffold Test", GIT_COMMITTER_EMAIL="test@example.invalid",
            GIT_CONFIG_NOSYSTEM="1", GIT_CONFIG_GLOBAL=os.devnull,
        )

    def shim(self, name, body):
        directory = self.root / "bin"
        directory.mkdir(exist_ok=True)
        tool = directory / name
        tool.write_text("#!/bin/sh\n" + body)
        tool.chmod(0o755)
        self.env["PATH"] = str(directory) + os.pathsep + os.environ["PATH"]

    def run_scaffold(self):
        return subprocess.run(
            ["/bin/zsh", str(SCRIPT), "Demo", "com.example.demo", str(self.root)],
            env=self.env, capture_output=True, text=True, timeout=30,
        )

    def assert_failure(self, result):
        self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertNotIn("created ", result.stdout)
        self.assertFalse((self.dest / ".git").exists(), "Failure must stop before git init/commit")

    def assert_scaffold(self, result):
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        package = (self.dest / "Package.swift").read_text()
        self.assertIn('name: "DemoKit"', package)
        self.assertTrue((self.dest / "Sources/Demo").is_dir())
        self.assertTrue((self.dest / "Sources/DemoKit").is_dir())
        self.assertTrue((self.dest / "Tests/DemoKitTests").is_dir())
        for path in self.dest.rglob("*"):
            if not path.is_file() or ".git" in path.relative_to(self.dest).parts:
                continue
            content = path.read_bytes()
            self.assertNotIn(b"__APP_NAME__", content, str(path))
            self.assertNotIn(b"__BUNDLE_ID__", content, str(path))
        self.assertIn("com.example.demo", (self.dest / "Info.plist.in").read_text())
        self.assertTrue(os.access(self.dest / "build.sh", os.X_OK))
        commit = subprocess.run(["git", "log", "-1", "--format=%s"], cwd=self.dest,
                                env=self.env, capture_output=True, text=True, check=True)
        self.assertEqual(commit.stdout.strip(), "Create Demo from the macOS app template")

    def test_system_grep(self):
        self.assert_scaffold(self.run_scaffold())

    def test_grep_without_basic_regex_alternation(self):
        self.shim("grep", 'for arg do\n  case "$arg" in *\\\\\\|*) exit 1;; esac\ndone\nexec /usr/bin/grep "$@"\n')
        self.assert_scaffold(self.run_scaffold())

    def test_existing_files_and_git_metadata_survive(self):
        (self.dest / "docs").mkdir(parents=True)
        brief = self.dest / "docs/BRIEF.md"
        brief.write_text("Keep this project brief.\n")
        (self.dest / ".gitignore").write_text("custom-ignore\n")
        subprocess.run(["git", "init", "-q", str(self.dest)], env=self.env, check=True)
        note = self.dest / ".git/scaffold-test-note"
        note.write_text("__APP_NAME__ __BUNDLE_ID__\n")
        self.assert_scaffold(self.run_scaffold())
        self.assertEqual(brief.read_text(), "Keep this project brief.\n")
        self.assertIn("custom-ignore", (self.dest / ".gitignore").read_text())
        self.assertEqual(note.read_text(), "__APP_NAME__ __BUNDLE_ID__\n")

    def test_no_matches_stops_before_commit(self):
        self.shim("grep", 'case "$1" in -rlI*) exit 1;; esac\nexec /usr/bin/grep "$@"\n')
        self.assert_failure(self.run_scaffold())

    def test_search_error_stops_before_commit(self):
        self.shim("grep", 'case "$1" in -rlI*) exit 2;; esac\nexec /usr/bin/grep "$@"\n')
        self.assert_failure(self.run_scaffold())

    def test_sed_failure_stops_before_commit(self):
        self.shim("sed", "exit 2\n")
        self.assert_failure(self.run_scaffold())

    def test_sed_noop_is_detected(self):
        self.shim("sed", "exit 0\n")
        self.assert_failure(self.run_scaffold())

    def test_verification_error_stops_before_commit(self):
        self.env["GREP_TEST_STATE"] = str(self.root / "grep-called")
        self.shim("grep", '''case "$1" in
  -rlI*)
    if [ -f "$GREP_TEST_STATE" ]; then exit 2; fi
    touch "$GREP_TEST_STATE"
    ;;
esac
exec /usr/bin/grep "$@"
''')
        self.assert_failure(self.run_scaffold())


if __name__ == "__main__":
    unittest.main(verbosity=2)
