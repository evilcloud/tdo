#!/usr/bin/env bash
# Build and launch the macOS app without tying up the terminal.
set -e
swift build --product tdo-mac
open ".build/debug/tdo-mac.app" >/dev/null 2>&1 &
disown
echo "tdo launched in background"
