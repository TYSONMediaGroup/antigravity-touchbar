#!/usr/bin/env bash
set -e

GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=== Uninstalling Antigravity Touch Bar ===${NC}"

# 1. Unload & remove LaunchAgent
PLIST_PATH="$HOME/Library/LaunchAgents/com.google.antigravity.touchbar.plist"
if [[ -f "$PLIST_PATH" ]]; then
    launchctl unload "$PLIST_PATH" 2>/dev/null || true
    rm -f "$PLIST_PATH"
    echo -e "${GREEN}✓ Removed LaunchAgent${NC}"
fi

# 2. Kill daemon process if running
killall antigravity-touchbar 2>/dev/null || true

# 3. Remove hook from ~/.gemini/config/hooks.json
python3 - << 'EOF'
import json, os

config_path = os.path.expanduser("~/.gemini/config/hooks.json")
if os.path.exists(config_path):
    try:
        with open(config_path, "r") as f:
            data = json.load(f)
        if "touchbar-integration" in data:
            del data["touchbar-integration"]
            with open(config_path, "w") as f:
                json.dump(data, f, indent=2)
            print("✓ Removed hook from ~/.gemini/config/hooks.json")
    except Exception:
        pass
EOF

# 4. Remove binaries
rm -f "$HOME/.gemini/antigravity-cli/bin/antigravity-touchbar"
rm -f "$HOME/.gemini/antigravity-cli/scripts/touchbar_hook.py"

echo -e "\n${GREEN}=== Uninstallation Complete ===${NC}"
