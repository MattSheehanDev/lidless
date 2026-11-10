import Foundation

/// Holds a power assertion for either a fixed duration or indefinitely, and optionally
/// disables lid-close sleep for the length of the session.
@MainActor
public final class AwakeController {
    public enum State: Equatable {
        case inactive
        case indefinite
        case until(Date, duration: TimeInterval)
    }

    /// Sessions that keep the Mac awake with the lid closed end at or below this battery level.
    public static let lowBatteryCutoffPercent = 10

    public private(set) var state: State = .inactive {
        didSet { onChange?() }
    }

    /// Called whenever the state changes and once per second while a timed session runs.
    public var onChange: (() -> Void)?

    /// True while Lidless itself has disabled system sleep for the current session.
    public private(set) var isOverridingLidSleep = false

    private let assertions: PowerAssertions
    private let lidSleep: LidSleepControl?
    private let powerSource: PowerSource?
    private let defaults: UserDefaults
    private let now: () -> Date
    private var assertionID: UInt32?
    private var assertionAllowsDisplaySleep: Bool?
    private var ticker: Timer?
    private var defaultsObserver: NSObjectProtocol?

    public var isActive: Bool { state != .inactive }

    public var remaining: TimeInterval? {
        guard case let .until(end, _) = state else { return nil }
        return max(0, end.timeIntervalSince(now()))
    }

    public init(
        assertions: PowerAssertions = IOKitPowerAssertions(),
        lidSleep: LidSleepControl? = PmsetLidSleepControl(),
        powerSource: PowerSource? = IOKitPowerSource(),
        defaults: UserDefaults = .standard,
        now: @escaping () -> Date = Date.init
    ) {
        self.assertions = assertions
        self.lidSleep = lidSleep
        self.powerSource = powerSource
        self.defaults = defaults
        self.now = now
        defaultsObserver = NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification, object: defaults, queue: nil
        ) { [weak self] _ in
            if Thread.isMainThread {
                MainActor.assumeIsolated { self?.preferencesDidChange() }
            } else {
                DispatchQueue.main.async { self?.preferencesDidChange() }
            }
        }
    }

    deinit {
        if let defaultsObserver {
            NotificationCenter.default.removeObserver(defaultsObserver)
        }
    }

    /// Re-enables system sleep if a previous run disabled it and exited without cleaning up.
    public func restoreLidSleepAfterUnexpectedExit() {
        guard defaults.bool(forKey: Prefs.lidSleepOverrideActiveKey) else { return }
        lidSleep?.setSleepDisabled(false)
        defaults.removeObject(forKey: Prefs.lidSleepOverrideActiveKey)
    }

    /// Pass `nil` to stay awake indefinitely.
    public func activate(for duration: TimeInterval?) {
        guard createAssertion() else { return }
        if let duration {
            state = .until(now().addingTimeInterval(duration), duration: duration)
        } else {
            state = .indefinite
        }
        startTicker()
        applyLidSleep()
    }

    public func deactivate() {
        stopTicker()
        releaseAssertion()
        state = .inactive
        applyLidSleep()
    }

    /// Ends expired or low-battery sessions; driven by the internal one-second timer.
    func tick() {
        guard isActive else { return }
        if isOverridingLidSleep, let battery = powerSource?.batteryStatus(),
           battery.isOnBattery, battery.percent <= Self.lowBatteryCutoffPercent {
            deactivate()
            return
        }
        guard case let .until(end, _) = state else { return }
        if now() >= end {
            deactivate()
        } else {
            onChange?()
        }
    }

    private func startTicker() {
        stopTicker()
        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
        RunLoop.main.add(timer, forMode: .common)
        ticker = timer
    }

    private func stopTicker() {
        ticker?.invalidate()
        ticker = nil
    }

    private var allowDisplaySleep: Bool {
        defaults.bool(forKey: Prefs.allowDisplaySleepKey)
    }

    private var wantsLidSleepDisabled: Bool {
        isActive && lidSleep != nil && defaults.bool(forKey: Prefs.keepAwakeWithLidClosedKey)
    }

    private func applyLidSleep() {
        guard let lidSleep else { return }
        if wantsLidSleepDisabled, !isOverridingLidSleep {
            // If sleep is already disabled outside Lidless, leave it alone and don't take ownership.
            guard !lidSleep.isSleepDisabled(), lidSleep.setSleepDisabled(true) else { return }
            isOverridingLidSleep = true
            defaults.set(true, forKey: Prefs.lidSleepOverrideActiveKey)
            onChange?()
        } else if !wantsLidSleepDisabled, isOverridingLidSleep {
            lidSleep.setSleepDisabled(false)
            isOverridingLidSleep = false
            defaults.removeObject(forKey: Prefs.lidSleepOverrideActiveKey)
            onChange?()
        }
    }

    @discardableResult
    private func createAssertion() -> Bool {
        releaseAssertion()
        let allowDisplaySleep = allowDisplaySleep
        guard let id = assertions.acquire(allowDisplaySleep: allowDisplaySleep) else { return false }
        assertionID = id
        assertionAllowsDisplaySleep = allowDisplaySleep
        return true
    }

    private func releaseAssertion() {
        if let assertionID {
            assertions.release(assertionID)
        }
        assertionID = nil
        assertionAllowsDisplaySleep = nil
    }

    private func preferencesDidChange() {
        if isActive, assertionAllowsDisplaySleep != allowDisplaySleep {
            createAssertion()
        }
        applyLidSleep()
    }
}
