// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import Foundation
@_spi(Host) import StateUI

/// One value emitted by the host motion engine for controls and StateUI.
@MainActor
struct AppKitMotionOutput {
    let state: Int32
    let binding: HostStateBinding
    let journey: HostJourney
    let report: HostJourneyUpdate?
}

/// The outcome of one awaited journey.
struct AppKitMotionCompletion: Equatable {
    let id: Int
    let succeeded: Bool
}

/// Stable identity of one host-presented property transition.
struct AppKitPropertyMotionKey: Hashable, Comparable {
    let mount: UInt64
    let property: Prop

    static func < (left: Self, right: Self) -> Bool {
        if left.mount != right.mount { return left.mount < right.mount }

        return left.property < right.property
    }
}

/// One property presentation produced for a mounted native element.
struct AppKitPropertyMotionOutput: Equatable {
    let key: AppKitPropertyMotionKey
    let value: HostValue
}

/// Host-local transitions keyed by element and property.
///
/// These channels share the display clock and `HostMotionLaw` with Journey,
/// but deliberately carry no StateUI state number, report, or completion.
/// `HostPatch.properties` remains the committed target while this engine owns
/// only the value drawn on the current frame.
@MainActor
final class AppKitPropertyMotionEngine {
    private var channels: [AppKitPropertyMotionKey: AppKitPropertyMotionChannel] = [:]
    private var outputs: [AppKitPropertyMotionOutput] = []

    var isActive: Bool { !channels.isEmpty }

    func presentedValue(for key: AppKitPropertyMotionKey) -> HostValue? {
        channels[key]?.presented
    }

    /// Starts, retargets, or interrupts a property transition.
    ///
    /// A missing transition is an explicit snap for a property present in the
    /// sparse patch. An unrelated sparse patch never calls this method and
    /// therefore leaves the channel alone.
    func receive(
        key: AppKitPropertyMotionKey,
        standing: HostValue?,
        target: HostValue?,
        transition: HostTransition?,
        now: Double,
        reducesMotion: Bool
    ) {
        var source = standing
        var carriedLanes: [Double] = []
        var carriedVelocity: [Double] = []

        if let channel = channels.removeValue(forKey: key) {
            _ = channel.sample(now: now)
            source = channel.presented
            carriedLanes = channel.lanes
            carriedVelocity = channel.velocity
        }

        guard let source,
              let target,
              let motion = transition?.motion,
              !motion.isInherited,
              !motion.isCustom,
              motion.factor.isFinite,
              !reducesMotion,
              !(motion.law == .eased && motion.millis == 0),
              let plan = AppKitMotionValuePlan(
                from: source,
                destination: target,
                exactSource: carriedLanes,
                property: key.property)
        else { return }

        let velocity = carriedVelocity.count == plan.from.count
            ? carriedVelocity
            : Array(repeating: 0, count: plan.from.count)
        let alreadyThere = zip(plan.from, plan.destination).allSatisfy {
            abs($0 - $1) < HostMotionLaw.still
        } && velocity.allSatisfy { abs($0) < HostMotionLaw.still }

        guard !alreadyThere else { return }
        channels[key] = AppKitPropertyMotionChannel(
            plan: plan,
            velocity: velocity,
            motion: motion,
            began: now)
    }

    /// Advances active channels in stable identity/property order.
    func advance(now: Double, reducesMotion: Bool = false) {
        if reducesMotion {
            for key in channels.keys.sorted() {
                guard let channel = channels[key] else { continue }
                outputs.append(AppKitPropertyMotionOutput(key: key, value: channel.target))
            }
            channels.removeAll(keepingCapacity: true)
            return
        }

        var landed: [AppKitPropertyMotionKey] = []

        for key in channels.keys.sorted() {
            guard let channel = channels[key] else { continue }
            let sample = channel.sample(now: now)
            outputs.append(AppKitPropertyMotionOutput(key: key, value: sample.value))
            if sample.rested { landed.append(key) }
        }

        for key in landed { channels[key] = nil }
    }

    /// Drops channels that no longer belong to a mounted property.
    func retain(_ keys: Set<AppKitPropertyMotionKey>) {
        channels = channels.filter { keys.contains($0.key) }
        outputs.removeAll { !keys.contains($0.key) }
    }

    /// Drops every transition owned by an element being replaced or adopted.
    func remove(mount: UInt64) {
        channels = channels.filter { $0.key.mount != mount }
        outputs.removeAll { $0.key.mount == mount }
    }

    func takeOutputs() -> [AppKitPropertyMotionOutput] {
        defer { outputs.removeAll(keepingCapacity: true) }
        return outputs
    }
}

