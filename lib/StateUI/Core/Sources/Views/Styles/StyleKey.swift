// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// The name a keyed style is asked for by, typed by the control it is for and declared once: a key misspelled, or
/// asked of another kind of control, does not compile.
///
///     extension StyleKey where Target == Button {
///         static let danger = StyleKey("Danger")
///     }
///
///     Style<Button>(.danger).background(.firebrick)
///     Button("Delete").style(.danger)
public struct StyleKey<Target: StyleTarget>: Hashable, Sendable {
    /// The name the style is kept under.
    public let name: String

    /// A key named `name`, for styles of `Target`.
    public init(_ name: String) {
        self.name = name
    }
}
