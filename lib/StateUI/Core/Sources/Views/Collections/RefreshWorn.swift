// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// One thing a list wears of the pull to refresh, put on the element showing it - its collection, or the scroller
/// its empty view stands in.
enum RefreshWorn {
    case requested(@MainActor () throws -> Void)
    case awaited(any Gate, EventHandler)
    case refreshing(Binding<Bool>)
    case enabled(Bool)
    case enabledBy(Binding<Bool>)

    /// `element` wearing `worn`, in the order written.
    @MainActor
    static func wear<Element: RefreshElement>(_ worn: [RefreshWorn], on element: Element) -> Element
    where Element.Modified == Element {
        worn.reduce(element) { element, worn in
            switch worn {
            case .requested(let handler): element.onRefreshRequested(handler)
            case .awaited(let gate, let handler): element.onRefreshRequested(gate: gate, handler)
            case .refreshing(let state): element.isRefreshing(state)
            case .enabled(let value): element.isRefreshEnabled(value)
            case .enabledBy(let state): element.isRefreshEnabled(state)
            }
        }
    }
}