/// Mutable presentation of one ordinary property.
@MainActor
private final class AppKitPropertyMotionChannel {
    private let plan: AppKitMotionValuePlan
    fileprivate var lanes: [Double]
    private let startingVelocity: [Double]
    private let motion: Motion
    private let began: Double
    fileprivate var velocity: [Double]

    init(
        plan: AppKitMotionValuePlan,
        velocity: [Double],
        motion: Motion,
        began: Double
    ) {
        self.plan = plan
        lanes = plan.from
        startingVelocity = velocity
        self.velocity = velocity
        self.motion = motion
        self.began = began
    }

    var presented: HostValue { plan.value(at: lanes) }
    var target: HostValue { plan.target }

    func sample(now: Double) -> (value: HostValue, rested: Bool) {
        let sample = HostMotionLaw.sample(
            motion,
            elapsed: max(0, now - began),
            from: plan.from,
            destination: plan.destination,
            velocity: startingVelocity)

        guard sample.value.allSatisfy(\.isFinite),
              sample.velocity.allSatisfy(\.isFinite)
        else {
            lanes = plan.destination
            velocity = Array(repeating: 0, count: lanes.count)
            return (plan.target, true)
        }

        if sample.rested {
            lanes = plan.destination
            velocity = Array(repeating: 0, count: lanes.count)
            return (plan.target, true)
        }

        lanes = sample.value
        velocity = sample.velocity
        return (plan.value(at: lanes), false)
    }
}

/// A shape-preserving conversion between a host value and numerical lanes.
///
/// Structured values move only when their discrete scaffolding is identical;
/// for example, a gradient may move its geometry, stops, and colours without
/// changing kind or stop count midway through the transition.
private struct AppKitMotionValuePlan {
    let from: [Double]
    let destination: [Double]
    let target: HostValue

    init?(
        from source: HostValue,
        destination target: HostValue,
        exactSource: [Double] = [],
        property: Prop? = nil
    ) {
        var from: [Double] = []
        var destination: [Double] = []

        if let property, Self.brushProperties.contains(property),
           !Self.isPaint(source) || !Self.isPaint(target) {
            return nil
        }

        guard Self.append(
            source: source,
            target: target,
            from: &from,
            destination: &destination),
            !from.isEmpty,
            from.allSatisfy(\.isFinite),
            destination.allSatisfy(\.isFinite)
        else { return nil }

        self.from = exactSource.count == from.count && exactSource.allSatisfy(\.isFinite)
            ? exactSource
            : from
        self.destination = destination
        self.target = target
    }

    func value(at lanes: [Double]) -> HostValue {
        guard lanes.count == destination.count, lanes.allSatisfy(\.isFinite) else {
            return target
        }

        var index = 0
        guard let value = Self.rebuild(target, lanes: lanes, index: &index),
              index == lanes.count
        else { return target }
        return value
    }

    private static func append(
        source: HostValue,
        target: HostValue,
        from: inout [Double],
        destination: inout [Double]
    ) -> Bool {
        switch (source, target) {
        case (.number(let source), .number(let target)):
            from.append(source)
            destination.append(target)
            return true

        case (.numbers(let source), .numbers(let target)) where source.count == target.count:
            from.append(contentsOf: source)
            destination.append(contentsOf: target)
            return true

        case let (.color(sr, sg, sb, sa), .color(tr, tg, tb, ta)):
            from.append(contentsOf: [sr, sg, sb, sa].map { Double($0) / 255 })
            destination.append(contentsOf: [tr, tg, tb, ta].map { Double($0) / 255 })
            return true

        case (.values(let source), .values(let target)) where source.count == target.count:
            for (sourcePart, targetPart) in zip(source, target) {
                guard append(
                    source: sourcePart,
                    target: targetPart,
                    from: &from,
                    destination: &destination)
                else { return false }
            }
            return true

        case (.themed(_, _), _), (_, .themed(_, _)):
            return false

        default:
            return source == target
        }
    }

    private static func rebuild(
        _ target: HostValue,
        lanes: [Double],
        index: inout Int
    ) -> HostValue? {
        switch target {
        case .number:
            guard index < lanes.count else { return nil }
            defer { index += 1 }
            return .number(lanes[index])

        case .numbers(let target):
            guard index + target.count <= lanes.count else { return nil }
            defer { index += target.count }
            return .numbers(Array(lanes[index..<(index + target.count)]))

        case .color:
            guard index + 4 <= lanes.count else { return nil }
            let channels = lanes[index..<(index + 4)].map { lane -> UInt8 in
                UInt8(min(max((lane * 255).rounded(), 0), 255))
            }
            index += 4
            return .color(
                red: channels[0],
                green: channels[1],
                blue: channels[2],
                alpha: channels[3])

        case .values(let target):
            var values: [HostValue] = []
            values.reserveCapacity(target.count)
            for part in target {
                guard let value = rebuild(part, lanes: lanes, index: &index) else { return nil }
                values.append(value)
            }
            return .values(values)

        default:
            return target
        }
    }

