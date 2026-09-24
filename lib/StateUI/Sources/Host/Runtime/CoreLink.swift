// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// A runtime's one line to the running StateUI core; nothing else in a runtime calls it.
/// Design: docs/design/host/runtime.md#core-link
@_spi(Host) public struct CoreLink: Sendable {
    /// The line to the core running in this process.
    public init() {}

    // MARK: - Rendering

    /// Whether state changed since the last render.
    public var needsRender: Bool { StateUIHost.needsRender }

    /// Builds the patch against the generation the runtime holds.
    public func render(baseline: Int32) -> HostRender {
        StateUIHost.render(baseline: baseline)
    }

    // MARK: - The inspector

    /// Whether an inspector records: the runtime tallies what applying a message costs only while one does.
    var inspecting: Bool { Inspection.recording }

    /// Tells the inspector what applying the message of `generation` cost: every scene's part by its place
    /// in the application's list, then the whole.
    @MainActor
    func inspected(_ tally: RenderTally, generation: Int32) {
        let apply = RenderTally.micros(ContinuousClock.now - tally.began)
        for (scene, spent) in tally.scenes {
            guard case .manual(let name) = scene, let index = Scenes.shared.index(of: name) else { continue }
            Inspection.applied(generation: generation, scene: index, micros: RenderTally.micros(spent))
        }
        Inspection.applied(
            generation: generation,
            InspectedHost(apply: apply, nodes: tally.nodes, made: tally.made, kept: tally.nodes - tally.made))
    }

    // MARK: - The display cycle

    /// Whether any state or engine waits for a display cycle.
    public var cyclesPending: Bool { StateUIHost.cyclesPending }

    /// The last display cycle as one line.
    public var cycleTrace: String { StateUIHost.cycleTrace }

    /// What this process's renders came to - the tally a runtime prints to count leaks.
    public var tally: HostTally { StateUIHost.tally }

    /// Runs the display's cycle at `now` and returns what it published.
    public func cycle(now: Double, reducesMotion: Bool) -> HostCycle {
        StateUIHost.cycle(.display, now: now, reducesMotion: reducesMotion)
    }

    /// The complete image of an attached state.
    public func value(for binding: HostStateBinding) -> HostStateValue? {
        StateUIHost.value(for: binding)
    }

    /// Reports a complete text, plain value or feed a user changed.
    @discardableResult
    public func report(_ value: HostStateValue, through binding: HostStateBinding) -> Bool {
        StateUIHost.report(value, through: binding)
    }

    /// Reports where a host-walked journey stands.
    @discardableResult
    public func report(
        _ journey: HostJourney,
        updating update: HostJourneyUpdate,
        through binding: HostStateBinding
    ) -> Bool {
        StateUIHost.report(journey, updating: update, through: binding)
    }

    /// Answers the caller awaiting a journey's end.
    @discardableResult
    public func complete(_ completion: Int, succeeded: Bool) -> Bool {
        StateUIHost.complete(completion, succeeded: succeeded)
    }

    /// Where a one-lane state named by a native gesture stands.
    public func gestureValue(state: Int32) -> Double? {
        StateUIHost.gestureValue(state: state)
    }

    /// Moves a one-lane state named by a native gesture.
    @discardableResult
    public func moveGestureValue(_ value: Double, state: Int32) -> Bool {
        StateUIHost.moveGestureValue(value, state: state)
    }

    // MARK: - Events, jobs and acts

    /// Reports a native event and runs its handler.
    @discardableResult
    public func dispatch(_ handler: Int32, payload: [HostValue] = []) -> Bool {
        StateUIHost.dispatch(handler, payload: payload)
    }

    /// Runs the jobs waiting on StateUI's UI executor.
    @discardableResult
    public func runJobs() -> Int { StateUIHost.runJobs() }

    /// Parks the doorbell's thread until work arrives.
    public func waitForWork() -> Int { StateUIHost.waitForWork() }

    /// Takes the act calls queued since the previous pump.
    public func takeActCalls() -> [HostActCall] { StateUIHost.takeActCalls() }

    /// Answers a performed act call with the values it came to.
    @discardableResult
    public func reply(_ completion: Int, with values: [HostValue]) -> Bool {
        StateUIHost.reply(completion, with: values)
    }

    /// Fails an act call this runtime could not perform.
    @discardableResult
    public func fail(_ completion: Int, reason: String) -> Bool {
        StateUIHost.fail(completion, reason: reason)
    }

    /// Raises an application event no control raises; answers how many heard it. Any thread.
    @discardableResult
    public func raise<Owner: ApplicationTier, each Value: HostRepresentable>(
        _ event: ElementEvent<Owner, (repeat each Value)>,
        _ value: repeat each Value
    ) -> Int {
        StateUIHost.raise(event, repeat each value)
    }

    // MARK: - The application, its scenes and its kept values

    /// Reports the appearance themed values resolve against.
    public func setTheme(_ theme: Theme) { StateUIHost.setTheme(theme) }

    /// Reports the device the application runs on.
    public func setDeviceInfo(_ info: HostDeviceInfo) { StateUIHost.setDeviceInfo(info) }

    /// Reports the main display.
    public func setDisplayInfo(_ info: HostDisplayInfo) { StateUIHost.setDisplayInfo(info) }

    /// Reports the application's manifest.
    public func setApplicationInfo(_ info: HostApplicationInfo) {
        StateUIHost.setApplicationInfo(info)
    }

    /// Reports the battery.
    public func setBatteryInfo(_ info: HostBatteryInfo) { StateUIHost.setBatteryInfo(info) }

    /// Reports the network.
    public func setConnectivityInfo(_ info: HostConnectivityInfo) {
        StateUIHost.setConnectivityInfo(info)
    }

    /// Reports the user's locale.
    public func setLocaleInfo(_ info: HostLocaleInfo) { StateUIHost.setLocaleInfo(info) }

    /// Reports the application's lifecycle phase.
    public func setApplicationPhase(_ phase: ApplicationPhase) {
        StateUIHost.setApplicationPhase(phase)
    }

    /// Hands a platform scene to StateUI before its first render.
    public func connectScene(restoring values: [String: HostValue] = [:]) {
        StateUIHost.connectScene(restoring: values)
    }

    /// The keys read from the platform's settings store before the first render.
    public var persistentKeys: [PersistentKey] { StateUIHost.persistentKeys }

    /// Hydrates the kept values found in the store.
    public func restorePersistent(_ values: [String: HostValue]) {
        StateUIHost.restorePersistent(values)
    }
}
