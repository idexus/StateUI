// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// The keys StateUI makes for what it keys itself - a scene, a window - apart from any an author writes by the
/// record separator, which no author's description holds; a repeated id's variant keeps the group separator.
/// Design: docs/design/core/scenes.md#the-scene-tree
enum OwnKey {
    /// The separator no author's identity holds.
    static let separator = "\u{1E}"

    /// The key of the scene numbered `number`.
    static func scene(_ number: String) -> String {
        "scene\(separator)\(number)"
    }

    /// The key of a window of `kind` - nil for the group with no name - numbered `serial` in its scene.
    static func window(kind: String?, serial: Int) -> String {
        "\(kind ?? "window")\(separator)\(serial)"
    }

    /// The number of the scene `key` is the key of; nil for any other key.
    static func sceneNumber(of key: String) -> String? {
        let head = "scene\(separator)"
        return key.hasPrefix(head) ? String(key.dropFirst(head.count)) : nil
    }
}

@_spi(Host) extension ElementID {
    /// The key of the scene numbered `number`.
    public static func scene(_ number: String) -> ElementID {
        .manual(OwnKey.scene(number))
    }

    /// The key of the window numbered `serial` in its scene, of `kind` - nil for the group with no name.
    public static func window(_ serial: Int, kind: String? = nil) -> ElementID {
        .manual(OwnKey.window(kind: kind, serial: serial))
    }

    /// The number of the scene this key is the key of; nil for any other key.
    public var sceneNumber: String? {
        if case .manual(let name) = self { OwnKey.sceneNumber(of: name) } else { nil }
    }
}
