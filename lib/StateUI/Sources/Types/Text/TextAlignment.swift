// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// A closed vocabulary, numbered by StateUI: append a case, never insert one.
// Design: docs/design/types/vocabularies.md#written-out-and-appended

/// Where text sits inside the space its own control was given.
///
/// What `.horizontalTextAlignment` and `.verticalTextAlignment` take. NOT
/// `.horizontalAlignment`, which moves the whole control inside its layout: a
/// label centred with this one still occupies the same box.
public enum TextAlignment: Int32, Sendable {
    /// Against the near edge - the left in a left-to-right language.
    case start = 0

    /// Centred.
    case center = 1

    /// Against the far edge.
    case end = 2
}

extension TextAlignment: HostRepresentable {}
extension TextAlignment: StateChoice {}
