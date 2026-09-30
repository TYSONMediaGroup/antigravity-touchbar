# ✦ Antigravity Touch Bar for macOS & Ghostty

[![macOS](https://img.shields.io/badge/macOS-12.0%2B-black?logo=apple&logoColor=white)](https://apple.com)
[![Swift](https://img.shields.io/badge/Swift-6.0%2B-orange?logo=swift&logoColor=white)](https://swift.org)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Zero Dependencies](https://img.shields.io/badge/Dependencies-Zero-brightgreen.svg)](#)

A **100% native, free, zero-dependency macOS Touch Bar companion** for Google Antigravity CLI (`agy`) and Ghostty terminal. 

Brings your MacBook Touch Bar to life with real-time agent status, animated thinking indicators, and physical, color-coded **`✓ Yes`** and **`✗ No`** buttons whenever the agent asks for confirmation.

---

## ⚡️ Touch Bar Preview

### 1. Agent Thinking
```
┌───┬─────────────────────────────────────────────────────────────────────────┐
│ ✕ │  🧠 Thinking ⠋ Searching codebase...                                    │
└───┴─────────────────────────────────────────────────────────────────────────┘
```

### 2. Command Proposed / Confirmation Needed
```
┌───┬──────────────────────────────┬───────────────┬──────────────┬───────────┐
│ ✕ │  ⚡️ git push origin main     │   ✓ Yes (y)   │   ✗ No (n)   │ Always(a) │
└───┴──────────────────────────────┴───────────────┴──────────────┴───────────┘
```
*Tapping **`✓ Yes`** or **`✗ No`** instantly brings Ghostty forward and sends `y` + `Enter` or `n` + `Enter`.*

### 3. Idle / Control Strip
```
┌─────────────────────────────────────────────────────────────┬───────┬───────┐
│  (Normal App Touch Bar / Finder / IDE)                      │ AGY ✦ │  Vol  │
└─────────────────────────────────────────────────────────────┴───────┴───────┘
```
*When idle, it minimizes after 6 seconds to the **`AGY ✦`** button in the Control Strip.*

---

## ✨ Features

- **Zero External Dependencies**: Does **not** require BetterTouchTool, third-party apps, or paid licenses.
- **Pure Native Swift**: Uses Apple's native AppKit and Touch Bar Control Strip APIs (`DFRSystemModal`).
- **Interactive Yes/No Buttons**: Tap `[ ✓ Yes ]` (green) or `[ ✗ No ]` (red) directly on the Touch Bar to approve or deny proposed CLI commands.
- **Live Thinking Animation**: Braille spinner indicator rotates dynamically while the LLM generates answers.
- **Terminal Integration**: Optimized for Ghostty (`com.mitchellh.ghostty`), with automatic fallback to Terminal, iTerm2, Alacritty, or Kitty.
- **Background Daemon**: Runs as a lightweight macOS `LaunchAgent` (~8MB RAM, 0% CPU idle).
- **One-Command Install & Uninstall**.

---

## 🚀 Quick Start

### 1. Clone the repository
```bash
git clone https://github.com/TYSONMediaGroup/antigravity-touchbar.git
cd antigravity-touchbar
```

### 2. Run the installer
```bash
./install.sh
```

That's it! Look at your MacBook's Touch Bar: you'll see the **`AGY ✦`** icon in your Control Strip.

---

## 🛠 How It Works

```
Antigravity CLI (agy)
       │
       ▼ (Lifecycle Hooks: PreInvocation, PreToolUse, PostToolUse, Stop)
touchbar_hook.py
       │
       ▼ (Sub-millisecond state updates)
touchbar_state.json
       │
       ▼ (kqueue watcher & event loop)
AntigravityTouchBar (Native Swift Daemon)
       │
       ▼ (Apple System Modal / Control Strip APIs)
MacBook Touch Bar Display (Live Status + Interactive Yes/No Buttons)
```

1. **Lifecycle Hooks**: Whenever `agy` runs, it calls `touchbar_hook.py` on state transitions (`PreInvocation`, `PreToolUse`, `PostToolUse`, `Stop`).
2. **State Sync**: The hook writes current state to `~/.gemini/antigravity-cli/touchbar_state.json`.
3. **Swift Daemon**: `antigravity-touchbar` monitors this file via kernel `kqueue` notifications and instantly presents the Touch Bar UI.
4. **Keystroke Injection**: When a touch button is tapped, the daemon brings your terminal to front and dispatches the keystroke (`y\n`, `n\n`, or `a\n`).

---

## ⚙️ Configuration & Customization

You can adjust colors, fonts, or auto-dismiss timeouts in [`src/AntigravityTouchBar.swift`](src/AntigravityTouchBar.swift):

- **Auto-dismiss timeout**: Change `TimeInterval = 6.0` to keep the bar open longer or shorter when returning to idle.
- **Button styling**: Change `bezelColor` RGB values for `yesButton` or `noButton`.

After making changes, recompile and update with:
```bash
make install
```

---

## 🗑 Uninstallation

To cleanly remove the daemon, LaunchAgent, and hooks:

```bash
./uninstall.sh
```

---

## 📄 License

MIT License © 2026 Tyler Custine (TYSONMediaGroup). See [LICENSE](LICENSE) for details.
