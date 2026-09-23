// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// `ProgressBar`'s own properties, shared by the control and its
/// `Style<ProgressBar>`.
public protocol ProgressBarProperties: PropertyContainer {}

extension ProgressBarProperties {
    /// How far along, as a fraction from 0 to 1. The host clamps anything
    /// outside that range.
    public func progress(_ value: Double) -> Modified {
        setValue(ProgressBarContract.progress, value)
    }
}

/// How far along something is, from 0 to 1.
///
///     @State private var done = 0.0
///
///     ProgressBar(done)
///         .tint(.firebrick)
///
/// A fraction, not a percentage and not a count: 0.4 is four tenths of the
/// way through, so a job counting files divides by the total itself. For work with no measurable length, use an
/// `ActivityIndicator`.
///
/// `.progress($done)` carries it from a state, animated to each new value.
public struct ProgressBar: View, TintElement, ProgressBarProperties {
    /// The node this control describes.
    public var node: Node

    /// An empty one - what a `Style<ProgressBar>` is written against.
    public init() {
        node = Node(contract: ProgressBarContract.self)
    }

    /// A bar filled `progress` of the way, from 0 to 1. The host clamps
    /// anything outside that.
    public init(_ progress: Double) {
        node = Node(contract: ProgressBarContract.self)
        node.write(ProgressBarContract.progress, progress)
    }
}

extension ProgressBar {
    /// `progress` from a state, `$x`: the host animates the property to each
    /// new value, and no view is rebuilt for it.
    public func progress(_ state: Binding<Double>) -> Modified {
        journey(.progress, by: state)
    }
}
