// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// The Wire: the patch, the acts and the host's reports as deterministic bytes, for
// a runtime that cannot read Swift types. Little-endian and fixed width; every
// name rides the session's dictionary.
// Design: docs/design/core/wire.md#bytes-rather-than-text

/// The wire's writer - and the reader of every channel the host writes.
public enum Wire {
    /// How deep a list value may nest before decoding refuses it, so a corrupt count
    /// is an unreadable buffer rather than a stack overflow.
    static let mostNesting = 256

    /// A list's length in the width the wire writes, or a stop naming the list and the
    /// limit where it does not fit.
    /// Design: docs/design/core/wire.md#limits
    static func count<Written: FixedWidthInteger>(
        _ value: Int,
        of what: String
    ) -> Written {
        guard let written = Written(exactly: value) else {
            preconditionFailure(
                "StateUI: \(value) \(what) in one message, and the wire counts "
                + "them in \(Written.bitWidth) bits - at most \(Written.max).")
        }

        return written
    }

    /// The format's version, answered by `stateui_wire_version` and written first into
    /// every message on every channel but the state batch. It changes only when the
    /// layout does.
    public static let version: UInt8 = 15

    // The render message's field markers, each written only when its field is
    // present; zero ends a node.
    // Design: docs/design/core/wire.md#the-render-message
    enum Field {
        static let end: UInt8 = 0
        static let replace: UInt8 = 1
        static let props: UInt8 = 2
        static let events: UInt8 = 3
        static let children: UInt8 = 4
        static let arranged: UInt8 = 5
        static let transitions: UInt8 = 6
        static let cleared: UInt8 = 7
        static let recycles: UInt8 = 8
        static let shape: UInt8 = 9
        static let motion: UInt8 = 10
        static let driven: UInt8 = 11
    }

    /// Serializes a render message: the envelope, the names the message is
    /// the first to use, then the root's patch.
    static func encode(
        _ patch: HostPatch,
        generation: Int32,
        complete: Bool = false,
        dictionary: WireDictionary
    ) -> [UInt8] {
        // The body first: writing it discovers which names the head announces.
        var body: [UInt8] = []
        write(patch, into: &body, dictionary: dictionary)

        var out: [UInt8] = []
        out.u8(version)
        out.u8(complete ? 1 : 0)
        out.i32(generation)
        announce(dictionary.takePending(), into: &out)
        out.append(contentsOf: body)
        return out
    }

    /// Serializes a batch of acts for the host, announcements first.
    static func encode(_ calls: [ActCall], dictionary: WireDictionary) -> [UInt8] {
        var body: [UInt8] = []
        body.u16(count(calls.count, of: "acts"))

        for call in calls {
            body.u16(dictionary.id(of: call.act.name))
            body.i32(Int32(call.completion ?? 0))
            body.u8(count(call.arguments.count, of: "arguments to one act"))

            for argument in call.arguments {
                write(argument, into: &body, dictionary: dictionary)
            }
        }

        var out: [UInt8] = []
        out.u8(version)
        announce(dictionary.takePending(), into: &out)
        out.append(contentsOf: body)
        return out
    }

    /// The head's announcements: the names this message is the first to use, ahead of
    /// anything that refers to them.
    /// Design: docs/design/core/wire.md#announcements-come-first
    private static func announce(
        _ entries: [(id: UInt16, name: String)],
        into out: inout [UInt8]
    ) {
        out.u16(count(entries.count, of: "names announced"))

        for entry in entries {
            out.u16(entry.id)
            out.string(entry.name)
        }
    }

    /// Writes one element's patch and, recursively, the patches under it: the key and
    /// the type always, every other field only when present.
    private static func write(
        _ patch: HostPatch,
        into out: inout [UInt8],
        dictionary: WireDictionary
    ) {
        write(patch.id, into: &out)
        out.u16(dictionary.id(of: patch.type.name))

        if patch.replace {
            out.u8(Field.replace)
        }

        // Whether the children are rows the host may reuse, and what a row looks like -
        // each only when it changed.
        if let recycles = patch.recycles {
            out.u8(Field.recycles)
            out.u8(recycles ? 1 : 0)
        }

        if let shape = patch.shape {
            out.u8(Field.shape)
            out.u64(shape)
        }

        if !patch.properties.isEmpty {
            out.u8(Field.props)
            out.u16(count(patch.properties.count, of: "properties on one element"))
            // Sorted: the determinism rule.
            // Design: docs/design/core/wire.md#determinism
            for key in patch.properties.keys.sorted() {
                out.u16(dictionary.id(of: key.name))
                write(patch.properties[key]!, into: &out, dictionary: dictionary)
            }
        }

        // The properties no longer described, by key alone, in name order.
        if !patch.clearedProperties.isEmpty {
            out.u8(Field.cleared)
            out.u16(count(
                patch.clearedProperties.count,
                of: "cleared properties on one element"))

            for key in patch.clearedProperties {
                out.u16(dictionary.id(of: key.name))
            }
        }

        // How the children animate where this element places them.
        // Design: docs/design/core/wire.md#layout-motion
        if let placement = patch.motion {
            out.u8(Field.motion)

            // Inherited is -1 here: a layout that stops saying how its children animate has
            // to be heard saying so.
            if placement.motion.isInherited {
                out.i32(-1)
            } else {
                out.i32(placement.motion.law.rawValue)
                out.u32(placement.motion.millis)
                out.i32(placement.motion.curve.rawValue)
                out.f64(placement.motion.factor)
            }

            // Always, whichever law: one part of a place may stay still.
            out.u8(placement.lanes.rawValue)
        }

        // Beside the properties, never inside one: the value is the destination, and this
        // says which the host animates to.
        // Design: docs/design/core/wire.md#transitions
        if !patch.transitions.isEmpty {
            out.u8(Field.transitions)
            out.u16(count(patch.transitions.count, of: "motions on one element"))

            for key in patch.transitions.keys.sorted() {
                let transition = patch.transitions[key]!
                out.u16(dictionary.id(of: key.name))
                out.i32(transition.motion.law.rawValue)
                out.u32(transition.motion.millis)
                out.i32(transition.motion.curve.rawValue)
                out.f64(transition.motion.factor)
            }
        }

        // The driven properties, whenever the set changed, an empty set included; sorted;
        // no law - it lies in the value's own lanes.
        // Design: docs/design/core/wire.md#driven-states
        if case .replace(let driven)? = patch.driven {
            out.u8(Field.driven)
            out.u16(count(driven.count, of: "driven properties on one element"))

            for key in driven.keys.sorted(by: { ($0.name, driven[$0]!.kind.rawValue) < ($1.name, driven[$1]!.kind.rawValue) }) {
                let entry = driven[key]!
                out.u16(dictionary.id(of: key.name))
                out.i32(entry.state)
                out.u8(UInt8(truncatingIfNeeded: entry.mode.rawValue))
                out.u8(UInt8(truncatingIfNeeded: entry.kind.rawValue))
            }
        }

        // Whenever the event set changed, an empty set included.
        // Design: docs/design/core/wire.md#events-and-children
        if case .replace(let events)? = patch.events {
            out.u8(Field.events)
            out.u16(count(events.count, of: "handlers on one element"))
            for key in events.keys.sorted() {
                out.u16(dictionary.id(of: key.name))
                out.i32(events[key]!)
            }
        }

        // The complete arrangement even when empty; the sparse form only when it is not.
        switch patch.children {
        case .unchanged:
            break

        case .changed(let children) where children.isEmpty:
            break

        case .changed(let children), .arranged(let children):
            if case .arranged = patch.children {
                out.u8(Field.arranged)
            } else {
                out.u8(Field.children)
            }
            out.u16(count(children.count, of: "children of one element"))
            for child in children {
                write(child, into: &out, dictionary: dictionary)
            }
        }

        out.u8(Field.end)
    }

