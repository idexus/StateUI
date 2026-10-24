// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// `Spinner`'s own properties, shared by the control and its
/// `Style<Spinner>`.
public protocol SpinnerProperties: PropertyContainer {}

extension SpinnerProperties {
    /// Whether it is turning. A still spinner is invisible on most
    /// platforms, so this alone shows and hides it.
    public func isAnimating(_ value: Bool) -> Modified {
        setValue(SpinnerContract.isAnimating, value)
    }
}

/// A spinner, turning while something happens that has no measurable length.
///
///     @State private var loading = false
///     …
///     Spinner(loading)
///         .tint(.firebrick)
///
/// For work whose progress can be measured, use a `ProgressBar`: a spinner
/// says "wait", a bar says "how much longer".
public struct Spinner: ElementView, TintElement, SpinnerProperties {
    /// The node this control describes.
    public var node: Node

    /// An empty one - what a `Style<Spinner>` is written against.
    public init() {
        node = Node(contract: SpinnerContract.self)
    }

    /// A spinner, spinning or still - and still is invisible on most
    /// platforms, so `Spinner(loading)` shows only while work runs.
    public init(_ isAnimating: Bool) {
        node = Node(contract: SpinnerContract.self)
        node.write(SpinnerContract.isAnimating, isAnimating)
    }
}

extension Spinner {
    /// `isAnimating` from a state, `$x`: the host sets each new value as it
    /// stands, and no view is rebuilt for it.
    public func isAnimating(_ state: Binding<Bool>) -> Modified {
        twin(SpinnerContract.isAnimating, by: state)
    }
}
