import Foundation
import ServiceManagement

public enum Prefs {
    public static let allowDisplaySleepKey = "allowDisplaySleep"

    public static var allowDisplaySleep: Bool {
        UserDefaults.standard.bool(forKey: allowDisplaySleepKey)
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
