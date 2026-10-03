// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// An arrangement stands where a page stands, and keeps what its contract declares; anything else is left out and
// said once.
// Design: docs/design/views/pages.md#an-arrangement-is-a-view

extension Differ {
    /// Whether `child` may stand under `parent`: an arrangement only where a page stands.
    func standsWhereItMay(_ child: RenderedNode, under parent: NodeType) -> Bool {
        guard NodeType.arrangements.contains(child.type), !NodeType.pagePositions.contains(parent) else { return true }

        complain(
            "\(child.type.name) stands where a page stands - a window's view, or a page of an arrangement - "
                + "and was left out of \(parent.name)")
        return false
    }
}

extension Node {
    /// An arrangement without what its contract does not declare: it fills where a page stands, so a view's
    /// width, margin or gesture written on it has nothing to act on.
    mutating func keepingDeclared() {
        guard let declared = Self.declared[type] else { return }

        for prop in props.keys.sorted() where !declared.contains(prop.name) {
            leaveOut(prop.name)
            props[prop] = nil
        }

        for prop in driven.keys.sorted() where !declared.contains(prop.name) {
            leaveOut(prop.name)
            driven[prop] = nil
        }

        for event in events.keys.sorted() where !declared.contains(event.name) {
            leaveOut(event.name)
            events[event] = nil
        }
    }

    private func leaveOut(_ member: String) {
        complain("\(type.name) fills where a page stands and takes no \(member): it was left out")
    }

    /// The names each arrangement's contract declares, its tiers' included.
    private static let declared: [NodeType: Set<String>] = {
        let contracts: [any ElementContract.Type] = [
            NavigationStackContract.self, TabViewContract.self, SplitViewContract.self, ModalStackContract.self,
        ]

        return Dictionary(uniqueKeysWithValues: contracts.map { contract in
            (contract.nodeType, Set(contract.worn.flatMap { $0.members.map(\.name) }))
        })
    }()
}
