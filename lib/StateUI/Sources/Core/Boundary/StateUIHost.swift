// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// The typed boundary for a Swift host in this process: the renderer's sparse patch
// as it is. A runtime in another language receives its Wire encoding.
// Design: docs/design/core/README.md#two-ways-out

/// Operations a native Swift host performs on the StateUI runtime.
@_spi(Host) public enum StateUIHost {
    /// Whether state changed since the last render.
    public static var needsRender: Bool { Renderer.shared.needsRender }

    /// Updates the appearance used to resolve themed values before rendering.
    public static func setTheme(_ theme: Theme) {
        StandardEnvironment.app.requestedTheme = theme
    }

    /// Replaces the standard device report used by application builds.
    public static func setDeviceInfo(_ info: HostDeviceInfo) {
        let device = StandardEnvironment.device
        device.formFactor = info.formFactor
        device.platform = info.platform
        device.model = info.model
        device.manufacturer = info.manufacturer
        device.name = info.name
        device.versionString = info.versionString
        device.deviceType = info.deviceType
    }

    /// Replaces the standard main-display report used by application builds.
    public static func setDisplayInfo(_ info: HostDisplayInfo) {
        let display = StandardEnvironment.display
        display.width = info.width
        display.height = info.height
        display.density = info.density
        display.orientation = info.orientation
        display.rotation = info.rotation
        display.refreshRate = info.refreshRate
    }

    /// Replaces the standard application-manifest report used by builds.
    public static func setApplicationInfo(_ info: HostApplicationInfo) {
        let app = StandardEnvironment.app
        app.name = info.name
        app.packageName = info.packageName
        app.versionString = info.versionString
        app.buildString = info.buildString
    }

    /// Replaces the standard battery report.
    public static func setBatteryInfo(_ info: HostBatteryInfo) {
        let battery = StandardEnvironment.battery
        battery.chargeLevel = info.chargeLevel
        battery.state = info.state
        battery.powerSource = info.powerSource
        battery.energySaverStatus = info.energySaverStatus
    }

    /// Replaces the standard connectivity report.
    public static func setConnectivityInfo(_ info: HostConnectivityInfo) {
        let connectivity = StandardEnvironment.connectivity
        connectivity.networkAccess = info.networkAccess
        connectivity.connectionProfiles = info.connectionProfiles
    }

    /// Replaces the standard locale report.
    public static func setLocaleInfo(_ info: HostLocaleInfo) {
        let locale = StandardEnvironment.locale
        locale.language = info.language
        locale.region = info.region
        locale.name = info.name
        locale.timeZone = info.timeZone
        locale.uses24HourClock = info.uses24HourClock
        locale.firstDayOfWeek = info.firstDayOfWeek
        locale.isMetric = info.isMetric
    }

    /// Hands a platform-created scene to StateUI before its first render.
    ///
    /// The first call claims the scene prepared when the application was
    /// registered. Every later call creates another independent scene. Values
    /// restored by the platform land before that scene builds, so
    /// `@State(sceneKey:)` never briefly exposes its declared default.
    public static func connectScene(restoring values: [String: HostValue] = [:]) {
        Scenes.shared.connected(restoring: values)
    }

    /// Updates the process-wide application session from native lifecycle.
    public static func setApplicationPhase(_ phase: ApplicationPhase) {
        StandardEnvironment.application.phase = phase
    }

    /// The platform store selected by the registered application.
    public static var persistentStorage: PersistentStorage {
        StandardEnvironment.application.persistentStorage
    }

    /// The typed keys the host reads before the first application render.
    public static var persistentKeys: [PersistentKey] {
        StandardEnvironment.application.persistentKeys
    }

    /// Hydrates values found in the native store before the first render.
    public static func restorePersistent(_ values: [String: HostValue]) {
        PersistentStore.shared.hydrate(
            values.sorted { $0.key < $1.key }.map { (name: $0.key, value: $0.value) })
    }

    /// Decodes a complete property-state image for a native motion channel.
    ///
    /// Returns nil for text, plain values, feeds, placement runs and malformed
    /// images. The lane layout remains an implementation detail of StateUI.
    public static func journey(from value: HostStateValue) -> HostJourney? {
        guard case .lanes(let lanes) = value else { return nil }

        let remainder = lanes.count - StateLaw.lanes - 2
        guard remainder > 0, remainder.isMultiple(of: 3) else { return nil }

        let width = remainder / 3
        let lawStart = width * 3
        let completionLane = lanes[lawStart + StateLaw.lanes]
        let stopped = lanes[lawStart + StateLaw.lanes + 1]
        guard lanes.allSatisfy(\.isFinite),
              let completion = Int(exactly: completionLane),
              let stoppedCount = UInt64(exactly: stopped)
        else { return nil }

        return HostJourney(
            value: Array(lanes[0..<width]),
            destination: Array(lanes[width..<(width * 2)]),
            velocity: Array(lanes[(width * 2)..<(width * 3)]),
            motion: StateLaw.motion(
                of: Array(lanes[lawStart..<(lawStart + StateLaw.lanes)])),
            completion: completion == 0 ? nil : completion,
            stopped: stoppedCount)
    }

