// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

/// A runtime's one line to the running StateUI core; nothing else in a runtime calls it.
/// Design: docs/design/host/runtime.md#core-link
@_spi(Host) public struct CoreLink: Sendable {
    /// The line to the core running in this process.
    public init() {}

    // MARK: - Rendering

    /// Whether state changed since the last render.
    public var needsRender: Bool { HostBoundary.needsRender }

    /// Builds the patch against the generation the runtime holds.
    public func render(baseline: Int32) -> HostRender {
        HostBoundary.render(baseline: baseline)
    }

    // MARK: - The inspector

    /// The way the user's language is written, as the host last reported it.
    public var languageDirection: LayoutDirection { HostBoundary.languageDirection }

    /// Whether an inspector records.
    var inspecting: Bool { HostBoundary.inspecting }

    /// Every pass reported on since the last take, as text; the first take starts the recording for good.
    func takeInspectionLog() -> String { HostBoundary.takeInspectionLog() }

    /// Tells the inspector what applying the message of `generation` cost: every scene's part by its key, then the
    /// whole.
    @MainActor
    func inspected(_ tally: RenderTally, generation: Int32) {
        var scenes: [String: Double] = [:]
        for (scene, spent) in tally.scenes {
            if case .manual(let name) = scene { scenes[name] = RenderTally.micros(spent) }
        }
        HostBoundary.inspected(
            generation: generation, scenes: scenes, apply: RenderTally.micros(ContinuousClock.now - tally.began),
            nodes: tally.nodes, made: tally.made)
    }

    // MARK: - The display cycle

    /// Whether any state or engine waits for a display cycle.
    public var cyclesPending: Bool { HostBoundary.cyclesPending }

    /// The last display cycle as one line.
    public var cycleTrace: String { HostBoundary.cycleTrace }

    /// What this process's renders came to - the tally a runtime prints to count leaks.
    public var tally: HostTally { HostBoundary.tally }

    /// Runs the display's cycle at `now` and returns what it published.
    public func cycle(now: Double, reducesMotion: Bool) -> HostCycle {
        HostBoundary.cycle(.display, now: now, reducesMotion: reducesMotion)
    }

    /// The complete image of an attached state.
    public func value(for binding: HostStateBinding) -> HostStateValue? {
        HostBoundary.value(for: binding)
    }

    /// Reports a complete text, plain value or feed a user changed.
    @discardableResult
    public func report(_ value: HostStateValue, through binding: HostStateBinding) -> Bool {
        HostBoundary.report(value, through: binding)
    }

    /// Reports where a host-walked journey stands.
    @discardableResult
    public func report(
        _ journey: HostJourney,
        updating update: HostJourneyUpdate,
        through binding: HostStateBinding
    ) -> Bool {
        HostBoundary.report(journey, updating: update, through: binding)
    }

    /// Answers the caller awaiting a journey's end.
    @discardableResult
    public func complete(_ completion: Int, succeeded: Bool) -> Bool {
        HostBoundary.complete(completion, succeeded: succeeded)
    }

    /// Where a one-lane state named by a native gesture stands.
    public func gestureValue(state: Int32) -> Double? {
        HostBoundary.gestureValue(state: state)
    }

    /// Moves a one-lane state named by a native gesture.
    @discardableResult
    public func moveGestureValue(_ value: Double, state: Int32) -> Bool {
        HostBoundary.moveGestureValue(value, state: state)
    }

    // MARK: - Events, jobs and acts

    /// Reports a native event and runs its handler.
    @discardableResult
    public func dispatch(_ handler: Int32, payload: [HostValue] = []) -> Bool {
        HostBoundary.dispatch(handler, payload: payload)
    }

    /// Runs the jobs waiting on StateUI's UI executor.
    @discardableResult
    public func runJobs() -> Int { HostBoundary.runJobs() }

    /// Parks the doorbell's thread until work arrives.
    public func waitForWork() -> Int { HostBoundary.waitForWork() }

    /// Takes the act calls queued since the previous pump.
    public func takeActCalls() -> [HostActCall] { HostBoundary.takeActCalls() }

    /// Answers a performed act call with the values it came to.
    @discardableResult
    public func reply(_ completion: Int, with values: [HostValue]) -> Bool {
        HostBoundary.reply(completion, with: values)
    }

    /// Fails an act call this runtime could not perform.
    @discardableResult
    public func fail(_ completion: Int, reason: String) -> Bool {
        HostBoundary.fail(completion, reason: reason)
    }

    /// Raises an application event no control raises; answers how many heard it. Any thread.
    @discardableResult
    public func raise<Owner: ApplicationTier, each Value: HostRepresentable>(
        _ event: ElementEvent<Owner, (repeat each Value)>,
        _ value: repeat each Value
    ) -> Int {
        HostBoundary.raise(event, repeat each value)
    }

    /// Tells the core what this runtime realizes before its first render: its registry's elements and members,
    /// and every element of the library's but those it names `unrealized`.
    /// Design: docs/design/core/contracts.md#unrealized-names
    public func setRealization(_ registry: HostRealization, unrealized: Set<String>) {
        let library = Set(LibraryContracts.elements.map { $0.nodeType.name }).subtracting(unrealized)
        HostBoundary.setRealization(HostRealization(elements: library.union(registry.elements), members: registry.members))
    }

    // MARK: - The application, its scenes and its kept values

    /// Reports the appearance themed values resolve against.
    public func setTheme(_ theme: Theme) { HostBoundary.setTheme(theme) }

    /// Reports the device the application runs on.
    public func setDeviceInfo(_ info: HostDeviceInfo) { HostBoundary.setDeviceInfo(info) }

    /// Reports the main display.
    public func setDisplayInfo(_ info: HostDisplayInfo) { HostBoundary.setDisplayInfo(info) }

    /// Reports the application's manifest.
    public func setApplicationInfo(_ info: HostApplicationInfo) {
        HostBoundary.setApplicationInfo(info)
    }

    /// Reports the battery.
    public func setBatteryInfo(_ info: HostBatteryInfo) { HostBoundary.setBatteryInfo(info) }

    /// Reports the network.
    public func setConnectivityInfo(_ info: HostConnectivityInfo) {
        HostBoundary.setConnectivityInfo(info)
    }

    /// Reports the user's locale.
    public func setLocaleInfo(_ info: HostLocaleInfo) { HostBoundary.setLocaleInfo(info) }

    /// Reports the application's lifecycle phase.
    public func setApplicationPhase(_ phase: ApplicationPhase) {
        HostBoundary.setApplicationPhase(phase)
    }

    /// Hands a platform scene to StateUI before its first render.
    public func connectScene(restoring values: [String: HostValue] = [:]) {
        HostBoundary.connectScene(restoring: values)
    }

    /// The keys read from the platform's settings store before the first render.
    public var persistentKeys: [PersistentKey] { HostBoundary.persistentKeys }

    /// Hydrates the kept values found in the store.
    public func restorePersistent(_ values: [String: HostValue]) {
        HostBoundary.restorePersistent(values)
    }
}
