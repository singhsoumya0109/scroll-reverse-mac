# Scroll Reverse for macOS (Apple Silicon M4)

A native, ultra-lightweight macOS Menu Bar application (~94 KB, 0.0% CPU) designed specifically to **invert the external mouse scroll wheel direction while keeping macOS "Natural Scrolling" untouched for your trackpad**.

---

## Why this is needed

On macOS, the **"Natural Scrolling"** setting in *System Settings > Trackpad / Mouse* links trackpad and mouse scrolling together:
- When Natural Scrolling is **ON**, trackpad gestures feel natural (like an iPad), but moving a physical mouse wheel scrolls in reverse compared to Windows.
- When Natural Scrolling is **OFF**, the mouse wheel scrolls normally like Windows, but trackpad two-finger scrolling feels backwards.

**Scroll Reverse fixes this dilemma:**
It intercepts discrete scroll events from traditional mouse wheels (`continuous == 0`) and reverses their direction, while leaving continuous gesture events from your built-in trackpad (`continuous != 0`) completely untouched.

---

## Quick Start

### 1. Launch the App
In Terminal, simply run:
```bash
./start.sh
```
Or double-click **`ScrollReverse.app`** directly in Finder.

A small mouse icon (🖱️) will appear in your top macOS Menu Bar.

---

### 2. Grant Accessibility Permission (One-time macOS requirement)

macOS requires accessibility permissions for any app that intercepts input device events:

1. When you first start the app, macOS may prompt:  
   *"Scroll Reverse would like to control this computer using accessibility features."*
2. Click **Open System Settings** (or navigate to **System Settings > Privacy & Security > Accessibility**).
3. Turn **ON** the toggle next to **Scroll Reverse** (or add `ScrollReverse.app`).
4. Scroll Reverse detects the permission automatically—you don't even need to restart it! The menu bar status will change to:
   > `Status: ● Active (Mouse Inverted)`

---

## Features & Menu Bar Options

Click the mouse icon in your top menu bar to see:

- **Status Indicator**: Shows whether scroll reversal is active or waiting for Accessibility permission.
- **Enable Scroll Reversal**: Quick master switch to turn inversion on or off.
- **Reverse Vertical Scroll (Wheel)**: Inverts the vertical mouse wheel (Enabled by default).
- **Reverse Horizontal Scroll (Wheel)**: Inverts horizontal tilt/thumb wheels (Optional).
- **Start at Login**: Installs a lightweight user LaunchAgent so Scroll Reverse starts silently whenever you log in.
- **Open Accessibility Settings...**: Shortcut to macOS Privacy settings if needed.
- **Quit Scroll Reverse**: Completely exits the application.

---

## Commands & Scripts

| Script | Purpose |
|---|---|
| `./start.sh` | Builds (if needed) and starts the app in the background |
| `./stop.sh` | Quits the running Scroll Reverse application |
| `./build.sh` | Recompiles `ScrollReverse.app` from source code |
| `./install.sh` | Copies `ScrollReverse.app` to your `/Applications` folder |

---

## Technical Details

- **Native Architecture**: Compiled directly for `arm64` (Apple Silicon M1/M2/M3/M4).
- **Zero Overhead**: Native AppKit + CoreGraphics (`CGEventTap`), no Electron or heavy runtimes.
- **Binary Size**: ~94 KB.
- **Memory footprint**: ~10–15 MB.
- **Smooth Recovery**: Handles macOS event tap timeouts (`kCGEventTapDisabledByTimeout`) with auto-reconnect so scrolling never stutters.
