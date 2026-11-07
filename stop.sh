#!/usr/bin/env bash
echo "Stopping Scroll Reverse..."
pkill -x ScrollReverse 2>/dev/null || pkill -f "ScrollReverse.app" 2>/dev/null || true
echo "Scroll Reverse stopped."
