// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// The walk over a composed view's stored properties that finds its state boxes, its `@Environment` slots and its
// inputs: what each type met is to the walk worked out once.
// Design: docs/design/core/identity-and-diffing.md#paths-pair-state

import StateUIFoundation

/// Every state box and `@Environment` slot a view owns, with its inputs, in one
/// walk. Each box comes back under the path the walk reached it by, which pairs
/// it with its predecessor next render.
/// Design: docs/design/core/identity-and-diffing.md#paths-pair-state
@MainActor
func stateParts(
    in value: Any
) -> (
    boxes: [(path: PathNumber, box: StateBox)],
    slots: [EnvironmentSlot],
    inputs: [(path: PathNumber, input: Input)]
) {
    Renderer.shared.walks += 1
    var parts = StateParts()
    parts.walk(value, at: PathNumber(), named: nil)
    return (parts.boxes, parts.slots, parts.inputs)
}

/// What each part of `value` the walk reaches is called, by its path: the names a path stands for, spelled only
/// where one is shown - a state's first naming, an inspector's reason.
/// Design: docs/design/core/identity-and-diffing.md#a-path-is-a-number
@MainActor
func partNames(in value: Any) -> [PathNumber: String] {
    var parts = StateParts()
    parts.walk(value, at: PathNumber(), named: "")
    return parts.names
}

/// A composed view's value and what the walk finds in it, walked at the first asking - or taken from its
/// predecessor where the value lies in memory byte for byte as the predecessor's did: the same values, the same
/// objects, the same storage, so the same inputs, with no mirror made.
/// Design: docs/design/core/identity-and-diffing.md#a-view-built-as-it-was
@MainActor
final class ViewWalk {
    /// The view, kept while its element is: what a successor is laid against.
    let view: Any
    private var found: (boxes: [(path: PathNumber, box: StateBox)], slots: [EnvironmentSlot],
                        inputs: [(path: PathNumber, input: Input)])?

    init(_ view: Any) {
        self.view = view
    }

    /// What the walk found: the state boxes by path, the `@Environment` slots, the inputs.
    var parts: (boxes: [(path: PathNumber, box: StateBox)], slots: [EnvironmentSlot],
                inputs: [(path: PathNumber, input: Input)]) {
        if let found { return found }
        let walked = stateParts(in: view)
        found = walked
        return walked
    }

    /// What each part the walk reached is called, spelled at the first asking.
    private(set) lazy var names = partNames(in: view)

    /// Takes `kept`'s walk, where this view lies in memory as `kept`'s does and `kept` holds nothing that cannot be
    /// compared - a closure counts as changed whatever its bytes; whether it did.
    func takes(_ kept: ViewWalk) -> Bool {
        guard found == nil, !kept.holdsOpaque, Self.identical(view, kept.view) else { return false }
        found = kept.parts
        return true
    }

    /// Whether an input of the view cannot be compared.
    private var holdsOpaque: Bool {
        parts.inputs.contains { if case .opaque = $0.input { true } else { false } }
    }

    /// Whether two values are of one type and alike byte for byte.
    private static func identical(_ one: Any, _ other: Any) -> Bool {
        guard Swift.type(of: one) == Swift.type(of: other) else { return false }

        // Laid side by side over zeroes: a copy of a value holding references goes field by field, so the bytes
        // that pad a field stand zero in both - a pad's leftovers would part two equal values.
        func open<Value>(_ one: Value) -> Bool {
            let size = MemoryLayout<Value>.size
            guard size > 0 else { return true }

            return withUnsafeTemporaryAllocation(of: Value.self, capacity: 2) { pair in
                UnsafeMutableRawBufferPointer(pair).initializeMemory(as: UInt8.self, repeating: 0)
                let first = pair.baseAddress!
                first.initialize(to: one)
                (first + 1).initialize(to: other as! Value)
                defer { first.deinitialize(count: 2) }
                return memcmp(first, first + 1, size) == 0
            }
        }
        return _openExistential(one, do: open)
    }
}

/// A type's key: its module-qualified name, made a key once a type.
@MainActor
func typeKey(of type: Any.Type) -> KeyName {
    if let key = StateParts.names[ObjectIdentifier(type)] { return key }

    let key = KeyName(String(reflecting: type))
    StateParts.names[ObjectIdentifier(type)] = key
    return key
}

/// A view the walk reads by the parts it names, with no mirror: a library view standing once an item of a layout,
/// generic over what it holds - a mirror of a generic type works its fields' types out at every reading.
/// Design: docs/design/core/identity-and-diffing.md#a-type-learned-once
@MainActor
protocol WalkedView {
    /// Its stored parts, each under the label a mirror would give it.
    var walkedParts: [(label: String, value: Any)] { get }
}

/// What one walk has found, and what every walk has learned of the types it met.
@MainActor
private struct StateParts {
    var boxes: [(path: PathNumber, box: StateBox)] = []
    var slots: [EnvironmentSlot] = []
    var inputs: [(path: PathNumber, input: Input)] = []
    var names: [PathNumber: String] = [:]

    /// What a value of a type is to the walk, decided by the first value of it met.
    /// Design: docs/design/core/identity-and-diffing.md#a-type-learned-once
    enum Kind {
        case aim, box, slot, borrowed, node
        case value((Any) -> any Equatable)
        case reference
        case walked((Any) -> [(label: String, value: Any)])
        case mirrored

