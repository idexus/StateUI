// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// The typed boundary for a Swift host in this process: the renderer's sparse patch
// as it is.
// Design: docs/design/core/README.md#the-typed-boundary

/// Operations a native Swift host performs on the StateUI runtime.
@_spi(Host) @MainActor public enum HostBoundary {
    /// Whether state changed since the last render.
    public static var needsRender: Bool { Renderer.shared.needsRender }

    /// Updates the appearance used to resolve themed values before rendering.
    public static func setColorScheme(_ theme: ColorScheme) {
        let turned = StandardEnvironment.application.info.colorScheme != theme
        update(StandardEnvironment.application.info, \.colorScheme, theme)
        if turned { StandardEnvironment.application.themeTurned() }
    }

    /// Updates the accent in force: the user's, or the application's where the platform took it.
    public static func setAccentColor(_ color: Color) {
        update(StandardEnvironment.application.info, \.accentColor, color)
    }

    /// Replaces the standard device report used by application builds.
    public static func setDeviceInfo(_ info: HostDeviceInfo) {
        let device = StandardEnvironment.device.info
        update(device, \.formFactor, info.formFactor)
        update(device, \.platform, info.platform)
        update(device, \.model, info.model)
        update(device, \.manufacturer, info.manufacturer)
        update(device, \.name, info.name)
        update(device, \.versionString, info.versionString)
        update(device, \.isVirtual, info.isVirtual)
    }

    /// Replaces the standard main-display report used by application builds.
    public static func setDisplayInfo(_ info: HostDisplayInfo) {
        let display = StandardEnvironment.device.display
        update(display, \.width, info.width)
        update(display, \.height, info.height)
        update(display, \.density, info.density)
        update(display, \.orientation, info.orientation)
        update(display, \.rotation, info.rotation)
        update(display, \.refreshRate, info.refreshRate)
    }

    /// The application's name, as the host reported it - what a host shows where a sidebar says no title.
    public static var applicationName: String { StandardEnvironment.application.info.name }

    /// The application's session - what `@Environment(\.application)` reads - for a test that sets what the
    /// application writes, its motion.
    public static var application: ApplicationSession { StandardEnvironment.application }

    /// Replaces the standard application-manifest report used by builds.
    public static func setApplicationInfo(_ info: HostApplicationInfo) {
        let app = StandardEnvironment.application.info
        update(app, \.name, info.name)
        update(app, \.packageName, info.packageName)
        update(app, \.versionString, info.versionString)
        update(app, \.buildString, info.buildString)
    }

    /// Replaces the standard battery report.
    public static func setBatteryInfo(_ info: HostBatteryInfo) {
        let battery = StandardEnvironment.device.battery
        update(battery, \.chargeLevel, info.chargeLevel)
        update(battery, \.state, info.state)
        update(battery, \.powerSource, info.powerSource)
        update(battery, \.energySaverStatus, info.energySaverStatus)
    }

    /// Replaces the standard report of the user's accessibility settings.
    public static func setAccessibilityInfo(_ info: HostAccessibilityInfo) {
        let settings = StandardEnvironment.device.accessibility
        update(settings, \.reducesMotion, info.reducesMotion)
        update(settings, \.prefersHigherContrast, info.prefersHigherContrast)
        update(settings, \.isScreenReaderOn, info.isScreenReaderOn)
        update(settings, \.textScale, info.textScale)
    }

    /// Replaces the standard connectivity report.
    public static func setConnectivityInfo(_ info: HostConnectivityInfo) {
        let connectivity = StandardEnvironment.device.connectivity
        update(connectivity, \.networkAccess, info.networkAccess)
        update(connectivity, \.connectionProfiles, info.connectionProfiles)
    }

    /// What a window's chrome says of its own controls - back, the sidebar, close, more - in the system's language.
    public static var chromeWords: ChromeWords { LibraryWords.inSystemLanguage.chrome }

    /// What an Edit menu says of the entries a host keeps in it, in the system's language.
    public static var editWords: EditWords { LibraryWords.inSystemLanguage.edit }

    /// What a control a host composes says of its own parts - a stepper's step down and up - in the system's language.
    public static var controlWords: ControlWords { LibraryWords.inSystemLanguage.control }

