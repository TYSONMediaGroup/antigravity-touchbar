.PHONY: build install uninstall test run clean

build:
	@echo "Compiling AntigravityTouchBar.app..."
	@mkdir -p bin/AntigravityTouchBar.app/Contents/MacOS
	@cp resources/Info.plist bin/AntigravityTouchBar.app/Contents/
	@swiftc -O -o bin/AntigravityTouchBar.app/Contents/MacOS/antigravity-touchbar src/AntigravityTouchBar.swift
	@echo "Built bin/AntigravityTouchBar.app"

install:
	@./install.sh

uninstall:
	@./uninstall.sh

run: build
	@open bin/AntigravityTouchBar.app

test:
	@python3 hooks/touchbar_hook.py pre_invocation <<< '{}'
	@sleep 1
	@python3 hooks/touchbar_hook.py pre_tool <<< '{"toolCall": {"name": "run_command", "args": {"CommandLine": "git status"}}}'
	@sleep 2
	@python3 hooks/touchbar_hook.py stop <<< '{}'
	@echo "Test events sent successfully."

clean:
	@rm -rf bin
