// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// `ActivityIndicator`'s own properties, shared by the control and its
/// `Style<ActivityIndicator>`.
public protocol ActivityIndicatorProperties: PropertyContainer {}

extension ActivityIndicatorProperties {
    /// Whether it is spinning. A still indicator is invisible on most
    /// platforms, so this alone shows and hides it.
    public func isRunning(_ value: Bool) -> Modified {
        setValue(ActivityIndicatorContract.isRunning, value)
    }
}

/// The spinner shown while something is happening that has no measurable
/// length.
///
///     @State private var loading = false
///     …
///     ActivityIndicator(loading)
///         .tint(.firebrick)
///
/// For work whose progress can be measured, use a `ProgressBar`: a spinner
/// says "wait", a bar says "how much longer".
public struct ActivityIndicator: View, TintElement, ActivityIndicatorProperties {
    /// The node this control describes.
    public var node: Node

    /// An empty one - what a `Style<ActivityIndicator>` is written against.
    public init() {
        node = Node(contract: ActivityIndicatorContract.self)
    }

    /// A spinner, spinning or still - and still is invisible on most
    /// platforms, so `ActivityIndicator(loading)` shows only while work runs.
    public init(_ isRunning: Bool) {
        node = Node(contract: ActivityIndicatorContract.self)
        node.write(ActivityIndicatorContract.isRunning, isRunning)
    }
}

extension ActivityIndicator {
    /// `isRunning` from a state, `$x`: the host sets each new value as it
    /// stands, and no view is rebuilt for it.
    public func isRunning(_ state: Binding<Bool>) -> Modified {
        plain(.isRunning, by: state)
    }
}