    /// Replaces the standard locale report.
    public static func setLocaleInfo(_ info: HostLocaleInfo) {
        let locale = StandardEnvironment.locale
        update(locale, \.language, info.language)
        update(locale, \.region, info.region)
        update(locale, \.name, info.name)
        update(locale, \.timeZone, info.timeZone)
        update(locale, \.uses24HourClock, info.uses24HourClock)
        update(locale, \.firstDayOfWeek, info.firstDayOfWeek)
        update(locale, \.isMetric, info.isMetric)
        update(locale, \.layoutDirection, info.layoutDirection == .rightToLeft ? .rightToLeft : .leftToRight)
        update(locale, \.languages, info.languages.map { LocaleTag($0) })
    }

    /// The way the user's language is written, as the host last reported it.
    public static var languageDirection: LayoutDirection {
        StandardEnvironment.locale.layoutDirection
    }

    /// Hands StateUI a window the platform made, before its first render.
    ///
    /// The platform's first window is the one launch opens. A window it kept
    /// comes as the `windowType` and the `windowValue` it carried, with its
    /// scene's kept values, which land before that scene builds where it opens
    /// with this window - so `@State(sceneKey:)` never briefly exposes its
    /// declared default. A new window of no kind is one more of the group with
    /// no name. Answers the number of the scene the window opened in, nil where
    /// no scene declares it - the host closes that one.
    /// Design: docs/design/core/scenes.md#what-the-platform-hands-over
    @discardableResult
    public static func connectWindow(
        kind: String? = nil, value: String? = nil, restoring values: [String: HostValue] = [:]
    ) -> String? {
        OpenScenes.shared.connected(kind: kind, text: value, restoring: values)
    }

    /// Updates the process-wide application session from native lifecycle.
    public static func setApplicationPhase(_ phase: ApplicationPhase) {
        update(StandardEnvironment.application, \.phase, phase)
    }

    /// Writes a report's field where it differs, so a report that repeats itself asks for no render.
    /// Design: docs/design/types/environment.md#a-report-that-repeats-itself
    private static func update<Provider: AnyObject, Value: Equatable>(
        _ provider: Provider, _ field: ReferenceWritableKeyPath<Provider, Value>, _ value: Value
    ) {
        guard provider[keyPath: field] != value else { return }
        provider[keyPath: field] = value
        environmentChanges += 1
    }

    /// How many fields the host's reports have changed so far: a report repeating what stands leaves it.
    /// Design: docs/design/types/environment.md#a-report-that-repeats-itself
    public private(set) static var environmentChanges = 0

