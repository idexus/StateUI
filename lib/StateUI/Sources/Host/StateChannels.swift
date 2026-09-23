// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// What a state channel gives its controls and the core after a step.
@_spi(Host) public struct StateChannelOutput {
    /// The state's number.
    public let state: Int32

    /// How the controls wear the state.
    public let binding: HostStateBinding

    /// Where the state's journey stands.
    public let journey: HostJourney

    /// What the core hears of it; nil where it hears nothing.
    public let report: HostJourneyUpdate?
}

/// How one awaited animation of a state ended.
@_spi(Host) public struct JourneyCompletion: Equatable {
    /// The waiter the core is to answer.
    public let id: Int

    /// Whether it arrived, rather than being cut short.
    public let succeeded: Bool

    /// The answer `succeeded` for the waiter `id`.
    public init(id: Int, succeeded: Bool) {
        self.id = id
        self.succeeded = succeeded
    }
}

/// One channel per host-carried `@State`, shared by every control bound to it.
/// Design: docs/design/host/motion.md#state-channels
@_spi(Host) @MainActor public final class StateChannels {
    private let walker: Walker
    private var channels: [Int32: StateChannel] = [:]

    /// How many controls wear each state: a channel lives while any does.
    private var wearers: [Int32: Int] = [:]
    private var outputs: [StateChannelOutput] = []
    private var completions: [JourneyCompletion] = []

    /// State channels whose trips `walker` walks.
    public init(walker: Walker) {
        self.walker = walker
    }

    /// Whether any channel's trip is under way.
    public var isActive: Bool { channels.values.contains(where: \.isActive) }

    /// How many states have a channel.
    public var count: Int { channels.count }

    /// The value a bound property draws, opening the state's channel for its first control.
    public func presentedValue(
        for binding: HostStateBinding,
        from carried: HostStateValue,
        now: Double,
        reducesMotion: Bool
    ) -> HostStateValue {
        guard binding.kind == .property,
              let incoming = StateUIHost.journey(from: carried)
        else { return carried }

        let channel: StateChannel

        if let existing = channels[binding.state] {
            existing.binding = binding
            channel = existing
        } else {
            channel = StateChannel(
                binding: binding,
                journey: incoming,
                walker: walker,
                now: now,
                reducesMotion: reducesMotion,
                emit: emit)
            channels[binding.state] = channel
        }

        return StateUIHost.value(of: channel.presented)
    }

    /// Applies a sparse StateUI cycle change to the channel it names.
    public func receive(
        _ change: HostStateChange,
        now: Double,
        reducesMotion: Bool
    ) {
        guard let channel = channels[change.state],
              let incoming = StateUIHost.journey(from: change.value)
        else { return }

        channel.receive(
            incoming,
            changed: change.changed,
            now: now,
            reducesMotion: reducesMotion,
            emit: emit)
    }

    /// Takes a walker step's values; a channel no control wears goes once it lands.
    public func follow(_ steps: [Step]) {
        for step in steps {
            guard case .state(let number) = step.target else { continue }
            channels[number]?.follow(step.value, step.velocity, rested: step.rested, emit: emit)
            if step.rested, wearers[number] == nil { channels[number] = nil }
        }
    }

    /// A control ties one of its properties to `state`.
    public func attach(_ state: Int32) {
        wearers[state, default: 0] += 1
    }

    /// A control lets go of `state`; the channel goes with the last one, once it lands.
    public func detach(_ state: Int32) {
        guard let count = wearers[state] else { return }

        if count > 1 {
            wearers[state] = count - 1
            return
        }

        wearers[state] = nil
        if channels[state]?.isActive != true { channels[state] = nil }
    }

    /// The user takes the state at `value` on a two-way control; its animation stops there.
    @discardableResult
    public func take(_ value: [Double], through binding: HostStateBinding) -> Bool {
        guard binding.kind == .property,
              binding.mode != .out,
              let channel = channels[binding.state],
              channel.take(value, emit: emit)
        else { return false }

        return true
    }

    /// Takes values emitted since the previous host pump.
    public func takeOutputs() -> [StateChannelOutput] {
        defer { outputs.removeAll(keepingCapacity: true) }
        return outputs
    }

    /// Takes journey completions emitted since the previous host pump.
    public func takeCompletions() -> [JourneyCompletion] {
        defer { completions.removeAll(keepingCapacity: true) }
        return completions
    }

    private func emit(
        _ channel: StateChannel,
        report: HostJourneyUpdate?,
        completion: JourneyCompletion? = nil
    ) {
        outputs.append(StateChannelOutput(
            state: channel.binding.state,
            binding: channel.binding,
            journey: channel.presented,
            report: report))

        if let completion {
            completions.append(completion)
        }
    }
}

/// One state's channel: its animated value, walked on one trip.
@MainActor
private final class StateChannel {
    var binding: HostStateBinding

    private let walker: Walker
    private let target: TripTarget
    private var value: [Double]
    private var destination: [Double]
    private var velocity: [Double]
    private var motion: Motion
    private var completion: Int?
    private var stopped: UInt64

    /// Whether the walker walks this channel's trip.
    var isActive: Bool { walker.trip(for: target) != nil }

    init(
        binding: HostStateBinding,
        journey: HostJourney,
        walker: Walker,
        now: Double,
        reducesMotion: Bool,
        emit: (StateChannel, HostJourneyUpdate?, JourneyCompletion?) -> Void
    ) {
        self.binding = binding
        self.walker = walker
        target = .state(binding.state)
        value = journey.value
        destination = journey.destination
        velocity = journey.velocity
        motion = journey.motion
        completion = journey.completion
        stopped = journey.stopped

        guard !motion.isCustom else { return }
        aim(
            at: journey,
            usesStatedVelocity: true,
            usesCompletion: true,
            now: now,
            reducesMotion: reducesMotion,
            emit: emit)
    }

