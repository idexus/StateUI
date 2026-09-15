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
/// value and retarget with the same velocity on the same display frame.
@MainActor
final class AppKitStateChannels {
    private var channels: [Int32: AppKitStateChannel] = [:]
    private var outputs: [AppKitStateChannelOutput] = []
    private var completions: [AppKitJourneyCompletion] = []

    var isActive: Bool { channels.values.contains(where: \.isActive) }

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

    /// Advances every active channel from the display's monotonic clock.
    func advance(now: Double, reducesMotion: Bool = false) {
        for state in channels.keys.sorted() {
            channels[state]?.advance(
                now: now,
                reducesMotion: reducesMotion,
                emit: emit)
        }
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

    /// Keeps inactive channels only while a rendered control still wears them.
    /// An active channel with no view runs to its truthful landing first.
    func retain(_ states: Set<Int32>) {
        channels = channels.filter { state, channel in
            states.contains(state) || channel.isActive
        }
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

/// One state's channel: its journey, and the trip the host walks it on.
@MainActor
private final class AppKitStateChannel {
    var binding: HostStateBinding

    private var value: [Double]
    private var destination: [Double]
    private var velocity: [Double]
    private var from: [Double]
    private var startingVelocity: [Double]
    private var motion: Motion
    private var completion: Int?
    private var stopped: UInt64
    private var began: Double
    private(set) var isActive = false

    init(
        binding: HostStateBinding,
        journey: HostJourney,
        now: Double,
        reducesMotion: Bool,
        emit: (AppKitStateChannel, HostJourneyUpdate?, AppKitJourneyCompletion?) -> Void
    ) {
        self.binding = binding
        value = journey.value
        destination = journey.destination
        velocity = journey.velocity
        from = journey.value
        startingVelocity = journey.velocity.map { $0 / 1_000 }
        motion = journey.motion
        completion = journey.completion
        stopped = journey.stopped
        began = now

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
            isActive = false
            destination = value
            velocity = Array(repeating: 0, count: width)
            motion = incoming.motion
            stopped = incoming.stopped
            emit(self, .position, nil)
        }

        if changedValue {
            sample(now: now, emit: emit)
            if isActive { cancelCompletion(emit: emit) }
            isActive = false
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

    func advance(
        now: Double,
        reducesMotion: Bool,
        emit: (AppKitStateChannel, HostJourneyUpdate?, AppKitJourneyCompletion?) -> Void
    ) {
        guard isActive else { return }
        if reducesMotion {
            value = destination
            velocity = Array(repeating: 0, count: value.count)
            isActive = false
            let landed = completion.map { AppKitJourneyCompletion(id: $0, succeeded: true) }
            completion = nil
            emit(self, .position, landed)
            return
        }
        sample(now: now, emit: emit)
    }

    /// Stops the current motion at the reader's authoritative position.
    @discardableResult
    func take(
        _ taken: [Double],
        emit: (AppKitStateChannel, HostJourneyUpdate?, AppKitJourneyCompletion?) -> Void
    ) -> Bool {
        guard taken.count == value.count else { return false }

        if isActive { cancelCompletion(emit: emit) }
        isActive = false
        value = taken
        destination = taken
        velocity = Array(repeating: 0, count: taken.count)
        from = taken
        startingVelocity = velocity
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
            isActive = false
            value = incoming.value
            velocity = incoming.velocity
            emit(self, nil, nil)
            return
        }

        from = value
        startingVelocity = usesStatedVelocity
            ? incoming.velocity.map { $0 / 1_000 }
            : velocity.map { $0 / 1_000 }
        velocity = startingVelocity.map { $0 * 1_000 }
        began = now

        let instant = motion.law == .eased && motion.millis == 0
        let alreadyThere = zip(value, destination).allSatisfy {
            abs($0 - $1) < HostMotionLaw.still
        } && startingVelocity.allSatisfy { abs($0) < HostMotionLaw.still }

        if instant || reducesMotion || alreadyThere {
            value = destination
            velocity = Array(repeating: 0, count: value.count)
            isActive = false
            let landed = completion.map { AppKitJourneyCompletion(id: $0, succeeded: true) }
            completion = nil
            emit(self, .position, landed)
            return
        }

        isActive = true
        emit(self, .position, nil)
    }

    private func sample(
        now: Double,
        emit: (AppKitStateChannel, HostJourneyUpdate?, AppKitJourneyCompletion?) -> Void
    ) {
        guard isActive else { return }

        let sample = HostMotionLaw.sample(
            motion,
            elapsed: max(0, now - began),
            from: from,
            destination: destination,
            velocity: startingVelocity)
        value = sample.value
        velocity = sample.velocity.map { $0 * 1_000 }

        if sample.rested {
            value = destination
            velocity = Array(repeating: 0, count: value.count)
            isActive = false
            let landed = completion.map { AppKitJourneyCompletion(id: $0, succeeded: true) }
            completion = nil
            emit(self, .position, landed)
        } else {
            emit(self, .frame, nil)
        }
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
