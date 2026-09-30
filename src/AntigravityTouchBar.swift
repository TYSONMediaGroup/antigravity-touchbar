import AppKit
import Carbon

// MARK: - Private NSTouchBar Selectors
private let presentSel = NSSelectorFromString("presentSystemModalTouchBar:systemTrayItemIdentifier:")
private let dismissSel = NSSelectorFromString("dismissSystemModalTouchBar:")
private let addTraySel = NSSelectorFromString("addSystemTrayItem:")
private let removeTraySel = NSSelectorFromString("removeSystemTrayItem:")

// MARK: - State Model
struct AgentState: Codable {
    var state: String       // "idle", "thinking", "confirm", "command", "tool_done"
    var title: String?
    var detail: String?
    var showYesNo: Bool?
    var command: String?
    var timestamp: Double?
}

// MARK: - TouchBar Controller
class AntigravityTouchBarController: NSObject, NSTouchBarDelegate {
    static let shared = AntigravityTouchBarController()
    
    private let trayItemId = NSTouchBarItem.Identifier("com.google.antigravity.touchbar.tray")
    private let closeItemId = NSTouchBarItem.Identifier("com.google.antigravity.touchbar.close")
    private let statusItemId = NSTouchBarItem.Identifier("com.google.antigravity.touchbar.status")
    private let yesItemId = NSTouchBarItem.Identifier("com.google.antigravity.touchbar.yes")
    private let noItemId = NSTouchBarItem.Identifier("com.google.antigravity.touchbar.no")
    private let alwaysItemId = NSTouchBarItem.Identifier("com.google.antigravity.touchbar.always")
    
    private var touchBar: NSTouchBar?
    private var trayItem: NSCustomTouchBarItem?
    
    // UI Elements
    private var statusLabel: NSTextField!
    private var yesButton: NSButton!
    private var noButton: NSButton!
    private var alwaysButton: NSButton!
    
    // Animation & Timers
    private var thinkingTimer: Timer?
    private var autoDismissTimer: Timer?
    private var spinnerIndex = 0
    private let spinnerFrames = ["⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏"]
    
    private var currentState: AgentState = AgentState(state: "idle", title: "Antigravity", detail: nil, showYesNo: false, command: nil)
    private var isPresented = false
    private var lastTimestamp: Double = 0.0
    
    override init() {
        super.init()
        setupUI()
        setupTouchBar()
        setupControlStrip()
        startFileWatcher()
    }
    
