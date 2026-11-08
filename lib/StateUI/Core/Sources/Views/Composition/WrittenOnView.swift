// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// What every view's modifiers wrote on one of the library's composed views, carried by the view itself.
/// Design: docs/design/views/modifiers.md#one-shape
@MainActor
struct WrittenOnView {
    private var written = Node(type: .composed)

    /// The placeholder `view`'s body is built under, with everything written on it.
    func node<Shown: View>(of view: Shown) -> Node {
        let made = Node.composed(view, type: typeKey(of: Shown.self), shown: Shown.self) { view.body.node }.stateful
        var node = written
        if node.type == .anchor { node.children[0].stateful = made } else { node.stateful = made }
        return node
    }

    /// Writes one modifier's change, as a `ModifiedContent` does.
    mutating func write<Shown: View>(_ change: (inout Node) -> Void, on shown: Shown.Type) {
        written = written.writing(change, flips: Node.flips(shown))
    }
}
