// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

/// What a layout takes of its own box and its children's spacing, and a space or a fill of its box, the same on
/// every host.
@_spi(Host) public enum LayoutMembers {
    /// What a space or a fill takes of its box: what it is made of, its outline and its shape - it holds nothing to
    /// cut.
    public static let regionMembers = PropertyList(
        VisualElementContract.background,
        BorderElementContract.stroke, BorderElementContract.lineWidth, BorderElementContract.shape)

    /// What every layout takes of its own box: what fills it, its outline, its shape and its cut.
    public static let boxMembers = PropertyList(
        VisualElementContract.background,
        BorderElementContract.stroke, BorderElementContract.lineWidth, BorderElementContract.shape,
        LayoutContract.clipsContent)

    /// What both stacks take: the space between their children, and the space inside their own edge.
    public static let stackMembers = PropertyList(StackContract.spacing, PaddingElementContract.padding)

    /// What a row takes besides: whether it wraps, and the space between its lines (`StackArithmetic.Lines`).
    public static let rowMembers = PropertyList(HStackContract.wraps, HStackContract.rowSpacing)
}
