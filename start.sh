#!/usr/bin/env bash
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$DIR"

if [ ! -d "ScrollReverse.app" ]; then
    echo "ScrollReverse.app not found. Building first..."
    ./build.sh
fi

echo "Launching Scroll Reverse in Menu Bar..."
open -n ScrollReverse.app
echo "Started! Look for the mouse icon in your top macOS Menu Bar."