        /// Asked of each value: an optional, or an `AnyHashable`, is what it holds to a cast.
        case each
    }

    /// What a type met is to the walk, and the step a stored view of it adds to a path - its name in brackets, and
    /// that as a number.
    struct Learned {
        var kind: Kind
        let stored: String
        let storedNumber: UInt64?
    }

    /// What every type met is.
    static var kinds: [ObjectIdentifier: Learned] = [:]
    static var names: [ObjectIdentifier: KeyName] = [:]

    /// Adds what `value`, at `path`, holds - each part's name spelled under `name` where one is asked.
    mutating func walk(_ value: Any, at path: PathNumber, named name: String?, declared: Bool = false) {
        var kind = Self.learned(value).kind
        if case .each = kind { kind = Self.kind(of: value) }
        if let name { names[path] = name }

        switch kind {
        case .aim:
            // An aim the view was handed is compared by its box and never adopted; one it
            // declares is `@Aim`'s underscored backing property, adopted like any state.
            guard declared else {
                return inputs.append((path: path, input: .borrowed(ObjectIdentifier((value as! Aiming).box), nil)))
            }
            mirrored(value, at: path, named: name, declaredAim: true)
        case .box:
            let box = value as! StateBox
            boxes.append((path: path, box: box))
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
        case .walked(let parts):
            let parts = parts(value)
            inputs.append((path: path, input: .parts(parts.count)))
            for (label, part) in parts {
                walk(part, label: label, offset: nil, under: path, named: name)
            }
        case .mirrored, .each:
            mirrored(value, at: path, named: name, declaredAim: false)
        }
    }

    /// Walks `part`, the stored property `label` - or the element at `offset` of a collection - of the value at
    /// `path`: a step on by its label, and by the type of a view stored there.
    private mutating func walk(_ part: Any, label: String?, offset: Int?, under path: PathNumber, named name: String?) {
        let stored = Self.learned(part)
        var next = label.map(path.appending) ?? path.appending(UInt64(offset ?? 0))
        if let number = stored.storedNumber { next = next.appending(number) }

        var spelled: String?
        if let name {
            Renderer.shared.texts += 1
            spelled = "\(name).\(label ?? String(offset ?? 0))\(stored.stored)"
        }
        walk(part, at: next, named: spelled, declared: label?.hasPrefix("_") ?? false)
    }

    /// The parts of a value - a struct's fields, an enum's payload, a tuple's or a collection's elements - read
    /// through a mirror.
    private mutating func mirrored(_ value: Any, at path: PathNumber, named name: String?, declaredAim: Bool) {
        if declaredAim {
            guard let box = value as? StateBox else {
                return inputs.append((path: path, input: .reference(ObjectIdentifier(value as AnyObject))))
            }
            boxes.append((path: path, box: box))
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
            walk(child.value, label: child.label, offset: offset, under: path, named: name)
        }
    }

    /// What `value`'s type is to the walk, learned from it where no value of its type was met before.
    private static func learned(_ value: Any) -> Learned {
        let type = ObjectIdentifier(Swift.type(of: value))
        if let known = kinds[type] { return known }

        // The type of a stored view, in brackets after the property holding it, so one
        // property holding different views gives different paths. Module-qualified. An
        // optional is what it holds - a cast looks through it - so what it holds is named
        // on its own part, the same whatever value of it came first.
        let held = Mirror(reflecting: value).displayStyle == .optional || Swift.type(of: value) == AnyHashable.self
        let key = !held && value is Element ? typeKey(of: Swift.type(of: value)) : nil
        var kind = held ? Kind.each : kind(of: value)
        if case .value = kind, ownsState(value) { kind = .mirrored }
        let learned = Learned(kind: kind, stored: key.map { "(\($0.name))" } ?? "", storedNumber: key?.number)
        kinds[type] = learned
        return learned
    }

    /// Whether `value` holds a state, a binding, an environment value or an aim of its own: its author's equality
    /// cannot pair them with its predecessor's, so a type of it is read part by part, however it compares.
    /// Design: docs/design/core/identity-and-diffing.md#a-type-learned-once
    private static func ownsState(_ value: Any) -> Bool {
        Mirror(reflecting: value).children.contains { part in
            part.value is StateBox || part.value is EnvironmentSlot || part.value is BorrowedState
                || part.value is Aiming
        }
    }

    /// What `value` is, in the order the walk asks it.
    private static func kind(of value: Any) -> Kind {
        if value is Aiming { return .aim }
        if value is StateBox { return .box }
        if value is EnvironmentSlot { return .slot }
        if value is BorrowedState { return .borrowed }
        if value is Node { return .node }
        if let walked = Swift.type(of: value) as? any WalkedView.Type { return .walked(reader(walked)) }
        if let comparable = Swift.type(of: value) as? any Equatable.Type { return .value(opener(comparable)) }

        return Mirror(reflecting: value).displayStyle == .class ? .reference : .mirrored
    }

    /// The parts of a value of a walked type.
    private static func reader<Walked: WalkedView>(_: Walked.Type) -> (Any) -> [(label: String, value: Any)] {
        { ($0 as! Walked).walkedParts }
    }

    /// A value of an equatable type, made the existential it is compared as.
    private static func opener<Value: Equatable>(_: Value.Type) -> (Any) -> any Equatable {
        { $0 as! Value }
    }
}
