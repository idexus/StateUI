// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
@_spi(Host) import StateUI

/// The AppKit runtime's one line to the StateUI core.
///
/// Every element that needs the running core asks through this, and no other
/// part of the host calls into it: a patch, a cycle, an event, an act call and
/// its answer, a reader's report, the application's and the scene's reports,
/// the kept values and the doorbell's wait all cross here. For a host in the
/// process the line is the typed `StateUIHost` SPI; in a runtime in another
/// language the same element is the one that knows the Wire.
///
/// The lane codecs - a journey read from its image and written back, a
/// placement run - are arithmetic on values the host already holds, not calls
/// into the core, and stay the SPI's.
struct AppKitCoreLink: Sendable {
    // MARK: - Rendering

    /// Whether state changed since the last render.
    var needsRender: Bool { StateUIHost.needsRender }

    /// Builds the patch against the generation the host holds.
    func render(baseline: Int32) -> HostRender {
        StateUIHost.render(baseline: baseline)
    }

    // MARK: - The display cycle

    /// Whether any state or engine waits for a display cycle.
    var cyclesPending: Bool { StateUIHost.cyclesPending }

    /// Runs the display's cycle at `now` and returns what it published.
    func cycle(now: Double, reducesMotion: Bool) -> HostCycle {
        StateUIHost.cycle(.display, now: now, reducesMotion: reducesMotion)
    }

    /// The complete image of an attached state.
    func value(for binding: HostStateBinding) -> HostStateValue? {
        StateUIHost.value(for: binding)
    }

    /// Reports a complete text, plain value or feed a reader changed.
    @discardableResult
    func report(_ value: HostStateValue, through binding: HostStateBinding) -> Bool {
        StateUIHost.report(value, through: binding)
    }

    /// Reports where a host-walked journey stands.
    @discardableResult
    func report(
        _ journey: HostJourney,
        updating update: HostJourneyUpdate,
        through binding: HostStateBinding
    ) -> Bool {
        StateUIHost.report(journey, updating: update, through: binding)
    }

    /// Answers the caller awaiting a journey's end.
    @discardableResult
    func complete(_ completion: Int, succeeded: Bool) -> Bool {
        StateUIHost.complete(completion, succeeded: succeeded)
    }

    /// Where a one-lane state named by a native gesture stands.
    func gestureValue(state: Int32) -> Double? {
        StateUIHost.gestureValue(state: state)
    }

    /// Moves a one-lane state named by a native gesture.
    @discardableResult
    func moveGestureValue(_ value: Double, state: Int32) -> Bool {
        StateUIHost.moveGestureValue(value, state: state)
    }

    // MARK: - Events, jobs and acts

    /// Reports a native event and runs its handler.
    @discardableResult
    func dispatch(_ handler: Int32, payload: [HostValue] = []) -> Bool {
        StateUIHost.dispatch(handler, payload: payload)
    }

    /// Runs the jobs waiting on StateUI's UI executor.
    @discardableResult
    func runJobs() -> Int { StateUIHost.runJobs() }

    /// Parks the doorbell's thread until work arrives.
    func waitForWork() -> Int { StateUIHost.waitForWork() }

    /// Takes the act calls queued since the previous pump.
    func takeActCalls() -> [HostActCall] { StateUIHost.takeActCalls() }

    /// Answers a performed act call with the values it came to.
    @discardableResult
    func reply(_ completion: Int, with values: [HostValue]) -> Bool {
        StateUIHost.reply(completion, with: values)
    }

    /// Fails an act call this host could not perform.
    @discardableResult
    func fail(_ completion: Int, reason: String) -> Bool {
        StateUIHost.fail(completion, reason: reason)
    }

    /// Raises an event of the application's - one no control raises - with the
    /// values its contract declares, and answers how many subscriptions heard
    /// it. Safe from any thread, as the sources reporting one are.
    @discardableResult
    func raise<Owner: ApplicationTier, each Value: HostRepresentable>(
        _ event: ElementEvent<Owner, (repeat each Value)>,
        _ value: repeat each Value
    ) -> Int {
        StateUIHost.raise(event, repeat each value)
    }

    // MARK: - The application, its scenes and its kept values

    /// Reports the appearance themed values resolve against.
    func setTheme(_ theme: Theme) { StateUIHost.setTheme(theme) }

    /// Reports the device the application runs on.
    func setDeviceInfo(_ info: HostDeviceInfo) { StateUIHost.setDeviceInfo(info) }

    /// Reports the main display.
    func setDisplayInfo(_ info: HostDisplayInfo) { StateUIHost.setDisplayInfo(info) }

    /// Reports the application's manifest.
    func setApplicationInfo(_ info: HostApplicationInfo) {
        StateUIHost.setApplicationInfo(info)
    }

    /// Reports the application's lifecycle phase.
    func setApplicationPhase(_ phase: ApplicationPhase) {
        StateUIHost.setApplicationPhase(phase)
    }

    /// Hands a platform scene to StateUI before its first render.
    func connectScene(restoring values: [String: HostValue] = [:]) {
        StateUIHost.connectScene(restoring: values)
    }

    /// The store the application keeps its values in.
    var persistentStorage: PersistentStorage { StateUIHost.persistentStorage }

    /// The keys read from that store before the first render.
    var persistentKeys: [PersistentKey] { StateUIHost.persistentKeys }

    /// Hydrates the kept values found in the store.
    func restorePersistent(_ values: [String: HostValue]) {
        StateUIHost.restorePersistent(values)
    }
}
#endif
