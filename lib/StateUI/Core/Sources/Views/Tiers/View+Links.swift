// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// The links a view hears: those the application is asked to open, given to the window it stands in.
// Design: docs/design/host/runtime.md#a-link-opened

extension View {
    /// Runs when the application is asked to open a link - one the user chose elsewhere, of a scheme the
    /// application's head registers - and gives it to the window this view stands in: its address.
    ///
    ///     NavigationStack($path) { NotesPage() } destination: { NotePage($0) }
    ///         .onLinkOpened { address in path = Route.path(for: address) }
    ///
    /// The view writes its own state, and its scene's through a binding. Every view of the window that hears
    /// links hears the same one, the outermost first.
    public func onLinkOpened(_ handler: @escaping @MainActor (String) throws -> Void) -> Modified {
        modified { $0.addHandler(ViewContract.linkOpened, handler) }
    }

    /// The same, with a handler that awaits - a sign-in finished in a browser exchanging its code: its `policy`
    /// says what a link does when it comes again while a run is under way.
    public func onLinkOpened(_ policy: GatePolicy, _ handler: @escaping ValueEventHandler<String>) -> Modified {
        modified { $0.addHandler(ViewContract.linkOpened, policy: policy, handler) }
    }

    /// The same, through `gate`, which every handler and task written with it shares.
    public func onLinkOpened(gate: Gate, _ handler: @escaping ValueEventHandler<String>) -> Modified {
        modified { $0.addHandler(ViewContract.linkOpened, gate: gate, handler) }
    }
}
