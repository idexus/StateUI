// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

extension MountedElement {
    /// The radio buttons a check of this one takes away: those of its `groupName` in its window, or, where
    /// it names no group, its siblings - itself left out.
    /// Design: docs/design/host/tree.md#a-radio-group
    public var radioPeers: [MountedElement] {
        guard let group = name(.groupName), !group.isEmpty else {
            return parent?.children.filter { $0.type == .radioButton && $0 !== self } ?? []
        }

        var scope = self
        while let ancestor = scope.parent {
            scope = ancestor
            if scope.type == .window { break }
        }
        return scope.radioButtons(named: group).filter { $0 !== self }
    }

    /// Every radio button of `group` in this element and under it, in the tree's order.
    private func radioButtons(named group: String) -> [MountedElement] {
        let own = type == .radioButton && name(.groupName) == group ? [self] : []
        return own + children.flatMap { $0.radioButtons(named: group) }
    }
}
