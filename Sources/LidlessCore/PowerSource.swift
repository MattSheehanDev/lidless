import Foundation
import IOKit.ps

public struct BatteryStatus: Equatable {
    public var isOnBattery: Bool
    public var percent: Int

    public init(isOnBattery: Bool, percent: Int) {
        self.isOnBattery = isOnBattery
        self.percent = percent
    }
}

public protocol PowerSource {
    /// Returns `nil` on Macs without a battery.
    func batteryStatus() -> BatteryStatus?
}

public struct IOKitPowerSource: PowerSource {
    public init() {}

    public func batteryStatus() -> BatteryStatus? {
        let info = IOPSCopyPowerSourcesInfo().takeRetainedValue()
        let providing = IOPSGetProvidingPowerSourceType(info).takeUnretainedValue() as String
        let sources = IOPSCopyPowerSourcesList(info).takeRetainedValue() as [CFTypeRef]

        for source in sources {
            guard let description = IOPSGetPowerSourceDescription(info, source)?.takeUnretainedValue() as? [String: Any],
                  description[kIOPSTypeKey] as? String == kIOPSInternalBatteryType,
                  let current = description[kIOPSCurrentCapacityKey] as? Int,
                  let max = description[kIOPSMaxCapacityKey] as? Int, max > 0 else { continue }
            return BatteryStatus(isOnBattery: providing == kIOPSBatteryPowerValue, percent: current * 100 / max)
        }
        return nil
    }
}
