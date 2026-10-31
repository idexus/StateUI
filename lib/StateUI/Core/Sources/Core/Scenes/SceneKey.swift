// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// The name a scene keeps a value under, typed by the value it keeps -
/// `@State(sceneKey:)`'s key. This library's own.
///
///     extension SceneKey where Value == [Route] {
///         static let path = SceneKey("path")
///     }
///
///     @State(sceneKey: .path) private var path: [Route] = []
///
/// Each scene keeps its own value under the name - any `Codable`, written down
/// as text - handed back with the scene when the system restores it; where a
/// platform restores no scenes, the value lives as long as its scene. A value
/// every scene shares is a `PersistentKey`.
public struct SceneKey<Value: Codable>: Hashable, Sendable, CustomStringConvertible {
    /// The name - what the value is written down under.
    public var name: String { key.name }

    /// The name and the number the key is worked by (`KeyName`).
    let key: KeyName

    /// A key from the application's own name for it.
    public init(_ name: String) {
        key = KeyName(name)
    }

    /// The name, so an interpolated diagnostic prints it plainly.
    public var description: String { name }
}
