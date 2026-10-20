// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

extension Node {
    /// A view shown as a screen: an arrangement as it is - written there, or built by the view's body - and any
    /// other view on a page element of its own, which says what the view says of it. Told by the node it builds, so
    /// a branch's page is told the same way; the branch is part of what the page is.
    /// Design: docs/design/views/pages.md#a-page-around-a-view
    static func page(_ shown: some View) -> Node {
        let content = shown.node
        if content.isArrangement == true { return content }

        var kind = PathNumber().appending(content.stateful?.viewType.number ?? content.type.key.number)
        if let identity = content.identity { kind = kind.appending(UInt64(bitPattern: Int64(identity.number))) }
        if let key = content.key { kind = kind.appending(key.number) }

        return composed(ShownView(content: content), type: pageType) {
            var page = Node(contract: PageContract.self, children: [content])
            page.branch = kind
            return page
        }
    }

    /// What a page's placeholder is to the differ and the inspector: one kind for every page, each telling what it
    /// shows as its branch.
    private static let pageType = KeyName("StateUI.Page")
}

/// The view a page shows, held as a node so the view is compared on its own.
private struct ShownView {
    let content: Node
}
