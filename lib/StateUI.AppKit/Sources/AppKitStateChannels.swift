// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import Foundation
@_spi(Host) import StateUI

/// What a state channel gives the controls and StateUI after a step: its
/// journey, and the report the core hears.
@MainActor
struct AppKitStateChannelOutput {
    let state: Int32
    let binding: HostStateBinding
    let journey: HostJourney
    let report: HostJourneyUpdate?
}

/// The outcome of one awaited journey.
struct AppKitJourneyCompletion: Equatable {
    let id: Int
    let succeeded: Bool
}

/// The state channels: one per host-carried `@State`, shared by every control
/// tied to it.
///
/// Controls never own their own copy of a driven journey. Every property tied
/// to the same number reads this channel, so all of them stand at the same
/// value and retarget with the same velocity on the same display frame. The
/// trips they travel on are the walker's.
@MainActor
final class AppKitStateChannels {
    private let walker: AppKitWalker
    private var channels: [Int32: AppKitStateChannel] = [:]

    /// How many controls wear each state: a channel lives while any does.
    private var wearers: [Int32: Int] = [:]
    private var outputs: [AppKitStateChannelOutput] = []
    private var completions: [AppKitJourneyCompletion] = []

    /// State channels whose trips `walker` walks.
    init(walker: AppKitWalker) {
        self.walker = walker
    }

    var isActive: Bool { channels.values.contains(where: \.isActive) }

    /// How many states have a channel.
    var count: Int { channels.count }

    /// Resolves the value a driven property draws from, creating its shared
    /// channel when this is the first property attached to the state.
    func presentedValue(
        for binding: HostStateBinding,
        from carried: HostStateValue,
        now: Double,
        reducesMotion: Bool
    ) -> HostStateValue {
        guard binding.kind == .property,
              let incoming = StateUIHost.journey(from: carried)
        else { return carried }

        let channel: AppKitStateChannel

        if let existing = channels[binding.state] {
            existing.binding = binding
            channel = existing
        } else {
            channel = AppKitStateChannel(
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
    func receive(
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

    /// Follows what a step of the walker made of the channels' trips. A
    /// channel nobody wears any more goes once its trip has landed.
    func follow(_ steps: [AppKitStep]) {
        for step in steps {
            guard case .state(let number) = step.target else { continue }
            channels[number]?.follow(step.value, step.velocity, rested: step.rested, emit: emit)
            if step.rested, wearers[number] == nil { channels[number] = nil }
        }
    }

    /// A control ties one of its properties to `state`.
    func attach(_ state: Int32) {
        wearers[state, default: 0] += 1
    }

    /// A control lets go of `state` - it leaves the tree, or the property is
    /// no longer tied. The last one to let go takes the channel with it, once
    /// the value has landed where it was sent: THE STATE'S CHANNEL IS NOT A
    /// CONTROL'S TO END, and a control described again a moment later joins it
    /// where it is.
    func detach(_ state: Int32) {
        guard let count = wearers[state] else { return }

        if count > 1 {
            wearers[state] = count - 1
            return
        }

        wearers[state] = nil
        if channels[state]?.isActive != true { channels[state] = nil }
    }

    /// Lets a two-way native reader take a property journey at the position it
    /// has just established. The old destination and velocity cease to pull.
    @discardableResult
    func take(_ value: [Double], through binding: HostStateBinding) -> Bool {
        guard binding.kind == .property,
              binding.mode != .out,
              let channel = channels[binding.state],
              channel.take(value, emit: emit)
        else { return false }

        return true
    }

    /// Takes values emitted since the previous host pump.
    func takeOutputs() -> [AppKitStateChannelOutput] {
        defer { outputs.removeAll(keepingCapacity: true) }
        return outputs
    }

    /// Takes journey completions emitted since the previous host pump.
    func takeCompletions() -> [AppKitJourneyCompletion] {
        defer { completions.removeAll(keepingCapacity: true) }
        return completions
    }

    private func emit(
        _ channel: AppKitStateChannel,
        report: HostJourneyUpdate?,
        completion: AppKitJourneyCompletion? = nil
    ) {
        outputs.append(AppKitStateChannelOutput(
            state: channel.binding.state,
            binding: channel.binding,
            journey: channel.presented,
            report: report))

        if let completion {
            completions.append(completion)
        }
    }
}

/// One state's channel: its journey, and the trip the walker walks it on.
@MainActor
private final class AppKitStateChannel {
    var binding: HostStateBinding

    private let walker: AppKitWalker
    private let target: AppKitTripTarget
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
        walker: AppKitWalker,
        now: Double,
        reducesMotion: Bool,
        emit: (AppKitStateChannel, HostJourneyUpdate?, AppKitJourneyCompletion?) -> Void
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
        emit: (AppKitStateChannel, HostJourneyUpdate?, AppKitJourneyCompletion?) -> Void
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

    /// Follows where the walker put this channel's trip: a frame on the way,
    /// or the landing at its destination.
    func follow(
        _ lanes: [Double],
        _ speed: [Double],
        rested: Bool,
        emit: (AppKitStateChannel, HostJourneyUpdate?, AppKitJourneyCompletion?) -> Void
    ) {
        guard !rested else {
            walker.halt(target)
            value = destination
            velocity = Array(repeating: 0, count: value.count)
            let landed = completion.map { AppKitJourneyCompletion(id: $0, succeeded: true) }
            completion = nil
            emit(self, .position, landed)
            return
        }

        value = lanes
        velocity = speed.map { $0 * 1_000 }
        emit(self, .frame, nil)
    }

    /// Stops the current motion at the reader's authoritative position.
    @discardableResult
    func take(
        _ taken: [Double],
        emit: (AppKitStateChannel, HostJourneyUpdate?, AppKitJourneyCompletion?) -> Void
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
        emit: (AppKitStateChannel, HostJourneyUpdate?, AppKitJourneyCompletion?) -> Void
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

        let trip = AppKitTrip(
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
            let landed = completion.map { AppKitJourneyCompletion(id: $0, succeeded: true) }
            completion = nil
            emit(self, .position, landed)
            return
        }

        walker.start(trip, for: target)
        emit(self, .position, nil)
    }

    /// Brings the value to where the walker's trip stands at `now`, before a
    /// change lands on it.
    private func sample(
        now: Double,
        emit: (AppKitStateChannel, HostJourneyUpdate?, AppKitJourneyCompletion?) -> Void
    ) {
        guard let trip = walker.trip(for: target) else { return }

        let position = trip.position(at: now)
        follow(position.value, position.velocity, rested: position.rested, emit: emit)
    }

    private func cancelCompletion(
        emit: (AppKitStateChannel, HostJourneyUpdate?, AppKitJourneyCompletion?) -> Void
    ) {
        guard let completion else { return }
        self.completion = nil
        emit(self, nil, AppKitJourneyCompletion(id: completion, succeeded: false))
    }
}

#endif
