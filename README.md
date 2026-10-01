<p align="center">
  <a href="https://tysonmediagroup.org">
    <img src="https://raw.githubusercontent.com/TYSONMediaGroup/tysonmediagroup.org.myt5s.app/main/assets/LOGOSFORGEMINI/TYSONMediaGroupBanner.png" alt="TYSON Media Group" width="700">
  </a>
</p>

<h1 align="center">Antigravity Touch Bar for macOS & Ghostty</h1>

<p align="center">
  <a href="https://apple.com"><img src="https://img.shields.io/badge/macOS-12.0%2B-black?logo=apple&logoColor=white" alt="macOS"></a>
  <a href="https://swift.org"><img src="https://img.shields.io/badge/Swift-6.0%2B-orange?logo=swift&logoColor=white" alt="Swift"></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/License-MIT-blue.svg" alt="License: MIT"></a>
  <a href="#"><img src="https://img.shields.io/badge/Dependencies-Zero-brightgreen.svg" alt="Zero Dependencies"></a>
</p>

> [!IMPORTANT]
> **Current version is v0.1:** _**ALPHA**__ this is not necessarily a stable release _yet_. [Read the Antigravity-Touchbar guide](https://myt5s.app/tysonmediagroup/antigravity-touchbar/).

A native, zero-dependency macOS Touch Bar companion for Google Antigravity CLI (`agy`) and Ghostty terminal.

Brings the terminal's native CLI aesthetics to your MacBook Touch Bar: live braille dot orbit spinners, dynamic blue wave pulse shimmer across running commands, and interactive `Yes (y)` / `No (n)` confirmation buttons when prompts appear.

---

## Touch Bar Layout

### 1. Model Thinking
```
+-----+-----------------------------------------------------------------------+
| Esc | [✦]  ⠋ Thinking: Searching codebase...                                |
+-----+-----------------------------------------------------------------------+
```

### 2. Command Executing (Blue Wave Shimmer Pulse)
```
+-----+-----------------------------------------------------------------------+
| Esc | [✦]  ⠹ Running: cargo test --all...                                   |
+-----+-----------------------------------------------------------------------+
```
*The command text dynamically pulses with an electric-blue shimmer across the OLED display.*

### 3. Interactive Confirmation Needed
```
+-----+----------------------------+-------------+------------+---------------+
| Esc | [✦]  Confirm: Run deploy   |   Yes (y)   |   No (n)   |   Always (a)  |
+-----+----------------------------+-------------+------------+---------------+
```
*Tapping `Yes` or `No` brings Ghostty forward and sends `y` + `Enter` or `n` + `Enter` directly to the active terminal process.*

### 4. Idle / Control Strip
```
+-----------------------------------------------------------+---------+-------+
| (Active Application Touch Bar Controls)                   | [✦] AGY |  Vol  |
+-----------------------------------------------------------+---------+-------+
```
*When idle, the bar minimizes after 5 seconds to the `[✦] AGY` button in the Control Strip. Tap anytime to expand.*

---

## Features

- Zero External Dependencies: Built entirely with Apple AppKit and Touch Bar APIs (`DFRFoundation`, `NSTouchBar`). Does not require BetterTouchTool, paid software, or third-party utilities.
- Terminal-Matched Aesthetics: Monospaced typography, rotating braille dot orbit indicators, and an animated electric-blue pulse wave that sweeps across executing commands.
- Vector Antigravity Logo: Features the Antigravity four-point sparkle star logo rendered cleanly in pure vector curves.
- Zero Emojis: Clean, distraction-free developer interface matching professional terminal tools.
- Dual-Mode Keystroke Dispatcher: Uses low-level macOS CoreGraphics events (`CGEventPostToPid`) targeting Ghostty, with automatic fallbacks for Terminal.app, iTerm2, Alacritty, and Kitty.
- Lightweight Background Daemon: Runs as a native background `LaunchAgent` (~7MB RAM, 0% CPU at idle).
- Single-Command Installer: Automated compilation and lifecycle hook registration.

---

## Quick Start

### 1. Clone the repository
```bash
git clone https://github.com/TYSONMediaGroup/antigravity-touchbar.git
cd antigravity-touchbar
```

### 2. Install
```bash
./install.sh
```

The installer compiles the native application bundle (`AntigravityTouchBar.app`), registers the Antigravity CLI lifecycle hooks, and loads the background LaunchAgent. You will see the `[✦] AGY` icon appear in your MacBook Touch Bar Control Strip.

---

## Architecture

```
Antigravity CLI (agy)
       |
       v (Lifecycle Hooks: PreInvocation, PreToolUse, PostToolUse, Stop)
touchbar_hook.py
       |
       v (Sub-millisecond state updates)
touchbar_state.json
       |
       v (kqueue kernel watcher & 60ms pulse animation loop)
AntigravityTouchBar.app (Native Swift Daemon)
       |
       v (Apple System Modal / DFRFoundation)
MacBook Touch Bar Display (Dynamic Blue Wave Shimmer + Touch Controls)
```

1. Lifecycle Hooks: When `agy` executes, it triggers `touchbar_hook.py` on state transitions (`PreInvocation`, `PreToolUse`, `PostToolUse`, `Stop`).
2. State Dispatch: The hook writes structured states to `~/.gemini/antigravity-cli/touchbar_state.json`.
3. Swift Daemon: `AntigravityTouchBar` receives file notifications and drives the Touch Bar OLED display with custom CoreGraphics rendering.
4. Terminal Focus: Tapping a touch control sends the corresponding keystroke directly into Ghostty.

---

## Customization

You can adjust colors, pulse wave speeds, and auto-dismiss timeouts in [`src/AntigravityTouchBar.swift`](src/AntigravityTouchBar.swift):

- Auto-dismiss timeout: Edit `TimeInterval = 5.0` in `update(state:)` to change how long the bar remains visible after returning to idle.
- Pulse shimmer colors: Modify the RGB constants in `renderPulseFrame()` to customize the blue wave gradient.
- Button colors: Modify the `bezelColor` values in `setupUI()`.

After modifying, recompile and reinstall with:
```bash
make install
```

---

## Uninstallation

To cleanly remove the daemon, LaunchAgent, and hook registrations:

```bash
./uninstall.sh
```

---

## License

MIT License. Copyright (c) 2026 Tyler Custine (TYSONMediaGroup). See [LICENSE](LICENSE) for details.
