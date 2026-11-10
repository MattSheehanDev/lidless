import Foundation
import ServiceManagement

public enum Prefs {
    public static let allowDisplaySleepKey = "allowDisplaySleep"
    public static let keepAwakeWithLidClosedKey = "keepAwakeWithLidClosed"
    /// Set while Lidless has disabled system sleep, so a crash can be cleaned up on next launch.
    public static let lidSleepOverrideActiveKey = "lidSleepOverrideActive"

    public static var allowDisplaySleep: Bool {
        UserDefaults.standard.bool(forKey: allowDisplaySleepKey)
    }

    public static var keepAwakeWithLidClosed: Bool {
        get { UserDefaults.standard.bool(forKey: keepAwakeWithLidClosedKey) }
        set { UserDefaults.standard.set(newValue, forKey: keepAwakeWithLidClosedKey) }
    }
}

public enum LoginItem {
    public static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    public static func set(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            NSLog("Lidless: failed to update login item: \(error.localizedDescription)")
        }
    }
}
