import AppKit
import Carbon

// MARK: - Direct DFRFoundation Symbols
@_silgen_name("DFRElementSetControlStripPresenceForIdentifier")
func DFRElementSetControlStripPresenceForIdentifier(_ identifier: NSString, _ present: Bool)

@_silgen_name("DFRSystemModalShowsCloseBoxWhenFrontMost")
func DFRSystemModalShowsCloseBoxWhenFrontMost(_ shows: Bool)

// MARK: - Private NSTouchBar Selectors
private let presentSel = NSSelectorFromString("presentSystemModalTouchBar:systemTrayItemIdentifier:")
private let dismissSel = NSSelectorFromString("dismissSystemModalTouchBar:")
private let addTraySel = NSSelectorFromString("addSystemTrayItem:")
private let removeTraySel = NSSelectorFromString("removeSystemTrayItem:")

// MARK: - Official Antigravity Vector Logo Generator
func makeAntigravityLogo(size: NSSize = NSSize(width: 16, height: 16)) -> NSImage {
    // Official Google Antigravity rocket-chevron vector glyph
    let svgString = """
    <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" width="\(Int(size.width))" height="\(Int(size.height))">
      <path fill="white" fill-rule="evenodd" d="M21.751 22.607c1.34 1.005 3.35.335 1.508-1.508C17.73 15.74 18.904 1 12.037 1 5.17 1 6.342 15.74.815 21.1c-2.01 2.009.167 2.511 1.507 1.506 5.192-3.517 4.857-9.714 9.715-9.714 4.857 0 4.522 6.197 9.714 9.715z"/>
    </svg>
    """
    if let data = svgString.data(using: .utf8), let img = NSImage(data: data) {
        img.size = size
        img.isTemplate = true
        return img
    }
    return NSImage()
}

// MARK: - Vertically Centered Label Cell
class VerticallyCenteredTextFieldCell: NSTextFieldCell {
    override func drawingRect(forBounds rect: NSRect) -> NSRect {
        var newRect = super.drawingRect(forBounds: rect)
        let textSize = cellSize(forBounds: rect)
        // Adjust vertically so font baseline sits optically dead-center in the Touch Bar strip
        let deltaY = (rect.height - textSize.height) / 2.0 + 1.0
        if deltaY > 0 {
            newRect.origin.y += deltaY
            newRect.size.height -= deltaY
        }
        return newRect
    }
}

// MARK: - State Model
struct AgentState: Codable {
    var state: String       // "idle", "thinking", "running", "confirm", "done"
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
    private let logoItemId = NSTouchBarItem.Identifier("com.google.antigravity.touchbar.logo")
    private let statusItemId = NSTouchBarItem.Identifier("com.google.antigravity.touchbar.status")
    private let yesItemId = NSTouchBarItem.Identifier("com.google.antigravity.touchbar.yes")
    private let noItemId = NSTouchBarItem.Identifier("com.google.antigravity.touchbar.no")
    private let alwaysItemId = NSTouchBarItem.Identifier("com.google.antigravity.touchbar.always")
    
    private var touchBar: NSTouchBar?
    private var trayItem: NSCustomTouchBarItem?
    
    // UI Elements
    private var logoImageView: NSImageView!
    private var statusLabel: NSTextField!
    private var yesButton: NSButton!
    private var noButton: NSButton!
    private var alwaysButton: NSButton!
    private var closeButton: NSButton!
    
    // Animation & Timers
    private var pulseTimer: Timer?
    private var spinnerIndex = 0
    private var wavePhase = 0
    private var activeAnimText = ""
    private var isAnimating = false
    
    // CLI Terminal Braille Dot Orbit Frames
    private let spinnerFrames = ["⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏"]
    
    private var currentState: AgentState = AgentState(state: "idle", title: "Ready", detail: nil, showYesNo: false, command: nil)
    private var isPresented = false
    private var lastTimestamp: Double = 0.0
    
    override init() {
        super.init()
        setupUI()
        setupTouchBar()
        setupControlStrip()
        startFileWatcher()
    }
    
