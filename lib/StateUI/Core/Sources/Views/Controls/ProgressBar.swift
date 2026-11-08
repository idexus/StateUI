// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// How far along something is, from 0 to 1.
///
///     @State private var done = 0.0
///
///     ProgressBar(done)
///         .tint(.firebrick)
///
/// A fraction, not a percentage and not a count: 0.4 is four tenths of the
/// way through, so a job counting files divides by the total itself. For work with no measurable length, use an
/// `Spinner`.
///
/// `ProgressBar($done)` carries it from a state, animated to each new value.
public struct ProgressBar: ElementView, TintElement {
    /// The node this control describes.
    public var node: Node

    /// Empty, for an initializer to fill.
    init() {
        node = Node(contract: ProgressBarContract.self)
    }

    /// A bar filled `progress` of the way, from 0 to 1. The host clamps
    /// anything outside that.
    public init(_ progress: Double) {
        node = Node(contract: ProgressBarContract.self)
        node.write(ProgressBarContract.progress, progress)
    }

    /// A bar filled as far as `state` says, from 0 to 1: the host animates it to each new value, and no view is
    /// rebuilt for it.
    ///
    ///     ProgressBar($done)
    public init(_ state: Binding<Double>) {
        self = ProgressBar().progress(state)
    }
}

extension ProgressBar {
    /// How far along it is.
    func progress(_ value: Double) -> Modified {
        setValue(ProgressBarContract.progress, value)
    }

    /// How far along, from a state carried by the host as a journey.
    func progress(_ state: Binding<Double>) -> Modified {
        twin(ProgressBarContract.progress, by: state)
    }
}
