import AppKit
import LidlessCore

@MainActor
final class PreferencesWindowController: NSWindowController {
    private let launchAtLoginBox = NSButton(checkboxWithTitle: "Launch at login", target: nil, action: nil)
    private let displaySleepBox = NSButton(checkboxWithTitle: "Allow display to sleep", target: nil, action: nil)
    private let lidClosedBox = NSButton(checkboxWithTitle: "Keep awake with lid closed", target: nil, action: nil)
    private let removeHelperButton = NSButton(title: "Remove Lid-Closed Helper…", target: nil, action: nil)
    private var defaultsObserver: NSObjectProtocol?

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
        lidClosedBox.target = self
        lidClosedBox.action = #selector(toggleLidClosed)
        removeHelperButton.target = self
        removeHelperButton.action = #selector(removeHelper)
        removeHelperButton.controlSize = .small
        removeHelperButton.font = .systemFont(ofSize: NSFont.smallSystemFontSize)

        let displayHint = hint("When enabled, the screen may turn off but the Mac itself stays awake.")
        let lidHint = hint("""
            Stops the Mac from sleeping when you close the lid during a session. Needs your \
            administrator password once. Sessions end automatically at \
            \(AwakeController.lowBatteryCutoffPercent)% battery.
            """)

        let stack = NSStackView(views: [
            launchAtLoginBox, displaySleepBox, displayHint, lidClosedBox, lidHint, removeHelperButton,
        ])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 10
        stack.setCustomSpacing(18, after: displayHint)
        stack.edgeInsets = NSEdgeInsets(top: 20, left: 20, bottom: 20, right: 20)
        stack.translatesAutoresizingMaskIntoConstraints = false

        let content = NSView()
        content.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            stack.topAnchor.constraint(equalTo: content.topAnchor),
            stack.bottomAnchor.constraint(equalTo: content.bottomAnchor),
            displayHint.widthAnchor.constraint(equalToConstant: 320),
            lidHint.widthAnchor.constraint(equalToConstant: 320),
        ])
        window.contentView = content
        window.center()

        defaultsObserver = NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification, object: UserDefaults.standard, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.syncControls() }
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override func showWindow(_ sender: Any?) {
        syncControls()
        super.showWindow(sender)
    }

    private func hint(_ text: String) -> NSTextField {
        let field = NSTextField(wrappingLabelWithString: text)
        field.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        field.textColor = .secondaryLabelColor
        return field
    }

    private func syncControls() {
        launchAtLoginBox.state = LoginItem.isEnabled ? .on : .off
        displaySleepBox.state = Prefs.allowDisplaySleep ? .on : .off
        lidClosedBox.state = Prefs.keepAwakeWithLidClosed ? .on : .off
        removeHelperButton.isHidden = !FileManager.default.fileExists(atPath: LidSleepHelper.sudoersPath)
    }

    @objc private func toggleLaunchAtLogin() {
        LoginItem.set(launchAtLoginBox.state == .on)
        syncControls()
    }

    @objc private func toggleDisplaySleep() {
        UserDefaults.standard.set(displaySleepBox.state == .on, forKey: Prefs.allowDisplaySleepKey)
    }

    @objc private func toggleLidClosed() {
        LidModeSetup.setEnabled(lidClosedBox.state == .on)
        syncControls()
    }

    @objc private func removeHelper() {
        LidModeSetup.removeHelper()
        syncControls()
    }
}