    // MARK: - UI Construction
    private func setupUI() {
        statusLabel = NSTextField(labelWithString: "✨ Antigravity Ready")
        statusLabel.font = NSFont.monospacedSystemFont(ofSize: 13, weight: .semibold)
        statusLabel.textColor = .white
        statusLabel.alignment = .left
        statusLabel.lineBreakMode = .byTruncatingTail
        statusLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        
        // Yes Button (Vibrant Green)
        yesButton = NSButton(title: " ✓ Yes (y) ", target: self, action: #selector(handleYes))
        yesButton.bezelStyle = .rounded
        yesButton.font = NSFont.systemFont(ofSize: 13, weight: .bold)
        yesButton.bezelColor = NSColor(calibratedRed: 0.18, green: 0.80, blue: 0.44, alpha: 1.0)
        
        // No Button (Vibrant Red)
        noButton = NSButton(title: " ✗ No (n) ", target: self, action: #selector(handleNo))
        noButton.bezelStyle = .rounded
        noButton.font = NSFont.systemFont(ofSize: 13, weight: .bold)
        noButton.bezelColor = NSColor(calibratedRed: 0.90, green: 0.25, blue: 0.25, alpha: 1.0)
        
        // Always Button (Slate Gray)
        alwaysButton = NSButton(title: " Always (a) ", target: self, action: #selector(handleAlways))
        alwaysButton.bezelStyle = .rounded
        alwaysButton.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        alwaysButton.bezelColor = NSColor(calibratedRed: 0.35, green: 0.38, blue: 0.45, alpha: 1.0)
    }
    
    private func setupTouchBar() {
        let tb = NSTouchBar()
        tb.delegate = self
        tb.defaultItemIdentifiers = [
            closeItemId,
            statusItemId,
            .flexibleSpace,
            yesItemId,
            noItemId,
            alwaysItemId
        ]
        self.touchBar = tb
    }
    
    private func setupControlStrip() {
        let item = NSCustomTouchBarItem(identifier: trayItemId)
        let btn = NSButton(title: "AGY ✦", target: self, action: #selector(toggleTouchBar))
        btn.bezelStyle = .rounded
        btn.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .bold)
        item.view = btn
        self.trayItem = item
        
        if (NSTouchBarItem.self as AnyObject).responds(to: addTraySel) {
            _ = (NSTouchBarItem.self as AnyObject).perform(addTraySel, with: item)
        }
    }
    
    // MARK: - NSTouchBarDelegate
    func touchBar(_ touchBar: NSTouchBar, makeItemForIdentifier identifier: NSTouchBarItem.Identifier) -> NSTouchBarItem? {
        switch identifier {
        case closeItemId:
            let item = NSCustomTouchBarItem(identifier: identifier)
            let btn = NSButton(image: NSImage(systemSymbolName: "xmark.circle.fill", accessibilityDescription: "Close") ?? NSImage(), target: self, action: #selector(dismissTouchBar))
            btn.bezelStyle = .rounded
            item.view = btn
            return item
            
        case statusItemId:
            let item = NSCustomTouchBarItem(identifier: identifier)
            item.view = statusLabel
            return item
            
        case yesItemId:
            let item = NSCustomTouchBarItem(identifier: identifier)
            item.view = yesButton
            return item
            
        case noItemId:
            let item = NSCustomTouchBarItem(identifier: identifier)
            item.view = noButton
            return item
            
        case alwaysItemId:
            let item = NSCustomTouchBarItem(identifier: identifier)
            item.view = alwaysButton
            return item
            
        default:
            return nil
        }
    }
    
    // MARK: - Actions
    @objc func toggleTouchBar() {
        if isPresented {
            dismissTouchBar()
        } else {
            presentTouchBar()
        }
    }
    
    func presentTouchBar() {
        guard let tb = touchBar, let tray = trayItem else { return }
        if NSTouchBar.responds(to: presentSel) {
            _ = NSTouchBar.perform(presentSel, with: tb, with: tray.identifier)
            isPresented = true
        }
    }
    
    @objc func dismissTouchBar() {
        guard let tb = touchBar else { return }
        if NSTouchBar.responds(to: dismissSel) {
            _ = NSTouchBar.perform(dismissSel, with: tb)
            isPresented = false
        }
    }
    
    @objc func handleYes() {
        sendKeystrokeToTerminal("y\n")
        flashFeedback("Approved ✓")
    }
    
    @objc func handleNo() {
        sendKeystrokeToTerminal("n\n")
        flashFeedback("Denied ✗")
    }
    
    @objc func handleAlways() {
        sendKeystrokeToTerminal("a\n")
        flashFeedback("Always Allowed")
    }
    
    private func flashFeedback(_ text: String) {
        statusLabel.stringValue = text
        yesButton.isHidden = true
        noButton.isHidden = true
        alwaysButton.isHidden = true
    }
    
    // MARK: - State Update
    func update(state: AgentState) {
        DispatchQueue.main.async {
            self.currentState = state
            self.autoDismissTimer?.invalidate()
            
            let showButtons = state.showYesNo ?? (state.state == "confirm" || state.state == "command")
            self.yesButton.isHidden = !showButtons
            self.noButton.isHidden = !showButtons
            self.alwaysButton.isHidden = !showButtons
            
            switch state.state {
            case "thinking":
                self.startThinkingAnimation(detail: state.detail ?? "")
                self.presentTouchBar()
                
            case "command", "confirm":
                self.stopThinkingAnimation()
                let cmd = state.command ?? state.detail ?? "Action"
                let truncated = cmd.count > 38 ? String(cmd.prefix(35)) + "..." : cmd
                self.statusLabel.stringValue = "⚡️ " + truncated
                self.presentTouchBar()
                
            case "tool_done":
                self.stopThinkingAnimation()
                self.statusLabel.stringValue = "✅ Completed"
                
            case "idle":
                self.stopThinkingAnimation()
                self.statusLabel.stringValue = "✨ Antigravity Ready"
                // Auto-minimize after 6 seconds of idle to return to regular app touchbar
                self.autoDismissTimer = Timer.scheduledTimer(withTimeInterval: 6.0, repeats: false) { [weak self] _ in
                    self?.dismissTouchBar()
                }
                
            default:
                self.stopThinkingAnimation()
                self.statusLabel.stringValue = state.title ?? "✨ Antigravity"
            }
        }
    }
    
    private func startThinkingAnimation(detail: String) {
        thinkingTimer?.invalidate()
        spinnerIndex = 0
        let suffix = detail.isEmpty ? "" : " - " + detail
        thinkingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            let frame = self.spinnerFrames[self.spinnerIndex % self.spinnerFrames.count]
            self.statusLabel.stringValue = "🧠 Thinking " + frame + suffix
            self.spinnerIndex += 1
        }
    }
    
    private func stopThinkingAnimation() {
        thinkingTimer?.invalidate()
        thinkingTimer = nil
    }
    
    // MARK: - Send Keystroke to Active Terminal
    private func sendKeystrokeToTerminal(_ str: String) {
        // Find target terminal app: Ghostty preferred, then fall back to active app
        let targetBundleIds = [
            "com.mitchellh.ghostty",
            "com.apple.Terminal",
            "com.googlecode.iterm2",
            "org.alacritty",
            "net.kovidgoyal.kitty"
        ]
        
        var targetApp: NSRunningApplication?
        for bundleId in targetBundleIds {
            if let app = NSRunningApplication.runningApplications(withBundleIdentifier: bundleId).first {
                targetApp = app
                break
            }
        }
        
        if let app = targetApp {
            app.activate()
            usleep(25000) // 25ms delay to ensure focus
            
            let charToSend = str.replacingOccurrences(of: "\n", with: "")
            let processName = app.localizedName ?? "terminal"
            let scriptSource = """
            tell application "System Events"
                tell process "\(processName)"
                    keystroke "\(charToSend)"
                    key code 36
                end tell
            end tell
            """
            if let appleScript = NSAppleScript(source: scriptSource) {
                var error: NSDictionary?
                appleScript.executeAndReturnError(&error)
            }
        }
    }
    
    // MARK: - State File Watcher
    private func startFileWatcher() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let stateUrl = home.appendingPathComponent(".gemini/antigravity-cli/touchbar_state.json")
        let path = stateUrl.path
        
        readState(from: path)
        
        // Fast polling timer (every 0.25s) for instant response
        Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            self?.readState(from: path)
        }
        
        // File system kqueue watcher
        let fd = open(path, O_EVTONLY)
        if fd >= 0 {
            let source = DispatchSource.makeFileSystemObjectSource(fileDescriptor: fd, eventMask: [.write, .extend, .attrib], queue: .main)
            source.setEventHandler { [weak self] in
                self?.readState(from: path)
            }
            source.setCancelHandler {
                close(fd)
            }
            source.resume()
        }
    }
    
    private func readState(from path: String) {
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let stateStr = json["state"] as? String else {
            return
        }
        let ts = json["timestamp"] as? Double ?? 0.0
        if ts != lastTimestamp {
            lastTimestamp = ts
            let title = json["title"] as? String
            let detail = json["detail"] as? String
            let showYesNo = json["showYesNo"] as? Bool
            let cmd = json["command"] as? String
            let state = AgentState(state: stateStr, title: title, detail: detail, showYesNo: showYesNo, command: cmd, timestamp: ts)
            print("[AntigravityTouchBar] Event: \(stateStr) - \(cmd ?? detail ?? "")")
            self.update(state: state)
        }
    }
}

// MARK: - Application Entry Point
class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        _ = AntigravityTouchBarController.shared
        print("[AntigravityTouchBar] Ready and listening for events.")
    }
}

let app = NSApplication.shared
setlinebuf(stdout)
app.setActivationPolicy(.accessory) // Hidden from Dock & App Switcher
let delegate = AppDelegate()
app.delegate = delegate
app.run()
