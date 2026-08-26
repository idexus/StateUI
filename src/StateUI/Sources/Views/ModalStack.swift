// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// What is presented OVER everything, owned by Swift like the rest of it.
//
// A modal page is not on any navigation stack and not in any tab: it covers the
// window, bars and all, and the reader deals with it before anything else. MAUI
// keeps them on `INavigation.ModalStack` and moves them with `PushModalAsync`
// and `PopModalAsync`; here that stack is an ARRAY THE AUTHOR HOLDS, of the
// author's own type, and the host brings the native stack to whatever the array
// says - the same bargain `NavigationPage` strikes, one level up.
//
//     enum Sheet: Hashable { case settings, about }
//
//     struct MainWindow: Window {
//         @State private var sheets: [Sheet] = []
//
//         var modalStack: ModalStack? {
//             ModalStack($sheets) { sheet in
//                 switch sheet {
//                 case .settings: SettingsPage(sheets: $sheets)
//                 case .about:    AboutPage(sheets: $sheets)
//                 }
//             }
//         }
//
//         var content: Page { HomePage(sheets: $sheets) }
//     }
//
// Presenting is `sheets.append(.settings)`, closing is `sheets.removeLast()`,
// and closing everything is `sheets = []`. There is no present call and no
// completion to await.
//
// It is a STACK because the platforms make it one: a sheet may present a sheet.
// One at a time is the ordinary case and it is `[]` or `[.settings]`.
//
// The reader can close one without asking - an iOS sheet is dragged down,
// Android's system back dismisses the top - so the host reports what SURVIVED
// after a modal has gone, and the array is truncated to match. Nothing is said
// while a drag is still in the reader's hand.

/// The pages presented over a window, the last of them on top.
/// MAUI: INavigation.ModalStack.
///
///     enum Sheet: Hashable { case settings }
///
///     struct MainWindow: Window {
///         @State private var sheets: [Sheet] = []
///
///         var modalStack: ModalStack? {
///             ModalStack($sheets) { sheet in
///                 switch sheet {
///                 case .settings: SettingsPage(sheets: $sheets)
///                 }
///             }
///         }
///
///         var content: Page { HomePage(sheets: $sheets) }
///     }
///
/// `sheets.append(.settings)` presents, `sheets.removeLast()` closes, and an
/// empty array is a window with nothing over it. As with a navigation path, the
/// page that presents and the page presented both need the BINDING - a page
/// given nothing has no way to close itself.
///
/// A modal page covers the bars as well as the content, so it carries its own
/// way out: put the button on it. What it LOOKS like is the page's own
/// `modalPresentationStyle`, which is iOS and Mac Catalyst only - everywhere
/// else a modal page is full screen.
///
/// A VALUE rather than a modifier, because a window is declared rather than
/// chained onto: the generic lives in the initializer, which is what lets a
/// window's `modalStack` be one plain property whatever the author's sheet type
/// is.
public struct ModalStack {
    /// The presented pages, as the host reads them.
    ///
    /// A wrapper node of its own, the way a page's toolbar items are: the host
    /// has a list to keep in step, and a list needs somewhere to be matched
    /// against that is not the window's own children - where the root page and
    /// the title bar already live.
    let node: Node

    /// What runs when the host says a modal has GONE, carrying how many are
    /// still presented. Written on the WINDOW's node, the modal stack being the
    /// window's - see `body` in Views/Application.swift.
    let popped: EventHandler

    /// A modal stack over the author's own type.
    ///
    /// - Parameter stack: what is presented, the FIRST element presented first
    ///   and the last of them on top - the author's own type, borrowed two-way.
    ///   A modal the reader dismisses truncates it.
    /// - Parameter destination: the page for one element, asked in stack order.
    public init<Sheet: Hashable>(
        _ stack: Binding<[Sheet]>,
        destination: (Sheet) -> Page
    ) {
        node = Node(
            type: .modalStack,
            children: stack.wrappedValue.enumerated().map { depth, sheet in
                var page = destination(sheet).body
                page.id = ModalStack.identity(depth: depth, sheet: sheet)
                return page
            })

        // A modal that has GONE without this side saying so - a sheet dragged
        // down, Android's back, the platform closing one because the page under
        // it was taken away. The payload is how many are still presented, and
        // the guard only ever shortens the array: a report as long as what is
        // described, or longer, has been overtaken and would otherwise put a
        // dismissed sheet back on the screen. The same rule the navigation
        // stack's `popped` follows, and for the same reason.
        popped = {
            guard let depth = EventBuffer.current.value()?.int else { return }

            let sheets = stack.wrappedValue
            guard depth >= 0, depth < sheets.count else { return }

            stack.wrappedValue = Array(sheets.prefix(depth))
        }
    }

    /// Who a presented page is: its DEPTH and its value together.
    ///
    /// Neither half is enough, exactly as on a navigation stack - depth alone
    /// would hand a page's `@State` to whatever replaced it, and the value alone
    /// cannot tell two identical sheets apart. See `NavigationPage`, where the
    /// same decision is written out at length.
    private static func identity(depth: Int, sheet: some Hashable) -> String {
        "\(depth)/\(String(describing: sheet))"
    }
}
