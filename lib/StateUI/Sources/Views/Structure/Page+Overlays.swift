// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

extension PropertyContainer where Self: Page {
    /// Views laid over the window while the page this stands in is shown,
    /// declared where the state they follow lives.
    ///
    ///     VStack { … }
    ///         .overlays {
    ///             if !connection.isOnline {
    ///                 OfflineBanner()
    ///                     .horizontalAlignment(.center)
    ///                     .verticalAlignment(.start)
    ///             }
    ///         }
    ///
    /// The overlays are built with the body declaring them, so one comes and
    /// goes with the state it reads. Declared on a window's page they stand
    /// over every page the window shows, and every sheet; declared on a page,
    /// they stand while that page is shown and go with it. The overlays
    /// declared further in stand over those declared around them, and
    /// `.zIndex` reorders them. Each has the window's whole area and stands
    /// where its alignments put it; a touch beside it goes on to what is
    /// under it.
    ///
    /// - Parameter content: the views, in the order they stand, the last on
    ///   top.
    public func overlays(@ViewBuilder _ content: () -> [Element]) -> Modified {
        let views = content()
        return modified {
            var layer = ZStack().letsInputThrough(true).node
            layer.children = views.map(\.body)

            // After the element's own children; the host finds it by type.
            // Design: docs/design/views/modifiers.md#slot-children
            $0.children.append(Node(contract: OverlayContract.self, children: [layer]))
        }
    }
}
