import AppKit
import LidlessCore

/// Turns "Keep Awake with Lid Closed" on and off, running the one-time admin setup when needed.
@MainActor
enum LidModeSetup {
    static func setEnabled(_ enabled: Bool) {
        guard enabled else {
            Prefs.keepAwakeWithLidClosed = false
            return
        }
        guard LidSleepHelper.isInstalled || runFirstTimeSetup() else { return }
        Prefs.keepAwakeWithLidClosed = true
    }

    static func removeHelper() {
        Prefs.keepAwakeWithLidClosed = false
        do {
            try LidSleepHelper.uninstall()
        } catch LidSleepHelper.HelperError.cancelled {
        } catch {
            showError("Couldn't remove the lid-closed helper", error)
        }
    }

    private static func runFirstTimeSetup() -> Bool {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "Keep your Mac awake with the lid closed?"
        alert.informativeText = """
            macOS only allows this through a system setting that needs administrator rights. \
            Lidless will ask for your password once to install a rule that lets it turn lid-close \
            sleep off during a session and back on when the session ends.

            Sessions in this mode stop automatically when the battery drops to \
            \(AwakeController.lowBatteryCutoffPercent)% on battery power. Make sure your Mac has \
            airflow while it runs with the lid closed.
            """
        alert.addButton(withTitle: "Continue")
        alert.addButton(withTitle: "Cancel")
        guard alert.runModal() == .alertFirstButtonReturn else { return false }

        do {
            try LidSleepHelper.install()
            return true
        } catch LidSleepHelper.HelperError.cancelled {
            return false
        } catch {
            showError("Couldn't set up lid-closed mode", error)
            return false
        }
    }

    private static func showError(_ title: String, _ error: Error) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = title
        alert.informativeText = error.localizedDescription
        alert.runModal()
    }
}