    // MARK: - UI Construction (Terminal-Matched, Optically Centered)
    private func setupUI() {
        // 1. Official Antigravity Rocket Logo
        let logoImg = makeAntigravityLogo(size: NSSize(width: 14, height: 14))
        logoImageView = NSImageView(image: logoImg)
        logoImageView.imageScaling = .scaleProportionallyDown
        logoImageView.setContentHuggingPriority(.required, for: .horizontal)
        logoImageView.translatesAutoresizingMaskIntoConstraints = false
        logoImageView.heightAnchor.constraint(equalToConstant: 30).isActive = true
        logoImageView.widthAnchor.constraint(equalToConstant: 20).isActive = true
        
        // 2. Status Label with Vertically Centered Custom Cell
        statusLabel = NSTextField(frame: NSRect(x: 0, y: 0, width: 400, height: 30))
        statusLabel.cell = VerticallyCenteredTextFieldCell(textCell: "Antigravity Ready")
        statusLabel.isEditable = false
        statusLabel.isSelectable = false
        statusLabel.isBordered = false
        statusLabel.backgroundColor = .clear
        statusLabel.font = NSFont.monospacedSystemFont(ofSize: 13, weight: .medium)
        statusLabel.textColor = NSColor(calibratedRed: 0.75, green: 0.80, blue: 0.90, alpha: 1.0)
        statusLabel.alignment = .left
        statusLabel.lineBreakMode = .byTruncatingTail
        statusLabel.maximumNumberOfLines = 1
        statusLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.heightAnchor.constraint(equalToConstant: 30).isActive = true
        
        // 3. Close Button ("Esc")
        closeButton = NSButton(title: " Esc ", target: self, action: #selector(dismissTouchBar))
        closeButton.bezelStyle = .rounded
        closeButton.font = NSFont.monospacedSystemFont(ofSize: 11, weight: .bold)
        closeButton.bezelColor = NSColor(calibratedRed: 0.18, green: 0.20, blue: 0.24, alpha: 1.0)
        
        // 4. Yes Button (Terminal Green - No Emojis)
        yesButton = NSButton(title: " Yes (y) ", target: self, action: #selector(handleYes))
        yesButton.bezelStyle = .rounded
        yesButton.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .bold)
        yesButton.bezelColor = NSColor(calibratedRed: 0.10, green: 0.45, blue: 0.22, alpha: 1.0)
        
        // 5. No Button (Terminal Red - No Emojis)
        noButton = NSButton(title: " No (n) ", target: self, action: #selector(handleNo))
        noButton.bezelStyle = .rounded
        noButton.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .bold)
        noButton.bezelColor = NSColor(calibratedRed: 0.50, green: 0.12, blue: 0.15, alpha: 1.0)
        
        // 6. Always Button (Terminal Slate - No Emojis)
        alwaysButton = NSButton(title: " Always (a) ", target: self, action: #selector(handleAlways))
        alwaysButton.bezelStyle = .rounded
        alwaysButton.font = NSFont.monospacedSystemFont(ofSize: 11, weight: .medium)
        alwaysButton.bezelColor = NSColor(calibratedRed: 0.22, green: 0.25, blue: 0.32, alpha: 1.0)
    }
    
    private func setupTouchBar() {
        let tb = NSTouchBar()
        tb.delegate = self
        tb.defaultItemIdentifiers = [
            closeItemId,
            logoItemId,
            statusItemId,
            .flexibleSpace,
            yesItemId,
            noItemId,
            alwaysItemId
        ]
        self.touchBar = tb
    }
    
    private func setupControlStrip() {
        DFRSystemModalShowsCloseBoxWhenFrontMost(true)
        
        let item = NSCustomTouchBarItem(identifier: trayItemId)
        let btn = NSButton(title: " AGY", target: self, action: #selector(toggleTouchBar))
        btn.bezelStyle = .rounded
        btn.image = makeAntigravityLogo(size: NSSize(width: 14, height: 14))
        btn.imagePosition = .imageLeft
        btn.font = NSFont.monospacedSystemFont(ofSize: 11, weight: .bold)
        btn.sizeToFit()
        item.view = btn
        self.trayItem = item
        
        if (NSTouchBarItem.self as AnyObject).responds(to: addTraySel) {
            _ = (NSTouchBarItem.self as AnyObject).perform(addTraySel, with: item)
        }
        DFRElementSetControlStripPresenceForIdentifier(trayItemId.rawValue as NSString, true)
    }
    
    // MARK: - NSTouchBarDelegate
    func touchBar(_ touchBar: NSTouchBar, makeItemForIdentifier identifier: NSTouchBarItem.Identifier) -> NSTouchBarItem? {
        switch identifier {
        case trayItemId:
            return trayItem
            
        case closeItemId:
            let item = NSCustomTouchBarItem(identifier: identifier)
            item.view = closeButton
            return item
            
        case logoItemId:
            let item = NSCustomTouchBarItem(identifier: identifier)
            item.view = logoImageView
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
        guard let tb = touchBar else { return }
        if NSTouchBar.responds(to: presentSel) {
            _ = (NSTouchBar.self as AnyObject).perform(presentSel, with: tb, with: trayItemId.rawValue as NSString)
            isPresented = true
        }
    }
    
    @objc func dismissTouchBar() {
        guard let tb = touchBar else { return }
        if NSTouchBar.responds(to: dismissSel) {
            _ = (NSTouchBar.self as AnyObject).perform(dismissSel, with: tb)
            isPresented = false
        }
    }
    
    @objc func handleYes() {
        sendKeystrokeToTerminal("y\n")
        flashFeedback("Approved (y)")
    }
    
    @objc func handleNo() {
        sendKeystrokeToTerminal("n\n")
        flashFeedback("Denied (n)")
    }
    
    @objc func handleAlways() {
        sendKeystrokeToTerminal("a\n")
        flashFeedback("Always Allowed (a)")
    }
    
    private func flashFeedback(_ text: String) {
        stopPulseAnimation()
        statusLabel.stringValue = text
        yesButton.isHidden = true
        noButton.isHidden = true
        alwaysButton.isHidden = true
    }
    
    // MARK: - State Update
    func update(state: AgentState) {
        DispatchQueue.main.async {
            self.currentState = state
            
            // Buttons are strictly hidden unless showYesNo is explicitly true
            let showButtons = state.showYesNo ?? false
            self.yesButton.isHidden = !showButtons
            self.noButton.isHidden = !showButtons
            self.alwaysButton.isHidden = !showButtons
            
            switch state.state {
            case "thinking":
                let detail = state.detail?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                let labelText = detail.isEmpty ? "Thinking..." : "Thinking: " + detail
                self.startPulseAnimation(text: labelText)
                self.presentTouchBar()
                
            case "running", "command":
                let cmd = state.command ?? state.detail ?? "Command"
                let clean = cmd.trimmingCharacters(in: .whitespacesAndNewlines)
                let truncated = clean.count > 36 ? String(clean.prefix(33)) + "..." : clean
                let labelText = "Running: " + truncated
                self.startPulseAnimation(text: labelText)
                self.presentTouchBar()
                
            case "confirm", "prompt":
                self.stopPulseAnimation()
                let cmd = state.command ?? state.detail ?? "Action"
                let clean = cmd.trimmingCharacters(in: .whitespacesAndNewlines)
                let truncated = clean.count > 32 ? String(clean.prefix(29)) + "..." : clean
                self.statusLabel.stringValue = "Confirm: " + truncated
                self.presentTouchBar()
                
            case "done", "tool_done":
                self.stopPulseAnimation()
                self.statusLabel.stringValue = "Completed"
                
            case "idle":
                self.stopPulseAnimation()
                self.statusLabel.stringValue = "Antigravity Ready"
                // Keep Antigravity Ready visible on Touch Bar; user can tap Esc to dismiss anytime
                
            default:
                self.stopPulseAnimation()
                self.statusLabel.stringValue = state.title ?? "Antigravity"
            }
        }
    }
    
    // MARK: - Terminal Blue Wave Shimmer Animation
    private func startPulseAnimation(text: String) {
        activeAnimText = text
        if isAnimating && pulseTimer != nil { return }
        
        isAnimating = true
        spinnerIndex = 0
        wavePhase = 0
        pulseTimer?.invalidate()
        
        pulseTimer = Timer.scheduledTimer(withTimeInterval: 0.065, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.renderPulseFrame()
        }
    }
    
    private func renderPulseFrame() {
        let spinnerChar = spinnerFrames[spinnerIndex % spinnerFrames.count]
        spinnerIndex += 1
        
        let prefix = spinnerChar + " "
        let text = activeAnimText
        let full = prefix + text
        let attrStr = NSMutableAttributedString(string: full)
        
        let font = NSFont.monospacedSystemFont(ofSize: 13, weight: .medium)
        attrStr.addAttribute(.font, value: font, range: NSRange(location: 0, length: full.utf16.count))
        
        // Spinner Dot: Intense Cyan
        let spinnerColor = NSColor(calibratedRed: 0.25, green: 0.80, blue: 1.0, alpha: 1.0)
        attrStr.addAttribute(.foregroundColor, value: spinnerColor, range: NSRange(location: 0, length: prefix.utf16.count))
        
        let textStart = prefix.utf16.count
        let textLen = text.utf16.count
        
        if textLen > 0 {
            let phase = wavePhase % textLen
            wavePhase += 1
            
            for i in 0..<textLen {
                let charIndex = textStart + i
                var dist = abs(i - phase)
                if dist > textLen / 2 {
                    dist = textLen - dist
                }
                
                let color: NSColor
                if dist == 0 {
                    // Pulse Peak: Glowing Pure Ice-Blue
                    color = NSColor(calibratedRed: 0.85, green: 0.95, blue: 1.0, alpha: 1.0)
                } else if dist == 1 {
                    // High Wave: Electric Cyan
                    color = NSColor(calibratedRed: 0.40, green: 0.80, blue: 1.0, alpha: 1.0)
                } else if dist == 2 {
                    // Mid Wave: Antigravity Blue
                    color = NSColor(calibratedRed: 0.22, green: 0.55, blue: 0.98, alpha: 1.0)
                } else if dist == 3 {
                    // Tail: Deep Sapphire
                    color = NSColor(calibratedRed: 0.15, green: 0.38, blue: 0.75, alpha: 0.90)
                } else {
                    // Base: Sleek Cool Terminal Slate
                    color = NSColor(calibratedRed: 0.55, green: 0.60, blue: 0.72, alpha: 0.85)
                }
                
                attrStr.addAttribute(.foregroundColor, value: color, range: NSRange(location: charIndex, length: 1))
            }
        }
        
        statusLabel.attributedStringValue = attrStr
    }
    
    private func stopPulseAnimation() {
        isAnimating = false
        pulseTimer?.invalidate()
        pulseTimer = nil
    }
    
    // MARK: - Send Keystroke to Active Terminal
    private func sendKeystrokeToTerminal(_ charStr: String) {
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
        
        guard let app = targetApp else { return }
        
        // 1. Activate terminal app
        app.activate()
        
        // 2. Post CGEvents directly to PID
        let pid = app.processIdentifier
        let cleanChar = charStr.replacingOccurrences(of: "\n", with: "").lowercased()
        
        var keyCode: CGKeyCode?
        switch cleanChar {
        case "y": keyCode = 0x10 // kVK_ANSI_Y
        case "n": keyCode = 0x2D // kVK_ANSI_N
        case "a": keyCode = 0x00 // kVK_ANSI_A
        default: break
        }
        
        if let key = keyCode {
            let src = CGEventSource(stateID: .hidSystemState)
            let keyDown = CGEvent(keyboardEventSource: src, virtualKey: key, keyDown: true)
            let keyUp = CGEvent(keyboardEventSource: src, virtualKey: key, keyDown: false)
            keyDown?.postToPid(pid)
            keyUp?.postToPid(pid)
            
            // Post Return (kVK_Return = 0x24)
            let returnDown = CGEvent(keyboardEventSource: src, virtualKey: 0x24, keyDown: true)
            let returnUp = CGEvent(keyboardEventSource: src, virtualKey: 0x24, keyDown: false)
            returnDown?.postToPid(pid)
            returnUp?.postToPid(pid)
        } else {
            // Fallback via AppleScript System Events
            let processName = app.localizedName ?? "terminal"
            let scriptSource = """
            tell application "System Events"
                tell process "\(processName)"
                    keystroke "\(cleanChar)"
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
        
        // Fast polling timer (every 0.2s)
        Timer.scheduledTimer(withTimeInterval: 0.20, repeats: true) { [weak self] _ in
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
