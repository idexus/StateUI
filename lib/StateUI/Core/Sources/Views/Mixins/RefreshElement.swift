// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// An element the user pulls to refresh what it shows - a scroller, a list - with the platform's own pull and
/// spinner. A platform with no pull to refresh shows none, and a refresh is then the application's command.
public protocol RefreshElement: View {}

extension RefreshElement {
    /// Runs when the user pulls the element to refresh it; the element offers the pull once it hears it.
    ///
    ///     ScrollView { … }.onRefreshRequested { reload() }
    public func onRefreshRequested(_ handler: @escaping @MainActor () throws -> Void) -> Modified {
        onEvent(RefreshElementContract.refreshRequested, handler)
    }

    /// The same, with a handler that awaits - a reload does: its `policy` says what a pull does while a run is under
    /// way. The spinner shows while `isRefreshing` says so.
    ///
    ///     @State private var refreshing = false
    ///
    ///     ItemsView(mail) { MailRow($0) }
    ///         .isRefreshing($refreshing)
    ///         .onRefreshRequested(.ignoreWhileRunning) {
    ///             defer { refreshing = false }
    ///             try await inbox.reload()
    ///         }
    public func onRefreshRequested(_ policy: GatePolicy, _ handler: @escaping EventHandler) -> Modified {
        onEvent(RefreshElementContract.refreshRequested, policy: policy, handler)
    }

    /// The same, through `gate`, which every handler and task written with it shares.
    public func onRefreshRequested(gate: Gate, _ handler: @escaping EventHandler) -> Modified {
        onEvent(RefreshElementContract.refreshRequested, gate: gate, handler)
    }

    /// Whether the refresh is under way, both ways: the user's pull writes true into the state, and the
    /// application writes false once what it shows is fresh - or true, to show a refresh it began itself, which
    /// runs no `onRefreshRequested`. Without it, the spinner a pull shows goes at once.
    ///
    /// - Parameter state: the state the spinner follows, and the pull writes into.
    /// - Returns: the element, showing and reporting that state.
    public func isRefreshing(_ state: Binding<Bool>) -> Modified {
        plain(RefreshElementContract.isRefreshing.token, by: state, mode: .inOut)
    }

    /// Whether the user can pull to refresh - by default wherever the element hears the pull, through
    /// `onRefreshRequested` or `isRefreshing`; `false` withholds it while what it shows cannot be refreshed.
    public func isRefreshEnabled(_ value: Bool) -> Modified {
        setValue(RefreshElementContract.isRefreshEnabled, value)
    }

    /// `isRefreshEnabled` from a state, `$x`: the host sets each new value as it stands, and no view is rebuilt
    /// for it.
    public func isRefreshEnabled(_ state: Binding<Bool>) -> Modified {
        twin(RefreshElementContract.isRefreshEnabled, by: state)
    }
}
