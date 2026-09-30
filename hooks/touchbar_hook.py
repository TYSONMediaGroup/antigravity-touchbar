#!/usr/bin/env python3
"""
Antigravity Lifecycle Hook for Touch Bar Integration
Relays agent execution loop events (thinking, tool execution, prompts, idle)
to the native macOS Touch Bar daemon in real time.
"""
import sys
import json
import os
import time
import subprocess

STATE_FILE = os.path.expanduser("~/.gemini/antigravity-cli/touchbar_state.json")
APP_DAEMON_BIN = os.path.expanduser("~/.gemini/antigravity-cli/bin/AntigravityTouchBar.app/Contents/MacOS/antigravity-touchbar")
LEGACY_DAEMON_BIN = os.path.expanduser("~/.gemini/antigravity-cli/bin/antigravity-touchbar")
DAEMON_BIN = APP_DAEMON_BIN if os.path.exists(APP_DAEMON_BIN) else LEGACY_DAEMON_BIN

def ensure_daemon_running():
    try:
        res = subprocess.run(["pgrep", "-f", "antigravity-touchbar"], stdout=subprocess.DEVNULL)
        if res.returncode != 0 and os.path.exists(DAEMON_BIN):
            subprocess.Popen([DAEMON_BIN], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, start_new_session=True)
    except Exception:
        pass

def write_state(state, title=None, detail="", show_yes_no=False, command=""):
    ensure_daemon_running()
    payload = {
        "state": state,
        "title": title or ("Thinking..." if state == "thinking" else "Antigravity"),
        "detail": detail,
        "showYesNo": show_yes_no,
        "command": command,
        "timestamp": time.time()
    }
    try:
        os.makedirs(os.path.dirname(STATE_FILE), exist_ok=True)
        with open(STATE_FILE, "w") as f:
            json.dump(payload, f)
            f.flush()
    except Exception:
        pass

def main():
    event_type = sys.argv[1] if len(sys.argv) > 1 else ""
    
    # Read stdin context if available
    input_data = {}
    try:
        if not sys.stdin.isatty():
            content = sys.stdin.read()
            if content.strip():
                input_data = json.loads(content)
    except Exception:
        pass

    if event_type == "pre_invocation":
        write_state(state="thinking", title="Thinking...", detail="", show_yes_no=False)
        # PreInvocation contract: expects injectSteps array
        print(json.dumps({"injectSteps": []}))
        
    elif event_type == "pre_tool":
        tool_call = input_data.get("toolCall", {})
        tool_name = tool_call.get("name", "tool")
        args = tool_call.get("args", {})
        
        cmd = ""
        if tool_name == "run_command":
            cmd = args.get("CommandLine", "").strip()
            write_state(state="confirm", title="Confirm Command", detail=cmd, show_yes_no=True, command=cmd)
        elif tool_name in ("write_to_file", "replace_file_content"):
            target = os.path.basename(args.get("TargetFile", ""))
            desc = f"{tool_name} ({target})"
            write_state(state="command", title="Editing File", detail=desc, show_yes_no=False, command=desc)
        elif tool_name == "ask_question":
            write_state(state="confirm", title="Question Prompt", detail="Select Option", show_yes_no=True, command="Question")
        else:
            write_state(state="command", title=f"Running {tool_name}", detail=tool_name, show_yes_no=False, command=tool_name)
            
        # CRITICAL: PreToolUse contract requires decision: "allow"
        print(json.dumps({"decision": "allow"}))
        
    elif event_type == "post_tool":
        write_state(state="tool_done", title="Completed", detail="", show_yes_no=False)
        # PostToolUse contract: expects empty JSON object {}
        print(json.dumps({}))
        
    elif event_type == "stop":
        write_state(state="idle", title="Antigravity Ready", detail="", show_yes_no=False)
        # Stop contract: expects decision: ""
        print(json.dumps({"decision": ""}))
        
    else:
        print(json.dumps({}))

if __name__ == "__main__":
    main()
