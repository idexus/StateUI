// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// A spinner, turning while something happens that has no measurable length.
///
///     @State private var loading = false
///     …
///     Spinner($loading)
///         .tint(.firebrick)
///
/// For work whose progress can be measured, use a `ProgressBar`: a spinner
/// says "wait", a bar says "how much longer".
public struct Spinner: ElementView, TintElement {
    /// The node this control describes.
    public var node: Node

    /// Empty, for an initializer to fill.
    init() {
        node = Node(contract: SpinnerContract.self)
    }

    /// A spinner, spinning or still - and still is invisible on most
    /// platforms, so `Spinner(loading)` shows only while work runs.
    public init(_ isAnimating: Bool) {
        node = Node(contract: SpinnerContract.self)
        node.write(SpinnerContract.isAnimating, isAnimating)
    }

    /// A spinner turning while `state` is true: the host sets each new value as it stands, and no view is rebuilt
    /// for it.
    ///
    ///     Spinner($loading)
    public init(_ state: Binding<Bool>) {
        self = Spinner().isAnimating(state)
    }
}

extension Spinner {
    /// Whether it is turning.
    func isAnimating(_ value: Bool) -> Modified {
        setValue(SpinnerContract.isAnimating, value)
    }

    /// Whether it is turning, from a state the host sets as it stands.
    func isAnimating(_ state: Binding<Bool>) -> Modified {
        twin(SpinnerContract.isAnimating, by: state)
    }
}