    /// Gives the core the reader of the host's store: a kept key's name and kind to the value the store holds under
    /// it, nil for none. A state kept under a key reads it as it is first made - every key claimed before the reader
    /// came reads it now - so a value is back at the launch it is first needed in.
    /// Design: docs/design/core/state.md#kept-state
    public static func readsKept(_ reader: @escaping @MainActor (_ name: String, _ kind: PersistentKind) -> HostValue?) {
        PersistentStore.shared.reads(reader)
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
            })
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

    /// What this process's renders came to, for a host that prints the tally.
    public static var tally: HostTally {
        let renderer = Renderer.shared
        return HostTally(
            renders: renderer.renders, empty: renderer.emptyRenders,
            refused: renderer.refusedWrites, alive: renderer.liveNodes, runs: RunSlot.underWay,
            built: renderer.built, walks: renderer.walks, texts: renderer.texts)
    }

    /// Reports a native event: its handlers start at once on `MainActor`, each
    /// through its gate; false for an unknown id.
    @discardableResult
    public static func dispatch(_ handler: Int32, payload: [HostValue] = []) -> Bool {
        EventBuffer.current = payload
        return Renderer.shared.dispatch(Int(handler))
    }

    /// Raises an event of the application's - one no control raises - with
    /// the values its contract declares, as the platform reported them, from
    /// any thread: every `HostEvents.on` subscription to the member hears them
    /// in a job of the UI thread's soon after, in the order raised. Typed at the
    /// call: the values are the member's, so a raise of another shape does not
    /// compile. A raise nobody hears is an ordinary one.
    ///
    ///     HostBoundary.raise(GalleryContract.batteryChanged, level, charging)
    ///
    /// - Parameters:
    ///   - event: the member, written with its contract.
    ///   - value: what it carries, in the order its contract declares.
    public nonisolated static func raise<Owner: ApplicationTier, each Value: HostRepresentable>(
        _ event: ElementEvent<Owner, (repeat each Value)>,
        _ value: repeat each Value
    ) {
        RaisedEvents.shared.raise(EventMember(event), MemberValues.encode(repeat each value))
    }

    /// Tells the core what this host realizes - its `Registry.realization` -
    /// replacing what it said before. Until a host says, the core knows of
    /// nothing realized.
    ///
    /// - Parameter realization: the elements and members this host realizes.
    public static func setRealization(_ realization: HostRealization) {
        HostRealizations.current = realization
    }

    /// Tells the core what the host judges it realizes, member by member - what `Device.honors` answers from. The
    /// register is read when first asked, not as it is told: building it costs, and a host tells it at each start.
    ///
    /// - Parameter register: the host's register, its runtime's realization behind its own records.
    public static func setRegister(_ register: @autoclosure @escaping () -> HostRegister?) {
        HostRealizations.registerSource = register
    }

    /// Whether this host makes a view for an element.
    ///
    /// - Parameter contract: the element's contract.
    /// - Returns: whether the host said it realizes the element.
    public static func realizes(_ contract: any ElementContract.Type) -> Bool {
        HostRealizations.current.elements.contains(contract.nodeType)
    }

    /// Whether this host realizes a property, on any element.
    ///
    /// - Parameter member: the property, written with its contract.
    /// - Returns: whether the host said it realizes the property.
    public static func realizes<Owner: Contract, Value>(_ member: ElementProperty<Owner, Value>) -> Bool {
        HostRealizations.realizes(member.token.key, of: member.owner)
    }

    /// Whether this host raises an event, on any element.
    ///
    /// - Parameter member: the event, written with its contract.
    /// - Returns: whether the host said it raises the event.
    public static func realizes<Owner: Contract, Payload>(_ member: ElementEvent<Owner, Payload>) -> Bool {
        HostRealizations.realizes(member.token.key, of: member.owner)
    }

    /// Claims the calling thread as the UI thread, whose jobs are `MainActor`'s, and runs what waits - what a host's
    /// start does first, before anything starts a task.
    /// Design: docs/design/core/concurrency.md#mainactor-on-every-platform
    public nonisolated static func claimUIThread() {
        UIThreadExecutor.install()
        stateUIRunJobs()
    }

    /// Runs jobs waiting on StateUI's UI executor on the calling thread.
    @discardableResult
    public nonisolated static func runJobs() -> Int { stateUIRunJobs() }

    /// Says how a turn is put on the UI thread's queue from any thread: the core posts one through `post` when the
    /// UI thread makes work, and when a job is queued from any thread, on that thread. A host whose loop turns by
    /// itself says nothing; nil posts no more - between a host's tests. One turn is posted at once, for what came
    /// before.
    /// Design: docs/design/core/concurrency.md#the-doorbell
    public static func postTurns(with post: (@Sendable () -> Void)?) {
        UIThreadExecutor.shared.postTurns(with: post)
    }

    /// Whether a turn has anything to do: jobs on the UI executor, acts or saves not taken, a render, a cycle
    /// asked for - a write, an engine armed or stirred; an engine going on of its own waits for the display's frame.
    /// Design: docs/design/host/runtime.md#the-turn-on-apple
    public static var wantsTurn: Bool {
        let renderer = Renderer.shared
        return UIThreadExecutor.shared.pendingCount > 0 || renderer.actCallsPending > 0 || renderer.needsRender
            || renderer.cycleAsked()
    }

    /// Whether a cycle waits on something a turn answers at once - a write, an engine armed or woken - rather than
    /// on an engine going on of its own, which the display's frame serves.
    public static var cyclesAsked: Bool { Renderer.shared.cycleAsked() }

    /// A runtime brought its frame clock: the cycles take their time from it from its start, the first a start.
    /// Design: docs/design/core/cycle.md#a-start-is-a-gap
    public static func clockStarted() {
        Renderer.shared.clockStarted()
    }

    #if os(WASI)
    /// When the page is to call again, in milliseconds - at once where jobs, acts or a render wait, else when a job
    /// kept for later comes due; nil with nothing to come. A display frame serves a cycle.
    /// Design: docs/design/core/concurrency.md#webassembly
    public static var nextWake: Double? {
        let renderer = Renderer.shared
        if UIThreadExecutor.shared.pendingCount > 0 || renderer.actCallsPending > 0 || renderer.needsRender { return 0 }
        guard let due = UIThreadExecutor.shared.nextDue else { return nil }
        return max(0, Double(due.components.seconds) * 1000 + Double(due.components.attoseconds) / 1e15)
    }
    #endif

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
