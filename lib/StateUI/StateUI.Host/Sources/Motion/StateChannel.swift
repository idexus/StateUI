// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

/// What a channel says after a change: itself, what the core hears, the waiters answered, and who moved it.
typealias StateChannelEmit = (StateChannel, HostJourneyUpdate?, [JourneyCompletion], WriteOrigin) -> Void

/// One state's channel: its animated value, traveling in runs - the lanes one write sent on together, each an
/// animation of its own - so a write of some lanes leaves the other lanes' travel and their waiter as they were.
/// Design: docs/design/host/motion.md#a-channel-lane-by-lane
@MainActor
final class StateChannel {
    var binding: HostStateBinding

    let animator: Animator
    var value: [Double]
    var destination: [Double]
    var velocity: [Double]
    var motion: Motion
    var stopped: UInt64

    /// The runs under way by number, and the last number given.
    var runs: [Int: Run] = [:]
    var numbered = 0

    /// Lanes traveling together, and the waiter their arrival answers.
    struct Run {
        var lanes: [Int]
        var completion: Int?
    }

    /// The lanes a hand holds - whether a program's write of one waits for the hand to let go - and where the
    /// program sent a lane it holds, with the waiter of that write.
    /// Design: docs/design/host/motion.md#a-lane-a-hand-holds
    var held: [Int: Bool] = [:]
    var deferred: [Int: Double] = [:]
    var deferredCompletion: Int?

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

        var values = named(from: 0)
        var destinations = named(from: width)
        var velocities = named(from: width * 2)
        let changedCompletion = names((width * 3) + 3)
        let changedStop = names((width * 3) + 4)

        // A lane a hand holds stays under the hand: where the program sent it waits for the hand to let go.
        if !held.isEmpty {
            for lane in Set(values + destinations).sorted() where held[lane] != nil {
                deferred[lane] = incoming.destination[lane]
                destination[lane] = incoming.destination[lane]
                if changedCompletion { deferredCompletion = incoming.completion }
            }
            values.removeAll { held[$0] != nil }
            destinations.removeAll { held[$0] != nil }
            velocities.removeAll { held[$0] != nil }
        }

        if changedStop {
            let free = all.filter { held[$0] == nil }
            sample(now: now, emit: emit)
            halt(free, as: .stopped, emit: emit)
            for lane in free {
                destination[lane] = value[lane]
                velocity[lane] = 0
            }
            motion = incoming.motion
            stopped = incoming.stopped
            emit(self, .position, [], .program)
        }

        if !values.isEmpty {
            sample(now: now, emit: emit)
            halt(values, as: .superseded, emit: emit)
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
            emit(self, nil, [], .animation)
        }
    }

    /// Ends the channel as its last consumer leaves: every run stops, unanswered.
    func end() {
        for number in runs.keys.sorted() { animator.halt(.state(binding.state, run: number)) }
        runs.removeAll()
    }

    /// Takes where the animator put each run - a frame on the way, or the landing, answered as `landing` - and says
    /// it once.
    func follow(
        _ steps: [(run: Int, step: AnimationStep)], landing: HostMotionOutcome = .animated, emit: StateChannelEmit
    ) {
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
                if let completion = run.completion { answered.append(JourneyCompletion(id: completion, outcome: landing)) }
                continue
            }

            for (index, lane) in run.lanes.enumerated() {
                value[lane] = step.value[index]
                velocity[lane] = step.velocity[index]
            }
        }

        emit(self, landed ? .position : .frame, answered, .animation)
    }

    /// Stops every lane where the user holds the value.
    @discardableResult
    func take(_ taken: [Double], emit: StateChannelEmit) -> Bool {
        guard taken.count == value.count else { return false }

        halt(Array(value.indices), as: .superseded, emit: emit)
        value = taken
        destination = taken
        velocity = Array(repeating: 0, count: taken.count)
        emit(self, .position, [], .user)
        return true
    }

    /// Sends `lanes` on to where `incoming` says, under its law, as one run: from where they stand, at the speed
    /// stated for a lane `stated` names and at their own otherwise; a run they leave travels on without them.
    func aim(
        _ lanes: [Int],
        at incoming: HostJourney,
        stated: [Int],
        usesCompletion: Bool,
        now: Double,
        reducesMotion: Bool,
        emit: StateChannelEmit
    ) {
        sample(now: now, emit: emit)
        halt(lanes, as: .superseded, emit: emit)

        motion = incoming.motion
        stopped = incoming.stopped
        for lane in lanes { destination[lane] = incoming.destination[lane] }

        send(
            lanes,
            at: lanes.map { stated.contains($0) ? incoming.velocity[$0] : velocity[$0] },
            under: motion,
            completion: usesCompletion ? incoming.completion : nil,
            by: .animation,
            now: now,
            reducesMotion: reducesMotion,
            emit: emit)
    }

    /// Sends `lanes`, out of every run, on from where they stand to their destinations as one run under `law`,
    /// each setting out at its speed in `speeds`, and says so as `origin`'s.
    func send(
        _ lanes: [Int],
        at speeds: [Double],
        under law: Motion,
        completion: Int?,
        by origin: WriteOrigin,
        now: Double,
        reducesMotion: Bool,
        emit: StateChannelEmit
    ) {
        let animation = Animation(
            from: lanes.map { value[$0] },
            destination: lanes.map { destination[$0] },
            velocity: speeds,
            motion: law,
            began: now)
        for (index, lane) in lanes.enumerated() { velocity[lane] = animation.velocity[index] }

        // There already, under a motion that does not animate, or with less motion asked for: put there at once.
        let immediate: MotionImmediateReason? = animation.arrives ? .alreadyAtDestination
            : !law.animates ? .motionDisabled
            : reducesMotion ? .reducedMotion : nil

        if let immediate {
            for lane in lanes {
                value[lane] = destination[lane]
                velocity[lane] = 0
            }
            let answered = completion.map { [JourneyCompletion(id: $0, outcome: .immediate(immediate))] } ?? []
            emit(self, .position, answered, origin)
            return
        }

        numbered += 1
        runs[numbered] = Run(lanes: lanes, completion: completion)
        animator.start(animation, for: .state(binding.state, run: numbered))
        emit(self, .position, [], origin)
    }

    /// Takes `lanes` out of the runs they travel in, where they stand: a run cut short answers its waiter `outcome`
    /// once and travels on with the lanes it keeps, its own animation narrowed to them.
    func halt(_ lanes: [Int], as outcome: HostMotionOutcome, emit: StateChannelEmit) {
        for number in runs.keys.sorted() {
            guard let run = runs[number] else { continue }

            let kept = run.lanes.indices.filter { !lanes.contains(run.lanes[$0]) }
            guard kept.count < run.lanes.count else { continue }

            if let completion = run.completion {
                emit(self, nil, [JourneyCompletion(id: completion, outcome: outcome)], .animation)
            }

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
    func sample(now: Double, emit: StateChannelEmit) {
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
