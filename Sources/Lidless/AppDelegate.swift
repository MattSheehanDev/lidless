import AppKit
import LidlessCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private static let presets: [(title: String, seconds: TimeInterval?)] = [
        ("Indefinitely", nil),
        ("10 Minutes", 10 * 60),
        ("30 Minutes", 30 * 60),
        ("1 Hour", 60 * 60),
        ("2 Hours", 2 * 60 * 60),
        ("4 Hours", 4 * 60 * 60),
        ("8 Hours", 8 * 60 * 60),
        ("12 Hours", 12 * 60 * 60),
    ]

    private let controller = AwakeController()
    private var statusItem: NSStatusItem!
    private let menu = NSMenu()
    private var statusHeader: NSMenuItem?
    private lazy var preferencesWindow = PreferencesWindowController()

    private let remainingFormatter: DateComponentsFormatter = {
        let f = DateComponentsFormatter()
        f.allowedUnits = [.hour, .minute, .second]
        f.unitsStyle = .positional
        f.zeroFormattingBehavior = .pad
        return f
    }()

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        menu.delegate = self
        menu.autoenablesItems = false
        statusItem.menu = menu

        controller.onChange = { [weak self] in self?.stateDidChange() }
        controller.restoreLidSleepAfterUnexpectedExit()
        quitOnTerminationSignals()
        updateIcon()
        applyLaunchArguments()
    }

    /// Supports `--minutes <n>` and `--indefinite`, e.g. `open Lidless.app --args --minutes 45`.
    private func applyLaunchArguments() {
        if let request = LaunchArguments.sessionRequest(from: CommandLine.arguments) {
            controller.activate(for: request.seconds)
        }
    }

    private var signalSources: [DispatchSourceSignal] = []

    /// AppKit exits on SIGTERM/SIGINT/SIGHUP without calling applicationWillTerminate,
    /// which would leave lid-close sleep disabled until the next launch.
    private func quitOnTerminationSignals() {
        for sig in [SIGTERM, SIGINT, SIGHUP] {
            signal(sig, SIG_IGN)
            let source = DispatchSource.makeSignalSource(signal: sig, queue: .main)
            source.setEventHandler { NSApp.terminate(nil) }
            source.resume()
            signalSources.append(source)
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        controller.deactivate()
    }

    // MARK: - Menu

    func menuNeedsUpdate(_ menu: NSMenu) {
        rebuildMenu()
    }

    private func rebuildMenu() {
        menu.removeAllItems()

        let header = NSMenuItem(title: headerTitle(), action: nil, keyEquivalent: "")
        header.isEnabled = false
        menu.addItem(header)
        statusHeader = header

        if controller.isActive {
            menu.addItem(item("Turn Off", action: #selector(turnOff)))
            menu.addItem(.separator())
        }

        for (index, preset) in Self.presets.enumerated() {
            let presetItem = item(preset.title, action: #selector(selectPreset(_:)))
            presetItem.tag = index
            presetItem.state = isSelected(preset.seconds) ? .on : .off
            menu.addItem(presetItem)
        }

        menu.addItem(.separator())
        let lidItem = item("Keep Awake with Lid Closed", action: #selector(toggleLidMode))
        lidItem.state = Prefs.keepAwakeWithLidClosed ? .on : .off
        menu.addItem(lidItem)

        menu.addItem(.separator())
        menu.addItem(item("Preferences…", action: #selector(openPreferences), key: ","))

        let more = NSMenuItem(title: "More", action: nil, keyEquivalent: "")
        let moreMenu = NSMenu()
        moreMenu.addItem(item("Custom Duration…", action: #selector(customDuration)))
        moreMenu.addItem(.separator())
        moreMenu.addItem(item("About Lidless", action: #selector(showAbout)))
        more.submenu = moreMenu
        menu.addItem(more)

        menu.addItem(.separator())
        menu.addItem(item("Quit Lidless", action: #selector(quit), key: "q"))
    }

    private func item(_ title: String, action: Selector, key: String = "") -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = self
        return item
    }

    private func isSelected(_ seconds: TimeInterval?) -> Bool {
        switch controller.state {
        case .inactive: return false
        case .indefinite: return seconds == nil
        case let .until(_, duration): return seconds == duration
        }
    }

    private func headerTitle() -> String {
        switch controller.state {
        case .inactive:
            return "Keep this Mac awake"
        case .indefinite:
            return "Awake indefinitely" + lidSuffix
        case .until:
            let remaining = remainingFormatter.string(from: controller.remaining ?? 0) ?? ""
            return "Awake — \(remaining) remaining" + lidSuffix
        }
    }

    private var lidSuffix: String {
        controller.isOverridingLidSleep ? ", even with lid closed" : ""
    }

    private func stateDidChange() {
        updateIcon()
        statusHeader?.title = headerTitle()
    }

    private func updateIcon() {
        let symbol = controller.isActive ? "cup.and.saucer.fill" : "cup.and.saucer"
        let image = NSImage(systemSymbolName: symbol, accessibilityDescription: "Lidless")
        image?.isTemplate = true
        statusItem.button?.image = image
        statusItem.button?.toolTip = headerTitle()
    }

    // MARK: - Actions

    @objc private func selectPreset(_ sender: NSMenuItem) {
        controller.activate(for: Self.presets[sender.tag].seconds)
    }

    @objc private func turnOff() {
        controller.deactivate()
    }

    @objc private func toggleLidMode() {
        LidModeSetup.setEnabled(!Prefs.keepAwakeWithLidClosed)
    }

    @objc private func customDuration() {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "Keep this Mac awake for…"
        alert.informativeText = "Enter a number of minutes."
        alert.addButton(withTitle: "Start")
        alert.addButton(withTitle: "Cancel")

        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 200, height: 24))
        field.placeholderString = "e.g. 45"
        alert.accessoryView = field
        alert.window.initialFirstResponder = field

        guard alert.runModal() == .alertFirstButtonReturn else { return }
        guard let minutes = Double(field.stringValue.trimmingCharacters(in: .whitespaces)),
              minutes > 0 else {
            NSSound.beep()
            return
        }
        controller.activate(for: minutes * 60)
    }

    @objc private func openPreferences() {
        NSApp.activate(ignoringOtherApps: true)
        preferencesWindow.showWindow(nil)
        preferencesWindow.window?.makeKeyAndOrderFront(nil)
    }

    @objc private func showAbout() {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.orderFrontStandardAboutPanel(nil)
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
