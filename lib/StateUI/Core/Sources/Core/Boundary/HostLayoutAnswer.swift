// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// Design: docs/design/core/layout-program.md#the-answer

/// What a layout's program answers its host: where the layout puts each child, and how the child comes there.
@_spi(Host) public struct HostLayoutAnswer: Equatable, Sendable {
    /// One view a child, in the children's order.
    public var views: [HostLayoutView]

    /// An answer of `views`.
    public init(views: [HostLayoutView] = []) {
        self.views = views
    }
}

/// One child in a layout program's answer.
@_spi(Host) public struct HostLayoutView: Equatable, Sendable {
    /// The layout's own number for the child's item: the same while the item stands, whatever its place among the
    /// children.
    public var key: Int

    /// Where the layout puts the child at the parameters asked.
    public var target: HostPlacement

    /// How the child says it comes onto its place; nil for a child that says nothing, which its layout's bodies
    /// decide (`LayoutContract.layoutBodies`).
    public var body: LayoutBody?

    /// The child `key` at `target`.
    public init(key: Int, target: HostPlacement, body: LayoutBody? = nil) {
        self.key = key
        self.target = target
        self.body = body
    }
}

/// How a child comes onto the place its layout gives it, as the host runs it: a spring, and whether the child lags
/// behind a place that moves.
@_spi(Host) public struct HostLayoutBody: Equatable, Sendable {
    /// The spring's response, in milliseconds.
    public var milliseconds: Double

    /// The spring's damping.
    public var damping: Double

    /// Whether the child lags behind its place while the place moves; else the place carries it.
    public var follows: Bool

    /// A body on a spring answering in `milliseconds`, damped by `damping`.
    public init(milliseconds: Double, damping: Double, follows: Bool) {
        self.milliseconds = milliseconds
        self.damping = damping
        self.follows = follows
    }
}
