// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// Design: docs/design/core/identity-and-diffing.md#a-views-anchor

extension NodeType {
    /// What a view presents over others: written on a view keeping no node of its own, its anchor's.
    static let presented: Set<NodeType> = [.sheet, .popover]
}

extension Node {
    /// This node, of a view keeping no node of its own, with `change` written on it: where the view `flips`, what
    /// outlives the branch it shows on its anchor, made as the first of it is written, and the rest on what it builds.
    func writing(_ change: (inout Node) -> Void, flips: Bool) -> Node {
        var node = self
        change(&node)
        if node.type == .anchor {
            node.settle()
        } else if flips, node.outlivesBranches {
            node = node.anchored()
        }
        return node
    }

    /// Whether a view of this type may build one root or another while it stands: an `if/else`, a view of any type,
    /// or a view whose body is one, told by its type.
    static func flips<Shown: View>(_ shown: Shown.Type) -> Bool {
        if let flipping = shown as? any Flipping.Type { return flipping.flips }
        if shown is any ElementView.Type || Shown.Body.self is Never.Type { return false }
        return flips(Shown.Body.self)
    }

    /// Whether anything written here outlives the branch a view shows.
    var outlivesBranches: Bool {
        !watches.isEmpty || !created.isEmpty || !destroying.isEmpty || !hostEvents.isEmpty
            || children.contains { NodeType.presented.contains($0.type) }
    }

    /// An anchor holding this node, taking what of it outlives a branch, the environments it provides, and the
    /// identity written on a composed view.
    private func anchored() -> Node {
        var held = self
        var anchor = Node(contract: AnchorContract.self)
        swap(&anchor.watches, &held.watches)
        swap(&anchor.created, &held.created)
        swap(&anchor.destroying, &held.destroying)
        swap(&anchor.hostEvents, &held.hostEvents)
        swap(&anchor.environments, &held.environments)
        if held.stateful != nil { swap(&anchor.identity, &held.identity) }
        anchor.children = [held] + held.children.filter { NodeType.presented.contains($0.type) }
        anchor.children[0].children.removeAll { NodeType.presented.contains($0.type) }
        return anchor
    }

    /// This anchor keeping what outlives a branch, its environments and identity; the rest written on it lands on
    /// what it holds.
    private mutating func settle() {
        var written = Node(contract: AnchorContract.self)
        swap(&written.props, &props)
        swap(&written.driven, &driven)
        swap(&written.motion, &motion)
        swap(&written.events, &events)
        swap(&written.engines, &engines)
        swap(&written.pageValues, &pageValues)
        swap(&written.aim, &aim)
        swap(&written.samples, &samples)
        swap(&written.visualStates, &visualStates)
        swap(&written.visualStateListeners, &visualStateListeners)
        written.children = children.dropFirst().filter { !NodeType.presented.contains($0.type) }
        children = [children[0]] + children.dropFirst().filter { NodeType.presented.contains($0.type) }
        children[0].land(written)
        children[0].aim = written.aim ?? children[0].aim
        children[0].samples += written.samples
        children[0].visualStates += written.visualStates
        children[0].visualStateListeners += written.visualStateListeners
    }

    /// `written` - what is written on a view - landed on this node, the one the view builds, over what it says
    /// itself; on an anchor, on what the anchor holds.
    mutating func land(_ written: Node) {
        guard type != .anchor else { return children[0].land(written) }

        props.merge(written.props) { _, wrote in wrote }
        driven.merge(written.driven) { _, wrote in wrote }
        motion = MotionPlan.merged(motion, under: written.motion)
        for (name, handlers) in written.events.sorted(by: { $0.key < $1.key }) {
            addHandlers(name, handlers)
        }
        watches += written.watches
        created += written.created
        destroying += written.destroying
        hostEvents += written.hostEvents
        engines += written.engines
        children += written.children
        if let wrote = written.pageValues {
            pageValues = pageValues.map { $0.merged(under: wrote) } ?? wrote
        }
    }
}

/// A view telling by its type whether its root may change while it stands.
@MainActor
protocol Flipping {
    static var flips: Bool { get }
}

/// An `if/else` builds one branch or the other.
extension Either: Flipping where First: View, Second: View {
    static var flips: Bool { true }
}

/// A modifier keeps what its view builds.
extension ModifiedContent: Flipping {
    static var flips: Bool { Node.flips(Content.self) }
}

/// A view of any type cannot tell.
extension AnyView: Flipping {
    static var flips: Bool { true }
}
