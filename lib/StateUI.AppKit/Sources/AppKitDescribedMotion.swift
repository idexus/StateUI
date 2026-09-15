// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import Foundation
@_spi(Host) import StateUI

/// Stable identity of one host-presented property transition.
struct AppKitDescribedKey: Hashable, Comparable {
    let mount: UInt64
    let property: Prop

    static func < (left: Self, right: Self) -> Bool {
        if left.mount != right.mount { return left.mount < right.mount }

        return left.property < right.property
    }
}

/// One property presentation produced for a mounted native element.
struct AppKitDescribedOutput: Equatable {
    let key: AppKitDescribedKey
    let value: HostValue
}

/// The transitions a patch describes, keyed by element and property.
///
/// They share the display clock and `HostMotionLaw` with the state channels,
/// but carry no StateUI state number, report or completion:
/// `HostPatch.properties` remains the committed target, and this owns only the
/// value drawn on the current frame.
@MainActor
final class AppKitDescribedMotion {
    private var transitions: [AppKitDescribedKey: AppKitDescribedTransition] = [:]
    private var outputs: [AppKitDescribedOutput] = []

    var isActive: Bool { !transitions.isEmpty }

    func presentedValue(for key: AppKitDescribedKey) -> HostValue? {
        transitions[key]?.presented
    }

    /// Starts, retargets, or interrupts a property transition.
    ///
    /// A missing transition is an explicit snap for a property present in the
    /// sparse patch. An unrelated sparse patch never calls this method and
    /// therefore leaves the transition alone.
    func receive(
        key: AppKitDescribedKey,
        standing: HostValue?,
        target: HostValue?,
        transition: HostTransition?,
        now: Double,
        reducesMotion: Bool
    ) {
        var source = standing
        var carriedLanes: [Double] = []
        var carriedVelocity: [Double] = []

        if let running = transitions.removeValue(forKey: key) {
            _ = running.sample(now: now)
            source = running.presented
            carriedLanes = running.lanes
            carriedVelocity = running.velocity
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
        transitions[key] = AppKitDescribedTransition(
            plan: plan,
            velocity: velocity,
            motion: motion,
            began: now)
    }

    /// Advances active transitions in stable identity/property order.
    func advance(now: Double, reducesMotion: Bool = false) {
        if reducesMotion {
            for key in transitions.keys.sorted() {
                guard let transition = transitions[key] else { continue }
                outputs.append(AppKitDescribedOutput(key: key, value: transition.target))
            }
            transitions.removeAll(keepingCapacity: true)
            return
        }

        var landed: [AppKitDescribedKey] = []

        for key in transitions.keys.sorted() {
            guard let transition = transitions[key] else { continue }
            let sample = transition.sample(now: now)
            outputs.append(AppKitDescribedOutput(key: key, value: sample.value))
            if sample.rested { landed.append(key) }
        }

        for key in landed { transitions[key] = nil }
    }

    /// Drops transitions that no longer belong to a mounted property.
    func retain(_ keys: Set<AppKitDescribedKey>) {
        transitions = transitions.filter { keys.contains($0.key) }
        outputs.removeAll { !keys.contains($0.key) }
    }

    /// Drops every transition owned by an element being replaced or adopted.
    func remove(mount: UInt64) {
        transitions = transitions.filter { $0.key.mount != mount }
        outputs.removeAll { $0.key.mount == mount }
    }

    func takeOutputs() -> [AppKitDescribedOutput] {
        defer { outputs.removeAll(keepingCapacity: true) }
        return outputs
    }
}

/// One described property on its way to its target.
@MainActor
private final class AppKitDescribedTransition {
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
            let transitions = lanes[index..<(index + 4)].map { lane -> UInt8 in
                UInt8(min(max((lane * 255).rounded(), 0), 255))
            }
            index += 4
            return .color(
                red: transitions[0],
                green: transitions[1],
                blue: transitions[2],
                alpha: transitions[3])

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

#endif
