import Foundation
import Testing
@testable import LidlessCore

@MainActor
struct LidSleepSessionTests {
    let assertions = FakePowerAssertions()
    let lidSleep = FakeLidSleep()
    let power = FakePowerSource()
    let clock = FakeClock()
    let defaults: UserDefaults
    let controller: AwakeController

    init() {
        let suite = "LidlessLidTests-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        let clock = clock
        controller = AwakeController(
            assertions: assertions, lidSleep: lidSleep, powerSource: power,
            defaults: defaults, now: { clock.now }
        )
    }

    private func enableLidMode() {
        defaults.set(true, forKey: Prefs.keepAwakeWithLidClosedKey)
    }

    @Test func offByDefault() {
        controller.activate(for: nil)
        #expect(lidSleep.calls.isEmpty)
        #expect(!controller.isOverridingLidSleep)
    }

    @Test func enabledModeDisablesSleepForTheSession() {
        enableLidMode()
        controller.activate(for: 600)

        #expect(lidSleep.disabled)
        #expect(controller.isOverridingLidSleep)
        #expect(defaults.bool(forKey: Prefs.lidSleepOverrideActiveKey))

        controller.deactivate()
        #expect(!lidSleep.disabled)
        #expect(!controller.isOverridingLidSleep)
        #expect(!defaults.bool(forKey: Prefs.lidSleepOverrideActiveKey))
    }

    @Test func expiringSessionRestoresSleep() {
        enableLidMode()
        controller.activate(for: 60)
        clock.advance(by: 60)
        controller.tick()

        #expect(controller.state == .inactive)
        #expect(!lidSleep.disabled)
    }

    @Test func togglingModeMidSessionAppliesImmediately() {
        controller.activate(for: nil)
        #expect(!lidSleep.disabled)

        enableLidMode()
        #expect(lidSleep.disabled)

        defaults.set(false, forKey: Prefs.keepAwakeWithLidClosedKey)
        #expect(!lidSleep.disabled)
        #expect(controller.isActive)
    }

    @Test func switchingDurationsDoesNotToggleSleepAgain() {
        enableLidMode()
        controller.activate(for: 600)
        controller.activate(for: nil)
        controller.activate(for: 3600)

        #expect(lidSleep.calls == [true])
    }

    @Test func leavesSleepAloneWhenAlreadyDisabledOutsideLidless() {
        lidSleep.disabled = true
        enableLidMode()
        controller.activate(for: 600)
        controller.deactivate()

        #expect(lidSleep.calls.isEmpty)
        #expect(lidSleep.disabled)
    }

    @Test func failureToDisableSleepKeepsSessionRunning() {
        lidSleep.shouldFail = true
        enableLidMode()
        controller.activate(for: 600)

        #expect(controller.isActive)
        #expect(!controller.isOverridingLidSleep)
        #expect(!defaults.bool(forKey: Prefs.lidSleepOverrideActiveKey))
    }

    @Test func lowBatteryEndsLidClosedSession() {
        enableLidMode()
        controller.activate(for: nil)

        power.status = BatteryStatus(isOnBattery: true, percent: AwakeController.lowBatteryCutoffPercent + 1)
        controller.tick()
        #expect(controller.isActive)

        power.status = BatteryStatus(isOnBattery: true, percent: AwakeController.lowBatteryCutoffPercent)
        controller.tick()
        #expect(controller.state == .inactive)
        #expect(!lidSleep.disabled)
    }

    @Test func lowBatteryIgnoredWhenCharging() {
        enableLidMode()
        controller.activate(for: nil)
        power.status = BatteryStatus(isOnBattery: false, percent: 3)
        controller.tick()

        #expect(controller.isActive)
    }

    @Test func lowBatteryIgnoredWithoutLidMode() {
        controller.activate(for: nil)
        power.status = BatteryStatus(isOnBattery: true, percent: 3)
        controller.tick()

        #expect(controller.isActive)
    }

    @Test func restoresSleepAfterUnexpectedExit() {
        defaults.set(true, forKey: Prefs.lidSleepOverrideActiveKey)
        lidSleep.disabled = true

        controller.restoreLidSleepAfterUnexpectedExit()

        #expect(!lidSleep.disabled)
        #expect(!defaults.bool(forKey: Prefs.lidSleepOverrideActiveKey))
    }

    @Test func restoreDoesNothingAfterCleanExit() {
        lidSleep.disabled = true
        controller.restoreLidSleepAfterUnexpectedExit()

        #expect(lidSleep.calls.isEmpty)
        #expect(lidSleep.disabled)
    }
}

struct IOKitPowerSourceTests {
    @Test func readsThisMacsBattery() {
        // Desktops have no battery; laptops must report a sane percentage.
        guard let status = IOKitPowerSource().batteryStatus() else { return }
        #expect((0...100).contains(status.percent))
    }
}

struct PmsetOutputTests {
    @Test func parsesSleepDisabled() {
        let output = """
        System-wide power settings:
         SleepDisabled\t\t1
        Currently in use:
         standby              1
        """
        #expect(PmsetOutput.isSleepDisabled(output))
        #expect(!PmsetOutput.isSleepDisabled(output.replacingOccurrences(of: "\t\t1", with: "\t\t0")))
    }

    @Test func missingLineMeansEnabled() {
        #expect(!PmsetOutput.isSleepDisabled("Currently in use:\n sleep 1\n"))
    }
}

struct SudoersTests {
    @Test func allowsOnlyTheTwoPmsetCommandsForTheUser() throws {
        let contents = try #require(LidSleepHelper.sudoersContents(for: "matthew"))
        let rule = try #require(contents.split(separator: "\n").first { !$0.hasPrefix("#") })
        #expect(rule == "matthew ALL=(root) NOPASSWD: /usr/bin/pmset -a disablesleep 1, /usr/bin/pmset -a disablesleep 0")
    }

    @Test(arguments: ["", "bad user", "x,ALL", "root\nALL ALL=(ALL) ALL", "matthew\n", "-flag", "a;b"])
    func rejectsUnsafeUsernames(_ user: String) {
        #expect(LidSleepHelper.sudoersContents(for: user) == nil)
    }
}
