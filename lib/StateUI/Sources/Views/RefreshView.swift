// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// `RefreshView`'s own properties, shared by the control and its
/// `Style<RefreshView>`.
public protocol RefreshViewProperties: PropertyContainer {}

extension RefreshViewProperties {
    /// Whether the spinner is showing. Nothing clears it on its own: the work's
    /// handler writes it back down. The two-way form is the initializer,
    /// `RefreshView($refreshing) { … }`.
    public func isRefreshing(_ value: Bool) -> Modified {
        setValue(RefreshViewContract.isRefreshing, value)
    }

    /// Whether a pull does anything at all - which is how refreshing is turned
    /// off without the view being taken away.
    public func isRefreshEnabled(_ value: Bool) -> Modified {
        setValue(RefreshViewContract.isRefreshEnabled, value)
    }
}

/// Pull down on what is inside it to ask for it again.
///
///     @State private var refreshing = false
///
///     RefreshView($refreshing) {
///         ScrollView {
///             VStack { … }
///         }
///     }
///     .onRefreshRequested {
///         try await reload()
///         refreshing = false
///     }
///
/// The spinner shows while `isRefreshing` is true: the pull sets it, and the
/// handler clears it when the work is done.
///
/// It goes around the scroller rather than inside one: it holds a single
/// scrollable view, whose own gesture would otherwise claim the pull.
public struct RefreshView: View, TintElement, RefreshViewProperties {
    /// The node this control describes.
    public var node: Node

    /// An empty one - what a `Style<RefreshView>` is written against.
    public init() {
        node = Node(contract: RefreshViewContract.self)
    }

    /// A refreshable view around what the closure describes. One-way: the pull
    /// goes nowhere without `.onRefreshRequested`.
    public init(@ViewBuilder content: @escaping () -> [Element]) {
        node = Node(contract: RefreshViewContract.self)
        node.producer = { content().map { $0.body } }
    }

    /// Two-way: shows the spinner while the binding is true, and writes back
    /// every move the platform makes - true when a pull starts one, false when
    /// a pull is abandoned before it does.
    ///
    /// Once the refresh has started, clearing it is the handler's: nothing else
    /// writes false.
    public init(_ isRefreshing: Binding<Bool>, @ViewBuilder content: @escaping () -> [Element]) {
        node = Node(contract: RefreshViewContract.self)
        node.producer = { content().map { $0.body } }

        // Handed over, or described where the host cannot carry the binding.
        // Design: docs/design/views/bindings.md#two-way-controls
        self = isRefreshing.image == nil
            ? described(.isRefreshing, isRefreshing, on: .isRefreshingChanged)
            : plain(.isRefreshing, by: isRefreshing, mode: .inOut)
    }

    // MARK: Events

    /// Runs when the user pulls: where the work goes, and where `isRefreshing`
    /// is cleared once it is done. Runs after a binding's write.
    public func onRefreshRequested(_ handler: @escaping EventHandler) -> Self {
        onEvent(RefreshViewContract.refreshRequested, handler)
    }
}

extension RefreshView {
    /// `isRefreshEnabled` from a state, `$x`: the host sets each new value as
    /// it stands, and no view is rebuilt for it.
    public func isRefreshEnabled(_ state: Binding<Bool>) -> Modified {
        plain(.isRefreshEnabled, by: state)
    }
}
