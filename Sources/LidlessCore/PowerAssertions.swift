import Foundation
import IOKit.pwr_mgt

public protocol PowerAssertions {
    /// Returns an assertion ID, or `nil` if the assertion couldn't be created.
    func acquire(allowDisplaySleep: Bool) -> UInt32?
    func release(_ id: UInt32)
}

public struct IOKitPowerAssertions: PowerAssertions {
    public init() {}

    public func acquire(allowDisplaySleep: Bool) -> UInt32? {
        // CFSTR-based kIOPMAssertionType* constants aren't imported into Swift.
        let type = allowDisplaySleep ? "PreventUserIdleSystemSleep" : "PreventUserIdleDisplaySleep"
        var id: IOPMAssertionID = 0
        let result = IOPMAssertionCreateWithName(
            type as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            "Lidless is keeping this Mac awake" as CFString,
            &id
        )
        guard result == kIOReturnSuccess else {
            NSLog("Lidless: IOPMAssertionCreateWithName failed (\(result))")
            return nil
        }
        return id
    }

    public func release(_ id: UInt32) {
        IOPMAssertionRelease(id)
    }
}
