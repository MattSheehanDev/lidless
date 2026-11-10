import AppKit
import LidlessCore

@MainActor
final class PreferencesWindowController: NSWindowController {
    private let launchAtLoginBox = NSButton(checkboxWithTitle: "Launch at login", target: nil, action: nil)
    private let displaySleepBox = NSButton(checkboxWithTitle: "Allow display to sleep", target: nil, action: nil)

    init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 360, height: 120),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Lidless Preferences"
        window.isReleasedWhenClosed = false
        super.init(window: window)

        launchAtLoginBox.target = self
        launchAtLoginBox.action = #selector(toggleLaunchAtLogin)
        displaySleepBox.target = self
        displaySleepBox.action = #selector(toggleDisplaySleep)

        let hint = NSTextField(wrappingLabelWithString:
            "When enabled, the screen may turn off but the Mac itself stays awake.")
        hint.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        hint.textColor = .secondaryLabelColor

        let stack = NSStackView(views: [launchAtLoginBox, displaySleepBox, hint])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 10
        stack.edgeInsets = NSEdgeInsets(top: 20, left: 20, bottom: 20, right: 20)
        stack.translatesAutoresizingMaskIntoConstraints = false

        let content = NSView()
        content.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            stack.topAnchor.constraint(equalTo: content.topAnchor),
            stack.bottomAnchor.constraint(equalTo: content.bottomAnchor),
            hint.widthAnchor.constraint(equalToConstant: 320),
        ])
        window.contentView = content
        window.center()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override func showWindow(_ sender: Any?) {
        syncControls()
        super.showWindow(sender)
    }

    private func syncControls() {
        launchAtLoginBox.state = LoginItem.isEnabled ? .on : .off
        displaySleepBox.state = Prefs.allowDisplaySleep ? .on : .off
    }

    @objc private func toggleLaunchAtLogin() {
        LoginItem.set(launchAtLoginBox.state == .on)
        syncControls()
    }

    @objc private func toggleDisplaySleep() {
        UserDefaults.standard.set(displaySleepBox.state == .on, forKey: Prefs.allowDisplaySleepKey)
    }
}
