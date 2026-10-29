// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

extension View {
    /// A view at the foot of the page, declared where the state it follows
    /// lives: the page's safe area ends above it.
    ///
    ///     Grid { ScrollView { messages } }
    ///         .ignoresSafeArea(.all)
    ///         .bottomBar {
    ///             HStack {
    ///                 TextEditor($draft).growsWithText(true)
    ///                 Button("Send").onClicked { send() }
    ///             }
    ///         }
    ///
    /// It stands as tall as it lays out, above the keyboard while one shows,
    /// and the page's content stands clear of it; a scroller let under
    /// scrolls under it, its last row stopping clear, and one at its end stays
    /// there as the bar grows. Declared around the page - on its stack or its
    /// window's page - it stands on every page shown there that declares
    /// none of its own; the innermost declaration wins.
    ///
    /// - Parameter content: one view - an `if`/`else` is one; put several
    ///   controls in a layout.
    public func bottomBar<Content: View>(@ViewBuilder _ content: () -> Content) -> Modified {
        var layer = ZStack().node
        layer.children = [content().node]
        return modified {
            // After the element's own children; the host finds it by type. The view stands in a layer of its own,
            // which places it as its values say: no layout arranges what a slot holds.
            // Design: docs/design/views/modifiers.md#slot-children
            $0.children.append(Node(contract: BottomBarContract.self, children: [layer]))
        }
    }
}
