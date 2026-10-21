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
    private let animator: Animator
    private var channels: [Int32: StateChannel] = [:]

    /// How many controls wear each state: a channel lives while any does.
    private var wearers: [Int32: Int] = [:]
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

    /// The value a bound property draws, opening the state's channel for its first control.
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

        channel.receive(
            incoming,
            changed: change.changed,
            now: now,
            reducesMotion: reducesMotion,
            emit: emit)
    }

    /// Takes the values an animator advance gave, said once a channel; a channel no control wears goes once it
    /// lands.
    public func follow(_ steps: [AnimationStep]) {
        var moved: [Int32: [(run: Int, step: AnimationStep)]] = [:]

        for step in steps {
            guard case .state(let number, let run) = step.target else { continue }
            moved[number, default: []].append((run, step))
        }

        for number in moved.keys.sorted() {
            guard let channel = channels[number], let runs = moved[number] else { continue }

            channel.follow(runs, emit: emit)
            if !channel.isActive, wearers[number] == nil { channels[number] = nil }
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

    private func emit(_ channel: StateChannel, report: HostJourneyUpdate?, answered: [JourneyCompletion]) {
        outputs.append(StateChannelOutput(
            state: channel.binding.state,
            binding: channel.binding,
            journey: channel.presented,
            report: report))

        completions.append(contentsOf: answered)
    }
}

/// What a channel says after a change: itself, what the core hears, and the waiters answered.
private typealias StateChannelEmit = (StateChannel, HostJourneyUpdate?, [JourneyCompletion]) -> Void

/// One state's channel: its animated value, traveling in runs - the lanes one write sent on together, each an
/// animation of its own - so a write of some lanes leaves the other lanes' travel and their waiter as they were.
/// Design: docs/design/host/motion.md#a-channel-lane-by-lane
@MainActor
private final class StateChannel {
    var binding: HostStateBinding

    private let animator: Animator
    private var value: [Double]
    private var destination: [Double]
    private var velocity: [Double]
    private var motion: Motion
    private var stopped: UInt64

    /// The runs under way by number, and the last number given.
    private var runs: [Int: Run] = [:]
    private var numbered = 0

    /// Lanes traveling together, and the waiter their arrival answers.
    private struct Run {
        var lanes: [Int]
        var completion: Int?
    }

    /// Whether any run of this channel is under way.
    var isActive: Bool { !runs.isEmpty }

    init(
        binding: HostStateBinding,
        journey: HostJourney,
        animator: Animator,
        now: Double,
        reducesMotion: Bool,
        emit: StateChannelEmit
    ) {
        self.binding = binding
        self.animator = animator
        value = journey.value
        destination = journey.destination
        velocity = journey.velocity
        motion = journey.motion
        stopped = journey.stopped

        guard motion.kind != .custom else { return }
        aim(
            Array(value.indices),
            at: journey,
            stated: Array(value.indices),
            usesCompletion: true,
            now: now,
            reducesMotion: reducesMotion,
            emit: emit)
    }

    /// The journey as it stands; its waiter the newest run's.
    var presented: HostJourney {
        HostJourney(
            value: value,
            destination: destination,
            velocity: velocity,
            motion: motion,
            completion: runs.keys.max().flatMap { runs[$0]?.completion },
            stopped: stopped)
    }

    func receive(
        _ incoming: HostJourney,
        changed: UInt64,
        now: Double,
        reducesMotion: Bool,
        emit: StateChannelEmit
    ) {
        guard incoming.value.count == value.count else { return }
        let width = value.count
        let all = Array(value.indices)

        func names(_ lane: Int) -> Bool { changed & (UInt64(1) << UInt64(min(lane, 63))) != 0 }
        func named(from first: Int) -> [Int] { all.filter { names(first + $0) } }

        let values = named(from: 0)
        let destinations = named(from: width)
        let velocities = named(from: width * 2)
        let changedCompletion = names((width * 3) + 3)
        let changedStop = names((width * 3) + 4)

        if changedStop {
            sample(now: now, emit: emit)
            halt(all, emit: emit)
            destination = value
            velocity = Array(repeating: 0, count: width)
            motion = incoming.motion
            stopped = incoming.stopped
            emit(self, .position, [])
        }

        if !values.isEmpty {
            sample(now: now, emit: emit)
            halt(values, emit: emit)
            for lane in values {
                value[lane] = incoming.value[lane]
                destination[lane] = incoming.destination[lane]
                velocity[lane] = incoming.velocity[lane]
            }
            motion = incoming.motion
            stopped = incoming.stopped
        }

        if !destinations.isEmpty {
            aim(
                destinations,
                at: incoming,
                stated: velocities,
                usesCompletion: changedCompletion,
                now: now,
                reducesMotion: reducesMotion,
                emit: emit)
        } else if !velocities.isEmpty {
            aim(
                velocities,
                at: incoming,
                stated: velocities,
                usesCompletion: false,
                now: now,
                reducesMotion: reducesMotion,
                emit: emit)
        } else {
            motion = incoming.motion
            stopped = incoming.stopped
            emit(self, nil, [])
        }
    }

    /// Takes where the animator put each run - a frame on the way, or the landing - and says it once.
    func follow(_ steps: [(run: Int, step: AnimationStep)], emit: StateChannelEmit) {
        var landed = false
        var answered: [JourneyCompletion] = []

        for (number, step) in steps {
            guard let run = runs[number] else { continue }

            guard !step.rested else {
                animator.halt(.state(binding.state, run: number))
                runs[number] = nil
                for lane in run.lanes {
                    value[lane] = destination[lane]
                    velocity[lane] = 0
                }
                landed = true
                if let completion = run.completion { answered.append(JourneyCompletion(id: completion, succeeded: true)) }
                continue
            }

            for (index, lane) in run.lanes.enumerated() {
                value[lane] = step.value[index]
                velocity[lane] = step.velocity[index] * 1_000
            }
        }

        emit(self, landed ? .position : .frame, answered)
    }

    /// Stops every lane where the user holds the value.
    @discardableResult
    func take(_ taken: [Double], emit: StateChannelEmit) -> Bool {
        guard taken.count == value.count else { return false }

        halt(Array(value.indices), emit: emit)
        value = taken
        destination = taken
        velocity = Array(repeating: 0, count: taken.count)
        emit(self, .position, [])
        return true
    }

    /// Sends `lanes` on to where `incoming` says, under its law, as one run: from where they stand, at the speed
    /// stated for a lane `stated` names and at their own otherwise; a run they leave travels on without them.
    private func aim(
        _ lanes: [Int],
        at incoming: HostJourney,
        stated: [Int],
        usesCompletion: Bool,
        now: Double,
        reducesMotion: Bool,
        emit: StateChannelEmit
    ) {
        sample(now: now, emit: emit)
        halt(lanes, emit: emit)

        motion = incoming.motion
        stopped = incoming.stopped
        let completion = usesCompletion ? incoming.completion : nil
        for lane in lanes { destination[lane] = incoming.destination[lane] }

        if motion.kind == .custom {
            for lane in lanes {
                value[lane] = incoming.value[lane]
                velocity[lane] = incoming.velocity[lane]
            }
            emit(self, nil, [])
            return
        }

        let animation = Animation(
            from: lanes.map { value[$0] },
            destination: lanes.map { destination[$0] },
            velocity: lanes.map { (stated.contains($0) ? incoming.velocity[$0] : velocity[$0]) / 1_000 },
            motion: motion,
            began: now)
        for (index, lane) in lanes.enumerated() { velocity[lane] = animation.velocity[index] * 1_000 }

        let instant = !motion.animates

        if instant || reducesMotion || animation.arrives {
            for lane in lanes {
                value[lane] = destination[lane]
                velocity[lane] = 0
            }
            emit(self, .position, completion.map { [JourneyCompletion(id: $0, succeeded: true)] } ?? [])
            return
        }

        numbered += 1
        runs[numbered] = Run(lanes: lanes, completion: completion)
        animator.start(animation, for: .state(binding.state, run: numbered))
        emit(self, .position, [])
    }

    /// Takes `lanes` out of the runs they travel in, where they stand: a run cut short fails its waiter and travels
    /// on with the lanes it keeps, its own animation narrowed to them.
    private func halt(_ lanes: [Int], emit: StateChannelEmit) {
        for number in runs.keys.sorted() {
            guard let run = runs[number] else { continue }

            let kept = run.lanes.indices.filter { !lanes.contains(run.lanes[$0]) }
            guard kept.count < run.lanes.count else { continue }

            if let completion = run.completion { emit(self, nil, [JourneyCompletion(id: completion, succeeded: false)]) }

            let target = AnimationTarget.state(binding.state, run: number)
            guard !kept.isEmpty, let animation = animator.animation(for: target) else {
                animator.halt(target)
                runs[number] = nil
                continue
            }

            animator.start(
                Animation(
                    from: kept.map { animation.from[$0] },
                    destination: kept.map { animation.destination[$0] },
                    velocity: kept.map { animation.velocity[$0] },
                    motion: animation.motion,
                    began: animation.began),
                for: target)
            runs[number] = Run(lanes: kept.map { run.lanes[$0] }, completion: nil)
        }
    }

    /// Brings every run to where it stands at `now`, before a change lands.
    private func sample(now: Double, emit: StateChannelEmit) {
        let steps = runs.keys.sorted().compactMap { number -> (run: Int, step: AnimationStep)? in
            let target = AnimationTarget.state(binding.state, run: number)
            guard let animation = animator.animation(for: target) else { return nil }

            let position = animation.position(at: now)
            return (number, AnimationStep(
                target: target, value: position.value, velocity: position.velocity, rested: position.rested))
        }

        guard !steps.isEmpty else { return }

        follow(steps, emit: emit)
    }
}
