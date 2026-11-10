import Foundation
import Testing
@testable import LidlessCore

final class FakePowerAssertions: PowerAssertions {
    var shouldFail = false
    private(set) var acquired: [(id: UInt32, allowDisplaySleep: Bool)] = []
    private(set) var released: [UInt32] = []
    private var nextID: UInt32 = 1

    var held: Set<UInt32> {
        Set(acquired.map(\.id)).subtracting(released)
    }

    func acquire(allowDisplaySleep: Bool) -> UInt32? {
        guard !shouldFail else { return nil }
        let id = nextID
        nextID += 1
        acquired.append((id, allowDisplaySleep))
        return id
    }

    func release(_ id: UInt32) {
        released.append(id)
    }
}

final class FakeLidSleep: LidSleepControl {
    var disabled = false
    var shouldFail = false
    private(set) var calls: [Bool] = []

    func isSleepDisabled() -> Bool { disabled }

    func setSleepDisabled(_ disabled: Bool) -> Bool {
        calls.append(disabled)
        guard !shouldFail else { return false }
        self.disabled = disabled
        return true
    }
}

final class FakePowerSource: PowerSource {
    var status: BatteryStatus?
    func batteryStatus() -> BatteryStatus? { status }
}

final class FakeClock {
    var now = Date(timeIntervalSinceReferenceDate: 0)
    func advance(by seconds: TimeInterval) { now += seconds }
}

@MainActor
struct AwakeControllerTests {
    let assertions = FakePowerAssertions()
    let lidSleep = FakeLidSleep()
    let power = FakePowerSource()
    let clock = FakeClock()
    let defaults: UserDefaults
    let controller: AwakeController

    init() {
        let suite = "LidlessTests-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        let clock = clock
        controller = AwakeController(
            assertions: assertions, lidSleep: lidSleep, powerSource: power,
            defaults: defaults, now: { clock.now }
        )
    }

    @Test func startsInactive() {
        #expect(controller.state == .inactive)
        #expect(!controller.isActive)
        #expect(controller.remaining == nil)
        #expect(assertions.acquired.isEmpty)
    }

    @Test func timedSessionHoldsAssertionAndCountsDown() {
        controller.activate(for: 600)

        #expect(controller.state == .until(clock.now + 600, duration: 600))
        #expect(assertions.held.count == 1)

        clock.advance(by: 240)
        controller.tick()
        #expect(controller.isActive)
        #expect(controller.remaining == 360)
    }

    @Test func timedSessionEndsWhenTimeRunsOut() {
        controller.activate(for: 600)
        clock.advance(by: 600)
        controller.tick()

        #expect(controller.state == .inactive)
        #expect(assertions.held.isEmpty)
    }

    @Test func indefiniteSessionIgnoresTicks() {
        controller.activate(for: nil)
        clock.advance(by: 86_400 * 7)
        controller.tick()

        #expect(controller.state == .indefinite)
        #expect(controller.remaining == nil)
        #expect(assertions.held.count == 1)
    }

    @Test func deactivateReleasesAssertion() {
        controller.activate(for: nil)
        controller.deactivate()

        #expect(controller.state == .inactive)
        #expect(assertions.held.isEmpty)
    }

    @Test func switchingSessionsKeepsExactlyOneAssertion() {
        controller.activate(for: 600)
        controller.activate(for: nil)
        controller.activate(for: 3600)

        #expect(controller.state == .until(clock.now + 3600, duration: 3600))
        #expect(assertions.acquired.count == 3)
        #expect(assertions.held.count == 1)
    }

    @Test func failedAssertionLeavesControllerInactive() {
        assertions.shouldFail = true
        controller.activate(for: 600)

        #expect(controller.state == .inactive)
    }

    @Test func usesDisplaySleepPreferenceWhenActivating() {
        controller.activate(for: nil)
        #expect(assertions.acquired.last?.allowDisplaySleep == false)

        defaults.set(true, forKey: Prefs.allowDisplaySleepKey)
        controller.deactivate()
        controller.activate(for: nil)
        #expect(assertions.acquired.last?.allowDisplaySleep == true)
    }

    @Test func changingPreferenceMidSessionSwapsAssertion() {
        controller.activate(for: 600)
        let end = clock.now + 600

        defaults.set(true, forKey: Prefs.allowDisplaySleepKey)

        #expect(assertions.acquired.count == 2)
        #expect(assertions.acquired.last?.allowDisplaySleep == true)
        #expect(assertions.held.count == 1)
        #expect(controller.state == .until(end, duration: 600))
    }

    @Test func changingPreferenceWhileInactiveDoesNothing() {
        defaults.set(true, forKey: Prefs.allowDisplaySleepKey)
        #expect(assertions.acquired.isEmpty)
    }

    @Test func onChangeFiresForStateChangesAndTicks() {
        var calls = 0
        controller.onChange = { calls += 1 }

        controller.activate(for: 600)
        #expect(calls == 1)

        clock.advance(by: 1)
        controller.tick()
        #expect(calls == 2)

        controller.deactivate()
        #expect(calls == 3)
    }
}