    /// Encodes a typed journey as the complete state image a host applies.
    public static func value(of journey: HostJourney) -> HostStateValue {
        .lanes(
            journey.value
                + journey.destination
                + journey.velocity
                + StateLaw.lanes(of: journey.motion)
                + [Double(journey.completion ?? 0), Double(journey.stopped)])
    }

    /// Decodes an engine-authored arrangement without exposing its lane layout.
    public static func placements(from value: HostStateValue) -> HostPlacementRun? {
        guard let run = PlacedRun(carried: value) else { return nil }

        return HostPlacementRun(
            placements: run.placements.map {
                HostPlacement(
                    bounds: $0.bounds,
                    translationX: $0.transform.x,
                    translationY: $0.transform.y,
                    rotation: $0.transform.rotation,
                    scaleX: $0.transform.width,
                    scaleY: $0.transform.height,
                    opacity: $0.opacity,
                    zIndex: $0.zIndex,
                    shade: $0.shade)
            },
            motion: run.motion)
    }

    /// Builds and returns a typed patch against the generation the host holds.
    public static func render(baseline: Int32) -> HostRender {
        Renderer.shared.renderHost(baseline: baseline)
    }

    /// Reads the complete image for an outward state attachment.
    ///
    /// Text and plain values arrive in their declared shape. A moving
    /// property carries its complete journey so a host can retain one motion
    /// channel for every state number.
    public static func value(for binding: HostStateBinding) -> HostStateValue? {
        Renderer.shared.hostValue(for: binding)
    }

    /// Reads where a one-lane state named directly by `panX` or `panY` stands.
    public static func gestureValue(state: Int32) -> Double? {
        Renderer.shared.hostGestureValue(state: state)
    }

    /// Moves the first lane of a state named directly by a native gesture.
    /// The host advances its StateUI cycle immediately after this write.
    @discardableResult
    public static func moveGestureValue(_ value: Double, state: Int32) -> Bool {
        Renderer.shared.hostMovedGesture(value, state: state)
    }

    /// Reports a complete text, plain value, or feed through an inward state
    /// attachment.
    ///
    /// A moving property reports through its host motion channel instead; its
    /// image contains the value, destination, velocity, law and completion,
    /// rather than only the value a user moved.
    @discardableResult
    public static func report(
        _ value: HostStateValue,
        through binding: HostStateBinding
    ) -> Bool {
        Renderer.shared.hostReported(value, through: binding)
    }

    /// Reports the host-owned position of a moving property state.
    ///
    /// A frame normally updates only `value` and `velocity`. Aiming, stopping
    /// and landing also update `destination`, keeping the journey's three
    /// numerical groups coherent without exposing their lane layout.
    ///
    /// - Parameters:
    ///   - journey: The complete journey after the host-side change.
    ///   - update: The numerical groups the host changed.
    ///   - binding: Any inward-capable property attachment on this state.
    /// - Returns: Whether the current attachment accepted the report.
    @discardableResult
    public static func report(
        _ journey: HostJourney,
        updating update: HostJourneyUpdate,
        through binding: HostStateBinding
    ) -> Bool {
        Renderer.shared.hostReported(journey, updating: update, through: binding)
    }

    /// Completes an awaited journey after its host motion ends or is replaced.
    ///
    /// - Parameters:
    ///   - completion: The negative continuation id carried by the journey.
    ///   - succeeded: Whether the journey reached its destination.
    /// - Returns: Whether a continuation still waited under that id.
    @discardableResult
    public static func complete(_ completion: Int, succeeded: Bool) -> Bool {
        guard completion < 0 else { return false }
        ReplyBuffer.current = .finished([.bool(succeeded)])
        return Renderer.shared.dispatch(completion)
    }

    /// Advances one StateUI clock and returns the state values it published.
    public static func cycle(
        _ sync: Sync,
        now: Double,
        reducesMotion: Bool
    ) -> HostCycle {
        Renderer.shared.hostCycle(sync: sync, now: now, reducesMotion: reducesMotion)
    }

    /// Whether any state or engine is waiting for a host cycle.
    public static var cyclesPending: Bool { Renderer.shared.cycleAwake() != 0 }

    /// Reports a native event and runs its handler on StateUI's UI executor.
    @discardableResult
    public static func dispatch(_ handler: Int32, payload: [HostValue] = []) -> Bool {
        EventBuffer.current = payload
        return Renderer.shared.dispatch(Int(handler))
    }

