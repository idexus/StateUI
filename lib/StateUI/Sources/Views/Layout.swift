// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// The properties every layout has, shared by the control and its `Style`.
public protocol LayoutProperties: ViewProperties {}

/// A view that arranges children.
public protocol Layout: View, LayoutProperties, PaddingElement {}

extension LayoutProperties {
    /// Whether a child drawn outside the layout's bounds is cut off at them.
    public func clipsContent(_ value: Bool) -> Modified {
        setValue(LayoutContract.clipsContent, value)
    }

    /// Whether the layout's own empty area lets input through to whatever is
    /// behind it, while its children still answer - an overlay whose buttons
    /// float over a page that stays in reach.
    ///
    ///     Grid { panel }.letsInputThrough(true)
    ///
    /// `.ignoresInput(true)` is the other half: the view and everything in it
    /// let input through. Where both are set, `ignoresInput` wins.
    public func letsInputThrough(_ value: Bool) -> Modified {
        setValue(LayoutContract.letsInputThrough, value)
    }

    /// Which parts of the screen's unsafe strip - the notch, the bars, the
    /// on-screen keyboard - this layout stays clear of, one value for all four
    /// edges.
    ///
    ///     VStack { … }.avoidsSafeArea(.none)    // edge to edge
    ///
    /// iOS is where it shows; the other platforms have no unsafe strip and
    /// ignore it. A layout that stays clear of the strip is inset by it, so a
    /// header meant to reach the top edge wants `.none`: its content then sits
    /// where its padding says, and its frame fits that content.
    public func avoidsSafeArea(_ value: SafeArea) -> Modified {
        setValue(LayoutContract.avoidsSafeArea, .uniform(value))
    }

    /// The same, said for the horizontal and the vertical edges separately.
    ///
    ///     Grid { … }.avoidsSafeArea(.none, .container)
    ///
    /// Left and right take the first, top and bottom the second.
    ///
    /// - Parameters:
    ///   - horizontal: what the left and right edges stay clear of.
    ///   - vertical: what the top and bottom edges stay clear of.
    public func avoidsSafeArea(
        _ horizontal: SafeArea,
        _ vertical: SafeArea
    ) -> Modified {
        avoidsSafeArea(horizontal, vertical, horizontal, vertical)
    }

    /// The same, one edge at a time: left, top, right, bottom.
    ///
    /// - Parameters:
    ///   - left: what the left edge stays clear of.
    ///   - top: what the top edge stays clear of.
    ///   - right: what the right edge stays clear of.
    ///   - bottom: what the bottom edge stays clear of.
    public func avoidsSafeArea(
        _ left: SafeArea,
        _ top: SafeArea,
        _ right: SafeArea,
        _ bottom: SafeArea
    ) -> Modified {
        setValue(LayoutContract.avoidsSafeArea, .edges(left: left, top: top, right: right, bottom: bottom))
    }
}
