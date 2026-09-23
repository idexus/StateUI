// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// A closed vocabulary, numbered by StateUI: append a case, never insert one.
// Design: docs/design/types/vocabularies.md#written-out-and-appended

/// How a picture or a shape fills the room it was given, when the two are not
/// the same shape - what `.aspect` takes on an `Image` and on a shape alike.
///
/// Something has to give: the space, the edges, or the proportions.
public enum Aspect: Int32, Sendable {
    /// Fits it all in, keeping the proportions - so there may be space at the
    /// sides. The default.
    case fit = 0

    /// Covers the room, keeping the proportions - so the edges may be cut off.
    case fill = 1

    /// Fills the room, proportions and all - so it may be stretched.
    case stretch = 2

    /// Drawn at its own size, in the middle.
    case center = 3
}

extension Aspect: HostRepresentable {}
extension Aspect: StateChoice {}
