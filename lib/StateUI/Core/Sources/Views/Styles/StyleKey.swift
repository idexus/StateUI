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
    public var name: String { key.name }

    /// The name and the number the key is worked by (`KeyName`).
    let key: KeyName

    /// A key named `name`, for styles of `Target`.
    public init(_ name: String) {
        key = KeyName(name)
    }

    /// A key already made.
    init(key: KeyName) {
        self.key = key
    }
}

extension StyleKey {
    /// The platform's own look: a control asking for it wears no style of the application's sheet - neither the one
    /// every control of its type wears nor one filed under a name.
    ///
    ///     Button("Delete").style(.platform).role(.destructive)
    public static var platform: Self { Self(key: platformStyle) }
}

/// The name the platform's own look is asked for by: none, which no style is filed under.
let platformStyle = KeyName("")

