// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// A sheet is a state of the view presenting it: built while it shows, closed as the state says - by the user's
// dismissal written back, and by the view leaving.
// Design: docs/design/views/pages.md#a-sheet-is-a-state

extension View {
    /// Presents what `content` describes in the platform's sheet over the window while the state holds true, both
    /// ways: the user dismissing it - a swipe, Escape, the way back - writes false, and so does this view leaving.
    ///
    ///     @State private var editing = false
    ///
    ///     Button("Edit")
    ///         .onClicked { editing = true }
    ///         .sheet(isPresented: $editing) {
    ///             Button("Done").onClicked { editing = false }
    ///         }
    ///
    /// A sheet has no bar of its own - a `NavigationStack` in it brings one, in the look of the bar over the view
    /// presenting it. A sheet declared in a sheet stands over
    /// it; its content is built while it shows. A view holds one sheet: written again, it stands in.
    ///
    /// - Parameters:
    ///   - state: whether the sheet shows, written false as it closes.
    ///   - content: what the sheet shows.
    /// - Returns: this view, with its sheet.
    public func sheet<Content: View>(
        isPresented state: Binding<Bool>, @ViewBuilder content: @escaping () -> Content
    ) -> Modified {
        presenting(SheetElement(
            page: { state.wrappedValue ? Node.page(content()) : nil },
            read: { state.wrappedValue }, write: { state.wrappedValue = $0 }))
    }

    /// Presents the page `content` makes of a value while the state holds one: the user dismissing it writes nil,
    /// and so does this view leaving. Another value presents another page in its place.
    ///
    ///     @State private var editing: String?
    ///
    ///     Button("Edit Inbox")
    ///         .onClicked { editing = "Inbox" }
    ///         .sheet(item: $editing) { folder in
    ///             Text(folder)
    ///         }
    ///
    /// - Parameters:
    ///   - state: the value the sheet shows, nil while none shows; written nil as it closes.
    ///   - content: what the sheet shows of the value.
    /// - Returns: this view, with its sheet.
    public func sheet<Item: Hashable, Content: View>(
        item state: Binding<Item?>, @ViewBuilder content: @escaping (Item) -> Content
    ) -> Modified {
        let page: @MainActor () -> Node? = {
            state.wrappedValue.map { item in
                var page = Node.page(content(item))
                page.identify(item)
                return page
            }
        }
        return presenting(SheetElement(
            page: page, read: { state.wrappedValue != nil }, write: { if !$0 { state.wrappedValue = nil } }))
    }

    /// This view with `sheet` after its own children: one, written again it stands in.
    /// Design: docs/design/views/modifiers.md#slot-children
    private func presenting(_ sheet: SheetElement) -> Modified {
        modified {
            $0.children.removeAll { $0.type == SheetContract.nodeType }
            $0.children.append(sheet.node)
        }
    }
}

/// The sheet a view declares, holding the page it presents while it shows.
struct SheetElement: ElementView {
    var node: Node

    /// `page` presented while `read` says so, the user's dismissal written through `write` - described, never
    /// carried by the host: the view presenting it builds again as it changes, its page with it; leaving the tree
    /// writes false.
    init(
        page: @escaping @MainActor () -> Node?, read: @escaping @MainActor () -> Bool,
        write: @escaping @MainActor (Bool) -> Void
    ) {
        node = Node(contract: SheetContract.self)
        self = described(
            SheetContract.isPresented.token, read: read, write: write, on: SheetContract.isPresentedChanged.token)
        // The page, made as the sheet is described: the sheet reads its state, never the body that presents it.
        node.readsWhenDescribed { $0.children.insert(contentsOf: page().map { [$0] } ?? [], at: 0) }
        node.destroying.append { if read() { write(false) } }
    }
}
