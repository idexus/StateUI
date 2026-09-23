// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if MAUI

/// How much of an `ItemsView` is measured to know where each item goes -
/// which decides what a long list costs.
public enum ItemSizing: Sendable {
    /// One item is measured and every other one is given its length. The
    /// default.
    ///
    /// Where a slot sits is then one multiplication, so a hundred thousand
    /// items cost what ten do. Exact whenever the items are alike.
    case uniform

    /// Every item is measured, and each one is its own length, filed under its
    /// identity.
    ///
    /// For a feed whose posts are a line or a paragraph, a chat, a run of tags.
    /// Every item is walked to work out where the next one goes, so it suits
    /// tens or hundreds of items. An item that has never been in view has never
    /// been measured, and the length of the run is an estimate until it has.
    case individual
}

#endif
