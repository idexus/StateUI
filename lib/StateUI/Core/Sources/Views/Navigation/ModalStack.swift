// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// The modal stack: what is presented over a window is an array the author
// holds, and a sheet the user dismisses shortens it.
// Design: docs/design/views/pages.md#the-modal-stack-is-the-state

/// The pages presented over a page, the last of them on top - standing as a
/// window's page, over everything the window shows.
///
///     enum Sheet: Hashable { case settings, about }
///
///     struct MainWindow: Window {
///         @State private var sheets: [Sheet] = []
///
///         var page: any Page {
///             ModalStack($sheets) {
///                 HomePage(sheets: $sheets)
///             } destination: { sheet in
///                 switch sheet {
///                 case .settings: SettingsPage(sheets: $sheets)
///                 case .about: AboutPage()
///                 }
///             }
///         }
///     }
///
/// Presenting a page is `sheets.append(.settings)`, closing it a `remove`, and
/// a sheet the user dismisses shortens the array itself. The page presented
/// needs the binding too, to close itself; the host picks the platform's own
/// modal presentation.
public struct ModalStack: Page, ModifiableElement, BarElement {
    /// The node this stack describes.
    public var node: Node

    /// A modal stack over the author's own type.
    ///
    /// - Parameters:
    ///   - sheets: what is presented, the first presented first and the last on
    ///     top - the author's own type, borrowed two-way. A sheet the user
    ///     dismisses shortens it.
    ///   - root: the page the sheets are presented over.
    ///   - destination: the page for one element, asked in stack order.
    public init<Sheet: Hashable>(
        _ sheets: Binding<[Sheet]>,
        @PageBuilder root: () -> any Page,
        @PageBuilder destination: (Sheet) -> any Page
    ) {
        var root = Node.page(root())
        root.id = Self.rootIdentity
        var children = [root]

        for (depth, sheet) in sheets.wrappedValue.enumerated() {
            var page = Node.page(destination(sheet))
            page.id = Self.identity(depth: depth, sheet: sheet)
            children.append(page)
        }

        node = Node(contract: ModalStackContract.self, children: children)

        // A sheet gone without this side saying so; the report only shortens.
        // Design: docs/design/views/pages.md#a-pop-report-only-shortens
        node.addHandler(ModalStackContract.popped.token) {
            guard let remaining = EventBuffer.current.value()?.int else { return }

            let presented = sheets.wrappedValue
            guard remaining >= 0, remaining < presented.count else { return }

            sheets.wrappedValue = Array(presented.prefix(remaining))
        }
    }

    private static let rootIdentity = "root"

    /// Who a presented page is: its depth and its value together.
    private static func identity(depth: Int, sheet: some Hashable) -> String {
        "\(depth)/\(String(describing: sheet))"
    }
}
