// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// Which shape a `GalleryView` stands its cards in; the cards animate from
/// one shape to the next.
public enum GalleryArrangement: Sendable, Equatable {
    /// The cards stand on a wheel: the one in the middle faces the user and
    /// the rest turn away, shrink and fade behind it.
    case `default`

    /// A hand of cards: the middle one stands tallest and its neighbours lean
    /// out and sink.
    case fan

    /// Side by side, the middle card largest - a strip to run along rather
    /// than a deck to look into.
    case row
}
