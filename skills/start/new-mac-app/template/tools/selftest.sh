#!/bin/zsh
# Runs the in-app self-test against a fresh store in /tmp. Exit code 0 when every check passed.
set -u
rm -rf ~/Library/Saved\ Application\ State/__BUNDLE_ID__.savedState
store=/tmp/__APP_NAME__-self.store
rm -f $store $store-shm $store-wal
APP_STORE=$store ~/Applications/__APP_NAME__.app/Contents/MacOS/__APP_NAME__ --selftest