    /// Raises an event of the application's - one no control raises - with
    /// the values its contract declares, as the platform reported them: every
    /// `HostEvents.on` subscription to the member hears them, each handler
    /// queued on this library's executor for the next `runJobs`. The road a
    /// foreign host's raise takes through the export, typed at the call: the
    /// values are the member's, so a raise of another shape does not compile.
    ///
    ///     StateUIHost.raise(GalleryContract.batteryChanged, level, charging)
    ///
    /// - Parameters:
    ///   - event: the member, written with its contract.
    ///   - value: what it carries, in the order its contract declares.
    /// - Returns: how many subscriptions heard it - a raise nobody hears is
    ///   an ordinary zero.
    @discardableResult
    public static func raise<Owner: ApplicationTier, each Value: HostRepresentable>(
        _ event: ElementEvent<Owner, (repeat each Value)>,
        _ value: repeat each Value
    ) -> Int {
        HostEvents.dispatch(event.token.name, MemberValues.encode(repeat each value))
    }

    /// Tells the core what this host realizes - its `Registry.realization`,
    /// or what a host across the Wire reported - replacing what it said
    /// before. Until a host says, the core knows of nothing realized.
    ///
    /// - Parameter realization: the elements and members this host realizes.
    public static func setRealization(_ realization: HostRealization) {
        HostRealizations.current = realization
    }

    /// Whether this host makes a view for an element.
    ///
    /// - Parameter contract: the element's contract.
    /// - Returns: whether the host said it realizes the element.
    public static func realizes(_ contract: any ElementContract.Type) -> Bool {
        HostRealizations.current.elements.contains(contract.nodeType.name)
    }

    /// Whether this host realizes a property, on any element.
    ///
    /// - Parameter member: the property, written with its contract.
    /// - Returns: whether the host said it realizes the property.
    public static func realizes<Owner: Contract, Value>(_ member: ElementProperty<Owner, Value>) -> Bool {
        HostRealizations.current.members.contains { $0.owner == Owner.name && $0.member == member.name }
    }

    /// Whether this host raises an event, on any element.
    ///
    /// - Parameter member: the event, written with its contract.
    /// - Returns: whether the host said it raises the event.
    public static func realizes<Owner: Contract, Payload>(_ member: ElementEvent<Owner, Payload>) -> Bool {
        HostRealizations.current.members.contains { $0.owner == Owner.name && $0.member == member.name }
    }

    /// Runs jobs waiting on StateUI's UI executor on the calling thread.
    @discardableResult
    public static func runJobs() -> Int { stateUIRunJobs() }

    /// Parks the calling doorbell thread until asynchronous work arrives, and
    /// answers how much is waiting - which can be 0, when another turn got
    /// there first.
    ///
    /// Four kinds of work, each of which a handler resumed on the pool can
    /// leave with nothing else to announce it: jobs in the executor's queue,
    /// acts not yet taken, a tree a write left dirty, and a value waiting on
    /// its board for a cycle - a driven write nobody reads, or a movement
    /// `move(to:)` sent. Each wakes this thread after it lands, so the thread
    /// cannot wake, count nothing and park again with the work behind it.
    public static func waitForWork() -> Int {
        UIThreadExecutor.shared.waitForWork()
            + Renderer.shared.actCallsPending
            + (Renderer.shared.needsRender ? 1 : 0)
            + (Renderer.shared.cycleAwake() > 0 ? 1 : 0)
    }

    /// Takes the act calls queued since the previous host pump, in the order
    /// the application made them.
    public static func takeActCalls() -> [HostActCall] {
        Renderer.shared.takeActCalls().map(HostActCall.init)
    }

    /// Answers a performed act call with the values it came to.
    ///
    /// The awaiting `stateUICall` resumes with exactly these values - none
    /// for an act that returns nothing.
    ///
    /// - Parameters:
    ///   - completion: The negative id the act call carried.
    ///   - values: What the act came to, in the order it declares them.
    /// - Returns: Whether a caller still waited under that id.
    @discardableResult
    public static func reply(_ completion: Int, with values: [HostValue]) -> Bool {
        guard completion < 0 else { return false }
        ReplyBuffer.current = .finished(values)
        return Renderer.shared.dispatch(completion)
    }

    /// Fails an act call the host could not perform.
    ///
    /// The awaiting `stateUICall` throws `StateUIError` carrying `reason`.
    ///
    /// - Parameters:
    ///   - completion: The negative id the act call carried.
    ///   - reason: Why the host could not perform it.
    /// - Returns: Whether a caller still waited under that id.
    @discardableResult
    public static func fail(_ completion: Int, reason: String) -> Bool {
        guard completion < 0 else { return false }
        ReplyBuffer.current = .failed(reason)
        return Renderer.shared.dispatch(completion)
    }
}
