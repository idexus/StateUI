// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

extension Node {
    /// A scene's window showing the page `page` builds, a view of `kind`, its scene's inspector docked in it where
    /// `inspector` reads a place: a placeholder built again when its session or that place moves, or it starts or
    /// stops docking one, its session offered on it.
    /// Design: docs/design/views/pages.md#a-window-is-a-placeholder
    static func window(
        showing page: @escaping () -> Node, kind: String, session: WindowSession,
        inspector: (() -> Inspector.Place?)? = nil
    ) -> Node {
        var window = composed(Shown(docks: inspector != nil), type: "StateUI.Window(\(kind))") {
            let overlay = Node.overlay(inspector: inspector?(), of: session.record?.id)

            // Its page, then the library's overlay: one order.
            // Design: docs/design/views/pages.md#the-children-of-a-window
            var node = Node(contract: WindowContract.self, children: [page()] + (overlay.map { [$0] } ?? []))
            node.props = session.props

            // One handler per lifecycle report, never iterated from a collection.
            // Design: docs/design/views/pages.md#lifecycle-reports-one-by-one
            node.addHandler(WindowContract.created.token, gate: .none) { session.phase = .created }
            node.addHandler(WindowContract.activated.token, gate: .none) { session.phase = .activated }
            node.addHandler(WindowContract.deactivated.token, gate: .none) { session.phase = .deactivated }
            node.addHandler(WindowContract.stopped.token, gate: .none) { session.phase = .stopped }
            node.addHandler(WindowContract.resumed.token, gate: .none) { session.phase = .resumed }
            node.addHandler(WindowContract.destroying.token, gate: .none) { session.phase = .destroying }

            return node
        }
        window.environments.append((key: ObjectIdentifier(WindowSession.self), object: session))
        return window
    }

    /// The scene's inspector docked at `place`, laid over every overlay a page declares; nil where none is.
    /// Design: docs/design/views/pages.md#the-children-of-a-window
    static func overlay(inspector place: Inspector.Place?, of scene: String?) -> Node? {
        guard let place, let scene else { return nil }

        var layer = ZStack().letsInputThrough(true).node
        layer.children = [InspectorPanel(scene: scene, place: place).node]
        return Node(contract: OverlayContract.self, children: [layer])
    }
}

/// What a window's placeholder is made of: whether it docks its scene's inspector.
private struct Shown {
    let docks: Bool
}