    /// A key in the shape that says which kind: a number the differ assigned, or the
    /// author's text.
    private static func write(_ id: ElementId, into out: inout [UInt8]) {
        switch id {
        case .auto(let value):
            out.u8(1)
            out.i32(Int32(value))
        case .manual(let value):
            out.u8(2)
            out.string(value)
        }
    }

    /// One tagged value; the dictionary is for the arm that carries a name.
    private static func write(
        _ value: PropValue,
        into out: inout [UInt8],
        dictionary: WireDictionary
    ) {
        switch value {
        case .name(let name):
            out.u8(11)
            out.u16(dictionary.id(of: name))

        case .values(let values):
            // Recursed here, so a name nested in a list still rides the dictionary.
            out.u8(9)
            out.u16(count(values.count, of: "parts of one value"))
            for value in values {
                write(value, into: &out, dictionary: dictionary)
            }

        case .themed:
            // Picked by the differ as the element was built; one arriving here anyway is
            // written as the theme stands.
            write(value.resolvingTheme(), into: &out, dictionary: dictionary)

        default:
            out.value(value)
        }
    }

    /// Announces the store the application keeps state in and its keys, names in full.
    /// Design: docs/design/core/wire.md#persistent-keys
    static func encodePersistent(storage: PersistentStorage, keys: [PersistentKey]) -> [UInt8] {
        var out: [UInt8] = []
        out.u8(version)
        out.string(storage.name)
        out.u16(count(keys.count, of: "persistent keys"))

        for key in keys {
            out.string(key.name)

            // One byte for a vocabulary of four.
            out.u8(UInt8(truncatingIfNeeded: key.kind.rawValue))
        }

        return out
    }

    /// What a host realizes, said once at start-up by a runtime across the Wire;
    /// sorted, names in full.
    /// Design: docs/design/core/wire.md#realizations-and-declarations
    static func encodeRealization(_ realization: HostRealization) -> [UInt8] {
        var out: [UInt8] = []
        out.u8(version)
        out.u16(count(realization.elements.count, of: "realized elements"))

        for element in realization.elements.sorted() {
            out.string(element)
        }

        let members = realization.members.sorted {
            ($0.element, $0.owner, $0.member) < ($1.element, $1.owner, $1.member)
        }
        out.u16(count(members.count, of: "realized members"))

        for member in members {
            out.string(member.element)
            out.string(member.owner)
            out.string(member.member)
        }

        return out
    }

    /// What a host declares, read off its own runtime: presence, never ownership.
    /// Design: docs/design/core/wire.md#realizations-and-declarations
    static func encodeDeclaration(_ declaration: HostDeclaration) -> [UInt8] {
        var out: [UInt8] = []
        out.u8(version)
        out.u16(count(declaration.elements.count, of: "declared elements"))

        for element in declaration.elements.keys.sorted() {
            let declared = declaration.elements[element] ?? HostDeclaration.Element()
            out.string(element)
            write(declared, into: &out, of: "element")
        }

        write(declaration.shared, into: &out, of: "shared")

        out.u16(count(declaration.acts.count, of: "performed acts"))

        for act in declaration.acts.sorted() {
            out.string(act)
        }

        return out
    }

    /// One element's members and then its events, each counted and sorted.
    private static func write(
        _ declared: HostDeclaration.Element, into out: inout [UInt8], of what: String
    ) {
        out.u16(count(declared.members.count, of: "members on one \(what)"))

        for member in declared.members.sorted() {
            out.string(member)
        }

        out.u16(count(declared.events.count, of: "events on one \(what)"))

        for event in declared.events.sorted() {
            out.string(event)
        }
    }
}
