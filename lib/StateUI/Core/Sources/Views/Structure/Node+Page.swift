// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

extension Node {
    /// A view shown as a screen: an arrangement as it is - written there, or built by the view's body - and any
    /// other view on a page element of its own, which holds the view's `PageSession`. Told by the node it builds,
    /// so a branch's page is told the same way; the branch is part of what the page is.
    /// Design: docs/design/views/pages.md#a-page-around-a-view
    static func page(_ shown: some View) -> Node {
        let content = shown.node
        if content.isArrangement == true { return content }

        let kind = (content.stateful?.viewType ?? content.type.name) + (content.id.map { "#\($0)" } ?? "")
            + (content.key.map { "@\($0)" } ?? "")
        let request = ElementSession(PageSession.self) { PageSession() }

        var node = composed(ShownView(content: content), type: "StateUI.Page(\(kind))") {
            page(around: content, session: request.held(as: PageSession.self))
        }

        node.session = request
        return node
    }

    /// The page: the session's properties around its content.
    private static func page(around content: Node, session: PageSession) -> Node {
        var node = Node(contract: PageContract.self, children: [content])
        node.props = session.props

        node.addHandler(PageContract.appearing.token) { session.phase = .appearing }
        node.addHandler(PageContract.disappearing.token) { session.phase = .disappearing }
        node.addHandler(PageContract.navigatedTo.token) { session.phase = .navigatedTo }
        node.addHandler(PageContract.navigatingFrom.token) { session.phase = .navigatingFrom }
        node.addHandler(PageContract.navigatedFrom.token) { session.phase = .navigatedFrom }

        return node
    }
}

/// The view a page shows, held as a node so the view is compared on its own.
private struct ShownView {
    let content: Node
}
