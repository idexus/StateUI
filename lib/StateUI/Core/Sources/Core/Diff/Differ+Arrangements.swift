// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// An arrangement stands where a page stands, every element keeps what its contract declares, and a place is a
// layout's own; anything else is left out or said, once.
// Design: docs/design/views/pages.md#an-arrangement-is-a-view
// Design: docs/design/contracts/README.md#what-an-element-does-not-wear

extension Differ {
    /// Whether `child` may stand under `parent`: an arrangement only where a page stands.
    func standsWhereItMay(_ child: RenderedNode, under parent: NodeType) -> Bool {
        guard NodeType.arrangements.contains(child.type), !NodeType.pagePositions.contains(parent) else { return true }

        complain(
            "\(child.type.name) stands where a page stands - a window's view, or a page of an arrangement - "
                + "and was left out of \(parent.name)")
        return false
    }

    /// Says once a place `child` was given for a layout it does not stand in - a grid's row or column outside a
    /// Grid, an area outside a ZStack: the layout it stands in places it by its own rule.
    func saysAPlaceForAnotherLayout(_ child: RenderedNode, under parent: NodeType) {
        let placements: [(layout: NodeType, members: [Prop])] = [
            (.grid, [.gridRow, .gridColumn, .gridRowSpan, .gridColumnSpan]),
            (.zStack, [.area]),
        ]

        for (layout, members) in placements where parent != layout {
            for member in members where child.props[member] != nil {
                complain(
                    "\(child.type.name)'s \(member.name) places it in a \(layout.name), and it stands in a "
                        + "\(parent.name)")
            }
        }
    }
}

extension Node {
    /// The node without what its contract does not wear: a member written where nothing declares it would reach a
    /// host with nothing to act on. An arrangement fills where a page stands, so a view's width, margin or gesture
    /// written on it is one of these.
    mutating func keepingDeclared() {
        guard let declared = Self.declared[type] else { return }

        // What is left out, in name order; nothing is sorted where nothing is.
        for prop in props.keys.filter({ !declared.props.contains($0) }).sorted() {
            leaveOut(prop.name)
            props[prop] = nil
        }

        for prop in driven.keys.filter({ !declared.props.contains($0) }).sorted() {
            leaveOut(prop.name)
            driven[prop] = nil
        }

        for event in events.keys.filter({ !declared.events.contains($0) }).sorted() {
            leaveOut(event.name)
            events[event] = nil
        }
    }

    private func leaveOut(_ member: String) {
        if NodeType.arrangements.contains(type) {
            complain("\(type.name) fills where a page stands and takes no \(member): it was left out")
        } else {
            complain("\(type.name) takes no \(member) - its contract does not wear it: it was left out")
        }
    }

    /// The keys each element of the library's contract declares, its tiers' included.
    private static let declared: [NodeType: (props: Set<Prop>, events: Set<Event>)] = {
        var declared: [NodeType: (props: Set<Prop>, events: Set<Event>)] = [:]
        for contract in LibraryContracts.elements {
            let names: [String] = contract.worn.flatMap { tier in tier.members.map { $0.name } }
            declared[contract.nodeType] = (Set(names.map { Prop($0) }), Set(names.map { Event($0) }))
        }
        return declared
    }()
}