    var presented: HostJourney {
        HostJourney(
            value: value,
            destination: destination,
            velocity: velocity,
            motion: motion,
            completion: completion,
            stopped: stopped)
    }

    func receive(
        _ incoming: HostJourney,
        changed: UInt64,
        now: Double,
        reducesMotion: Bool,
        emit: (StateChannel, HostJourneyUpdate?, JourneyCompletion?) -> Void
    ) {
        guard incoming.value.count == value.count else { return }
        let width = value.count

        func changedAny(_ range: Range<Int>) -> Bool {
            range.contains { changed & (UInt64(1) << UInt64(min($0, 63))) != 0 }
        }

        let changedValue = changedAny(0..<width)
        let changedDestination = changedAny(width..<(width * 2))
        let changedVelocity = changedAny((width * 2)..<(width * 3))
        let changedCompletion = changed
            & (UInt64(1) << UInt64(min((width * 3) + 3, 63))) != 0
        let changedStop = changed & (UInt64(1) << UInt64(min((width * 3) + 4, 63))) != 0

        if changedStop {
            sample(now: now, emit: emit)
            if isActive { cancelCompletion(emit: emit) }
            walker.halt(target)
            destination = value
            velocity = Array(repeating: 0, count: width)
            motion = incoming.motion
            stopped = incoming.stopped
            emit(self, .position, nil)
        }

        if changedValue {
            sample(now: now, emit: emit)
            if isActive { cancelCompletion(emit: emit) }
            walker.halt(target)
            value = incoming.value
            destination = incoming.destination
            velocity = incoming.velocity
            motion = incoming.motion
            completion = nil
            stopped = incoming.stopped
        }

        if changedDestination {
            aim(
                at: incoming,
                usesStatedVelocity: changedVelocity,
                usesCompletion: changedCompletion,
                now: now,
                reducesMotion: reducesMotion,
                emit: emit)
        } else if changedVelocity {
            aim(
                at: incoming,
                usesStatedVelocity: true,
                usesCompletion: false,
                now: now,
                reducesMotion: reducesMotion,
                emit: emit)
        } else {
            motion = incoming.motion
            stopped = incoming.stopped
            emit(self, nil, nil)
        }
    }

    /// Takes where the walker put the trip: a frame on the way, or the landing.
    func follow(
        _ lanes: [Double],
        _ speed: [Double],
        rested: Bool,
        emit: (StateChannel, HostJourneyUpdate?, JourneyCompletion?) -> Void
    ) {
        guard !rested else {
            walker.halt(target)
            value = destination
            velocity = Array(repeating: 0, count: value.count)
            let landed = completion.map { JourneyCompletion(id: $0, succeeded: true) }
            completion = nil
            emit(self, .position, landed)
            return
        }

        value = lanes
        velocity = speed.map { $0 * 1_000 }
        emit(self, .frame, nil)
    }

    /// Stops the animation where the user holds the value.
    @discardableResult
    func take(
        _ taken: [Double],
        emit: (StateChannel, HostJourneyUpdate?, JourneyCompletion?) -> Void
    ) -> Bool {
        guard taken.count == value.count else { return false }

        if isActive { cancelCompletion(emit: emit) }
        walker.halt(target)
        value = taken
        destination = taken
        velocity = Array(repeating: 0, count: taken.count)
        completion = nil
        emit(self, .position, nil)
        return true
    }

    private func aim(
        at incoming: HostJourney,
        usesStatedVelocity: Bool,
        usesCompletion: Bool,
        now: Double,
        reducesMotion: Bool,
        emit: (StateChannel, HostJourneyUpdate?, JourneyCompletion?) -> Void
    ) {
        if isActive {
            sample(now: now, emit: emit)
            if isActive { cancelCompletion(emit: emit) }
        }

        motion = incoming.motion
        completion = usesCompletion ? incoming.completion : nil
        stopped = incoming.stopped
        destination = incoming.destination

        if motion.isCustom {
            walker.halt(target)
            value = incoming.value
            velocity = incoming.velocity
            emit(self, nil, nil)
            return
        }

        let trip = Trip(
            from: value,
            destination: destination,
            velocity: (usesStatedVelocity ? incoming.velocity : velocity).map { $0 / 1_000 },
            motion: motion,
            began: now)
        velocity = trip.velocity.map { $0 * 1_000 }

        let instant = motion.law == .eased && motion.millis == 0

        if instant || reducesMotion || trip.arrives {
            walker.halt(target)
            value = destination
            velocity = Array(repeating: 0, count: value.count)
            let landed = completion.map { JourneyCompletion(id: $0, succeeded: true) }
            completion = nil
            emit(self, .position, landed)
            return
        }

        walker.start(trip, for: target)
        emit(self, .position, nil)
    }

    /// Brings the value to where the trip stands at `now`, before a change lands.
    private func sample(
        now: Double,
        emit: (StateChannel, HostJourneyUpdate?, JourneyCompletion?) -> Void
    ) {
        guard let trip = walker.trip(for: target) else { return }

        let position = trip.position(at: now)
        follow(position.value, position.velocity, rested: position.rested, emit: emit)
    }

    private func cancelCompletion(
        emit: (StateChannel, HostJourneyUpdate?, JourneyCompletion?) -> Void
    ) {
        guard let completion else { return }
        self.completion = nil
        emit(self, nil, JourneyCompletion(id: completion, succeeded: false))
    }
}
