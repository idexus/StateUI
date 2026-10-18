// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// The walk over a composed view's stored properties that finds its state boxes, its `@Environment` slots and its
// inputs: what each type met is to the walk worked out once, a struct's fields reached by key paths.
// Design: docs/design/core/identity-and-diffing.md#paths-pair-state

@_spi(Reflection) import Swift

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
        case fields(Fields)
        case mirrored

        /// Asked of each value: an optional, or an `AnyHashable`, is what it holds to a cast.
        case each
    }

    /// A struct's stored properties, in their order, each reached by a key path: what a mirror would list, with
    /// none of the work of making one.
    final class Fields {
        let labels: [String]
        let read: (Any) -> [Any]

        init(labels: [String], read: @escaping (Any) -> [Any]) {
            self.labels = labels
            self.read = read
        }
    }

    /// What every type met is, and the bracketed name it adds to a path where it is a stored view.
    static var kinds: [ObjectIdentifier: (kind: Kind, stored: String)] = [:]
    static var names: [ObjectIdentifier: String] = [:]

    /// Adds what `value`, at `path`, holds.
    mutating func walk(_ value: Any, at path: String) {
        var kind = Self.learnt(value).kind
        if case .each = kind { kind = Self.kind(of: value, plans: false) }

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
        case .fields(let fields):
            inputs.append((path: path, input: .parts(fields.labels.count)))
            for (label, field) in zip(fields.labels, fields.read(value)) {
                walk(field, at: "\(path).\(label)\(Self.learnt(field).stored)")
            }
        case .mirrored, .each:
            mirrored(value, at: path, declaredAim: false)
        }
    }

    /// The parts of a value no key path reaches - an enum, a tuple, a collection, a struct holding a closure or a
    /// weak reference - read through a mirror, as the walk read every value before it learnt types.
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
        let learnt = (kind: held ? Kind.each : kind(of: value, plans: true), stored: stored)
        kinds[type] = learnt
        return learnt
    }

    /// What `value` is, in the order the walk asks it; a struct planned by its fields where `plans`.
    private static func kind(of value: Any, plans: Bool) -> Kind {
        if value is Aiming { return .aim }
        if value is StateBox { return .box }
        if value is EnvironmentSlot { return .slot }
        if value is BorrowedState { return .borrowed }
        if value is Node { return .node }
        if let comparable = Swift.type(of: value) as? any Equatable.Type { return .value(opener(comparable)) }

        let mirror = Mirror(reflecting: value)
        if mirror.displayStyle == .class { return .reference }
        guard plans, mirror.displayStyle == .struct else { return .mirrored }

        // The type itself, opened: a value a mirror hands back may be an existential holding it.
        let labels = mirror.children.map { $0.label ?? "" }
        func opened<Root>(_: Root.Type) -> Fields? { fields(of: Root.self, labels: labels) }
        return _openExistential(Swift.type(of: value), do: opened).map(Kind.fields) ?? .mirrored
    }

    /// A value of an equatable type, made the existential it is compared as.
    private static func opener<Value: Equatable>(_: Value.Type) -> (Any) -> any Equatable {
        { $0 as! Value }
    }

    /// A struct's fields by key path, where a key path reaches every one a mirror lists, by the same labels in the
    /// same order; nil where one is a closure or a reference held weakly, which only a mirror reads.
    private static func fields<Root>(of _: Root.Type, labels: [String]) -> Fields? {
        var keys: [PartialKeyPath<Root>] = []
        var found: [String] = []
        let whole = _forEachFieldWithKeyPath(of: Root.self) { name, key in
            found.append(String(cString: name))
            keys.append(key)
            return true
        }
        guard whole, found == labels else { return nil }

        return Fields(labels: labels) { value in
            let root = value as! Root
            return keys.map { root[keyPath: $0] }
        }
    }
}
