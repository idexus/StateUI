// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// The key of one property animation: its element and its property.
@_spi(Host) public struct DescribedKey: Hashable, Comparable {
    /// The mounted element the property belongs to.
    public let mount: UInt64

    /// The property.
    public let property: Prop

    /// The transition of `property` on the mounted element `mount`.
    public init(mount: UInt64, property: Prop) {
        self.mount = mount
        self.property = property
    }

    /// By element, then by property.
    public static func < (left: Self, right: Self) -> Bool {
        if left.mount != right.mount { return left.mount < right.mount }

        return left.property < right.property
    }
}

/// One frame's value of a property animation.
@_spi(Host) public struct DescribedOutput: Equatable {
    /// The property it presents, on its element.
    public let key: DescribedKey

    /// The value drawn on this frame.
    public let value: HostValue
}

/// The property animations a patch describes, keyed by element and property.
/// Design: docs/design/host/motion.md#described-motion
@_spi(Host) @MainActor public final class DescribedMotion {
    private let animator: Animator
    private var transitions: [DescribedKey: DescribedTransition] = [:]
    private var outputs: [DescribedOutput] = []

    /// Described motion whose animations `animator` advances.
    public init(animator: Animator) {
        self.animator = animator
    }

    /// Whether any transition is under way.
    public var isActive: Bool { !transitions.isEmpty }

    /// The value a transition under way draws for `key`.
    public func presentedValue(for key: DescribedKey) -> HostValue? {
        transitions[key]?.presented
    }

    /// Starts, retargets or cuts short a property's animation; a nil `motion` snaps.
    /// `landed` runs when it ends or is cut short; returns whether one started.
    @discardableResult
    public func receive(
        key: DescribedKey,
        standing: HostValue?,
        target: HostValue?,
        motion: Motion?,
        landed: (() -> Void)? = nil,
        now: Double,
        reducesMotion: Bool
    ) -> Bool {
        var source = standing
        var carriedLanes: [Double] = []
        var carriedVelocity: [Double] = []

        if let running = transitions.removeValue(forKey: key) {
            if let animation = animator.animation(for: .described(key)) {
                _ = running.follow(animation.position(at: now))
            }
            animator.halt(.described(key))
            source = running.presented
            carriedLanes = running.lanes
            carriedVelocity = running.velocity
            running.landed?()
        }

        guard let source,
              let target,
              let motion,
              !motion.isInherited,
              !motion.isCustom,
              motion.factor.isFinite,
              !reducesMotion,
              !(motion.law == .eased && motion.millis == 0),
              let plan = MotionValuePlan(
                from: source,
                destination: target,
                exactSource: carriedLanes,
                property: key.property)
        else { return false }

        let animation = Animation(
            from: plan.from,
            destination: plan.destination,
            velocity: carriedVelocity.count == plan.from.count
                ? carriedVelocity
                : Array(repeating: 0, count: plan.from.count),
            motion: motion,
            began: now)

        guard !animation.arrives else { return false }
        transitions[key] = DescribedTransition(
            plan: plan, velocity: animation.velocity, landed: landed)
        animator.start(animation, for: .described(key))
        return true
    }

    /// Takes the values an animator advance gave for the animations, in key order.
    public func follow(_ steps: [AnimationStep]) {
        for step in steps {
            guard case .described(let key) = step.target,
                  let transition = transitions[key]
            else { continue }

            let presented = transition.follow((step.value, step.velocity, step.rested))
            outputs.append(DescribedOutput(key: key, value: presented.value))

            if presented.rested {
                transitions[key] = nil
                animator.halt(.described(key))
                transition.landed?()
            }
        }
    }

    /// Drops every animation of an element that leaves.
    public func remove(mount: UInt64) {
        transitions = transitions.filter { $0.key.mount != mount }
        outputs.removeAll { $0.key.mount == mount }
        animator.retain { target in
            guard case .described(let key) = target else { return true }
            return key.mount != mount
        }
    }

    /// Takes the values drawn since the previous take.
    public func takeOutputs() -> [DescribedOutput] {
        defer { outputs.removeAll(keepingCapacity: true) }
        return outputs
    }
}

/// One property on its way: its value's shape and where its lanes stand.
@MainActor
private final class DescribedTransition {
    private let plan: MotionValuePlan
    fileprivate var lanes: [Double]
    fileprivate var velocity: [Double]

    /// What follows the transition's end.
    let landed: (() -> Void)?

    init(plan: MotionValuePlan, velocity: [Double], landed: (() -> Void)?) {
        self.plan = plan
        lanes = plan.from
        self.velocity = velocity
        self.landed = landed
    }

    var presented: HostValue { plan.value(at: lanes) }

    /// The value to draw at `position`, and whether it is over; a non-number lands.
    func follow(
        _ position: (value: [Double], velocity: [Double], rested: Bool)
    ) -> (value: HostValue, rested: Bool) {
        guard !position.rested,
              position.value.allSatisfy(\.isFinite),
              position.velocity.allSatisfy(\.isFinite)
        else {
            lanes = plan.destination
            velocity = Array(repeating: 0, count: lanes.count)
            return (plan.target, true)
        }

        lanes = position.value
        velocity = position.velocity
        return (plan.value(at: lanes), false)
    }
}

/// A value as numeric lanes and back, keeping its shape.
/// Design: docs/design/host/motion.md#described-motion
private struct MotionValuePlan {
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

    /// Whether a brush property holds a colour or a well-formed brush.
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
