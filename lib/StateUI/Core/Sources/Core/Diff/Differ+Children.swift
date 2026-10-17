// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// An element's children matched against the last render's - by `.id()`, then by
// builder path, then by position - and patched.
// Design: docs/design/core/identity-and-diffing.md#keys

extension Differ {
    /// Matches this render's children against the last one's and patches each. An
    /// unchanged key sequence sends only the children with something to say; a
    /// changed one sends the complete list in order. The walk goes down through this frame too, kept small: the
    /// matching is done in a step of its own.
    /// Design: docs/design/core/identity-and-diffing.md#keys
    func reconcileChildren(
        of previous: RenderedNode?,
        node: Node,
        into patch: inout HostPatch,
        sizesArrive: Bool
    ) -> [RenderedNode] {
        let matching = ChildMatching(previous?.children ?? [])
        var children: [RenderedNode] = []
        var patches: [HostPatch] = []

        for index in node.children.indices {
            let next = identified(node.children[index], at: index, by: matching)
            let (child, childPatch) = element(
                id: next.id, rendered: next.match, node: next.node, sizesArrive: sizesArrive)

            // An arrangement anywhere a page does not stand is left out (Differ+Arrangements.swift).
            guard standsWhereItMay(child, under: node.type) else {
                forget(child)
                continue
            }
            saysAPlaceForAnotherLayout(child, under: node.type)

            children.append(child)
            patches.append(childPatch)
        }

        arranged(children, patches, after: matching, into: &patch)
        return children
    }

    /// The child `written` at `index` as the walk goes on with it: its identity - its own, its builder path's, its
    /// position's - and the rendered element it continues, matched by `matching`.
    @inline(never)
    private func identified(
        _ written: Node, at index: Int, by matching: ChildMatching
    ) -> (id: ElementID, match: RenderedNode?, node: Node) {
        // A repeated `.id()` takes a stable variant: the id, a NUL, its occurrence.
        // Design: docs/design/core/identity-and-diffing.md#repeated-ids
        var childNode = written
        if let rawId = childNode.id {
            let seen = matching.manualSeen[rawId]
            let occurrence = seen?.count ?? 0
            matching.manualSeen[rawId] = (occurrence + 1, seen?.identity ?? childNode.identity)

            if occurrence > 0 {
                childNode.id = "\(rawId)\u{0}\(occurrence)"
                Self.sayRepeated(rawId, first: seen?.identity, again: childNode.identity)
            }
        }

        let match = self.match(
            childNode,
            at: childNode.key == nil ? matching.unkeyedSoFar : index,
            rendered: matching.unkeyed,
            byManualId: matching.byManualId,
            byKey: matching.byKey,
            claimed: matching.claimed)

        if childNode.key == nil {
            matching.unkeyedSoFar += 1
        }

        if let match = match {
            matching.claimed.insert(match.id)
        }

        var id = match?.id ?? identity(for: childNode)

        // A backstop for a variant that still collided, which it should not.
        if matching.used.contains(id) {
            id = .auto(allocateElementId())
        }

        matching.used.insert(id)
        return (id, match, childNode)
    }

    /// The children walked, said to the host: the last render's that were not continued forgotten, and the
    /// arrangement sent only when it changed.
    @inline(never)
    private func arranged(
        _ children: [RenderedNode], _ patches: [HostPatch], after matching: ChildMatching, into patch: inout HostPatch
    ) {
        for child in matching.rendered where !matching.claimed.contains(child.id) {
            forget(child)
        }

        if describeAll || children.map(\.id) != matching.rendered.map(\.id) {
            patch.children = .arranged(patches)
        } else {
            let changed = patches.filter { !$0.isEmpty }
            patch.children = changed.isEmpty ? .unchanged : .changed(changed)
        }
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
        claimed: Set<ElementID>
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

    /// Says a repeated identity once: one value written twice, or two values that describe themselves alike.
    /// Design: docs/design/core/identity-and-diffing.md#repeated-ids
    static func sayRepeated(_ id: String, first: AnyHashable?, again: AnyHashable?) {
        if let first, let again, first != again {
            complain("two different identities describe alike as \"\(id)\": a description that says less than the "
                + "value - a class prints its type's name - gives two values one identity; identify each by what it "
                + "holds (`id: \\.path`).")
        } else {
            complain("two siblings share the identity \"\(id)\": the second is told apart by where it stands, not by "
                + "what it is; give each its own (`id:`).")
        }
    }
}

/// The last render's children as this render's are matched against them - by the author's `.id()`, by the builder
/// path, by position - and what the matching has claimed and used so far, behind a reference the walk's frame holds.
/// Design: docs/design/core/identity-and-diffing.md#the-walks-stack
@MainActor
final class ChildMatching {
    let rendered: [RenderedNode]
    var byManualId: [String: RenderedNode] = [:]
    var byKey: [String: RenderedNode] = [:]

    /// Nodes put in by hand, matched by position among themselves.
    let unkeyed: [RenderedNode]

    var claimed: Set<ElementID> = []
    var used: Set<ElementID> = []
    var unkeyedSoFar = 0
    var manualSeen: [String: (count: Int, identity: AnyHashable?)] = [:]

    init(_ rendered: [RenderedNode]) {
        self.rendered = rendered
        unkeyed = rendered.filter { $0.key == nil }
        for child in rendered {
            if case .manual(let key) = child.id {
                byManualId[key] = child
            }

            // First wins, so two elements claiming one path behave like a repeated `.id()`.
            if let key = child.key, byKey[key] == nil {
                byKey[key] = child
            }
        }
    }
}
