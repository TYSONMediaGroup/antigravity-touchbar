.PHONY: build install uninstall test run clean

build:
	@echo "Compiling AntigravityTouchBar..."
	swiftc -O -o bin/antigravity-touchbar src/AntigravityTouchBar.swift

install:
	@./install.sh

uninstall:
	@./uninstall.sh

run: build
	@bin/antigravity-touchbar

test:
	@python3 hooks/touchbar_hook.py pre_invocation <<< '{}'
	@sleep 1
	@python3 hooks/touchbar_hook.py pre_tool <<< '{"toolCall": {"name": "run_command", "args": {"CommandLine": "git status"}}}'
	@sleep 2
	@python3 hooks/touchbar_hook.py stop <<< '{}'
	@echo "Test events sent successfully."

clean:
	@rm -rf bin
