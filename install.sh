#!/usr/bin/env bash
set -e

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$DIR"

echo "==> Building latest version..."
./build.sh

echo "==> Installing to /Applications..."
rm -rf /Applications/ScrollReverse.app
cp -R ScrollReverse.app /Applications/

echo "==> Installation complete! You can find Scroll Reverse in /Applications and Spotlight."
echo "==> To start now, run: open /Applications/ScrollReverse.app"
