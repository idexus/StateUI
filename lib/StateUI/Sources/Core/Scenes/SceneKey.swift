// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// The name a scene keeps a value under, and what kind of value it is -
/// `@State(sceneKey:)`'s key. This library's own.
///
///     extension SceneKey {
///         static let section = SceneKey("section", of: Int.self)
///     }
///
///     @State(sceneKey: .section) private var section = 0
///
/// Each scene keeps its own value under the name, handed back with the scene when
/// the system restores it; where a platform restores no scenes, the value lives as
/// long as its scene. A value every scene shares is a `PersistentKey`.
public struct SceneKey: Hashable, Sendable, CustomStringConvertible {
    /// The name - what the value is written down under.
    public let name: String

    /// What kind of value it holds, taken from the type it was declared with.
    public let kind: PersistentKind

    /// A key from its name and the type of the value it keeps.
    ///
    /// - Parameters:
    ///   - name: the application's own name for it.
    ///   - type: the type of the state kept under it.
    public init<Value: PersistentValue>(_ name: String, of type: Value.Type) {
        self.name = name
        kind = Value.persistentKind
    }

    /// The name, so an interpolated diagnostic prints it plainly.
    public var description: String { name }
}
