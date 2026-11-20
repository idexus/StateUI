// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// Which of a view's two rectangles is read: where its layout puts it, or where it is drawn.
///
///     Card()
///         .frame(into: $place)                           // where the layout puts it
///         .frame(into: $shown, stage: .presentation)     // where it is drawn now
///
/// The two are one while a view stands at its place with no transform. They part while it travels there, and
/// under a transform of its own: the layout's rectangle is at the destination at once, the presentation's follows
/// what is drawn.
/// Design: docs/design/host/runtime.md#two-rectangles
public enum GeometryStage: Equatable, Sendable {
    /// Where the view's layout puts it: its destination, whether or not the view has come there, with no transform.
    case layout

    /// The rectangle around what is drawn of the view: on its way to its place, and under its own transform.
    case presentation
}
