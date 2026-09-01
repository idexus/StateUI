// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// MAUI: RefreshView.

/// RefreshView's own properties - the half a `Style<RefreshView>` shares with the
/// control, beside what its tiers already carry. The control conforms on
/// the element side and the style on the property side, which is what
/// makes the same modifiers compile on both.
public protocol RefreshViewProperties: PropertyContainer {}

extension RefreshViewProperties {
    /// Whether the spinner is showing. MAUI: RefreshView.IsRefreshing.
    ///
    /// NOTHING clears it on its own. The pull raises it and the work's handler
    /// writes it back down, which is MAUI's contract for this control.
    ///
    /// One-way, and there is no `.isRefreshing($:)` beside it: the two-way form
    /// is the INITIALIZER, `RefreshView($refreshing) { … }`, where every other
    /// two-way control in this library spells it as a modifier of the same name.
    public func isRefreshing(_ value: Bool) -> Modified {
        setValue(.isRefreshing, .bool(value))
    }

    /// The colour of the spinner. MAUI: RefreshView.RefreshColor.
    public func refreshColor(_ value: Color) -> Modified {
        setValue(.refreshColor, value.propValue)
    }

    /// Whether a pull does anything at all - which is how refreshing is turned
    /// off without the view being taken away.
    /// MAUI: RefreshView.IsRefreshEnabled.
    public func isRefreshEnabled(_ value: Bool) -> Modified {
        setValue(.isRefreshEnabled, .bool(value))
    }
}

/// Pull down on what is inside it to ask for it again. MAUI: RefreshView.
///
///     @State private var refreshing = false
///
///     RefreshView($refreshing) {
///         ScrollView {
///             VStack { … }
///         }
///     }
///     .onRefreshing {
///         try await reload()
///         refreshing = false
///     }
///
/// The spinner is shown for as long as `isRefreshing` is true, and NOTHING sets
/// it back: the pull sets it, and the handler clears it when the work is done.
/// That is MAUI's contract, and it is what makes this binding unusual here: it
/// is written from both sides.
///
/// It goes AROUND the scroller rather than inside one - MAUI's RefreshView holds
/// a single scrollable view, and a pull is a gesture that scroller would
/// otherwise claim.
public struct RefreshView: View, DeferredContent, RefreshViewProperties {
    /// The node this control describes.
    public var node: Node

    /// An empty one - what a `Style<RefreshView>` is written against.
    public init() {
        node = Node(type: .refreshView)
    }

    /// A refreshable view around what the closure describes. One-way: the pull
    /// goes nowhere without `.onRefreshing`.
    /// The closure is kept and run when the differ describes the view.
    public init(@ViewBuilder content: @escaping () -> [Element]) {
        node = Node(type: .refreshView)
        node.producer = { content().map { $0.body } }
    }

    /// Two-way: shows the spinner while the binding is true, and writes back
    /// every move the platform makes - true when a pull starts one, false when
    /// a pull is abandoned before it does.
    ///
    /// Once the refresh has STARTED, clearing it is the handler's: nothing
    /// else ever writes false, and a spinner left turning is what forgetting
    /// looks like.
    public init(_ isRefreshing: Binding<Bool>, @ViewBuilder content: @escaping () -> [Element]) {
        node = Node(
            type: .refreshView,
            props: [.isRefreshing: .bool(isRefreshing.wrappedValue)])
        node.producer = { content().map { $0.body } }

        node.addHandler(.isRefreshingChanged) {
            if let refreshing = EventBuffer.current.value()?.bool {
                isRefreshing.wrappedValue = refreshing
            }
        }
    }

    // MARK: Properties

    // MARK: Events

    /// Runs when the user pulls. MAUI: RefreshView.Refreshing.
    ///
    /// Where the work goes, and where `isRefreshing` is cleared once it is done.
    /// Runs after a binding's write, if there is one.
    public func onRefreshing(_ handler: @escaping EventHandler) -> Self {
        addHandler(.refreshing, handler)
    }
}
