// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// A view that is an element of its own: its node names its contract, and a
/// modifier gives the view back, so a chain keeps everything it offers. Every
/// control is one, and so is an element an application registers with a host
/// (`ElementContract` shows one).
///
/// A view the application composes from other views is a `View` with a
/// `body` instead.
public protocol ElementView: View where Modified == Self, Body == Never {}

extension ElementView {
    /// None: an element is described by its node.
    public var body: Never { fatalError("\(Self.self) is an element: it has a node and no body") }

    /// A copy with one property changed. What every modifier on a control is
    /// built from.
    public func modified(_ change: (inout Node) -> Void) -> Self {
        var copy = self
        change(&copy.node)
        return copy
    }
}

/// The body of an element, which has none.
extension Never: View {
    /// Never modified.
    public typealias Modified = Never

    /// Never built.
    public typealias Body = Never

    /// Never read.
    public var node: Node {
        get { fatalError() }
        set {}
    }

    /// Never called.
    public func modified(_ change: (inout Node) -> Void) -> Never { fatalError() }

    /// Never read.
    public var body: Never { fatalError() }
}
