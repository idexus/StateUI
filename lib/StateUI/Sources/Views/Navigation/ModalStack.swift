// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// What is presented over a window: a stack of the author's own values.
// Design: docs/design/views/pages.md#the-modal-stack-is-a-value

/// The pages presented over a window, the last of them on top.
///
///     enum Sheet: Hashable { case settings }
///
///     window.modalStack = ModalStack($sheets) { sheet in
///         switch sheet {
///         case .settings: SettingsPage(sheets: $sheets)
///         }
///     }
///
/// Written once into `WindowSession.modalStack`: `sheets.append(.settings)`
/// presents, `sheets.removeLast()` closes, and a dismissal the user makes
/// shortens the array. The page presented needs the binding too, to close
/// itself; the host picks the platform's own modal presentation.
public struct ModalStack {
    /// The presented pages under a wrapper node, built as the window builds.
    /// Design: docs/design/views/pages.md#the-modal-stack-is-a-value
    var node: Node { build() }

    private let build: () -> Node

    /// Runs on the window's node when a modal has gone, with how many remain.
    let popped: EventHandler

    /// A modal stack over the author's own type.
    ///
    /// - Parameter stack: what is presented, the FIRST element presented first
    ///   and the last of them on top - the author's own type, borrowed two-way.
    ///   A modal the user dismisses truncates it.
    /// - Parameter destination: the page for one element, asked in stack order.
    public init<Sheet: Hashable>(
        _ stack: Binding<[Sheet]>,
        destination: @escaping (Sheet) -> any Page
    ) {
        build = {
            Node(
                contract: ModalStackContract.self,
                children: stack.wrappedValue.enumerated().map { depth, sheet in
                    var page = Node.page(destination(sheet))
                    page.id = ModalStack.identity(depth: depth, sheet: sheet)
                    return page
                })
        }

        // A modal gone without this side saying so; the report only shortens.
        // Design: docs/design/views/pages.md#a-pop-report-only-shortens
        popped = {
            guard let depth = EventBuffer.current.value()?.int else { return }

            let sheets = stack.wrappedValue
            guard depth >= 0, depth < sheets.count else { return }

            stack.wrappedValue = Array(sheets.prefix(depth))
        }
    }

    /// Who a presented page is: its depth and its value together.
    private static func identity(depth: Int, sheet: some Hashable) -> String {
        "\(depth)/\(String(describing: sheet))"
    }
}
