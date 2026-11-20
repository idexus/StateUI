// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

/// What a state channel gives its controls and the core after the animator advances.
@_spi(Host) public struct StateChannelOutput {
    /// The state's number.
    public let state: Int32

    /// How the controls wear the state.
    public let binding: HostStateBinding

    /// Where the state's journey stands.
    public let journey: HostJourney

    /// What the core hears of it; nil where it hears nothing.
    public let report: HostJourneyUpdate?

    /// Who moved it: the channel's animation, the user taking the value, the program stopping it.
    public let origin: WriteOrigin
}

/// How one awaited animation of a state ended.
@_spi(Host) public struct JourneyCompletion: Equatable {
    /// The waiter the core is to answer.
    public let id: Int

    /// How its run ended.
    public let outcome: HostMotionOutcome

    /// The answer `outcome` for the waiter `id`.
    public init(id: Int, outcome: HostMotionOutcome) {
        self.id = id
        self.outcome = outcome
    }
}

/// One channel per host-carried `@State`, shared by every control bound to it.
/// Design: docs/design/host/motion.md#state-channels
@_spi(Host) @MainActor public final class StateChannels {
    private let animator: Animator
    private var channels: [Int32: StateChannel] = [:]

    /// How many consumers each state has: a channel lives while any does.
    private var wearers: [Int32: Int] = [:]

    /// The states a consumer let go since the last settling, whose channels go if none took them again.
    private var letGo: Set<Int32> = []
    private var outputs: [StateChannelOutput] = []
    private var completions: [JourneyCompletion] = []

    /// State channels whose animations `animator` advances.
    public init(animator: Animator) {
        self.animator = animator
    }

    /// Whether any channel's animation is under way.
    public var isActive: Bool { channels.values.contains(where: \.isActive) }

    /// How many states have a channel.
    public var count: Int { channels.count }

    /// The value a bound property draws, opening the state's channel for its first consumer.
    public func presentedValue(
        for binding: HostStateBinding,
        from carried: HostStateValue,
        now: Double,
        reducesMotion: Bool
    ) -> HostStateValue {
        guard binding.kind == .property,
              let incoming = HostBoundary.journey(from: carried)
        else { return carried }

        let channel: StateChannel

        if let existing = channels[binding.state] {
            existing.binding = binding
            channel = existing
        } else if wearers[binding.state] == nil {
            // No consumer, no channel: a value read for an element that wears nothing is the state's own.
            return carried
        } else {
            channel = StateChannel(
                binding: binding,
                journey: incoming,
                animator: animator,
                now: now,
                reducesMotion: reducesMotion,
                emit: emit)
            channels[binding.state] = channel
        }

        return HostBoundary.value(of: channel.presented)
    }

    /// Applies a sparse StateUI cycle change to the channel it names.
    public func receive(
        _ change: HostStateChange,
        now: Double,
        reducesMotion: Bool
    ) {
        guard let channel = channels[change.state],
              let incoming = HostBoundary.journey(from: change.value)
        else { return }

        // A program's write of a lane a hand holds takes it from the hand first, unless the hand waits for it.
        let taken = channel.interrupted(by: change.changed)
        if !taken.isEmpty {
            channel.sample(now: now, emit: emit)
            interrupts?(change.state, taken)
            channel.drop(taken)
        }

        channel.receive(
            incoming,
            changed: change.changed,
            now: now,
            reducesMotion: reducesMotion,
            emit: emit)
    }

    /// Takes the values an animator advance gave, said once a channel. `reducedMotion` says the advance landed
    /// every animation for the user's asking, which is what a run it landed answers its waiter.
    public func follow(_ steps: [AnimationStep], reducedMotion: Bool = false) {
        var moved: [Int32: [(run: Int, step: AnimationStep)]] = [:]

        for step in steps {
            guard case .state(let number, let run) = step.target else { continue }
            moved[number, default: []].append((run, step))
        }

        for number in moved.keys.sorted() {
            guard let channel = channels[number], let runs = moved[number] else { continue }

            channel.follow(runs, landing: reducedMotion ? .immediate(.reducedMotion) : .animated, emit: emit)
        }
    }

    /// A consumer takes `state`: a control tying one of its properties to it.
    public func attach(_ state: Int32) {
        wearers[state, default: 0] += 1
    }

    /// A consumer lets go of `state`. Its channel goes with the last one as the change that took it is settled
    /// (`settle()`), so a consumer that leaves one element for another in one patch never ends it.
    /// Design: docs/design/host/motion.md#state-channels
    public func detach(_ state: Int32) {
        guard let count = wearers[state] else { return }

        if count > 1 {
            wearers[state] = count - 1
        } else {
            wearers[state] = nil
            letGo.insert(state)
        }
    }

    /// Settles the consumers a patch, or an element leaving, changed: a channel nobody took again goes at once,
    /// its runs with it and nothing said - the core, which counted the same consumers, answers their waiters.
    /// Design: docs/design/host/motion.md#state-channels
    public func settle() {
        for state in letGo.sorted() where wearers[state] == nil {
            channels.removeValue(forKey: state)?.end()
        }
        letGo.removeAll(keepingCapacity: true)
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

    /// What a program's write of lanes a hand holds asks before it lands: whoever holds them lets them go.
    /// Design: docs/design/host/motion.md#a-lane-a-hand-holds
    public var interrupts: ((_ state: Int32, _ lanes: [Int]) -> Void)?

    /// Where `state`'s lanes stand: as the last frame showed them, or - given `now` - with its runs brought there
    /// first. Nil for a state with no channel.
    public func standing(_ state: Int32, now: Double? = nil) -> HostJourney? {
        guard let channel = channels[state] else { return nil }

        if let now { channel.sample(now: now, emit: emit) }
        return channel.presented
    }

    /// A hand holds `lanes` of `state`, each shown where the hand holds it; `defers` says a program's write of one
    /// waits for the hand to let go. Whether the state has a channel to hold.
    @discardableResult
    public func hold(_ state: Int32, _ lanes: [HeldLane], defers: Bool = false) -> Bool {
        guard let channel = channels[state] else { return false }

        channel.hold(lanes, defers: defers, emit: emit)
        return true
    }

    /// The hand lets `lanes` of `state` go, on together as one run under `law` - the state's own where none is
    /// given. Whether the state has a channel.
    @discardableResult
    public func release(
        _ state: Int32, _ lanes: [ReleasedLane], under law: Motion? = nil, now: Double, reducesMotion: Bool
    ) -> Bool {
        guard let channel = channels[state] else { return false }

        channel.release(lanes, under: law, now: now, reducesMotion: reducesMotion, emit: emit)
        return true
    }

    /// The lanes of `state` a hand holds.
    public func held(_ state: Int32) -> [Int] {
        channels[state]?.held.keys.sorted() ?? []
    }

    /// Takes values emitted since the previous take.
    public func takeOutputs() -> [StateChannelOutput] {
        defer { outputs.removeAll(keepingCapacity: true) }
        return outputs
    }

    /// Takes journey completions emitted since the previous take.
    public func takeCompletions() -> [JourneyCompletion] {
        defer { completions.removeAll(keepingCapacity: true) }
        return completions
    }

    private func emit(
        _ channel: StateChannel, report: HostJourneyUpdate?, answered: [JourneyCompletion], origin: WriteOrigin
    ) {
        outputs.append(StateChannelOutput(
            state: channel.binding.state,
            binding: channel.binding,
            journey: channel.presented,
            report: report,
            origin: origin))

        completions.append(contentsOf: answered)
    }
}