    /// What a brush property carries: one colour or a well-formed brush.
    /// Motion runs only between two of the same shape.
    private static func isPaint(_ value: HostValue) -> Bool {
        value.color != nil || isValidBrush(value)
    }

    private static func isValidBrush(_ value: HostValue) -> Bool {
        guard let parts = value.values,
              let kind = parts.first?.enumeration
        else { return false }

        switch kind {
        case 1:
            return parts.count == 2 && parts[1].color != nil

        case 2, 3:
            let geometryCount = kind == 2 ? 4 : 3
            guard parts.count >= 4,
                  parts[1].numbers?.count == geometryCount,
                  (parts.count - 2).isMultiple(of: 2)
            else { return false }

            var index = 2
            while index < parts.count {
                guard parts[index].number != nil,
                      parts[index + 1].color != nil
                else { return false }
                index += 2
            }
            return true

        default:
            return false
        }
    }

    private static let brushProperties: Set<Prop> = [
        .background, .fill, .stroke,
    ]
}

/// One deterministic host-side channel per StateUI state number.
///
/// Controls never own their own copy of a driven journey. Every property tied
/// to the same number reads this channel, so all of them stand at the same
/// value and retarget with the same velocity on the same display frame.
@MainActor
final class AppKitMotionEngine {
    private var channels: [Int32: AppKitMotionChannel] = [:]
    private var outputs: [AppKitMotionOutput] = []
    private var completions: [AppKitMotionCompletion] = []

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

        let channel: AppKitMotionChannel

        if let existing = channels[binding.state] {
            existing.binding = binding
            channel = existing
        } else {
            channel = AppKitMotionChannel(
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
    func takeOutputs() -> [AppKitMotionOutput] {
        defer { outputs.removeAll(keepingCapacity: true) }
        return outputs
    }

    /// Takes journey completions emitted since the previous host pump.
    func takeCompletions() -> [AppKitMotionCompletion] {
        defer { completions.removeAll(keepingCapacity: true) }
        return completions
    }

    private func emit(
        _ channel: AppKitMotionChannel,
        report: HostJourneyUpdate?,
        completion: AppKitMotionCompletion? = nil
    ) {
        outputs.append(AppKitMotionOutput(
            state: channel.binding.state,
            binding: channel.binding,
            journey: channel.presented,
            report: report))

        if let completion {
            completions.append(completion)
        }
    }
}

/// Mutable state for one host motion channel.
@MainActor
private final class AppKitMotionChannel {
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
        emit: (AppKitMotionChannel, HostJourneyUpdate?, AppKitMotionCompletion?) -> Void
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
        emit: (AppKitMotionChannel, HostJourneyUpdate?, AppKitMotionCompletion?) -> Void
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
        emit: (AppKitMotionChannel, HostJourneyUpdate?, AppKitMotionCompletion?) -> Void
    ) {
        guard isActive else { return }
        if reducesMotion {
            value = destination
            velocity = Array(repeating: 0, count: value.count)
            isActive = false
            let landed = completion.map { AppKitMotionCompletion(id: $0, succeeded: true) }
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
        emit: (AppKitMotionChannel, HostJourneyUpdate?, AppKitMotionCompletion?) -> Void
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
        emit: (AppKitMotionChannel, HostJourneyUpdate?, AppKitMotionCompletion?) -> Void
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
            let landed = completion.map { AppKitMotionCompletion(id: $0, succeeded: true) }
            completion = nil
            emit(self, .position, landed)
            return
        }

        isActive = true
        emit(self, .position, nil)
    }

    private func sample(
        now: Double,
        emit: (AppKitMotionChannel, HostJourneyUpdate?, AppKitMotionCompletion?) -> Void
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
            let landed = completion.map { AppKitMotionCompletion(id: $0, succeeded: true) }
            completion = nil
            emit(self, .position, landed)
        } else {
            emit(self, .frame, nil)
        }
    }

    private func cancelCompletion(
        emit: (AppKitMotionChannel, HostJourneyUpdate?, AppKitMotionCompletion?) -> Void
    ) {
        guard let completion else { return }
        self.completion = nil
        emit(self, nil, AppKitMotionCompletion(id: completion, succeeded: false))
    }
}

#endif
