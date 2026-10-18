// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// The walk over a composed view's stored properties that finds its state boxes, its `@Environment` slots and its
// inputs: what each type met is to the walk worked out once.
// Design: docs/design/core/identity-and-diffing.md#paths-pair-state

/// Every state box and `@Environment` slot a view owns, with its inputs, in one
/// walk. Each box comes back under the path the walk reached it by, which pairs
/// it with its predecessor next render.
/// Design: docs/design/core/identity-and-diffing.md#paths-pair-state
@MainActor
func stateParts(
    in value: Any
) -> (
    boxes: [(path: String, box: StateBox)],
    slots: [EnvironmentSlot],
    inputs: [(path: String, input: Input)]
) {
    var parts = StateParts()
    parts.walk(value, at: "")
    return (parts.boxes, parts.slots, parts.inputs)
}

/// A type's module-qualified name, worked out once a type.
@MainActor
func qualifiedName(of type: Any.Type) -> String {
    if let name = StateParts.names[ObjectIdentifier(type)] { return name }

    let name = String(reflecting: type)
    StateParts.names[ObjectIdentifier(type)] = name
    return name
}

/// What one walk has found, and what every walk has learnt of the types it met.
@MainActor
private struct StateParts {
    var boxes: [(path: String, box: StateBox)] = []
    var slots: [EnvironmentSlot] = []
    var inputs: [(path: String, input: Input)] = []

    /// What a value of a type is to the walk, decided by the first value of it met.
    /// Design: docs/design/core/identity-and-diffing.md#a-type-learnt-once
    enum Kind {
        case aim, box, slot, borrowed, node
        case value((Any) -> any Equatable)
        case reference
        case mirrored

        /// Asked of each value: an optional, or an `AnyHashable`, is what it holds to a cast.
        case each
    }

    /// What every type met is, and the bracketed name it adds to a path where it is a stored view.
    static var kinds: [ObjectIdentifier: (kind: Kind, stored: String)] = [:]
    static var names: [ObjectIdentifier: String] = [:]

    /// Adds what `value`, at `path`, holds.
    mutating func walk(_ value: Any, at path: String) {
        var kind = Self.learnt(value).kind
        if case .each = kind { kind = Self.kind(of: value) }

        switch kind {
        case .aim:
            // An aim the view was handed is compared by its box and never adopted; one it
            // declares is `@Aim`'s underscored backing property, adopted like any state.
            guard path.split(separator: ".").last?.hasPrefix("_") ?? false else {
                return inputs.append((path: path, input: .borrowed(ObjectIdentifier((value as! Aiming).box), nil)))
            }
            mirrored(value, at: path, declaredAim: true)
        case .box:
            let box = value as! StateBox
            boxes.append((path: path, box: box))
            box.named(path)
            inputs.append((path: path, input: .box(box)))
        case .slot:
            let slot = value as! EnvironmentSlot
            slots.append(slot)
            inputs.append((path: path, input: .slot(slot)))
        case .borrowed:
            // A borrowed state is compared by what it borrows from.
            let lends = (value as! BorrowedState).lends
            inputs.append((
                path: path,
                input: lends.lender.map { .borrowed(ObjectIdentifier($0), lends.lent) } ?? .opaque))
        case .node:
            // A built node is interface, never state, and cannot be compared.
            inputs.append((path: path, input: .opaque))
        case .value(let comparable):
            inputs.append((path: path, input: .value(comparable(value))))
        case .reference:
            // A reference keeps itself alive; as an input it is the object it is.
            inputs.append((path: path, input: .reference(ObjectIdentifier(value as AnyObject))))
        case .mirrored, .each:
            mirrored(value, at: path, declaredAim: false)
        }
    }

    /// The parts of a value - a struct's fields, an enum's payload, a tuple's or a collection's elements - read
    /// through a mirror.
    private mutating func mirrored(_ value: Any, at path: String, declaredAim: Bool) {
        if declaredAim {
            guard let box = value as? StateBox else {
                return inputs.append((path: path, input: .reference(ObjectIdentifier(value as AnyObject))))
            }
            boxes.append((path: path, box: box))
            box.named(path)
            return inputs.append((path: path, input: .box(box)))
        }

        let mirror = Mirror(reflecting: value)
        let children = Array(mirror.children)

        // A leaf the mirror cannot open - a closure, a metatype - counts as changed; an
        // empty struct or enum is the one value it can be.
        guard !children.isEmpty else {
            return inputs.append((path: path, input: mirror.displayStyle == nil ? .opaque : .parts(0)))
        }

        inputs.append((path: path, input: .parts(children.count)))

        // A collection's children have no labels, so their position stands in.
        for (offset, child) in children.enumerated() {
            walk(child.value, at: "\(path).\(child.label ?? String(offset))\(Self.learnt(child.value).stored)")
        }
    }

    /// What `value`'s type is to the walk, learnt from it where no value of its type was met before.
    private static func learnt(_ value: Any) -> (kind: Kind, stored: String) {
        let type = ObjectIdentifier(Swift.type(of: value))
        if let known = kinds[type] { return known }

        // The type of a stored view, in brackets after the property holding it, so one
        // property holding different views gives different paths. Module-qualified.
        let stored = value is Element ? "(\(qualifiedName(of: Swift.type(of: value))))" : ""
        let held = Mirror(reflecting: value).displayStyle == .optional || Swift.type(of: value) == AnyHashable.self
        let learnt = (kind: held ? Kind.each : kind(of: value), stored: stored)
        kinds[type] = learnt
        return learnt
    }

    /// What `value` is, in the order the walk asks it.
    private static func kind(of value: Any) -> Kind {
        if value is Aiming { return .aim }
        if value is StateBox { return .box }
        if value is EnvironmentSlot { return .slot }
        if value is BorrowedState { return .borrowed }
        if value is Node { return .node }
        if let comparable = Swift.type(of: value) as? any Equatable.Type { return .value(opener(comparable)) }

        return Mirror(reflecting: value).displayStyle == .class ? .reference : .mirrored
    }

    /// A value of an equatable type, made the existential it is compared as.
    private static func opener<Value: Equatable>(_: Value.Type) -> (Any) -> any Equatable {
        { $0 as! Value }
    }
}
