#!/usr/bin/env bash
set -e

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== Antigravity Touch Bar Installer ===${NC}"

# 1. Platform Check
if [[ "$(uname)" != "Darwin" ]]; then
    echo -e "${RED}Error: This tool is only supported on macOS with a Touch Bar.${NC}"
    exit 1
fi

# 2. Check Prerequisites
echo "Checking prerequisites..."
if ! command -v swiftc &> /dev/null; then
    echo -e "${RED}Error: 'swiftc' compiler not found.${NC}"
    echo "Install Apple Command Line Tools by running: xcode-select --install"
    exit 1
fi

if ! command -v python3 &> /dev/null; then
    echo -e "${RED}Error: 'python3' not found.${NC}"
    exit 1
fi

# 3. Create Required Directories
TARGET_BIN_DIR="$HOME/.gemini/antigravity-cli/bin"
TARGET_SCRIPTS_DIR="$HOME/.gemini/antigravity-cli/scripts"
TARGET_CONFIG_DIR="$HOME/.gemini/config"
TARGET_TOUCHBAR_DIR="$HOME/.gemini/antigravity-cli/touchbar"
LAUNCH_AGENTS_DIR="$HOME/Library/LaunchAgents"

mkdir -p "$TARGET_BIN_DIR" "$TARGET_SCRIPTS_DIR" "$TARGET_CONFIG_DIR" "$TARGET_TOUCHBAR_DIR" "$LAUNCH_AGENTS_DIR"

# 4. Compile Swift Daemon
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
echo "Compiling native Touch Bar daemon..."
swiftc -O -o "$TARGET_BIN_DIR/antigravity-touchbar" "$SCRIPT_DIR/src/AntigravityTouchBar.swift"
echo -e "${GREEN}✓ Compiled antigravity-touchbar binary${NC}"

# 5. Copy Hook Script
cp "$SCRIPT_DIR/hooks/touchbar_hook.py" "$TARGET_SCRIPTS_DIR/touchbar_hook.py"
chmod +x "$TARGET_SCRIPTS_DIR/touchbar_hook.py"
echo -e "${GREEN}✓ Installed lifecycle hook script${NC}"

# 6. Initialize State File
if [[ ! -f "$HOME/.gemini/antigravity-cli/touchbar_state.json" ]]; then
    cat << 'EOF' > "$HOME/.gemini/antigravity-cli/touchbar_state.json"
{
  "state": "idle",
  "title": "Antigravity Ready",
  "detail": "",
  "showYesNo": false,
  "command": ""
}
EOF
fi

# 7. Merge Hook into ~/.gemini/config/hooks.json
python3 - << 'EOF'
import json, os

config_path = os.path.expanduser("~/.gemini/config/hooks.json")
script_path = os.path.expanduser("~/.gemini/antigravity-cli/scripts/touchbar_hook.py")

data = {}
if os.path.exists(config_path):
    try:
        with open(config_path, "r") as f:
            data = json.load(f)
    except Exception:
        data = {}

data["touchbar-integration"] = {
    "enabled": True,
    "PreInvocation": [
        {
            "type": "command",
            "command": f"python3 {script_path} pre_invocation"
        }
    ],
    "PreToolUse": [
        {
            "matcher": "*",
            "hooks": [
                {
                    "type": "command",
                    "command": f"python3 {script_path} pre_tool"
                }
            ]
        }
    ],
    "PostToolUse": [
        {
            "matcher": "*",
            "hooks": [
                {
                    "type": "command",
                    "command": f"python3 {script_path} post_tool"
                }
            ]
        }
    ],
    "Stop": [
        {
            "type": "command",
            "command": f"python3 {script_path} stop"
        }
    ]
}

with open(config_path, "w") as f:
    json.dump(data, f, indent=2)

print("✓ Registered lifecycle hooks in ~/.gemini/config/hooks.json")
EOF

# 8. Setup macOS LaunchAgent
PLIST_PATH="$LAUNCH_AGENTS_DIR/com.google.antigravity.touchbar.plist"
cat << EOF > "$PLIST_PATH"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.google.antigravity.touchbar</string>
    <key>ProgramArguments</key>
    <array>
        <string>$TARGET_BIN_DIR/antigravity-touchbar</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>StandardErrorPath</key>
    <string>$TARGET_TOUCHBAR_DIR/touchbar.log</string>
    <key>StandardOutPath</key>
    <string>$TARGET_TOUCHBAR_DIR/touchbar.log</string>
</dict>
</plist>
EOF

# 9. Reload LaunchAgent
launchctl unload "$PLIST_PATH" 2>/dev/null || true
launchctl load "$PLIST_PATH"
echo -e "${GREEN}✓ Loaded background LaunchAgent${NC}"

echo -e "\n${GREEN}=== Installation Complete! ===${NC}"
echo "You will now see 'AGY ✦' on your MacBook Touch Bar Control Strip."
echo "Live thinking states, command notifications, and [ ✓ Yes ] / [ ✗ No ] buttons are active!"
