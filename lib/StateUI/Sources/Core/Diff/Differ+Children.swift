// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// An element's children matched against the last render's - by `.id()`, then by
// builder path, then by position - and patched.
// Design: docs/design/core/identity-and-diffing.md#keys

extension Differ {
    /// Matches this render's children against the last one's and patches each. An
    /// unchanged key sequence sends only the children with something to say; a
    /// changed one sends the complete list in order.
    /// Design: docs/design/core/identity-and-diffing.md#keys
    func reconcileChildren(
        of previous: RenderedNode?,
        node: Node,
        into patch: inout HostPatch,
        sizesArrive: Bool
    ) -> [RenderedNode] {
        let rendered = previous?.children ?? []

        var byManualId: [String: RenderedNode] = [:]
        var byKey: [String: RenderedNode] = [:]
        for child in rendered {
            if case .manual(let key) = child.id {
                byManualId[key] = child
            }

            // First wins, so two elements claiming one path behave like a repeated `.id()`.
            if let key = child.key, byKey[key] == nil {
                byKey[key] = child
            }
        }

        // Nodes put in by hand are matched by position among themselves.
        let unkeyed = rendered.filter { $0.key == nil }

        var children: [RenderedNode] = []
        var patches: [HostPatch] = []
        var claimed: Set<ElementId> = []
        var used: Set<ElementId> = []
        var unkeyedSoFar = 0
        var manualSeen: [String: Int] = [:]

        for (index, childNode) in node.children.enumerated() {
            // A repeated `.id()` takes a stable variant: the id, a NUL, its occurrence.
            // Design: docs/design/core/identity-and-diffing.md#repeated-ids
            var childNode = childNode
            if let rawId = childNode.id {
                let occurrence = manualSeen[rawId, default: 0]
                manualSeen[rawId] = occurrence + 1

                if occurrence > 0 {
                    childNode.id = "\(rawId)\u{0}\(occurrence)"
                }
            }

            let match = self.match(
                childNode,
                at: childNode.key == nil ? unkeyedSoFar : index,
                rendered: unkeyed,
                byManualId: byManualId,
                byKey: byKey,
                claimed: claimed)

            if childNode.key == nil {
                unkeyedSoFar += 1
            }

            if let match = match {
                claimed.insert(match.id)
            }

            var id = match?.id ?? identity(for: childNode)

            // A backstop for a variant that still collided, which it should not.
            if used.contains(id) {
                id = .auto(allocateElementId())
            }

            used.insert(id)

            var (child, childPatch) = element(
                id: id, rendered: match, node: childNode, sizesArrive: sizesArrive)

            // What this row looks like, under a layout whose rows are recycled; sent when
            // it moved.
            // Design: docs/design/core/identity-and-diffing.md#recycling
            if node.recycles {
                child.shape = Recycling.shape(of: child)

                // Against the host's default on a complete description.
                let had = describeAll ? Recycling.none : (match?.shape ?? Recycling.none)

                if child.shape != had {
                    childPatch.shape = child.shape
                }
            }

            children.append(child)
            patches.append(childPatch)
        }

        for child in rendered where !claimed.contains(child.id) {
            forget(child)
        }

        // The arrangement is sent only when it changed.
        if describeAll || children.map(\.id) != rendered.map(\.id) {
            patch.children = .arranged(patches)
        } else {
            let changed = patches.filter { !$0.isEmpty }
            patch.children = changed.isEmpty ? .unchanged : .changed(changed)
        }

        return children
    }

    /// The rendered element a node continues: by the author's `.id()`, then by the
    /// builder path, then by position - three ways that never meet.
    /// Design: docs/design/core/identity-and-diffing.md#keys
    private func match(
        _ node: Node,
        at index: Int,
        rendered: [RenderedNode],
        byManualId: [String: RenderedNode],
        byKey: [String: RenderedNode],
        claimed: Set<ElementId>
    ) -> RenderedNode? {
        if let id = node.id {
            let match = byManualId[id]
            return match.flatMap { claimed.contains($0.id) ? nil : $0 }
        }

        if let key = node.key {
            let match = byKey[key]
            return match.flatMap {
                claimed.contains($0.id) || $0.id.isManual ? nil : $0
            }
        }

        guard index < rendered.count else { return nil }

        let candidate = rendered[index]

        guard case .auto = candidate.id, !claimed.contains(candidate.id) else {
            return nil
        }

        return candidate
    }
}
